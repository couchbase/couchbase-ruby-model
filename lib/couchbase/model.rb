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
unless "".respond_to?(:constantize)
  require 'couchbase/model/ext/constantize'
end
unless "".respond_to?(:camelize)
  require 'couchbase/model/ext/camelize'
end

module Couchbase

  # @since 0.0.1
  class Error::MissingId < Error::Base; end

  # @since 0.4.0
  class Error::RecordInvalid < Error::Base
    attr_reader :record
    def initialize(record)
      @record = record
      if @record.errors
        super(@record.errors.full_messages.join(", "))
      else
        super("Record invalid")
      end
    end
  end

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

    # @since 0.4.5
    attr_reader :errors

    # @since 0.4.5
    attr_reader :raw

    # @private Container for all attributes with defaults of all subclasses
    @@attributes = {}

    # @private Container for all view names of all subclasses
    @@views = {}

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

    def self.defaults(options = nil)
      if options
        @_defaults = options
      else
        @_defaults || {}
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
      views.each do |name, _|
        doc['views'][name] = {}
        doc['spatial'] = {}
        ['map', 'reduce', 'spatial'].each do |type|
          Configuration.design_documents_paths.each do |path|
            ff = File.join(path, design_document.to_s, name.to_s, "#{type}.js")
            if File.file?(ff)
              contents = File.read(ff).gsub(/^\s*\/\/.*$\n\r?/, '').strip
              next if contents.empty?
              mtime = [mtime, File.mtime(ff).to_i].max
              digest << contents
              case type
              when 'map', 'reduce'
                doc['views'][name][type] = contents
              when 'spatial'
                doc['spatial'][name] = contents
              end
              break # pick first matching file
            end
          end
        end
      end

      doc['views'].delete_if {|_, v| v.empty? }
      doc.delete('spatial') if doc['spatial'] && doc['spatial'].empty?
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

    def read_attribute(attr_name)
      @_attributes[attr_name]
    end

    def write_attribute(attr_name, value)
      @_attributes[attr_name] = value
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
        name = name.to_sym
        attributes[name] = options[:default]
        next if self.instance_methods.include?(name)
        define_method(name) do
          read_attribute(name)
        end
        define_method(:"#{name}=") do |value|
          write_attribute(name, value)
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
      is_spatial = options.delete(:spatial)
      names.each do |name|
        path = "_design/%s/_%s/%s" % [design_document, is_spatial ? "spatial" : "view", name]
        views[name] = lambda do |*params|
          params = options.merge(params.first || {})
          View.new(bucket, path, params)
        end
        singleton_class.send(:define_method, name, &views[name])
      end
    end

    # Defines a belongs_to association for the model
    #
    # @since 0.3.0
    #
    # @param [Symbol, String] name name of the associated model
    # @param [Hash] options association options
    # @option options [String, Symbol] :class_name the name of the
    #   association class
    #
    # @example Define some association for a model
    #  class Brewery < Couchbase::Model
    #    attribute :name
    #  end
    #
    #  class Beer < Couchbase::Model
    #    attribute :name, :brewery_id
    #    belongs_to :brewery
    #  end
    #
    #  Beer.find("heineken").brewery.name
    def self.belongs_to(name, options = {})
      ref = "#{name}_id"
      attribute(ref)
      assoc = name.to_s.camelize.constantize
      define_method(name) do
        assoc.find(self.send(ref))
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
        obj = {:raw => obj} unless obj.is_a?(Hash)
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
      if id && (res = bucket.get(id, :quiet => true, :extended => true))
        obj, flags, cas = res
        obj = {:raw => obj} unless obj.is_a?(Hash)
        new({:id => id, :meta => {'flags' => flags, 'cas' => cas}}.merge(obj))
      end
    end

    # Create the model with given attributes
    #
    # @since 0.0.1
    #
    # @param [Hash] args attribute-value pairs for the object
    # @return [Couchbase::Model, false] an instance of the model
    def self.create(*args)
      new(*args).create
    end

    # Creates an object just like {{Model.create} but raises an exception if
    # the record is invalid.
    #
    # @since 0.5.1
    # @raise [Couchbase::Error::RecordInvalid] if the instance is invalid
    def self.create!(*args)
      new(*args).create!
    end

    # Constructor for all subclasses of Couchbase::Model
    #
    # @since 0.0.1
    #
    # Optionally takes a Hash of attribute value pairs.
    #
    # @param [Hash] attrs attribute-value pairs
    def initialize(attrs = {})
      @errors = ::ActiveModel::Errors.new(self) if defined?(::ActiveModel)
      @_attributes = ::Hash.new do |h, k|
        default = self.class.attributes[k]
        h[k] = if default.respond_to?(:call)
                 default.call
               else
                 default
               end
      end
      case attrs
      when Hash
        if defined?(HashWithIndifferentAccess) && !attrs.is_a?(HashWithIndifferentAccess)
          attrs = attrs.with_indifferent_access
        end
        @id = attrs.delete(:id)
        @key = attrs.delete(:key)
        @value = attrs.delete(:value)
        @doc = attrs.delete(:doc)
        @meta = attrs.delete(:meta)
        @raw = attrs.delete(:raw)
        update_attributes(@doc || attrs)
      else
        @raw = attrs
      end
    end

    # Create this model and assign new id if necessary
    #
    # @since 0.0.1
    #
    # @return [Couchbase::Model, false] newly created object
    #
    # @raise [Couchbase::Error::KeyExists] if model with the same +id+
    #   exists in the bucket
    #
    # @example Create the instance of the Post model
    #   p = Post.new(:title => 'Hello world', :draft => true)
    #   p.create
    def create(options = {})
      @id ||= Couchbase::Model::UUID.generator.next(1, model.thread_storage[:uuid_algorithm])
      if respond_to?(:valid?) && !valid?
        return false
      end
      options = model.defaults.merge(options)
      value = (options[:format] == :plain) ?  @raw : attributes_with_values
      unless @meta
        @meta = {}
        if @meta.respond_to?(:with_indifferent_access)
          @meta = @meta.with_indifferent_access
        end
      end
      @meta['cas'] = model.bucket.add(@id, value, options)
      self
    end

    # Creates an object just like {{Model#create} but raises an exception if
    # the record is invalid.
    #
    # @since 0.5.1
    #
    # @raise [Couchbase::Error::RecordInvalid] if the instance is invalid
    def create!(options = {})
      create(options) || raise(Couchbase::Error::RecordInvalid.new(self))
    end

    # Create or update this object based on the state of #new?.
    #
    # @since 0.0.1
    #
    # @param [Hash] options options for operation, see
    #   {{Couchbase::Bucket#set}}
    #
    # @return [Couchbase::Model, false] saved object or false if there
    #   are validation errors
    #
    # @example Update the Post model
    #   p = Post.find('hello-world')
    #   p.draft = false
    #   p.save
    #
    # @example Use CAS value for optimistic lock
    #   p = Post.find('hello-world')
    #   p.draft = false
    #   p.save('cas' => p.meta['cas'])
    #
    def save(options = {})
      return create(options) unless @meta
      if respond_to?(:valid?) && !valid?
        return false
      end
      options = model.defaults.merge(options)
      value = (options[:format] == :plain) ?  @raw : attributes_with_values
      @meta['cas'] = model.bucket.replace(@id, value, options)
      self
    end

    # Creates an object just like {{Model#save} but raises an exception if
    # the record is invalid.
    #
    # @since 0.5.1
    #
    # @raise [Couchbase::Error::RecordInvalid] if the instance is invalid
    def save!(options = {})
      save(options) || raise(Couchbase::Error::RecordInvalid.new(self))
    end

    # Update this object, optionally accepting new attributes.
    #
    # @since 0.0.1
    #
    # @param [Hash] attrs Attribute value pairs to use for the updated
    #               version
    # @param [Hash] options options for operation, see
    #   {{Couchbase::Bucket#set}}
    # @return [Couchbase::Model] The updated object
    def update(attrs, options = {})
      update_attributes(attrs)
      save(options)
    end

    # Delete this object from the bucket
    #
    # @since 0.0.1
    #
    # @note This method will reset +id+ attribute
    #
    # @param [Hash] options options for operation, see
    #   {{Couchbase::Bucket#delete}}
    # @return [Couchbase::Model] Returns a reference of itself.
    #
    # @example Delete the Post model
    #   p = Post.find('hello-world')
    #   p.delete
    def delete(options = {})
      raise Couchbase::Error::MissingId, "missing id attribute" unless @id
      model.bucket.delete(@id, options)
      @id = nil
      @meta = nil
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

    # @return [true, false] Where on on this object persisted in the storage
    def persisted?
      !!@id
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
      @attributes ||= if self == Model
                        @@attributes.dup
                      else
                        couchbase_ancestor.attributes.dup
                      end
    end

    # All defined views within a class.
    #
    # @since 0.1.0
    #
    # @see Model.view
    #
    # @return [Array]
    def self.views
      @views ||= if self == Model
                   @@views.dup
                 else
                   couchbase_ancestor.views.dup
                 end
    end

    # Returns the first ancestor that is also a Couchbase::Model ancestor.
    #
    # @return Class
    def self.couchbase_ancestor
      ancestors[1..-1].each do |ancestor|
        return ancestor if ancestor.ancestors.include?(Couchbase::Model)
      end
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

    # Format the model for use in a JSON response
    #
    # @since 0.5.2
    #
    # @return [Hash] a JSON representation of the model for REST APIs
    #
    def as_json(options = {})
      attributes.merge({:id => @id}).as_json(options)
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
        doc[:doc] = data['doc']['value'] || data['doc']['json']
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
        val = read_attribute(attr)
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

    # @private Returns a hash with model attributes
    #
    # @since 0.1.0
    def attributes_with_values
      ret = {:type => model.design_document}
      model.attributes.keys.each do |attr|
        ret[attr] = read_attribute(attr)
      end
      ret
    end

    protected :attributes_with_values

    if defined?(::ActiveModel)
      extend ActiveModel::Callbacks
      extend ActiveModel::Naming
      include ActiveModel::Conversion
      include ActiveModel::Validations

      define_model_callbacks :create, :update, :delete, :save
      [:save, :create, :update, :delete].each do |meth|
        class_eval <<-EOC
          alias #{meth}_without_callbacks #{meth}
          def #{meth}(*args, &block)
            run_callbacks(:#{meth}) do
              #{meth}_without_callbacks(*args, &block)
            end
          end
        EOC
      end
    end

    # Redefine (if exists) #to_key to use #key if #id is missing
    def to_key
      keys = [id || key]
      keys.empty? ? nil : keys
    end

    def to_param
      keys = to_key
      if keys && !keys.empty?
        keys.join("-")
      end
    end
  end

end
