# frozen_string_literal: true

require "rbconfig"
require "time"
require "logger"
require "fiber"
require "pathname"

# Lumberjack is a flexible logging framework for Ruby that extends the standard
# Logger functionality with structured logging, context isolation, and advanced
# formatting capabilities.
#
# The main features include:
# - Structured logging with attributes for machine-readable metadata
# - Context isolation for scoping logging behavior to specific code blocks
# - Flexible formatters for customizing log output
# - Multiple output devices and templates
# - Built-in testing utilities
#
# @example Basic usage
#   logger = Lumberjack::Logger.new(STDOUT)
#   logger.info("Hello world")
#
# @example Using contexts
#   Lumberjack.context do
#     Lumberjack.tag(user_id: 123)
#     logger.info("User action") # Will include user_id: 123
#   end
#
# @see Lumberjack::Logger
# @see Lumberjack::ContextLogger
module Lumberjack
  VERSION = File.read(File.join(__dir__, "..", "VERSION")).strip.freeze

  LINE_SEPARATOR = ((RbConfig::CONFIG["host_os"] =~ /mswin/i) ? "\r\n" : "\n")

  require_relative "lumberjack/attribute_formatter"
  require_relative "lumberjack/attributes_helper"
  require_relative "lumberjack/context"
  require_relative "lumberjack/context_logger"
  require_relative "lumberjack/fiber_locals"
  require_relative "lumberjack/io_compatibility"
  require_relative "lumberjack/log_entry"
  require_relative "lumberjack/log_entry_matcher"
  require_relative "lumberjack/device_registry"
  require_relative "lumberjack/device"
  require_relative "lumberjack/entry_formatter"
  require_relative "lumberjack/formatter_registry"
  require_relative "lumberjack/formatter"
  require_relative "lumberjack/forked_logger"
  require_relative "lumberjack/logger"
  require_relative "lumberjack/message_attributes"
  require_relative "lumberjack/remap_attribute"
  require_relative "lumberjack/rack"
  require_relative "lumberjack/severity"
  require_relative "lumberjack/template"
  require_relative "lumberjack/utils"

  # Deprecated
  require_relative "lumberjack/tag_context"
  require_relative "lumberjack/tag_formatter"
  require_relative "lumberjack/tags"

  @global_contexts = {}
  @global_contexts_mutex = Mutex.new
  @deprecation_mode = nil
  @raise_logger_errors = false

  class << self
    # Contexts can be used to store attributes that will be attached to all log entries in the block.
    # The context will apply to all Lumberjack loggers that are used within the block.
    #
    # If this method is called with a block, it will set a logging context for the scope of a block.
    # If there is already a context in scope, a new one will be created that inherits
    # all the attributes of the parent context.
    #
    # Otherwise, it will return the current context. If one doesn't exist, it will return a new one
    # but that context will not be in any scope.
    #
    # @return [Object] The result
    #   of the block
    def context(&block)
      use_context(Context.new(current_context), &block)
    end

    # Set the context to use within a block.
    #
    # @param context [Lumberjack::Context] The context to use within the block.
    # @return [Object] The result of the block.
    # @api private
    def use_context(context, &block)
      fiber_id = Fiber.current.object_id
      ctx = @global_contexts[fiber_id]
      begin
        @global_contexts_mutex.synchronize do
          @global_contexts[fiber_id] = (context || Context.new)
        end
        yield
      ensure
        @global_contexts_mutex.synchronize do
          if ctx.nil?
            @global_contexts.delete(fiber_id)
          else
            @global_contexts[fiber_id] = ctx
          end
        end
      end
    end

    # Return true if inside a context block.
    #
    # @return [Boolean]
    def in_context?
      !!@global_contexts[Fiber.current.object_id]
    end

    def context?
      Utils.deprecated("Lumberjack.context?", "Lumberjack.context? is deprecated; use in_context? instead.") do
        in_context?
      end
    end

    # Return attributes that will be applied to all Lumberjack loggers.
    #
    # @return [Hash, nil]
    def context_attributes
      current_context&.attributes
    end

    # Alias for context_attributes to provide API compatibility with version 1.x.
    # This method will eventually be removed.
    #
    # @return [Hash, nil]
    # @deprecated Use {.context_attributes}
    def context_tags
      Utils.deprecated("Lumberjack.context_tags", "Lumberjack.context_tags is deprecated; use context_attributes instead.") do
        context_attributes
      end
    end

    # Tag all loggers with attributes on the current context.
    #
    # @param attributes [Hash] The attributes to set.
    # @param block [Proc] optional context block in which to set the attributes.
    # @return [void]
    def tag(attributes, &block)
      if block
        context do
          current_context.assign_attributes(attributes)
          block.call
        end
      else
        current_context&.assign_attributes(attributes)
      end
    end

    # Helper method to build an entry formatter.
    #
    # @param block [Proc] The block to use for building the entry formatter.
    # @return [Lumberjack::EntryFormatter] The built entry formatter.
    # @see Lumberjack::EntryFormatter.build
    def build_formatter(&block)
      EntryFormatter.build(&block)
    end

    # Control how use of deprecated methods is handled. The default is to print a warning
    # the first time a deprecated method is called. Setting this to "verbose" will print
    # a warning every time a deprecated method is called. Setting this to "silent" will
    # suppress all deprecation warnings. Setting this to "raise" will raise an exception
    # when a deprecated method is called.
    #
    # The default value can be set with the `LUMBERJACK_DEPRECATION_WARNINGS` environment variable.
    #
    # @param value [String, Symbol, nil] The deprecation mode to set. Valid values are "normal",
    #   "verbose", "silent", and "raise".
    def deprecation_mode=(value)
      @deprecation_mode = value&.to_s
    end

    # @return [String] The current deprecation mode.
    # @api private
    def deprecation_mode
      @deprecation_mode ||= ENV.fetch("LUMBERJACK_DEPRECATION_WARNINGS", "normal").to_s
    end

    # Set whether errors encountered while logging entries should be raised. The default behavior
    # is to rescue these errors and print them to standard error. Otherwise there can be no way
    # to record the error since it cannot be logged.
    #
    # You can set this to true in you test and development environments to catch logging errors
    # before they make it to production.
    #
    # @param value [Boolean] Whether to raise logger errors.
    # @return [void]
    def raise_logger_errors=(value)
      @raise_logger_errors = !!value
    end

    # @return [Boolean] Whether logger errors should be raised.
    # @api private
    def raise_logger_errors?
      @raise_logger_errors
    end

    private

    def current_context
      @global_contexts[Fiber.current.object_id]
    end
  end
end
