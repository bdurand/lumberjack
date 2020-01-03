# frozen_string_literals: true

require 'rbconfig'
require 'time'
require 'thread'
require 'securerandom'
require 'logger'

module Lumberjack
  LINE_SEPARATOR = (RbConfig::CONFIG['host_os'].match(/mswin/i) ? "\r\n" : "\n")

  require_relative "lumberjack/severity.rb"
  require_relative "lumberjack/context.rb"
  require_relative "lumberjack/log_entry.rb"
  require_relative "lumberjack/formatter.rb"
  require_relative "lumberjack/device.rb"
  require_relative "lumberjack/logger.rb"
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
      with_context do
        context[:unit_of_work_id] = id
        yield
      end
    end

    # Get the UniqueIdentifier for the current unit of work.
    def unit_of_work_id
      context[:unit_of_work_id]
    end

    # This method will set a logging context for the scope of a block. Contexts can
    # be used to store tags that will be attached to all log entries in the block.
    # If there is already a context in scope, a new one will be created that inherits
    # all the tags of the parent context.
    def with_context
      parent_context = Thread.current[:lumberjack_context]
      Thread.current[:lumberjack_context] = Context.new(parent_context)
      begin
        yield
      ensure
        Thread.current[:lumberjack_context] = parent_context
      end
    end

    # Return the current context. If there is not current context, a new one will be returned
    # but it will not be saved anywhere in the current scope. This is just so code that expects
    # a context will always get one.
    def context
      Thread.current[:lumberjack_context] || Context.new
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
