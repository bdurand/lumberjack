# frozen_string_literals: true

require 'rbconfig'
require 'time'
require 'thread'
require 'securerandom'
require 'logger'

module Lumberjack
  LINE_SEPARATOR = (RbConfig::CONFIG['host_os'].match(/mswin/i) ? "\r\n" : "\n")

  require_relative "lumberjack/severity.rb"
  require_relative "lumberjack/formatter.rb"

  require_relative "lumberjack/context.rb"
  require_relative "lumberjack/log_entry.rb"
  require_relative "lumberjack/device.rb"
  require_relative "lumberjack/logger.rb"
  require_relative "lumberjack/tags.rb"
  require_relative "lumberjack/tag_formatter.rb"
  require_relative "lumberjack/tagged_logger_support.rb"
  require_relative "lumberjack/tagged_logging.rb"
  require_relative "lumberjack/template.rb"
  require_relative "lumberjack/rack.rb"

  class << self
    # Define a unit of work within a block. Within the block supplied to this
    # method, calling +unit_of_work_id+ will return the same value that can
    # This can then be used for tying together log entries.
    #
    # You can specify the id for the unit of work if desired. If you don't supply
    # it, a 12 digit hexidecimal number will be automatically generated for you.
    #
    # For the common use case of treating a single web request as a unit of work, see the
    # Lumberjack::Rack::UnitOfWork class.
    def unit_of_work(id = nil)
      id ||= SecureRandom.hex(6)
      context do
        context[:unit_of_work_id] = id
        yield
      end
    end

    # Get the UniqueIdentifier for the current unit of work.
    def unit_of_work_id
      context[:unit_of_work_id]
    end

    # Contexts can be used to store tags that will be attached to all log entries in the block.
    #
    # If this method is called with a block, it will set a logging context for the scope of a block.
    # If there is already a context in scope, a new one will be created that inherits
    # all the tags of the parent context.
    #
    # Otherwise, it will return the current context. If one doesn't exist, it will return a new one
    # but that context will not be in any scope.
    def context
      current_context = Thread.current[:lumberjack_context]
      if block_given?
        Thread.current[:lumberjack_context] = Context.new(current_context)
        begin
          yield
        ensure
          Thread.current[:lumberjack_context] = current_context
        end
      else
        current_context || Context.new
      end
    end
    
    # Return true if inside a context block.
    def context?
      !!Thread.current[:lumberjack_context]
    end

    # Return the tags from the current context or nil if there are no tags.
    def context_tags
      context = Thread.current[:lumberjack_context]
      context.tags if context
    end

    # Set tags on the current context
    def tag(tags)
      context = Thread.current[:lumberjack_context]
      context.tag(tags) if context
    end

  end
end
