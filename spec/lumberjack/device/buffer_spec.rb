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
end
