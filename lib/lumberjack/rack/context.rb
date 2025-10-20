# frozen_string_literal: true

module Lumberjack
  module Rack
    # Rack middleware ensures that a global Lumberjack context exists for
    # the duration of each HTTP request. This middleware creates an isolated
    # logging context that automatically cleans up after the request completes,
    # ensuring that request-specific attributes don't leak between requests.
    #
    # The middleware supports dynamic attribute extraction from the Rack environment,
    # allowing automatic tagging of log entries with request-specific information
    # such as request IDs, user agents, IP addresses, or any other data available
    # in the Rack environment.
    #
    # This is particularly useful in web applications where you want to correlate
    # all log entries within a single request with common identifying information,
    # making it easier to trace request flows and debug issues.
    #
    # @example Basic usage in a Rack application
    #   use Lumberjack::Rack::Context
    #
    # @example With static attributes
    #   use Lumberjack::Rack::Context, {
    #     app_name: "MyWebApp",
    #     version: "1.2.3"
    #   }
    #
    # @example With dynamic attributes from request environment
    #   use Lumberjack::Rack::Context, {
    #     request_id: ->(env) { env["HTTP_X_REQUEST_ID"] },
    #     user_agent: ->(env) { env["HTTP_USER_AGENT"] },
    #     remote_ip: ->(env) { env["REMOTE_ADDR"] },
    #     method: ->(env) { env["REQUEST_METHOD"] },
    #     path: ->(env) { env["PATH_INFO"] }
    #   }
    #
    # @example Rails integration
    #   # In config/application.rb
    #   config.middleware.use Lumberjack::Rack::Context, {
    #     request_id: ->(env) { env["action_dispatch.request_id"] },
    #     session_id: ->(env) { env["rack.session"]&.id },
    #     user_id: ->(env) { env["warden"]&.user&.id }
    #   }
    #
    # @see Lumberjack.context
    # @see Lumberjack.tag
    class Context
      # Initialize the middleware with the Rack application and optional environment
      # attribute configuration. The middleware will create a scoped logging context
      # for each request and automatically apply the specified attributes.
      #
      # @param app [Object] The next Rack application in the middleware stack
      # @param env_attributes [Hash, nil] Optional hash defining attributes to extract
      #   from the request environment. Values can be:
      #   - Static values: Applied directly to all requests
      #   - Proc objects: Called with the Rack env hash to generate dynamic values
      #   - Any callable: Invoked with env to produce request-specific attributes
      def initialize(app, env_attributes = nil)
        @app = app
        @env_attributes = env_attributes
      end

      # Process a Rack request within a scoped Lumberjack logging context.
      #
      # @param env [Hash] The Rack environment hash containing request information
      # @return [Array] The standard Rack response array [status, headers, body]
      def call(env)
        Lumberjack.ensure_context do
          apply_attributes(env) if @env_attributes
          @app.call(env)
        end
      end

      private

      # Apply configured environment attributes to the current logging context.
      #
      # @param env [Hash] The Rack environment hash
      # @return [void]
      def apply_attributes(env)
        attributes = @env_attributes.transform_values do |value|
          value.is_a?(Proc) ? value.call(env) : value
        end
        Lumberjack.tag(attributes)
      end
    end
  end
end
