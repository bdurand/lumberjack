# frozen_string_literal: true

module Lumberjack
  module ContextLogger
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
    # @param [Object] message_or_progname_or_tags The message to log or progname
    #   if the message is passed in a block.
    # @param [String, Hash] progname_or_tags The name of the program that is logging the message or tags
    #   if the message is passed in a block.
    # @return [void]
    def fatal(message_or_progname_or_tags = nil, progname_or_tags = nil, &block)
      call_add_entry(Logger::FATAL, message_or_progname_or_tags, progname_or_tags, &block)
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
    # @param [Object] message_or_progname_or_tags The message to log or progname
    #   if the message is passed in a block.
    # @param [String, Hash] progname_or_tags The name of the program that is logging the message or tags
    #   if the message is passed in a block.
    # @return [void]
    def error(message_or_progname_or_tags = nil, progname_or_tags = nil, &block)
      call_add_entry(Logger::ERROR, message_or_progname_or_tags, progname_or_tags, &block)
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
    # @param [Object] message_or_progname_or_tags The message to log or progname
    #   if the message is passed in a block.
    # @param [String, Hash] progname_or_tags The name of the program that is logging the message or tags
    #   if the message is passed in a block.
    # @return [void]
    def warn(message_or_progname_or_tags = nil, progname_or_tags = nil, &block)
      call_add_entry(Logger::WARN, message_or_progname_or_tags, progname_or_tags, &block)
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
    # @param [Object] message_or_progname_or_tags The message to log or progname
    #   if the message is passed in a block.
    # @param [String] progname_or_tags The name of the program that is logging the message or tags
    #   if the message is passed in a block.
    # @return [void]
    def info(message_or_progname_or_tags = nil, progname_or_tags = nil, &block)
      call_add_entry(Logger::INFO, message_or_progname_or_tags, progname_or_tags, &block)
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
    # @param [Object] message_or_progname_or_tags The message to log or progname
    #   if the message is passed in a block.
    # @param [String, Hash] progname_or_tags The name of the program that is logging the message or tags
    #   if the message is passed in a block.
    # @return [void]
    def debug(message_or_progname_or_tags = nil, progname_or_tags = nil, &block)
      call_add_entry(Logger::DEBUG, message_or_progname_or_tags, progname_or_tags, &block)
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

    # Log a message when the severity is not known. Unknown messages will always appear in the log.
    # The message can be passed in either the +message+ argument or in a block.
    #
    # @param [Object] message_or_progname_or_tags The message to log or progname
    #   if the message is passed in a block.
    # @param [String, Hash] progname_or_tags The name of the program that is logging the message or tags
    #   if the message is passed in a block.
    # @return [void]
    def unknown(message_or_progname_or_tags = nil, progname_or_tags = nil, &block)
      call_add_entry(Logger::UNKNOWN, message_or_progname_or_tags, progname_or_tags, &block)
    end

    # Add a message when the severity is not known.
    #
    # @param [Object] msg The message to log.
    # @return [void]
    def <<(msg)
      add_entry(Logger::UNKNOWN, msg)
    end

    # Set a hash of tags on logger. If a block is given, the tags will only be set
    # for the duration of the block. Otherwise the tags will be applied on the current
    # logger context for the duration of the current context. If there is no current context,
    # then a new logger object will be returned with those tags set on it.
    #
    # @param [Hash] tags The tags to set.
    # @return [Object, Lumberjack::ContextLogger] If a block is given then the result of the block is returned.
    #   Otherwise it returns a Lumberjack::ContextLogger with the tags set.
    #
    # @example
    #   # Only applies the tag inside the block
    #   logger.tag(foo: "bar") do
    #     logger.info("message")
    #   end
    #
    # @example
    #   # Only applies the tag inside the context block
    #   logger.context do
    #     logger.tag(foo: "bar")
    #     logger.info("message")
    #   end
    #
    # @example
    #   # Returns a new logger with the tag set on it
    #   logger.tag(foo: "bar").info("message")
    def tag(tags, &block)
      if block
        context do |ctx|
          ctx.tag(tags)
          block.call(ctx)
        end
      elsif local_context
        local_context.tag(tags)
        self
      else
        local_logger = LocalLogger.new(self)
        local_logger.tag!(tags)
        local_logger
      end
    end

    # Add persistent tags to the logger. These tags will be included on every log entry and are
    # not tied to a context block. If the logger does not support global tags, then these will be
    # ignored.
    def tag!(tags)
      default_context&.tag(tags)
      nil
    end

    # Set up a context block for the logger. All tags added within the block will be cleared when
    # the block exits.
    #
    # @param [Proc] block The block to execute with the tag context.
    # @return [Object] The result of the block.
    # @yield [Context]
    def context(&block)
      new_context = Context.new(current_context)
      with_fiber_local(:logger_context, new_context) do
        block.call(new_context)
      end
    end

    # Remove a tag from the current context block.
    #
    # @param [Array<String, Symbol>] tag_names The tags to remove.
    # @return [void]
    def untag(*tag_names)
      tags = local_context&.tags
      TagContext.new(tags).delete(*tag_names) if tags
      nil
    end

    # Remove a tag from the default context for the logger.
    #
    # @param [Array<String, Symbol>] tag_names The tags to remove.
    # @return [void]
    def untag!(*tag_names)
      tags = default_context&.tags
      TagContext.new(tags).delete(*tag_names) if tags
      nil
    end

    # Return all tags in scope on the logger including global tags set on the Lumberjack
    # context, tags set on the logger, and tags set on the current block for the logger.
    #
    # @return [Hash]
    def tags
      merge_all_tags || {}
    end

    # Get the value of a tag by name from the current tag context.
    #
    # @param [String, Symbol] name The name of the tag to get.
    # @return [Object, nil] The value of the tag or nil if the tag does not exist.
    def tag_value(name)
      name = name.join(".") if name.is_a?(Array)
      TagContext.new(tags)[name]
    end

    # Remove all tags on the current logger and logging context within a block.
    # You can still set new block scoped tags within theuntagged block and provide
    # tags on individual log methods.
    #
    # @return [void]
    def untagged(&block)
      Lumberjack.use_context(nil) do
        untagged = fiber_local_value(:logger_untagged)
        begin
          set_fiber_local_value(:logger_untagged, true)
          context do |ctx|
            ctx.clear_tags
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
    # @param [Hash] tags The tags to add to the log entry.
    # @return [void]
    # @api private
    def add_entry(severity, message, progname = nil, tags = nil)
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
    def call_add_entry(severity, message_or_progname_or_tags, progname_or_tags, &block) # :nodoc:
      severity = Severity.coerce(severity) unless severity.is_a?(Integer)
      return true unless level.nil? || severity >= level

      message = nil
      progname = nil
      tags = nil
      if block
        message = block
        if message_or_progname_or_tags.is_a?(Hash)
          tags = message_or_progname_or_tags
          progname = progname_or_tags
        else
          progname = message_or_progname_or_tags
          tags = progname_or_tags if progname_or_tags.is_a?(Hash)
        end
      else
        message = message_or_progname_or_tags
        if progname_or_tags.is_a?(Hash)
          tags = progname_or_tags
        else
          progname = progname_or_tags
        end
      end

      message = message.call if message.is_a?(Proc)
      return if (message.nil? || message == "") && (tags.nil? || tags.empty?)

      add_entry(severity, message, progname, tags)
    end

    # Merge a tags hash into an existing tags hash.
    def merge_tags(current_tags, tags)
      if current_tags.nil? || current_tags.empty?
        tags
      elsif tags.nil?
        current_tags
      else
        current_tags.merge(tags)
      end
    end

    def merge_all_tags
      tags = nil

      unless fiber_local_value(:logger_untagged)
        global_context_tags = Lumberjack.context_tags
        if global_context_tags && !global_context_tags.empty?
          tags ||= {}
          tags.merge!(global_context_tags)
        end

        default_tags = default_context&.tags
        if default_tags && !default_tags.empty?
          tags ||= {}
          tags.merge!(default_tags)
        end
      end

      context_tags = current_context&.tags
      if context_tags && !context_tags.empty?
        tags ||= {}
        tags.merge!(context_tags)
      end

      tags
    end
  end
end
