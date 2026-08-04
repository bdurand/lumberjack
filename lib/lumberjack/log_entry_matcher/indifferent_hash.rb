# frozen_string_literal: true

# A minimal hash implementation that allows values to be looked up with either
# string or symbol keys.
#
# The keys stored in the hash are left exactly as they are; only lookups are
# indifferent. Log entry attributes are matched with string keys, but matchers
# that do their own key lookups on the attributes hash (i.e. RSpec's
# `hash_including`) have no way of knowing that. Wrapping the attributes in this
# class lets those matchers use either form.
#
# @api private
class Lumberjack::LogEntryMatcher::IndifferentHash < Hash
  class << self
    # Recursively wrap a value so that any hashes in it, including hashes nested
    # inside arrays, allow indifferent key lookups. Values that are not hashes or
    # arrays are returned as is.
    #
    # @param value [Object] The value to wrap.
    # @return [Object] The wrapped value.
    def wrap(value)
      case value
      when self
        value
      when Hash
        value.each_with_object(new) { |(key, val), hash| hash[key] = wrap(val) }
      when Array
        value.collect { |val| wrap(val) }
      else
        value
      end
    end
  end

  # Capture the unaliased implementation so the overrides below can check for a
  # key without recursing back into themselves.
  alias_method :stored_key?, :key?
  private :stored_key?

  def [](key)
    super(resolve_key(key))
  end

  def fetch(key, *args, &block)
    super(resolve_key(key), *args, &block)
  end

  def dig(key, *rest)
    super(resolve_key(key), *rest)
  end

  def values_at(*keys)
    super(*keys.collect { |key| resolve_key(key) })
  end

  def key?(key)
    stored_key?(resolve_key(key))
  end

  alias_method :has_key?, :key?
  alias_method :include?, :key?
  alias_method :member?, :key?

  private

  # Return the key as it is stored in the hash. If the key is not present in
  # either its string or symbol form, then the key itself is returned so that
  # normal missing key semantics apply.
  #
  # @param key [Object] The key being looked up.
  # @return [Object] The key to use for the lookup.
  def resolve_key(key)
    return key if stored_key?(key)

    alternate = if key.is_a?(String)
      key.to_sym
    elsif key.is_a?(Symbol)
      key.to_s
    end

    (alternate && stored_key?(alternate)) ? alternate : key
  end
end
