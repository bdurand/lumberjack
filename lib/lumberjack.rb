# frozen_string_literal: true

require "rbconfig"
require "time"
require "logger"
require "fiber"
require "pathname"

module Lumberjack
  LINE_SEPARATOR = ((RbConfig::CONFIG["host_os"] =~ /mswin/i) ? "\r\n" : "\n")

  require_relative "lumberjack/context"
  require_relative "lumberjack/context_logger"
  require_relative "lumberjack/fiber_locals"
  require_relative "lumberjack/io_compatibility"
  require_relative "lumberjack/log_entry"
  require_relative "lumberjack/log_entry_matcher"
  require_relative "lumberjack/device"
  require_relative "lumberjack/entry_formatter"
  require_relative "lumberjack/formatter"
  require_relative "lumberjack/local_logger"
  require_relative "lumberjack/logger"
  require_relative "lumberjack/rack"
  require_relative "lumberjack/severity"
  require_relative "lumberjack/tags"
  require_relative "lumberjack/tag_context"
  require_relative "lumberjack/tag_formatter"
  require_relative "lumberjack/template"
  require_relative "lumberjack/utils"

  @global_contexts = {}
  @global_contexts_mutex = Mutex.new

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
    # @param [Lumberjack::Context] context The context to use within the block.
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
    def context?
      !!@global_contexts[Fiber.current.object_id]
    end

    # Return attributes that will be applied to all Lumberjack loggers.
    #
    # @return [Hash, nil]
    def context_attributes
      current_context&.attributes
    end

    def context_tags
      context_attributes
    end

    # Set attributes on the current context
    #
    # @param attributes [Hash] The attributes to set.
    # @param block [Proc] optional context block in which to set the attributes.
    # @return [void]
    def assign_attributes(attributes, &block)
      if block
        context do
          current_context.tag(attributes)
          block.call
        end
      else
        current_context&.tag(attributes)
      end
    end

    def tag(tags, &block)
      assign_attributes(tags, &block)
    end

    private

    def current_context
      @global_contexts[Fiber.current.object_id]
    end
  end
end
