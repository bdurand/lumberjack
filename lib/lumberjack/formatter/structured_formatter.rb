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
        if obj.is_a?(Hash)
          hash = {}
          references ||= Set.new
          obj.each do |name, value|
            hash[name.to_s] = call(value)
          end
          hash
        elsif obj.is_a?(Enumerable) && obj.respond_to?(:size) && obj.size != Float::INFINITY
          obj.collect { |element| call(element) }
        elsif @formatter
          @formatter.format(obj)
        else
          obj
        end
      end
    end
  end
end
