# frozen_string_literal: true

module Lumberjack
  # ForkedLogger provides an isolated logging context that forwards all log entries to a parent logger
  # while maintaining its own independent configuration (level, progname, attributes).
  #
  # This class allows you to create specialized logger instances that:
  # - Inherit initial configuration from a parent logger
  # - Maintain isolated settings (level, progname, attributes) that don't affect the parent
  # - Forward all log entries to the parent logger's output device
  # - Combine their own attributes with the parent logger's attributes
  # - Provide scoped logging behavior without duplicating output infrastructure
  #
  # ForkedLogger is particularly useful for:
  #
  # - Component isolation: Give each component its own logger with specific attributes
  # - Request tracing: Create request-specific loggers with request IDs
  # - Temporary debugging: Create debug-level loggers for specific code paths
  # - Library integration: Allow libraries to have their own logging configuration
  # - Multi-tenant logging: Isolate tenant-specific logging configuration
  #
  # The forked logger inherits the parent's initial state but changes are isolated:
  #
  # - Inherited: Initial level, progname, and device (through forwarding)
  # - Isolated: subsequent changes to level, progname, and attributes do not affect the parent logger
  # - Combined: attributes from the parent and the forked loggers are merged when logging
  #
  # @example Basic forked logger
  #   parent = Lumberjack::Logger.new(STDOUT, level: :info)
  #   forked = Lumberjack::ForkedLogger.new(parent)
  #   forked.level = :debug  # Only affects the forked logger
  #   forked.debug("Debug message")  # Logged because forked logger is debug level
  #
  # @example Component-specific logging
  #   main_logger = Lumberjack::Logger.new("/var/log/app.log")
  #   db_logger = Lumberjack::ForkedLogger.new(main_logger)
  #   db_logger.progname = "Database"
  #   db_logger.tag!(component: "database", version: "1.2.3")
  #   db_logger.info("Connection established")  # Includes component attributes and different progname
  #
  # @example Request-scoped logging
  #   def handle_request(request_id)
  #     request_logger = Lumberjack::ForkedLogger.new(@logger)
  #     request_logger.tag!(request_id: request_id, user_id: current_user.id)
  #
  #     request_logger.info("Processing request")  # Includes request context
  #     # ... process request ...
  #     request_logger.info("Request completed")   # All logs tagged with request info
  #   end
  #
  # @see Lumberjack::Logger
  # @see Lumberjack::ContextLogger
  # @see Lumberjack::Context
  class ForkedLogger < Logger
    include ContextLogger

    # The parent logger that receives all log entries from this forked logger.
    # @return [Lumberjack::Logger, #add_entry] The parent logger instance.
    attr_reader :parent_logger

    # Create a new forked logger that forwards all log entries to the specified parent logger.
    # The forked logger inherits the parent's initial level and progname but maintains
    # its own independent context for future changes.
    #
    # @param logger [Lumberjack::ContextLogger, #add_entry] The parent logger to forward entries to.
    #   Must respond to either +add_entry+ (for Lumberjack loggers) or standard Logger methods.
    def initialize(logger)
      init_fiber_locals!
      @parent_logger = logger
      @context = Context.new
      @context.level ||= logger.level
      @context.progname ||= logger.progname
    end

    # Forward a log entry to the parent logger with the forked logger's configuration applied.
    # This method coordinates between the forked logger's settings and the parent logger's
    # output capabilities.
    #
    # @param severity [Integer, Symbol, String] The severity level of the log entry.
    # @param message [Object] The message to log.
    # @param progname [String, nil] The program name (defaults to this logger's progname).
    # @param attributes [Hash, nil] Additional attributes to include with the log entry.
    # @return [Boolean] Returns the result of the parent logger's logging operation.
    #
    # @api private
    def add_entry(severity, message, progname = nil, attributes = nil)
      parent_logger.with_level(level || Logger::DEBUG) do
        attributes = merge_attributes(local_attributes, attributes)
        progname ||= self.progname

        if parent_logger.is_a?(ContextLogger)
          parent_logger.add_entry(severity, message, progname, attributes)
        else
          parent_logger.tag(attributes) do
            parent_logger.add(severity, message, progname)
          end
        end
      end
    end

    # Flush any buffered log entries in the parent logger's device.
    #
    # @return [void]
    def flush
      parent_logger.flush
    end

    # Return the log device of the parent logger, if available.
    #
    # @return [Lumberjack::Device] The parent logger's output device.
    def device
      parent_logger.device if parent_logger.respond_to?(:device)
    end

    # Return the formatter of the parent logger, if available.
    #
    # @return [Lumberjack::EntryFormatter] The parent logger's formatter.
    def formatter
      parent_logger.formatter if parent_logger.respond_to?(:formatter)
    end

    private

    # Return the default context for this forked logger. This provides the isolated
    # configuration context that doesn't affect the parent logger.
    #
    # @return [Lumberjack::Context] The forked logger's private context.
    # @api private
    def default_context
      @context
    end

    # Merge all attributes that should be included with log entries from this forked logger.
    # This combines the default context attributes (set with tag!) and any local context
    # attributes (set within context blocks).
    #
    # @return [Hash, nil] The merged attributes hash, or nil if no attributes are set.
    # @api private
    def local_attributes
      merge_attributes(default_context&.attributes, local_context&.attributes)
    end
  end
end
