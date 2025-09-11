# frozen_string_literal: true

module Lumberjack
  # Provides isolated fiber-local storage for thread-safe data access.
  module FiberLocals
    # Lightweight structure to hold fiber-local data.
    #
    # @api private
    class Data
      attr_accessor :context, :logging, :cleared
    end

    private

    def fiber_locals(&block)
      init_fiber_locals! unless defined?(@fiber_locals)

      fiber_id = Fiber.current.object_id
      current = @fiber_locals[fiber_id]
      data = current.nil? ? Data.new : current.dup
      begin
        @fiber_locals_mutex.synchronize do
          @fiber_locals[fiber_id] = data
        end
        yield data
      ensure
        @fiber_locals_mutex.synchronize do
          if current.nil?
            @fiber_locals.delete(fiber_id)
          else
            @fiber_locals[fiber_id] = current
          end
        end
      end
    end

    def fiber_local
      return nil unless defined?(@fiber_locals)

      @fiber_locals[Fiber.current.object_id]
    end

    # Initialize the fiber locals storage and mutex.
    def init_fiber_locals!
      @fiber_locals ||= {}
      @fiber_locals_mutex ||= Mutex.new
    end
  end
end
