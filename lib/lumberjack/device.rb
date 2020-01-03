# frozen_string_literals: true

module Lumberjack
  # This is an abstract class for logging devices. Subclasses must implement the +write+ method and
  # may implement the +close+ and +flush+ methods if applicable.
  class Device
    require_relative "device/writer.rb"
    require_relative "device/log_file.rb"
    require_relative "device/rolling_log_file.rb"
    require_relative "device/date_rolling_log_file.rb"
    require_relative "device/size_rolling_log_file.rb"
    require_relative "device/multi.rb"
    require_relative "device/null.rb"

    # Subclasses must implement this method to write a LogEntry.
    def write(entry)
      raise NotImplementedError
    end
    
    # Subclasses may implement this method to close the device.
    def close
      flush
    end
    
    # Subclasses may implement this method to reopen the device.
    def reopen(logdev = nil)
      flush
    end
    
    # Subclasses may implement this method to flush any buffers used by the device.
    def flush
    end
    
    # Subclasses may implement this method to get the format for log timestamps.
    def datetime_format
    end
    
    # Subclasses may implement this method to set a format for log timestamps.
    def datetime_format=(format)
    end
  end
end
