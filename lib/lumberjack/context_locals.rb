# frozen_string_literal: true

module Lumberjack
  # Provides isolated fiber or thread local storage for thread-safe data access.
  module ContextLocals
    # Lightweight structure to hold context-local data.
    #
    # @api private
    class Data
      attr_accessor :context, :logging, :cleared

      def initialize(copy = nil)
        @context = copy&.context
        @logging = copy&.logging
        @cleared = copy&.cleared
      end
    end

    # Set the isolation level for context locals.
    #
    # @param value [Symbol] The isolation level, either :fiber or :thread.
    # @return [void]
    def isolation_level=(value)
      value = value&.to_sym
      value = :fiber unless [:fiber, :thread].include?(value)
      @isolation_level = value
    end

    def isolation_level
      @isolation_level ||= :fiber
    end

    private

    def new_context_locals(&block)
      init_context_locals! unless defined?(@context_locals)

      set_context_locals_thread_id do
        scope_id = context_locals_scope_id
        current = @context_locals[scope_id] if scope_id
        data = Data.new(current)
        begin
          @context_locals_mutex.synchronize do
            @context_locals[scope_id] = data
          end
          yield data
        ensure
          @context_locals_mutex.synchronize do
            if current.nil?
              @context_locals.delete(scope_id)
            else
              @context_locals[scope_id] = current
            end
          end
        end
      end
    end

    def current_context_locals
      return nil unless defined?(@context_locals)

      @context_locals[context_locals_scope_id]
    end

    # Initialize the context locals storage and mutex.
    def init_context_locals!
      @context_locals ||= {}
      @context_locals_mutex ||= Mutex.new
      @isolation_level ||= Lumberjack.isolation_level
    end

    def context_locals_scope_id
      if isolation_level == :fiber
        Fiber.current.object_id
      else
        Thread.current.thread_variable_get(:lumberjack_context_locals_thread_id)
      end
    end

    # Create a consistent thread ID for context locals. We can't use Thread.current.object_id
    # directly because it may change during execution (e.g., in JRuby when threads are
    # migrated between native threads). Instead we store a unique ID in a thread variable.
    def set_context_locals_thread_id
      thread_id = Thread.current.thread_variable_get(:lumberjack_context_locals_thread_id)
      return yield if thread_id

      thread_id = Object.new.object_id
      begin
        Thread.current.thread_variable_set(:lumberjack_context_locals_thread_id, thread_id)
        yield
      ensure
        Thread.current.thread_variable_set(:lumberjack_context_locals_thread_id, nil)
      end
    end
  end
end
