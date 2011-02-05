module Lumberjack
  # This is an abstract class for logging devices. Subclasses must implement the +write+ method and
  # may implement the +close+ and +flush+ methods if applicable.
  class Device
    autoload :DateRollingLogFile, File.expand_path("../device/date_rolling_log_file.rb", __FILE__)
    autoload :LogFile, File.expand_path("../device/log_file.rb", __FILE__)
    autoload :Null, File.expand_path("../device/null.rb", __FILE__)
    autoload :RollingLogFile, File.expand_path("../device/rolling_log_file.rb", __FILE__)
    autoload :SizeRollingLogFile, File.expand_path("../device/size_rolling_log_file.rb", __FILE__)
    autoload :Writer, File.expand_path("../device/writer.rb", __FILE__)

    # Subclasses must implement this method to write a LogEntry.
    def write(entry)
      raise NotImpelementedError
    end
    
    # Subclasses may implement this method to close the device.
    def close
      flush
    end
    
    # Subclasses may implement this method to flush any buffers used by the device.
    def flush
    end
  end
end
