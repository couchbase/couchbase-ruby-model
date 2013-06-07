module Couchbase
  module ActiveModel

    def included(base)
      return unless defined?(::ActiveModel)

      base.class_eval do
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
    end

  end
end
