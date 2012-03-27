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

require 'couchbase'
require 'couchbase/model/version'
require 'couchbase/model/uuid'

module Couchbase

  class Error::MissingId < Error::Base; end

  # Declarative layer for Couchbase gem
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
    attr_accessor :id

    # @private Container for all attributes with defaults of all subclasses
    @@attributes = ::Hash.new {|hash, key| hash[key] = {}}

    # Use custom connection options
    #
    # @param [String, Hash, Array] options for establishing connection.
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

    # Choose the UUID generation algorithms
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
    def self.uuid_algorithm(algorithm)
      self.thread_storage[:uuid_algorithm] = algorithm
    end

    # Defines an attribute for the model
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
        define_method(name) do
          @_attributes[name]
        end
        define_method(:"#{name}=") do |value|
          @_attributes[name] = value
        end
        attributes[name] = options[:default]
      end
    end

    # Find the model using +id+ attribute
    #
    # @param [String, Symbol] id model identificator
    # @return [Couchbase::Model] an instance of the model
    #
    # @example Find model using +id+
    #   post = Post.find('the-id')
    def self.find(id)
      if id && (obj = bucket.get(id))
        new({:id => id}.merge(obj))
      end
    end

    # Create the model with given attributes
    #
    # @param [Hash] args attribute-value pairs for the object
    # @return [Couchbase::Model] an instance of the model
    def self.create(*args)
      new(*args).create
    end

    # Constructor for all subclasses of Couchbase::Model, which optionally
    # takes a Hash of attribute value pairs.
    #
    # @param [Hash] attrs attribute-value pairs
    def initialize(attrs = {})
      @id = nil
      @_attributes = ::Hash.new do |h, k|
        default = self.class.attributes[k]
        h[k] = if default.respond_to?(:call)
                 default.call
               else
                 default
               end
      end
      update_attributes(attrs)
    end

    # Create this model and assign new id if necessary
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
    # @param [Hash] attrs Attribute value pairs to use for the updated
    #               version
    # @return [Couchbase::Model] The updated object
    def update(attrs)
      update_attributes(attrs)
      save
    end

    # Delete this object from the bucket
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
    # @param [String, Symbol] id the record identifier
    # @return [true, false] Whether or not the object with given +id+
    #   presented in the bucket.
    def self.exists?(id)
      !!bucket.get(id, :quiet => true)
    end

    # Check if this model exists in the bucket.
    #
    # @return [true, false] Whether or not this object presented in the
    #   bucket.
    def exists?
      model.exists?(@id)
    end

    # All the defined attributes within a class.
    #
    # @see Model.attribute
    def self.attributes
      @@attributes[self]
    end

    # All the attributes of the current instance
    #
    # @return [Hash]
    def attributes
      @_attributes
    end

    # Update all attributes without persisting the changes.
    #
    # @param [Hash] attrs attribute-value pairs.
    def update_attributes(attrs)
      if id = attrs.delete(:id)
        @id = id
      end
      attrs.each do |key, value|
        send(:"#{key}=", value)
      end
    end

    # Reload all the model attributes from the bucket
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
    def self.thread_storage
      Couchbase.thread_storage[self] ||= {:uuid_algorithm => :sequential}
    end

    # @private Fetch the current connection
    def self.bucket
      self.thread_storage[:bucket] ||= Couchbase.bucket
    end

    # @private Set the current connection
    #
    # @param [Bucket] connection the connection instance
    def self.bucket=(connection)
      self.thread_storage[:bucket] = connection
    end

    # @private Get model class
    def model
      self.class
    end

    # @private Wrap the hash to the model class
    #
    # @param [Model, Hash] the Couchbase::Model subclass or the
    #   attribute-value pairs
    def self.wrap(object)
      object.class == self ? object : new(object)
    end

    # @private Returns a string containing a human-readable representation
    # of the record.
    def inspect
      attrs = model.attributes.sort.map do |attr|
        [attr, @_attributes[attr].inspect]
      end
      sprintf("#<%s:%s %s>",
              model, new? ? "?" : id,
              attrs.map{|a| a.join("=")}.join(" "))
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
