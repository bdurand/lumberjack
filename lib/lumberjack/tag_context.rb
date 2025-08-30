# frozen_string_literal: true

module Lumberjack
  # This class was renamed to Lumberjack::AttributesHelper. This class is provided for
  # backward compatibility with the version 1.x API and will eventually be removed.
  #
  # @deprecated Use Lumberjack::AttributesHelper instead.
  class TagContext < AttributesHelper
    def initialize
      Utils.deprecated("Lumberjack::TagContext", "Use Lumberjack::AttributesHelper instead.") do
        super
      end
    end
  end
end
