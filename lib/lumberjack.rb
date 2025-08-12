# frozen_string_literal: true

require "rbconfig"
require "time"
require "logger"
require "fiber"

module Lumberjack
  LINE_SEPARATOR = ((RbConfig::CONFIG["host_os"] =~ /mswin/i) ? "\r\n" : "\n")

  require_relative "lumberjack/context"
  require_relative "lumberjack/log_entry"
  require_relative "lumberjack/device"
  require_relative "lumberjack/entry_formatter"
  require_relative "lumberjack/formatter"
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
    # Contexts can be used to store tags that will be attached to all log entries in the block.
    # The context will apply to all Lumberjack loggers that are used within the block.
    #
    # If this method is called with a block, it will set a logging context for the scope of a block.
    # If there is already a context in scope, a new one will be created that inherits
    # all the tags of the parent context.
    #
    # Otherwise, it will return the current context. If one doesn't exist, it will return a new one
    # but that context will not be in any scope.
    #
    # @return [Lumberjack::Context] The current context if called without a block.
    def context(&block)
      current_context = @global_contexts[Fiber.current]
      if block
        use_context(Context.new(current_context), &block)
      else
        current_context || Context.new
      end
    end

    # Set the context to use within a block.
    #
    # @param [Lumberjack::Context] context The context to use within the block.
    # @return [Object] The result of the block.
    def use_context(context, &block)
      current_context = @global_contexts[Fiber.current]
      begin
        @global_contexts_mutex.synchronize do
          @global_contexts[Fiber.current] = (context || Context.new)
        end
        yield
      ensure
        @global_contexts_mutex.synchronize do
          if current_context.nil?
            @global_contexts.delete(Fiber.current)
          else
            @global_contexts[Fiber.current] = current_context
          end
        end
      end
    end

    # Return true if inside a context block.
    #
    # @return [Boolean]
    def context?
      !!@global_contexts[Fiber.current]
    end

    # Return the tags from the current context or nil if there are no tags.
    #
    # @return [Hash, nil]
    def context_tags
      context = @global_contexts[Fiber.current]
      context&.tags
    end

    # Set tags on the current context
    #
    # @param [Hash] tags The tags to set.
    # @return [void]
    def tag(tags)
      context = @global_contexts[Fiber.current]
      context&.tag(tags)
    end
  end
end
