# frozen_string_literal: true

require "date"

module Lumberjack
  # Deprecated device. Use LogFile instead.
  #
  # @deprecated Use Lumberjack::Device::LogFile
  class Device::DateRollingLogFile < Device::LogFile
    def initialize(path, options = {})
      Utils.deprecated("Lumberjack::Device::DateRollingLogFile", "Lumberjack::Device::DateRollingLogFile is deprecated and will be removed in version 2.1; use Lumberjack::Device::LogFile instead.")

      unless options[:roll]&.to_s&.match(/(daily)|(weekly)|(monthly)/i)
        raise ArgumentError.new("illegal value for :roll (#{options[:roll].inspect})")
      end

      new_options = options.reject { |k, _| k == :roll }.merge(shift_age: options[:roll].to_s.downcase)

      super(path, new_options)
    end
  end
end
