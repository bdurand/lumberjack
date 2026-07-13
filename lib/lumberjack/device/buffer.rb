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
    # Internal class that manages the entry buffer and flushing logic.
    class EntryBuffer
      attr_accessor :size

      attr_reader :device

      def initialize(device, size, before_flush)
        @device = device
        @size = size
        @before_flush = before_flush if before_flush.respond_to?(:call)
        @before_flush_guard = :"lumberjack_device_buffer_before_flush_#{object_id}"
        @lock = Mutex.new
        @flush_lock = Mutex.new
        @entries = []
        @last_flushed_at = Time.now
        @closed = false
      end

      def <<(entry)
        flush_needed = false

        @lock.synchronize do
          unless @closed
            @entries << entry
            flush_needed = @entries.size >= @size
          end
        end

        flush if flush_needed
      end

      # Concurrent flushes are serialized by a separate lock so that batches cannot be
      # interleaved or reordered when written to the wrapped device. The entry lock is
      # only held while swapping out the buffered entries so that threads writing new
      # entries are not blocked while the wrapped device performs I/O.
      def flush
        call_before_flush

        @flush_lock.synchronize do
          entries = nil
          @lock.synchronize do
            entries = @entries
            @entries = []
            @last_flushed_at = Time.now
          end

          entries.each do |entry|
            @device.write(entry)
          rescue => e
            warn("Error writing log entry from buffer: #{e.inspect}")
          end
        end
      end

      def close
        @lock.synchronize { @closed = true }
        flush
      end

      def closed?
        @lock.synchronize { @closed }
      end

      def reopen
        @lock.synchronize { @closed = false }
      end

      def empty?
        @lock.synchronize { @entries.empty? }
      end

      def last_flushed_at
        @lock.synchronize { @last_flushed_at }
      end

      private

      # The callback must be invoked outside the mutex so that a callback that logs
      # through this buffer cannot deadlock on a recursive lock. The thread local
      # guards against infinite recursion when a callback write triggers another flush.
      # The guard is scoped per instance so a callback that logs through a different
      # buffer does not suppress that buffer's own callback.
      def call_before_flush
        return if @before_flush.nil? || Thread.current[@before_flush_guard]

        begin
          Thread.current[@before_flush_guard] = true
          @before_flush.call
        ensure
          Thread.current[@before_flush_guard] = nil
        end
      end
    end

    class << self
      private

      def create_finalizer(buffer) # :nodoc:
        lambda { |object_id| buffer.close }
      end

      def create_flusher_thread(flush_seconds, buffer) # :nodoc:
        Thread.new do
          until buffer.closed?
            sleep(flush_seconds)
            buffer.flush if Time.now - buffer.last_flushed_at >= flush_seconds
          end
        end
      end
    end

    # Initialize a new buffered logging device that wraps another device.
    #
    # @param wrapped_device [Lumberjack::Device, String, Symbol, IO] The underlying device to wrap.
    #   This can be any valid device specification that +Lumberjack::Device.open_device+ accepts.
    #   Options not related to buffering will be passed to the underlying device constructor.
    # @param options [Hash] Options for the buffer and the underlying device.
    # @option options [Integer] :buffer_size The number of entries to buffer before flushing. Default is 0 (no buffering).
    # @option options [Integer] :flush_seconds If specified, a background thread will flush the buffer every N seconds.
    # @option options [Proc] :before_flush A callback that will be called before each flush. The callback should
    #  respond to +call+ and take no arguments. The callback is invoked outside of the buffer lock, so it may
    #  be called concurrently from multiple threads flushing at the same time; it must be thread safe if it
    #  modifies any shared state.
    def initialize(wrapped_device, options = {})
      buffer_options = [:buffer_size, :flush_seconds, :before_flush]
      device_options = options.reject { |k, _| buffer_options.include?(k) }
      device = Device.open_device(wrapped_device, device_options)

      @buffer = EntryBuffer.new(device, options[:buffer_size] || 0, options[:before_flush])

      flush_seconds = options[:flush_seconds]
      self.class.send(:create_flusher_thread, flush_seconds, @buffer) if flush_seconds.is_a?(Numeric) && flush_seconds > 0

      # Add a finalizer to ensure flush is called before the object is destroyed
      ObjectSpace.define_finalizer(self, self.class.send(:create_finalizer, @buffer))
    end

    def buffer_size
      @buffer.size
    end

    # Set the buffer size. The underlying device will only be written to when the buffer size
    # is exceeded.
    #
    # @param [Integer] value The number of entries to buffer before flushing.
    # @return [void]
    def buffer_size=(value)
      @buffer.size = value
      @buffer.flush
    end

    # Write an entry to the underlying device.
    #
    # @param [LogEntry, String] entry The entry to write.
    # @return [void]
    def write(entry)
      @buffer << entry
    end

    # Close the device.
    #
    # @return [void]
    def close
      @buffer.close
      @buffer.device.close

      # Remove the finalizer since we've already flushed
      ObjectSpace.undefine_finalizer(self)
    end

    # Return true if the buffer has been closed.
    def closed?
      @buffer.closed?
    end

    # Flush the buffer to the underlying device.
    #
    # @return [void]
    def flush
      @buffer.flush
    end

    # Reopen the underlying device, optionally with a new log destination.
    def reopen(logdev = nil)
      flush
      @buffer.device.reopen(logdev)
      @buffer.reopen
      ObjectSpace.define_finalizer(self, self.class.send(:create_finalizer, @buffer))
    end

    # Return the underlying stream. Provided for API compatibility with Logger devices.
    #
    # @return [IO] The underlying stream.
    def dev
      @buffer.device.dev
    end

    # @api private
    def last_flushed_at
      @buffer.last_flushed_at
    end

    # @api private
    def empty?
      @buffer.empty?
    end
  end
end
