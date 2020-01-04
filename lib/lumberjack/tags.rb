# frozen_string_literal: true

module Lumberjack
  class Tags
    class << self
      # Transform hash keys to strings. This method exists for optimization and backward compatibility.
      # If a hash already has string keys, it will be returned as is.
      def stringify_keys(hash)
        return nil if hash.nil?
        if hash.keys.all? { |key| key.is_a?(String) }
          hash
        elsif hash.respond_to?(:transform_keys)
          hash.transform_keys(&:to_s)
        else
          copy = {}
          hash.each do |key, value|
            copy[key.to_s] = value
          end
          copy
        end
      end
    end
  end
end
