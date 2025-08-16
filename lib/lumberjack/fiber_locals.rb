# frozen_string_literal: true

module Lumberjack
  module FiberLocals
    private

    # Initialize the fiber locals storage and mutex.
    def init_fiber_locals!
      @fiber_locals ||= {}
      @fiber_locals_mutex ||= Mutex.new
    end

    def with_fiber_local(name, value)
      save_val = fiber_local_value(name)
      begin
        set_fiber_local_value(name, value)
        yield
      ensure
        set_fiber_local_value(name, save_val)
      end
    end

    # Set a local value for a thread tied to this object.
    #
    # @param name [Symbol] The name of the local value.
    # @param value [Object] The value to set.
    # @return [void]
    def set_fiber_local_value(name, value) # :nodoc:
      init_fiber_locals! unless defined?(@fiber_locals)

      fiber_id = Fiber.current.object_id
      local_values = @fiber_locals[fiber_id]
      if local_values.nil?
        return if value.nil?

        local_values = {}
        @fiber_locals_mutex.synchronize do
          @fiber_locals[fiber_id] = local_values
        end
      end

      if value.nil?
        local_values.delete(name)
        if local_values.empty?
          @fiber_locals_mutex.synchronize do
            @fiber_locals.delete(fiber_id)
          end
        end
      else
        local_values[name] = value
      end
    end

    # Get a local value for a thread tied to this object.
    #
    # @param name [Symbol] The name of the local value.
    # @return [Object, nil] The local value or nil if not set.
    def fiber_local_value(name) # :nodoc:
      init_fiber_locals! unless defined?(@fiber_locals)

      @fiber_locals.dig(Fiber.current.object_id, name)
    end
  end
end
