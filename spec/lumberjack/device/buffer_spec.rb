# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Device::Buffer do
  let(:device) { Lumberjack::Device::Test.new }
  let(:entry_1) { Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Message 1", nil, Process.pid, nil) }
  let(:entry_2) { Lumberjack::LogEntry.new(Time.now, Logger::INFO, "Message 2", nil, Process.pid, nil) }

  describe "#write" do
    it "writes entries immediately when buffer_size is 0" do
      buffer = Lumberjack::Device::Buffer.new(device, buffer_size: 0)
      begin
        buffer.write(entry_1)
        expect(device.entries.size).to eq(1)
        expect(device.entries.first).to eq(entry_1)
      ensure
        buffer.close unless buffer.closed?
      end
    end

    it "buffers entries and flushes when buffer_size is reached" do
      buffer = Lumberjack::Device::Buffer.new(device, buffer_size: 2)
      begin
        buffer.write(entry_1)
        expect(device.entries.size).to eq(0) # Not flushed yet
        buffer.write(entry_2)
        expect(device.entries).to eq([entry_1, entry_2])
        buffer.write(entry_2)
        buffer.write(entry_1)
        expect(device.entries).to eq([entry_1, entry_2, entry_2, entry_1])
      ensure
        buffer.close unless buffer.closed?
      end
    end
  end

  describe "#flush" do
    it "flushes entries when called" do
      buffer = Lumberjack::Device::Buffer.new(device, buffer_size: 5)
      begin
        buffer.write(entry_1)
        buffer.write(entry_2)
        buffer.flush
        expect(device.entries).to eq([entry_1, entry_2])
      ensure
        buffer.close unless buffer.closed?
      end
    end

    it "calls before_flush callback if provided" do
      before_flush_called = false
      before_flush = proc { before_flush_called = true }
      buffer = Lumberjack::Device::Buffer.new(device, buffer_size: 5, before_flush: before_flush)
      begin
        buffer.write(entry_1)
        buffer.flush
        expect(before_flush_called).to be true
        expect(device.entries).to eq([entry_1])
      ensure
        buffer.close unless buffer.closed?
      end
    end

    it "sets last_flushed_at timestamp" do
      buffer = Lumberjack::Device::Buffer.new(device, buffer_size: 5)
      begin
        initial_time = buffer.last_flushed_at
        buffer.write(entry_1)
        buffer.flush
        flushed_time = buffer.last_flushed_at
        expect(flushed_time).to be > initial_time
      ensure
        buffer.close unless buffer.closed?
      end
    end
  end

  describe "#close" do
    it "flushes entries and closes the wrapped device" do
      buffer = Lumberjack::Device::Buffer.new(device, buffer_size: 5)
      begin
        buffer.write(entry_1)
        expect(device).to receive(:close)
        buffer.close
        expect(device.entries).to eq([entry_1])
        expect { buffer.write(entry_2) }.not_to raise_error
        expect(buffer).to be_empty
      ensure
        buffer.close unless buffer.closed?
      end
    end
  end

  describe "#reopen" do
    it "flushes entries and reopens the wrapped device" do
      buffer = Lumberjack::Device::Buffer.new(device, buffer_size: 5)
      begin
        buffer.write(entry_1)
        expect(device).to receive(:reopen).with(nil)
        buffer.reopen
        expect(device.entries).to eq([entry_1])
      ensure
        buffer.close unless buffer.closed?
      end
    end
  end

  describe "#buffer_size" do
    it "returns the configured buffer size" do
      buffer = Lumberjack::Device::Buffer.new(device)
      begin
        expect(buffer.buffer_size).to eq(0)
        buffer.buffer_size = 3
        expect(buffer.buffer_size).to eq(3)
      ensure
        buffer.close unless buffer.closed?
      end
    end
  end

  describe "flusher thread" do
    it "automatically flushes entries after flush_seconds interval" do
      buffer = Lumberjack::Device::Buffer.new(device, buffer_size: 5, flush_seconds: 0.15)
      begin
        buffer.write(entry_1)
        expect(device.entries.size).to eq(0)
        sleep 0.2
        expect(device.entries).to eq([entry_1])
      ensure
        buffer.close unless buffer.closed?
      end
    end
  end

  describe "before_flush re-entrancy" do
    it "does not deadlock when the callback flushes the buffer" do
      buffer = nil
      before_flush = proc { buffer.flush }
      buffer = Lumberjack::Device::Buffer.new(device, buffer_size: 5, before_flush: before_flush)
      begin
        buffer.write(entry_1)
        expect { buffer.flush }.not_to raise_error
        expect(device.entries).to eq([entry_1])
      ensure
        buffer.close unless buffer.closed?
      end
    end

    it "does not deadlock or recurse infinitely when the callback writes to the buffer" do
      buffer = nil
      before_flush = proc { buffer.write(entry_2) }
      buffer = Lumberjack::Device::Buffer.new(device, buffer_size: 1, before_flush: before_flush)
      begin
        buffer.write(entry_1)
        buffer.flush
        expect(device.entries).to include(entry_1)
        expect(device.entries).to include(entry_2)
      ensure
        buffer.close unless buffer.closed?
      end
    end

    it "does not suppress the callback of a different buffer flushed from within a callback" do
      other_device = Lumberjack::Device::Test.new
      other_before_flush_called = false
      other_before_flush = proc { other_before_flush_called = true }
      other_buffer = Lumberjack::Device::Buffer.new(other_device, buffer_size: 5, before_flush: other_before_flush)

      before_flush = proc do
        other_buffer.write(entry_2)
        other_buffer.flush
      end
      buffer = Lumberjack::Device::Buffer.new(device, buffer_size: 5, before_flush: before_flush)

      begin
        buffer.write(entry_1)
        buffer.flush
        expect(device.entries).to eq([entry_1])
        expect(other_device.entries).to eq([entry_2])
        expect(other_before_flush_called).to be true
      ensure
        buffer.close unless buffer.closed?
        other_buffer.close unless other_buffer.closed?
      end
    end
  end

  describe "thread safety" do
    it "serializes writes to the wrapped device when flushing from multiple threads" do
      tracking_device_class = Class.new(Lumberjack::Device) do
        attr_reader :entries, :max_concurrent_writes

        def initialize
          @entries = []
          @mutex = Mutex.new
          @active_writes = 0
          @max_concurrent_writes = 0
        end

        def write(entry)
          @mutex.synchronize do
            @active_writes += 1
            @max_concurrent_writes = [@max_concurrent_writes, @active_writes].max
          end
          sleep(0.001)
          @mutex.synchronize do
            @entries << entry
            @active_writes -= 1
          end
        end
      end

      tracking_device = tracking_device_class.new
      buffer = Lumberjack::Device::Buffer.new(tracking_device, buffer_size: 100)
      thread_count = 4
      entries_per_thread = 5

      threads = thread_count.times.collect do |i|
        Thread.new do
          entries_per_thread.times do |n|
            entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "thread #{i} entry #{n}", nil, Process.pid, nil)
            buffer.write(entry)
            buffer.flush
          end
        end
      end
      threads.each(&:join)
      buffer.close

      expect(tracking_device.entries.size).to eq(thread_count * entries_per_thread)
      expect(tracking_device.max_concurrent_writes).to eq(1)
    end

    it "does not lose entries when multiple threads write concurrently" do
      buffer = Lumberjack::Device::Buffer.new(device, buffer_size: 3)
      thread_count = 8
      entries_per_thread = 100

      threads = thread_count.times.collect do |i|
        Thread.new do
          entries_per_thread.times do |n|
            entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "thread #{i} entry #{n}", nil, Process.pid, nil)
            buffer.write(entry)
          end
        end
      end
      threads.each(&:join)
      buffer.close

      expect(device.entries.size).to eq(thread_count * entries_per_thread)
    end
  end
end
