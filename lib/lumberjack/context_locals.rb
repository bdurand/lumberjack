# frozen_string_literal: true

module Lumberjack
  # Provides isolated fiber or thread local storage for thread-safe data access.
  module ContextLocals
    # Lightweight structure to hold fiber-local data.
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

    def context_locals(&block)
      init_context_locals! unless defined?(@context_locals)

      scope_id = ((isolation_level == :fiber) ? Fiber : Thread).current.object_id
      current = @context_locals[scope_id]
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

    def current_context_local
      return nil unless defined?(@context_locals)

      scope_id = ((isolation_level == :fiber) ? Fiber : Thread).current.object_id
      @context_locals[scope_id]
    end

    # Initialize the context locals storage and mutex.
    def init_context_locals!
      @context_locals ||= {}
      @context_locals_mutex ||= Mutex.new
      @isolation_level ||= Lumberjack.isolation_level
    end
  end
end
