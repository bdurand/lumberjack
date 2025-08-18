# frozen_string_literal: true

module Lumberjack
  module Rack
    # Middleware to create a global context for Lumberjack for the scope of a rack request.
    #
    # The optional `env_attributes` parameter can be used to set up global attributes from the request
    # environment. This is useful for setting attributes that are relevant to the entire request
    # like the request id, host, etc.
    class Context
      # @param [Object] app The rack application.
      # @param [Hash] env_attributes A hash of attributes to set from the request environment. If an attribute value is
      #   a Proc, it will be called with the request `env` as an argument to allow dynamic attribute values
      #   based on request data.
      def initialize(app, env_attributes = nil)
        @app = app
        @env_attributes = env_attributes
      end

      def call(env)
        Lumberjack.context do
          apply_attributes(env) if @env_attributes
          @app.call(env)
        end
      end

      private

      def apply_attributes(env)
        attributes = @env_attributes.transform_values do |value|
          value.is_a?(Proc) ? value.call(env) : value
        end
        Lumberjack.tag(attributes)
      end
    end
  end
end
