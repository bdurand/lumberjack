# frozen_string_literal: true

module Lumberjack
  module Rack
    # Rack middleware that establishes a scoped Lumberjack global context for
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
      #
      # @example Static attributes
      #   Context.new(app, {
      #     service: "api",
      #     environment: "production"
      #   })
      #
      # @example Dynamic attributes using Procs
      #   Context.new(app, {
      #     request_id: ->(env) { env["HTTP_X_REQUEST_ID"] || SecureRandom.uuid },
      #     ip_address: ->(env) { env["REMOTE_ADDR"] },
      #     user_agent: ->(env) { env["HTTP_USER_AGENT"]&.truncate(100) }
      #   })
      def initialize(app, env_attributes = nil)
        @app = app
        @env_attributes = env_attributes
      end

      # Process a Rack request within a scoped Lumberjack logging context. This method
      # creates an isolated logging context for the request duration, applies any
      # configured environment attributes, processes the request, and automatically
      # cleans up the context when the request completes.
      #
      # The context isolation ensures that logging attributes set during one request
      # don't affect subsequent requests, providing clean separation in multi-threaded
      # or concurrent request scenarios.
      #
      # @param env [Hash] The Rack environment hash containing request information
      # @return [Array] The standard Rack response array [status, headers, body]
      #
      # @example Request processing flow
      #   # 1. Create scoped logging context
      #   # 2. Apply environment attributes if configured
      #   # 3. Process request through application stack
      #   # 4. Automatically clean up context on completion
      def call(env)
        Lumberjack.context do
          apply_attributes(env) if @env_attributes
          @app.call(env)
        end
      end

      private

      # Apply configured environment attributes to the current logging context.
      # This method processes the env_attributes configuration, evaluating any
      # Proc values with the request environment and applying the resulting
      # attributes to the logging context.
      #
      # @param env [Hash] The Rack environment hash
      # @return [void]
      #
      # @example Attribute processing
      #   # Static value: { service: "api" } -> { service: "api" }
      #   # Proc value: { request_id: ->(env) { env["HTTP_X_REQUEST_ID"] } }
      #   #   -> { request_id: "abc-123-def" }
      def apply_attributes(env)
        attributes = @env_attributes.transform_values do |value|
          value.is_a?(Proc) ? value.call(env) : value
        end
        Lumberjack.tag(attributes)
      end
    end
  end
end
