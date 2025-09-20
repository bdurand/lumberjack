# frozen_string_literal: true

module Lumberjack
  # A buffered logging device that wraps another logging device. Entries are buffered in memory
  # until the buffer size is reached or the device is flushed.
  #
  # @example Create a buffered device that flushes every 5 entries
  #   device = Lumberjack::Device::Buffer.new(Lumberjack::Device::LogFile.new("logfile.log"), buffer_size: 5)
  #
  # @example Create a buffered device that automatically flushes every 10 seconds
  #   device = Lumberjack::Device::Buffer.new("/var/log/app.log", buffer_size: 10, flush_seconds: 10)
  #
  # @example Create a buffered device with a before_flush callback
  #   before_flush = -> { puts "Flushing log buffer" }
  #   device = Lumberjack::Device::Buffer.new(device, buffer_size: 10, before_flush: before_flush)
  class Device::Buffer < Device
    # Initialize a new buffered logging device that wraps another device.
    #
    # @param wrapped_device [Lumberjack::Device, String, Symbol, IO] The underlying device to wrap.
    #   This can be any valid device specification that `Lumberjack::Device.open_device` accepts.
    #   Options not related to buffering will be passed to the underlying device constructor.
    # @param options [Hash] Options for the buffer and the underlying device.
    # @option options [Integer] :buffer_size The number of entries to buffer before flushing. Default is 0 (no buffering).
    # @option options [Integer] :flush_seconds If specified, a background thread will flush the buffer every N seconds.
    # @option options [Proc] :before_flush A callback that will be called before each flush. The callback should
    #  respond to `call` and take no arguments.
    def initialize(wrapped_device, options = {})
      @lock = Mutex.new
      @closed = false
      @buffer = []
      @buffer_size = options[:buffer_size] || 0
      @last_flushed_at = Time.now
      @before_flush = options[:before_flush] if options[:before_flush].respond_to?(:call)

      buffer_options = [:buffer_size, :flush_seconds, :before_flush]
      device_options = options.reject { |k, _| buffer_options.include?(k) }
      @wrapped_device = Device.open_device(wrapped_device, device_options)

      flush_seconds = options[:flush_seconds]
      create_flusher_thread(flush_seconds) if flush_seconds.is_a?(Numeric) && flush_seconds > 0
    end

    # The size of the buffer.
    attr_reader :buffer_size

    # Set the buffer size. The underlying device will only be written to when the buffer size
    # is exceeded.
    #
    # @param [Integer] value The size of the buffer in bytes.
    # @return [void]
    def buffer_size=(value)
      @buffer_size = value
      flush
    end

    # Write an entry to the underlying device.
    #
    # @param [LogEntry, String] entry The entry to write.
    # @return [void]
    def write(entry)
      return if @closed

      @lock.synchronize do
        @buffer << entry
      end

      flush if @buffer.size >= buffer_size
    end

    # Close the device.
    #
    # @return [void]
    def close
      flush
      @closed = true
      @wrapped_device.close
    end

    # Flush the buffer to the underlying device.
    #
    # @return [void]
    def flush
      return if @closed

      entries = nil
      @lock.synchronize do
        @before_flush&.call
        entries = @buffer
        @buffer = []
      end

      @last_flushed_at = Time.now

      return if entries.nil?

      entries.each do |entry|
        @wrapped_device.write(entry)
      end
    end

    # The timestamp of the last flush.
    #
    # @return [Time] The time of the last flush.
    attr_reader :last_flushed_at

    # Reopen the underlying device, optionally with a new log destination.
    def reopen(logdev = nil)
      flush
      @closed = false
      @wrapped_device.reopen(logdev)
    end

    # Return the underlying stream. Provided for API compatibility with Logger devices.
    #
    # @return [IO] The underlying stream.
    def dev
      @wrapped_device.dev
    end

    private

    def create_flusher_thread(flush_seconds) # :nodoc:
      Thread.new do
        until @closed
          begin
            sleep(flush_seconds)
            flush if Time.now - @last_flushed_at >= flush_seconds
          rescue => e
            warn("Error flushing log: #{e.inspect}")
          end
        end
      end
    end
  end
end
