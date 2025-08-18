# frozen_string_literal: true

module Lumberjack
  class Tags
    class << self
      # Transform hash keys to strings. This method exists for optimization and backward compatibility.
      # If a hash already has string keys, it will be returned as is.
      #
      # @param [Hash] hash The hash to transform.
      # @return [Hash] The hash with string keys.
      # @deprecated
      def stringify_keys(hash)
        return nil if hash.nil?
        if hash.keys.all? { |key| key.is_a?(String) }
          hash
        else
          hash.transform_keys(&:to_s)
        end
      end

      # Alias to AttributesHelper.expand_runtime_values
      #
      # @param [Hash] hash The hash to transform.
      # @return [Hash] The hash with string keys and expanded values.
      # @deprecated Use {Lumberjack::AttributesHelper.expand_runtime_values} instead.
      def expand_runtime_values(hash)
        AttributesHelper.expand_runtime_values(hash)
      end
    end
  end
end
