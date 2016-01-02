require 'date'

module Lumberjack
  class Device
    # This log device will append entries to a file and roll the file periodically by date. Files
    # are rolled at midnight and can be rolled daily, weekly, or monthly. Archive file names will
    # have the date appended to them in the format ".YYYY-MM-DD" for daily, ".week-of-YYYY-MM-DD" for weekly
    # and ".YYYY-MM" for monthly. It is not guaranteed that log messages will break exactly on the
    # roll period as buffered entries will always be written to the same file.
    class DateRollingLogFile < RollingLogFile
      # Create a new logging device to the specified file. The period to roll the file is specified
      # with the <tt>:roll</tt> option which may contain a value of <tt>:daily</tt>, <tt>:weekly</tt>,
      # or <tt>:monthly</tt>.
      def initialize(path, options = {})
        @file_date = Date.today
        if options[:roll] && options[:roll].to_s.match(/(daily)|(weekly)|(monthly)/i)
          @roll_period = $~[0].downcase.to_sym
          options.delete(:roll)
        else
          raise ArgumentError.new("illegal value for :roll (#{options[:roll].inspect})")
        end
        super
      end

      def archive_file_suffix
        case @roll_period
        when :weekly
          "#{@file_date.strftime('week-of-%Y-%m-%d')}"
        when :monthly
          "#{@file_date.strftime('%Y-%m')}"
        else
          "#{@file_date.strftime('%Y-%m-%d')}"
        end
      end

      def roll_file?
        date = Date.today
        if date.year > @file_date.year
          true
        elsif @roll_period == :daily && date.yday != @file_date.yday
          true
        elsif @roll_period == :weekly && date.cweek != @file_date.cweek
          true
        elsif @roll_period == :monthly && date.month != @file_date.month
          true
        else
          false
        end
      end
      
      protected
      
      def after_roll
        @file_date = Date.today
      end
    end
  end
end
