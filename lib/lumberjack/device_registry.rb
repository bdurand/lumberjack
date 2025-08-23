# frozen_string_literal: true

module Lumberjack
  # The device registry is used for setting up names to represent Device classes. It is used
  # in the constructor for Lumberjack::Logger and allows passing in a symbol to reference a
  # device.
  #
  # Devices must have a constructor that accepts the options hash as its sole argument in order
  # to use the device registry.
  #
  # @example
  #
  #   Lumberjack::Device.register(:my_device, MyDevice)
  #   logger = Lumberjack::Logger.new(:my_device)
  module DeviceRegistry
    @device_registry = {}

    class << self
      # Register a device name. Device names can be used to associate a symbol with a device
      # class. The symbol can then be passed to Logger as the device argument.
      #
      # Registered devices must take only one argument and that is the options hash for the
      # device options.
      #
      # @param name [Symbol] The name of the device
      # @param klass [Class] The device class to register
      # @return [void]
      def add(name, klass)
        raise ArgumentError.new("name must be a symbol") unless name.is_a?(Symbol)

        @device_registry[name] = klass
      end

      # Remove a device from the registry.
      #
      # @param name [Symbol] The name of the device to remove
      # @return [void]
      def remove(name)
        @device_registry.delete(name)
      end

      # Instantiate a new device with the specified options from the device registry.
      #
      # @param name [Symbol] The name of the device
      # @param options [Hash] The device options
      # @return [Lumberjack::Device]
      def new_device(name, options)
        klass = device_class(name)
        raise ArgumentError.new("#{name.inspect} is not registered as a device name") unless klass

        klass.new(options)
      end

      # Retrieve the class registered with the given name or nil if the name is not defined.
      #
      # @param name [Symbol] The name of the device
      # @return [Class, nil] The registered device class or nil if not found
      def device_class(name)
        @device_registry[name]
      end

      # Return the map of registered device class names.
      #
      # @return [Hash]
      def registered_devices
        @device_registry.dup
      end
    end
  end
end
