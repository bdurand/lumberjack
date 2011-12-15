require 'rbconfig'
require 'time'
require 'thread'

module Lumberjack
  autoload :Device, File.expand_path("../lumberjack/device.rb", __FILE__)
  autoload :Formatter, File.expand_path("../lumberjack/formatter.rb", __FILE__)
  autoload :LogEntry, File.expand_path("../lumberjack/log_entry.rb", __FILE__)
  autoload :Logger, File.expand_path("../lumberjack/logger.rb", __FILE__)
  autoload :Rack, File.expand_path("../lumberjack/rack.rb", __FILE__)
  autoload :Severity, File.expand_path("../lumberjack/severity.rb", __FILE__)
  autoload :Template, File.expand_path("../lumberjack/template.rb", __FILE__)
  
  LINE_SEPARATOR = (RbConfig::CONFIG['host_os'].match(/mswin/i) ? "\r\n" : "\n")

  class << self
    # Define a unit of work within a block. Within the block supplied to this
    # method, calling +unit_of_work_id+ will return the same 12 digit hexadecimal number string.
    # This can then be used for tying together log entries.
    #
    # For the common use case of treating a single web request as a unit of work, see the
    # Lumberjack::Rack::UnitOfWork class.
    def unit_of_work
      save_val = Thread.current[:lumberjack_logger_unit_of_work_id]
      Thread.current[:lumberjack_logger_unit_of_work_id] = rand(0xFFFFFFFFFFFF).to_s(16).rjust(12, '0').upcase
      begin
        return yield
      ensure
        Thread.current[:lumberjack_logger_unit_of_work_id] = save_val
      end
    end
    
    # Get the UniqueIdentifier for the current unit of work.
    def unit_of_work_id
      Thread.current[:lumberjack_logger_unit_of_work_id] 
    end
  end
end
