module Couchbase
  module ActiveModel

    def self.included(base)
      base.class_eval do
        extend ::ActiveModel::Callbacks
        extend ::ActiveModel::Naming
        include ::ActiveModel::Conversion
        include ::ActiveModel::Validations
        include ::ActiveModel::Validations::Callbacks
        include ::ActiveModel::Dirty

        define_model_callbacks :create, :update, :delete, :destroy, :save, :initialize
        [:save, :create, :update, :delete, :destroy, :initialize].each do |meth|
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
    end

    # Public: Allows for access to ActiveModel functionality.
    #
    # Returns self.
    def to_model
      self
    end

    # Public: Hashes our unique key instead of the entire object.
    # Ruby normally hashes an object to be used in comparisons.  In our case
    # we may have two techincally different objects referencing the same entity id,
    # so we will hash just the class and id (via to_key) to compare so we get the
    # expected result
    #
    # Returns a string representing the unique key.
    def hash
      to_param.hash
    end

    # Public: Overrides eql? to use == in the comparison.
    #
    # other - Another object to compare to
    #
    # Returns a boolean.
    def eql?(other)
      self == other
    end

    # Public: Overrides == to compare via class and entity id.
    #
    # other - Another object to compare to
    #
    # Example
    #
    #     movie = Movie.find(1234)
    #     movie.to_key
    #     # => 'movie-1234'
    #
    # Returns a string representing the unique key.
    def ==(other)
      hash == other.hash
    end

  end
end
