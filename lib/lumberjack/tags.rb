# frozen_string_literal: true

module Lumberjack
  class Tags
    class << self
      # Transform hash keys to strings. This method exists for optimization and backward compatibility.
      # If a hash already has string keys, it will be returned as is.
      #
      # @param hash [Hash] The hash to transform.
      # @return [Hash] The hash with string keys.
      # @deprecated No longer supported
      def stringify_keys(hash)
        Utils.deprecated("Lumberjack::Tags.stringify_keys", "Lumberjack::Tags.stringify_keys is no longer supported and will be removed in version 2.1") do
          return nil if hash.nil?

          if hash.keys.all? { |key| key.is_a?(String) }
            hash
          else
            hash.transform_keys(&:to_s)
          end
        end
      end

      # Alias to AttributesHelper.expand_runtime_values
      #
      # @param hash [Hash] The hash to transform.
      # @return [Hash] The hash with string keys and expanded values.
      # @deprecated Use {Lumberjack::AttributesHelper.expand_runtime_values} instead.
      def expand_runtime_values(hash)
        Utils.deprecated("Lumberjack::Tags.expand_runtime_values", "Lumberjack::Tags.expand_runtime_values is deprecated and will be removed in version 2.1; use Lumberjack::AttributesHelper.expand_runtime_values instead.") do
          AttributesHelper.expand_runtime_values(hash)
        end
      end
    end
  end
end
