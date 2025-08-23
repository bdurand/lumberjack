# frozen_string_literal: true

module Lumberjack
  # TagFormatter has been renamed to {AttributeFormatter} as part of the transition from
  # "tags" to "attributes" terminology in Lumberjack 2.0. This class exists solely for
  # backward compatibility with the 1.x API and will be removed in a future version.
  #
  # All functionality has been moved to {AttributeFormatter} with no changes to the API.
  # Simply replace `TagFormatter` with `AttributeFormatter` in your code.
  #
  # @deprecated Use {Lumberjack::AttributeFormatter} instead.
  # @see Lumberjack::AttributeFormatter
  #
  # @example Migration
  #   # Old code (deprecated)
  #   formatter = Lumberjack::TagFormatter.new
  #
  #   # New code
  #   formatter = Lumberjack::AttributeFormatter.new
  class TagFormatter < AttributeFormatter
    # Create a new TagFormatter instance. Issues a deprecation warning and delegates
    # to {AttributeFormatter}.
    #
    # @deprecated Use {Lumberjack::AttributeFormatter.new} instead.
    def initialize
      Utils.deprecated("Lumberjack::TagFormatter", "Use Lumberjack::AttributeFormatter instead.") do
        super
      end
    end
  end
end
