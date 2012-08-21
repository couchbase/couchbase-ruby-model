# Author:: Couchbase <info@couchbase.com>
# Copyright:: 2012 Couchbase, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'digest/md5'

require 'couchbase'
require 'couchbase/model/version'
require 'couchbase/model/uuid'
require 'couchbase/model/configuration'

unless Object.respond_to?(:singleton_class)
  require 'couchbase/model/ext/singleton_class'
end

module Couchbase

  # @since 0.0.1
  class Error::MissingId < Error::Base; end

  # Declarative layer for Couchbase gem
  #
  # @since 0.0.1
  #
  #  require 'couchbase/model'
  #
  #  class Post < Couchbase::Model
  #    attribute :title
  #    attribute :body
  #    attribute :draft
  #  end
  #
  #  p = Post.new(:id => 'hello-world',
  #               :title => 'Hello world',
  #               :draft => true)
  #  p.save
  #  p = Post.find('hello-world')
  #  p.body = "Once upon the times...."
  #  p.save
  #  p.update(:draft => false)
  #  Post.bucket.get('hello-world')  #=> {"title"=>"Hello world", "draft"=>false,
  #                                  #    "body"=>"Once upon the times...."}
  #
  # You can also let the library generate the unique identifier for you:
  #
  #  p = Post.create(:title => 'How to generate ID',
  #                  :body => 'Open up the editor...')
  #  p.id        #=> "74f43c3116e788d09853226603000809"
  #
  # There are several algorithms available. By default it use `:sequential`
  # algorithm, but you can change it to more suitable one for you:
  #
  #  class Post < Couchbase::Model
  #    attribute :title
  #    attribute :body
  #    attribute :draft
  #
  #    uuid_algorithm :random
  #  end
  #
  # You can define connection options on per model basis:
  #
  #  class Post < Couchbase::Model
  #    attribute :title
  #    attribute :body
  #    attribute :draft
  #
  #    connect :port => 80, :bucket => 'blog'
  #  end
  class Model
    # Each model must have identifier
    #
    # @since 0.0.1
    attr_accessor :id

    # @since 0.2.0
    attr_reader :key

    # @since 0.2.0
    attr_reader :value

    # @since 0.2.0
    attr_reader :doc

    # @since 0.2.0
    attr_reader :meta

    # @private Container for all attributes with defaults of all subclasses
    @@attributes = ::Hash.new {|hash, key| hash[key] = {}}

    # @private Container for all view names of all subclasses
    @@views = ::Hash.new {|hash, key| hash[key] = []}

    # Use custom connection options
    #
    # @since 0.0.1
    #
    # @param [String, Hash, Array] options options for establishing
    #   connection.
    # @return [Couchbase::Bucket]
    #
    # @see Couchbase::Bucket#initialize
    #
    # @example Choose specific bucket
    #   class Post < Couchbase::Model
    #     connect :bucket => 'posts'
    #     ...
    #   end
    def self.connect(*options)
      self.bucket = Couchbase.connect(*options)
    end

    # Associate custom design document with the model
    #
    # Design document is the special document which contains views, the
    # chunks of code for building map/reduce indexes. When this method
    # called without argument, it just returns the effective design document
    # name.
    #
    # @since 0.1.0
    #
    # @see http://www.couchbase.com/docs/couchbase-manual-2.0/couchbase-views.html
    #
    # @param [String, Symbol] name the name for the design document. By
    #   default underscored model name is used.
    # @return [String] the effective design document
    #
    # @example Choose specific design document name
    #   class Post < Couchbase::Model
    #     design_document :my_posts
    #     ...
    #   end
    def self.design_document(name = nil)
      if name
        @_design_doc = name.to_s
      else
        @_design_doc ||= begin
                           name = self.name.dup
                           name.gsub!(/::/, '_')
                           name.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
                           name.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
                           name.downcase!
                         end
      end
    end

    # Ensure that design document is up to date.
    #
    # @since 0.1.0
    #
    # This method also cares about organizing view in separate javascript
    # files. The general structure is the following (+[root]+ is the
    # directory, one of the {Model::Configuration.design_documents_paths}):
    #
    #   [root]
    #   |
    #   `- link
    #   |  |
    #   |  `- by_created_at
    #   |  |  |
    #   |  |  `- map.js
    #   |  |
    #   |  `- by_session_id
    #   |  |  |
    #   |  |  `- map.js
    #   |  |
    #   |  `- total_views
    #   |  |  |
    #   |  |  `- map.js
    #   |  |  |
    #   |  |  `- reduce.js
    #
    # The directory structure above demonstrate layout for design document
    # with id +_design/link+ and three views: +by_create_at+,
    # +by_session_id` and `total_views`.
    def self.ensure_design_document!
      unless Configuration.design_documents_paths
        raise "Configuration.design_documents_path must be directory"
      end

      doc = {'_id' => "_design/#{design_document}", 'views' => {}}
      digest = Digest::MD5.new
      mtime = 0
      views.each do |name|
        doc['views'][name] = view = {}
        ['map', 'reduce'].each do |type|
          Configuration.design_documents_paths.each do |path|
            ff = File.join(path, design_document.to_s, name.to_s, "#{type}.js")
            if File.file?(ff)
              view[type] = File.read(ff).strip
              mtime = [mtime, File.mtime(ff).to_i].max
              digest << view[type]
              break # pick first matching file
            end
          end
        end
        doc['views'].delete(name) if view.empty?
      end
      doc['signature'] = digest.to_s
      doc['timestamp'] = mtime
      if doc['signature'] != thread_storage[:signature] && doc['timestamp'] > thread_storage[:timestamp].to_i
        current_doc = bucket.design_docs[design_document.to_s]
        if current_doc.nil? || (current_doc['signature'] != doc['signature'] && doc['timestamp'] > current_doc[:timestamp].to_i)
          bucket.save_design_doc(doc)
          current_doc = doc
        end
        thread_storage[:signature] = current_doc['signature']
        thread_storage[:timestamp] = current_doc['timestamp'].to_i
      end
    end

    # Choose the UUID generation algorithms
    #
    # @since 0.0.1
    #
    # @param [Symbol] algorithm (:sequential) one of the available
    #   algorithms.
    #
    # @see Couchbase::UUID#next
    #
    # @example Select :random UUID generation algorithm
    #   class Post < Couchbase::Model
    #     uuid_algorithm :random
    #     ...
    #   end
    #
    # @return [Symbol]
    def self.uuid_algorithm(algorithm)
      self.thread_storage[:uuid_algorithm] = algorithm
    end

    # Defines an attribute for the model
    #
    # @since 0.0.1
    #
    # @param [Symbol, String] name name of the attribute
    #
    # @example Define some attributes for a model
    #  class Post < Couchbase::Model
    #    attribute :title
    #    attribute :body
    #    attribute :published_at
    #  end
    #
    #  post = Post.new(:title => 'Hello world',
    #                  :body => 'This is the first example...',
    #                  :published_at => Time.now)
    def self.attribute(*names)
      options = {}
      if names.last.is_a?(Hash)
        options = names.pop
      end
      names.each do |name|
        attributes[name] = options[:default]
        name = name.to_sym
        next if self.instance_methods.include?(name)
        define_method(name) do
          @_attributes[name]
        end
        define_method(:"#{name}=") do |value|
          @_attributes[name] = value
        end
      end
    end

    # Defines a view for the model
    #
    # @since 0.0.1
    #
    # @param [Symbol, String, Array] names names of the views
    # @param [Hash] options options passed to the {Couchbase::View}
    #
    # @example Define some views for a model
    #  class Post < Couchbase::Model
    #    view :all, :published
    #    view :by_rating, :include_docs => false
    #  end
    #
    #  post = Post.find("hello")
    #  post.by_rating.each do |r|
    #    # ...
    #  end
    def self.view(*names)
      options = {:wrapper_class => self, :include_docs => true}
      if names.last.is_a?(Hash)
        options.update(names.pop)
      end
      names.each do |name|
        views << name
        singleton_class.send(:define_method, name) do |*params|
          params = options.merge(params.first || {})
          View.new(bucket, "_design/#{design_document}/_view/#{name}", params)
        end
      end
    end

    # Find the model using +id+ attribute
    #
    # @since 0.0.1
    #
    # @param [String, Symbol] id model identificator
    # @return [Couchbase::Model] an instance of the model
    # @raise [Couchbase::Error::NotFound] when given key isn't exist
    #
    # @example Find model using +id+
    #   post = Post.find('the-id')
    def self.find(id)
      if id && (res = bucket.get(id, :quiet => false, :extended => true))
        obj, flags, cas = res
        new({:id => id, :meta => {'flags' => flags, 'cas' => cas}}.merge(obj))
      end
    end

    # Find the model using +id+ attribute
    #
    # @since 0.1.0
    #
    # @param [String, Symbol] id model identificator
    # @return [Couchbase::Model, nil] an instance of the model or +nil+ if
    #   given key isn't exist
    #
    # @example Find model using +id+
    #   post = Post.find_by_id('the-id')
    def self.find_by_id(id)
      if id && (res = bucket.get(id, :quiet => true))
        obj, flags, cas = res
        new({:id => id, :meta => {'flags' => flags, 'cas' => cas}}.merge(obj))
      end
    end

    # Create the model with given attributes
    #
    # @since 0.0.1
    #
    # @param [Hash] args attribute-value pairs for the object
    # @return [Couchbase::Model] an instance of the model
    def self.create(*args)
      new(*args).create
    end

    # Constructor for all subclasses of Couchbase::Model
    #
    # @since 0.0.1
    #
    # Optionally takes a Hash of attribute value pairs.
    #
    # @param [Hash] attrs attribute-value pairs
    def initialize(attrs = {})
      if attrs.respond_to?(:with_indifferent_access)
        attrs = attrs.with_indifferent_access
      end
      @id = attrs.delete(:id)
      @key = attrs.delete(:key)
      @value = attrs.delete(:value)
      @doc = attrs.delete(:doc)
      @meta = attrs.delete(:meta)
      @_attributes = ::Hash.new do |h, k|
        default = self.class.attributes[k]
        h[k] = if default.respond_to?(:call)
                 default.call
               else
                 default
               end
      end
      update_attributes(@doc || attrs)
    end

    # Create this model and assign new id if necessary
    #
    # @since 0.0.1
    #
    # @return [Couchbase::Model] newly created object
    #
    # @raise [Couchbase::Error::KeyExists] if model with the same +id+
    #   exists in the bucket
    #
    # @example Create the instance of the Post model
    #   p = Post.new(:title => 'Hello world', :draft => true)
    #   p.create
    def create
      @id ||= Couchbase::Model::UUID.generator.next(1, model.thread_storage[:uuid_algorithm])
      model.bucket.add(@id, attributes_with_values)
      self
    end

    # Create or update this object based on the state of #new?.
    #
    # @since 0.0.1
    #
    # @return [Couchbase::Model] The saved object
    #
    # @example Update the Post model
    #   p = Post.find('hello-world')
    #   p.draft = false
    #   p.save
    def save
      return create if new?
      model.bucket.set(@id, attributes_with_values)
      self
    end

    # Update this object, optionally accepting new attributes.
    #
    # @since 0.0.1
    #
    # @param [Hash] attrs Attribute value pairs to use for the updated
    #               version
    # @return [Couchbase::Model] The updated object
    def update(attrs)
      update_attributes(attrs)
      save
    end

    # Delete this object from the bucket
    #
    # @since 0.0.1
    #
    # @note This method will reset +id+ attribute
    #
    # @return [Couchbase::Model] Returns a reference of itself.
    #
    # @example Delete the Post model
    #   p = Post.find('hello-world')
    #   p.delete
    def delete
      raise Couchbase::Error::MissingId, "missing id attribute" unless @id
      model.bucket.delete(@id)
      @id = nil
      self
    end

    # Check if the record have +id+ attribute
    #
    # @since 0.0.1
    #
    # @return [true, false] Whether or not this object has an id.
    #
    # @note +true+ doesn't mean that record exists in the database
    #
    # @see Couchbase::Model#exists?
    def new?
      !@id
    end

    # Check if the key exists in the bucket
    #
    # @since 0.0.1
    #
    # @param [String, Symbol] id the record identifier
    # @return [true, false] Whether or not the object with given +id+
    #   presented in the bucket.
    def self.exists?(id)
      !!bucket.get(id, :quiet => true)
    end

    # Check if this model exists in the bucket.
    #
    # @since 0.0.1
    #
    # @return [true, false] Whether or not this object presented in the
    #   bucket.
    def exists?
      model.exists?(@id)
    end

    # All defined attributes within a class.
    #
    # @since 0.0.1
    #
    # @see Model.attribute
    #
    # @return [Hash]
    def self.attributes
      @@attributes[self]
    end

    # All defined views within a class.
    #
    # @since 0.1.0
    #
    # @see Model.view
    #
    # @return [Array]
    def self.views
      @@views[self]
    end

    # All the attributes of the current instance
    #
    # @since 0.0.1
    #
    # @return [Hash]
    def attributes
      @_attributes
    end

    # Update all attributes without persisting the changes.
    #
    # @since 0.0.1
    #
    # @param [Hash] attrs attribute-value pairs.
    def update_attributes(attrs)
      if id = attrs.delete(:id)
        @id = id
      end
      attrs.each do |key, value|
        setter = :"#{key}="
        send(setter, value) if respond_to?(setter)
      end
    end

    # Reload all the model attributes from the bucket
    #
    # @since 0.0.1
    #
    # @return [Model] the latest model state
    #
    # @raise [Error::MissingId] for records without +id+
    #   attribute
    def reload
      raise Couchbase::Error::MissingId, "missing id attribute" unless @id
      attrs = model.find(@id).attributes
      update_attributes(attrs)
      self
    end

    # @private The thread local storage for model specific stuff
    #
    # @since 0.0.1
    def self.thread_storage
      Couchbase.thread_storage[self] ||= {:uuid_algorithm => :sequential}
    end

    # @private Fetch the current connection
    #
    # @since 0.0.1
    def self.bucket
      self.thread_storage[:bucket] ||= Couchbase.bucket
    end

    # @private Set the current connection
    #
    # @since 0.0.1
    #
    # @param [Bucket] connection the connection instance
    def self.bucket=(connection)
      self.thread_storage[:bucket] = connection
    end

    # @private Get model class
    #
    # @since 0.0.1
    def model
      self.class
    end

    # @private Wrap the hash to the model class.
    #
    # @since 0.0.1
    #
    # @param [Bucket] bucket the reference to Bucket instance
    # @param [Hash] data the Hash fetched by View, it should have at least
    #   +"id"+, +"key"+ and +"value"+ keys, also it could have optional
    #   +"doc"+ key.
    #
    # @return [Model]
    def self.wrap(bucket, data)
      doc = {
        :id => data['id'],
        :key => data['key'],
        :value => data['value']
      }
      if data['doc']
        doc[:meta] = data['doc']['meta']
        doc[:doc] = data['doc']['json']
      end
      new(doc)
    end

    # @private Returns a string containing a human-readable representation
    # of the record.
    #
    # @since 0.0.1
    def inspect
      attrs = []
      attrs << ["key", @key.inspect] unless @key.nil?
      attrs << ["value", @value.inspect] unless @value.nil?
      model.attributes.map do |attr, default|
        val = @_attributes[attr]
        attrs << [attr.to_s, val.inspect] unless val.nil?
      end
      attrs.sort!
      attrs.unshift([:id, id]) unless new?
      sprintf("#<%s %s>", model, attrs.map{|a| a.join(": ")}.join(", "))
    end

    def self.inspect
      buf = "#{name}"
      if self != Couchbase::Model
        buf << "(#{['id', attributes.map(&:first)].flatten.join(', ')})"
      end
      buf
    end

    protected

    # @private Returns a hash with model attributes
    #
    # @since 0.1.0
    def attributes_with_values
      ret = {:type => model.design_document}
      model.attributes.keys.each do |attr|
        ret[attr] = @_attributes[attr]
      end
      ret
    end
  end

end
