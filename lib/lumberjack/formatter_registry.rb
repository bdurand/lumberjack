# frozen_string_literal: true

module Lumberjack
  # The formatter registry is used for setting up names to represent Formatter classes. It is used
  # in the constructor for Lumberjack::Logger and allows passing in a symbol to reference a
  # formatter.
  #
  # Formatters must respond to the +call+ method.
  #
  # @example
  #
  #   Lumberjack::FormatterRegistry.add(:upcase) { |value| value.to_s.upcase }
  #   Lumberjack::FormatterRegistry.add(:currency, Lumberjack::Formatter::RoundFormatter, 2)
  #
  #   Lumberjack::EntryFormatter.build do |config|
  #     config.add_attribute :status, :upcase
  #     config.add_attribute :amount, :currency
  #   end
  module FormatterRegistry
    @registry = {}

    class << self
      # Register a formatter name. Formatter names can be used to associate a symbol with a formatter
      # class. The symbol can then be passed to Logger as the formatter argument.
      #
      # Registered formatters must take only one argument and that is the options hash for the
      # formatter options.
      #
      # @param name [Symbol] The name of the formatter
      # @param formatter [Class, #call] The formatter or formatter class to register..
      # @return [void]
      def add(name, formatter = nil, &block)
        raise ArgumentError.new("name must be a symbol") unless name.is_a?(Symbol)
        raise ArgumentError.new("formatter or block must be provided") if formatter.nil? && block.nil?
        raise ArgumentError.new("cannot have both formatter and a block") if !formatter.nil? && !block.nil?

        formatter ||= block
        raise ArgumentError.new("formatter must be a class or respond to call") unless formatter.is_a?(Class) || formatter.respond_to?(:call)

        @registry[name] = formatter
      end

      # Remove a formatter from the registry.
      #
      # @param name [Symbol] The name of the formatter to remove
      # @return [void]
      def remove(name)
        @registry.delete(name)
      end

      # Check if a formatter is registered.
      #
      # @param name [Symbol] The name of the formatter
      # @return [Boolean] True if the formatter is registered, false otherwise
      def registered?(name)
        @registry.include?(name)
      end

      # Retrieve the formatter registered with the given name or nil if the name is not defined.
      #
      # @param name [Symbol] The name of the formatter
      # @return [#call, nil] The registered formatter class or nil if not found
      def formatter(name, *args)
        instance = @registry[name]

        if instance.nil?
          valid_names = @registry.keys.map(&:inspect).join(", ")
          raise ArgumentError.new("#{name.inspect} is not registered as a formatter name; valid names are: #{valid_names}")
        end

        instance = instance.new(*args) if instance.is_a?(Class)

        instance
      end

      # Return the map of registered formatters.
      #
      # @return [Hash]
      def registered_formatters
        @registry.dup
      end
    end
  end
end
