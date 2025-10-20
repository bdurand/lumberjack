# frozen_string_literal: true

module Lumberjack
  class TemplateRegistry
    @templates = {}

    class << self
      # Register a log template class with a symbol.
      #
      # @param name [Symbol] The name of the template.
      # @param template [String, Class, #call] The log template to register.
      def add(name, template)
        unless template.is_a?(String) || template.is_a?(Class) || template.respond_to?(:call)
          raise ArgumentError.new("template must be a String, Class, or respond to :call")
        end

        @templates[name.to_sym] = template
      end

      # Remove a template from the registry.        raise ArgumentError.new("template must be a String, Class, or respond to :call")
      #
      # @param name [Symbol] The name of the template to remove.
      # @return [void]
      def remove(name)
        @templates.delete(name.to_sym)
      end

      # Check if a template is registered.
      #
      # @param name [Symbol] The name of the template.
      # @return [Boolean] True if the template is registered, false otherwise.
      def registered?(name)
        @templates.include(name.to_sym)
      end

      # Get a registered log template class by its symbol.
      #
      # @param name [Symbol] The symbol of the registered log template class.
      # @return [Class, nil] The registered log template class, or nil if not found.
      def template(name, options = {})
        template = @templates[name.to_sym]
        if template.is_a?(Class)
          template.new(options)
        elsif template.is_a?(String)
          template_options = options.slice(:additional_lines, :time_format, :attribute_format, :colorize)
          Template.new(template, **template_options)
        else
          template
        end
      end

      # List all registered log template symbols.
      #
      # @return [Array<Symbol>] An array of all registered log template symbols.
      def registered_templates
        @templates.dup
      end
    end
  end
end
