# frozen_string_literal: true

require "set"

module Lumberjack
  class Formatter
    # Dereference arrays and hashes and recursively call formatters on each element.
    # This formatter provides deep traversal of nested data structures, applying
    # formatting to all contained elements while handling circular references safely.
    #
    # The StructuredFormatter is essential for formatting complex nested objects
    # like configuration hashes, API responses, or any hierarchical data structures
    # that need consistent formatting throughout their entire structure.
    class StructuredFormatter
      FormatterRegistry.add(:structured, self)

      # Exception raised when a circular reference is detected during traversal.
      # This prevents infinite recursion when formatting objects that reference themselves.
      class RecusiveReferenceError < StandardError
      end

      # @param formatter [Formatter, nil] The formatter to call on each element
      #   in the structure. If nil, elements are returned unchanged.
      def initialize(formatter = nil)
        @formatter = formatter
      end

      # Format a structured object by recursively processing all nested elements.
      #
      # @param obj [Object] The object to format. Arrays and hashes are traversed
      #   recursively, while other objects are passed to the configured formatter.
      # @return [Object] The formatted structure with all nested elements processed.
      def call(obj)
        call_with_references(obj, Set.new)
      end

      private

      def call_with_references(obj, references)
        if obj.is_a?(Hash)
          with_object_reference(obj, references) do
            hash = {}
            obj.each do |name, value|
              value = call_with_references(value, references)
              hash[name.to_s] = value unless value.is_a?(RecusiveReferenceError)
            end
            hash
          end
        elsif obj.is_a?(Enumerable) && obj.respond_to?(:size) && obj.size != Float::INFINITY
          with_object_reference(obj, references) do
            array = []
            obj.each do |value|
              value = call_with_references(value, references)
              array << value unless value.is_a?(RecusiveReferenceError)
            end
            array
          end
        elsif @formatter
          @formatter.format(obj)
        else
          obj
        end
      end

      def with_object_reference(obj, references)
        if obj.is_a?(Enumerable)
          return RecusiveReferenceError.new if references.include?(obj.object_id)

          references << obj.object_id
          begin
            yield
          ensure
            references.delete(obj.object_id)
          end
        else
          yield
        end
      end
    end
  end
end
