# frozen_string_literal: true

require_relative "fiber_locals"
require_relative "io_compatibility"
require_relative "severity"

module Lumberjack
  module ContextLogger
    # Constant used for setting trace log level.
    TRACE = Severity::TRACE

    class << self
      def included(base)
        base.include(FiberLocals) unless base.include?(FiberLocals)
        base.include(IOCompatibility) unless base.include?(IOCompatibility)
      end
    end

    # Get the level of severity of entries that are logged. Entries with a lower
    # severity level will be ignored.
    #
    # @return [Integer] The severity level.
    def level
      current_context&.level || default_context&.level
    end

    alias_method :sev_threshold, :level

    # Set the log level using either an integer level like Logger::INFO or a label like
    # :info or "info"
    #
    # @param [Integer, Symbol, String] value The severity level.
    # @return [void]
    def level=(value)
      value = Severity.coerce(value) unless value.nil?

      ctx = current_context
      ctx.level = value if ctx
    end

    alias_method :sev_threshold=, :level=

    # Adjust the log level during the block execution for the current Fiber only.
    #
    # @param [Integer, Symbol, String] severity The severity level.
    # @return [Object] The result of the block.
    def with_level(severity, &block)
      context do |ctx|
        ctx.level = severity
        block.call(ctx)
      end
    end

    # Set the logger progname for the current context. This is the name of the program that is logging.
    #
    # @param value [String, nil]
    # @return [void]
    def progname=(value)
      value = value&.to_s&.freeze

      ctx = current_context
      ctx.progname = value if ctx
    end

    # Get the current progname.
    #
    # @return [String, nil]
    def progname
      current_context&.progname || default_context&.progname
    end

    # Set the logger progname for the duration of the block.
    #
    # @yield [Object] The block to execute with the program name set.
    # @param [String] value The program name to use.
    # @return [Object] The result of the block.
    def with_progname(value, &block)
      context do |ctx|
        ctx.progname = value
        block.call(ctx)
      end
    end

    # Get the default severity used when writing log messages directly to a stream.
    #
    # @return [Integer] The default severity level.
    def default_severity
      current_context&.default_severity || default_context&.default_severity || Logger::UNKNOWN
    end

    # Set the default severity used when writing log messages directly to a stream
    # for the current context.
    #
    # @param [Integer, Symbol, String] value The default severity level.
    # @return [void]
    def default_severity=(value)
      ctx = current_context
      ctx.default_severity = value if ctx
    end

    # ::Logger compatible method to add a log entry.
    #
    # @param [Integer, Symbol, String] severity The severity of the message.
    # @param [Object] message The message to log.
    # @param [String] progname The name of the program that is logging the message.
    # @return [void]
    def add(severity, message = nil, progname = nil, &block)
      if message.nil?
        if block
          message = block.call
        else
          message = progname
          progname = nil
        end
      end

      call_add_entry(severity, message, progname)
    end

    alias_method :log, :add

    # Log a +FATAL+ message. The message can be passed in either the +message+ argument or in a block.
    #
    # @param [Object] message_or_progname_or_attributes The message to log or progname
    #   if the message is passed in a block.
    # @param [String, Hash] progname_or_attributes The name of the program that is logging the message or attributes
    #   if the message is passed in a block.
    # @return [void]
    def fatal(message_or_progname_or_attributes = nil, progname_or_attributes = nil, &block)
      call_add_entry(Logger::FATAL, message_or_progname_or_attributes, progname_or_attributes, &block)
    end

    # Return +true+ if +FATAL+ messages are being logged.
    #
    # @return [Boolean]
    def fatal?
      level <= Logger::FATAL
    end

    # Set the log level to fatal.
    #
    # @return [void]
    def fatal!
      self.level = Logger::FATAL
    end

    # Log an +ERROR+ message. The message can be passed in either the +message+ argument or in a block.
    #
    # @param [Object] message_or_progname_or_attributes The message to log or progname
    #   if the message is passed in a block.
    # @param [String, Hash] progname_or_attributes The name of the program that is logging the message or attributes
    #   if the message is passed in a block.
    # @return [void]
    def error(message_or_progname_or_attributes = nil, progname_or_attributes = nil, &block)
      call_add_entry(Logger::ERROR, message_or_progname_or_attributes, progname_or_attributes, &block)
    end

    # Return +true+ if +ERROR+ messages are being logged.
    #
    # @return [Boolean]
    def error?
      level <= Logger::ERROR
    end

    # Set the log level to error.
    #
    # @return [void]
    def error!
      self.level = Logger::ERROR
    end

    # Log a +WARN+ message. The message can be passed in either the +message+ argument or in a block.
    #
    # @param [Object] message_or_progname_or_attributes The message to log or progname
    #   if the message is passed in a block.
    # @param [String, Hash] progname_or_attributes The name of the program that is logging the message or attributes
    #   if the message is passed in a block.
    # @return [void]
    def warn(message_or_progname_or_attributes = nil, progname_or_attributes = nil, &block)
      call_add_entry(Logger::WARN, message_or_progname_or_attributes, progname_or_attributes, &block)
    end

    # Return +true+ if +WARN+ messages are being logged.
    #
    # @return [Boolean]
    def warn?
      level <= Logger::WARN
    end

    # Set the log level to warn.
    #
    # @return [void]
    def warn!
      self.level = Logger::WARN
    end

    # Log an +INFO+ message. The message can be passed in either the +message+ argument or in a block.
    #
    # @param [Object] message_or_progname_or_attributes The message to log or progname
    #   if the message is passed in a block.
    # @param [String] progname_or_attributes The name of the program that is logging the message or attributes
    #   if the message is passed in a block.
    # @return [void]
    def info(message_or_progname_or_attributes = nil, progname_or_attributes = nil, &block)
      call_add_entry(Logger::INFO, message_or_progname_or_attributes, progname_or_attributes, &block)
    end

    # Return +true+ if +INFO+ messages are being logged.
    #
    # @return [Boolean]
    def info?
      level <= Logger::INFO
    end

    # Set the log level to info.
    #
    # @return [void]
    def info!
      self.level = Logger::INFO
    end

    # Log a +DEBUG+ message. The message can be passed in either the +message+ argument or in a block.
    #
    # @param [Object] message_or_progname_or_attributes The message to log or progname
    #   if the message is passed in a block.
    # @param [String, Hash] progname_or_attributes The name of the program that is logging the message or attributes
    #   if the message is passed in a block.
    # @return [void]
    def debug(message_or_progname_or_attributes = nil, progname_or_attributes = nil, &block)
      call_add_entry(Logger::DEBUG, message_or_progname_or_attributes, progname_or_attributes, &block)
    end

    # Return +true+ if +DEBUG+ messages are being logged.
    #
    # @return [Boolean]
    def debug?
      level <= Logger::DEBUG
    end

    # Set the log level to debug.
    #
    # @return [void]
    def debug!
      self.level = Logger::DEBUG
    end

    # Log a +TRACE+ message. The message can be passed in either the +message+ argument or in a block.
    # Trace logs are a level lower than debug and are generally used to log code execution paths for
    # low level debugging.
    #
    # @param [Object] message_or_progname_or_attributes The message to log or progname
    #   if the message is passed in a block.
    # @param [String, Hash] progname_or_attributes The name of the program that is logging the message or attributes
    #   if the message is passed in a block.
    # @return [void]
    def trace(message_or_progname_or_attributes = nil, progname_or_attributes = nil, &block)
      call_add_entry(TRACE, message_or_progname_or_attributes, progname_or_attributes, &block)
    end

    # Return +true+ if +TRACE+ messages are being logged.
    #
    # @return [Boolean]
    def trace?
      level <= TRACE
    end

    # Set the log level to trace.
    #
    # @return [void]
    def trace!
      self.level = TRACE
    end

    # Log a message when the severity is not known. Unknown messages will always appear in the log.
    # The message can be passed in either the +message+ argument or in a block.
    #
    # @param [Object] message_or_progname_or_attributes The message to log or progname
    #   if the message is passed in a block.
    # @param [String, Hash] progname_or_attributes The name of the program that is logging the message or attributes
    #   if the message is passed in a block.
    # @return [void]
    def unknown(message_or_progname_or_attributes = nil, progname_or_attributes = nil, &block)
      call_add_entry(Logger::UNKNOWN, message_or_progname_or_attributes, progname_or_attributes, &block)
    end

    # Add a message when the severity is not known.
    #
    # @param [Object] msg The message to log.
    # @return [void]
    def <<(msg)
      add_entry(default_severity, msg)
    end

    # Tag the logger with a set of attributes. If a block is given, the attributes will only be set
    # for the duration of the block. Otherwise the attributes will be applied on the current
    # logger context for the duration of the current context. If there is no current context,
    # then a new logger object will be returned with those attributes set on it.
    #
    # @param [Hash] attributes The attributes to set.
    # @return [Object, Lumberjack::ContextLogger] If a block is given then the result of the block is returned.
    #   Otherwise it returns a Lumberjack::ContextLogger with the attributes set.
    #
    # @example
    #   # Only applies the attributes inside the block
    #   logger.tag(foo: "bar") do
    #     logger.info("message")
    #   end
    #
    # @example
    #   # Only applies the attributes inside the context block
    #   logger.context do
    #     logger.tag(foo: "bar")
    #     logger.info("message")
    #   end
    #
    # @example
    #   # Returns a new logger with the attributes set on it
    #   logger.tag(foo: "bar").info("message")
    def tag(attributes, &block)
      if block
        context do |ctx|
          ctx.assign_attributes(attributes)
          block.call(ctx)
        end
      else
        local_context&.assign_attributes(attributes)
        self
      end
    end

    # Tags the logger with a set of persistent attributes. These attributes will be included on every log
    # entry and are not tied to a context block. If the logger does not have a default context, then
    # these will be ignored.
    def tag!(attributes)
      default_context&.assign_attributes(attributes)
      nil
    end

    # Set up a context block for the logger. All attributes added within the block will be cleared when
    # the block exits.
    #
    # @param [Proc] block The block to execute with the context.
    # @return [Object] The result of the block.
    # @yield [Context]
    def context(&block)
      unless block_given?
        raise ArgumentError, "A block must be provided to the context method"
      end

      new_context = Context.new(current_context)
      with_fiber_local(:logger_context, new_context) do
        block.call(new_context)
      end
    end

    def local_logger(level: nil, progname: nil, attributes: nil)
      logger = LocalLogger.new(self)
      logger.level = level if level
      logger.progname = progname if progname
      logger.tag!(attributes) if attributes
      logger
    end

    # Remove attributes from the current context block.
    #
    # @param [Array<String, Symbol>] attribute_names The attributes to remove.
    # @return [void]
    def untag(*attribute_names)
      attributes = local_context&.attributes
      TagContext.new(attributes).delete(*attribute_names) if attributes
      nil
    end

    # Remove attributes from the default context for the logger.
    #
    # @param [Array<String, Symbol>] attribute_names The attributes to remove.
    # @return [void]
    def untag!(*attribute_names)
      attributes = default_context&.attributes
      TagContext.new(attributes).delete(*attribute_names) if attributes
      nil
    end

    # Return all attributes in scope on the logger including global attributes set on the Lumberjack
    # context, attributes set on the logger, and attributes set on the current block for the logger.
    #
    # @return [Hash]
    def attributes
      merge_all_attributes || {}
    end

    # Alias method for #attributes to provide backward compatibility with version 1.x API. This
    # method will eventually be removed.
    #
    # @return [Hash]
    # @api deprecated
    def tags
      attributes
    end

    # Get the value of an attribute by name from the current context.
    #
    # @param [String, Symbol] name The name of the attribute to get.
    # @return [Object, nil] The value of the attribute or nil if the attribute does not exist.
    def attribute_value(name)
      name = name.join(".") if name.is_a?(Array)
      TagContext.new(attributes)[name]
    end

    # Alias method for #attribute_value to provide backward compatibility with version 1.x API. This
    # method will eventually be removed.
    #
    # @return [Hash]
    # @api deprecated
    def tag_value(name)
      attribute_value(name)
    end

    # Remove all attributes on the current logger and logging context within a block.
    # You can still set new block scoped attributes within the untagged block and provide
    # attributes on individual log methods.
    #
    # @return [void]
    def untagged(&block)
      Lumberjack.use_context(nil) do
        untagged = fiber_local_value(:logger_untagged)
        begin
          set_fiber_local_value(:logger_untagged, true)
          context do |ctx|
            ctx.clear_attributes
            block.call
          end
        ensure
          set_fiber_local_value(:logger_untagged, untagged)
        end
      end
    end

    # Return true if the thread is currently in a context block with a local context.
    #
    # @return [Boolean]
    def context?
      !!local_context
    end

    # Add an entry to the log. This method must be implemented by the class that includes this module.
    #
    # @param [Integer, Symbol, String] severity The severity of the message.
    # @param [Object] message The message to log.
    # @param [String] progname The name of the program that is logging the message.
    # @param [Hash] attributes The attributes to add to the log entry.
    # @return [void]
    # @api private
    def add_entry(severity, message, progname = nil, attributes = nil)
      raise NotImplementedError
    end

    private

    def current_context
      local_context || default_context
    end

    def local_context
      fiber_local_value(:logger_context)
    end

    def default_context
      nil
    end

    # Write a log entry to the logging device.
    #
    # @param [Lumberjack::LogEntry] entry The log entry to write.
    # @return [void]
    # @api private
    def write_to_device(entry)
      raise NotImplementedError
    end

    # Dereference arguments to log calls so we can have methods with compatibility with ::Logger
    def call_add_entry(severity, message_or_progname_or_attributes, progname_or_attributes, &block) # :nodoc:
      severity = Severity.coerce(severity) unless severity.is_a?(Integer)
      return true unless level.nil? || severity >= level

      message = nil
      progname = nil
      attributes = nil
      if block
        message = block
        if message_or_progname_or_attributes.is_a?(Hash)
          attributes = message_or_progname_or_attributes
          progname = progname_or_attributes
        else
          progname = message_or_progname_or_attributes
          attributes = progname_or_attributes if progname_or_attributes.is_a?(Hash)
        end
      else
        message = message_or_progname_or_attributes
        if progname_or_attributes.is_a?(Hash)
          attributes = progname_or_attributes
        else
          progname = progname_or_attributes
        end
      end

      message = message.call if message.is_a?(Proc)
      return if (message.nil? || message == "") && (attributes.nil? || attributes.empty?)

      add_entry(severity, message, progname, attributes)
    end

    # Merge a attributes hash into an existing attributes hash.
    def merge_attributes(current_attributes, attributes)
      if current_attributes.nil? || current_attributes.empty?
        attributes
      elsif attributes.nil?
        current_attributes
      else
        current_attributes.merge(attributes)
      end
    end

    def merge_all_attributes
      attributes = nil

      unless fiber_local_value(:logger_untagged)
        global_context_attributes = Lumberjack.context_attributes
        if global_context_attributes && !global_context_attributes.empty?
          attributes ||= {}
          attributes.merge!(global_context_attributes)
        end

        default_attributes = default_context&.attributes
        if default_attributes && !default_attributes.empty?
          attributes ||= {}
          attributes.merge!(default_attributes)
        end
      end

      context_attributes = current_context&.attributes
      if context_attributes && !context_attributes.empty?
        attributes ||= {}
        attributes.merge!(context_attributes)
      end

      attributes
    end
  end
end
