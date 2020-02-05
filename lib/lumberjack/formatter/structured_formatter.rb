# frozen_string_literals: true

require "set"

module Lumberjack
  class Formatter
    # Dereference arrays and hashes and recursively call formatters on each element.
    class StructuredFormatter
      def initialize(formatter = nil)
        @formatter = formatter
      end

      def call(obj)
        call_with_references(obj, Set.new)
      end

      private

      def call_with_references(obj, references)
        if obj.is_a?(Hash)
          hash = {}
          references << obj.object_id
          obj.each do |name, value|
            next if references.include?(value.object_id)
            references << value
            hash[name.to_s] = call_with_references(value, references)
          end
          references.delete(obj.object_id)
          hash
        elsif obj.is_a?(Enumerable) && obj.respond_to?(:size) && obj.size != Float::INFINITY
          array = []
          references << obj.object_id
          obj.each do |value|
            next if references.include?(value.object_id)
            references << value
            array << call_with_references(value, references)
          end
          references.delete(obj.object_id)
          array
        elsif @formatter
          @formatter.format(obj)
        else
          obj
        end
      end
    end
  end
end
