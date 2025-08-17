# frozen_string_literal: true

module Lumberjack
  # Provide methods used to write to IO objects. These allow a logger to be treated like
  # a stream. Values written to the stream are written as log messages with a timestamp
  # and severity label of ANY.
  #
  # @example
  #
  # logger.puts("Hello, world!")
  module IOCompatibility
    # Write a value to the log. It will be recorded with an UNKNOWN severity.
    #
    # @param value [Object] The log message to write
    # @return [Integer] Returns 1 if a log entry was written or 0 if not.
    def write(value)
      self << value
      (value.nil? || value == "") ? 0 : 1
    end

    # Writes the values to the log. Each value will be recorded with an UNKNOWN severity.
    #
    # @param args [Array<Object>] The log messages to write
    # @return [nil]
    def puts(*args)
      args.each do |arg|
        write(arg)
      end
      nil
    end

    # Writes the values to the log. Each value will be recorded with an UNKNOWN severity.
    # If no arguments are given, the last input will be used.
    #
    # @param args [Array<Object>] The log messages to write
    # @return [nil]
    def print(*args)
      if args.empty?
        write($_)
      else
        args.each { |arg| write(arg) }
      end
      nil
    end

    # Writes the formatted string to the log. It will be recorded with an UNKNOWN severity.
    #
    # @param format [String] The format string
    # @param args [Array<Object>] The values to format
    # @return [nil]
    def printf(format, *args)
      write(format % args)
      nil
    end

    # This method does nothing but is here so flush can be called without error.
    #
    # @return [nil]
    def flush
    end

    # This method does nothing but is here so close can be called without error.
    #
    # @return [nil]
    def close
    end

    # This method does nothing but is here so close can be called without error.
    #
    # @return [Boolean]
    def closed?
      false
    end

    # @api private
    def tty?
      false
    end
  end
end
