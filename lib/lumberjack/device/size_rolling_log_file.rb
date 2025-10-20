# frozen_string_literal: true

module Lumberjack
  # Deprecated device. Use LogFile instead.
  #
  # @deprecated Use Lumberjack::Device::LogFile
  class Device::SizeRollingLogFile < Device::LogFile
    attr_reader :max_size

    # Create an new log device to the specified file. The maximum size of the log file is specified with
    # the :max_size option. The unit can also be specified: "32K", "100M", "2G" are all valid.
    def initialize(path, options = {})
      Utils.deprecated("Lumberjack::Device::SizeRollingLogFile", "Lumberjack::Device::SizeRollingLogFile is deprecated and will be removed in version 2.1; use Lumberjack::Device::LogFile instead.")

      @max_size = options[:max_size]
      new_options = options.reject { |k, _| k == :max_size }.merge(shift_size: max_size)
      new_options[:shift_age] = 10 unless options[:shift_age].is_a?(Integer) && options[:shift_age] >= 0

      super(path, new_options)
    end
  end
end
