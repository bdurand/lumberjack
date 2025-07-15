# frozen_string_literal: true

require "spec_helper"

describe Lumberjack::Utils do
  describe ".hostname" do
    it "returns the hostname in UTF-8 encoding" do
      expect(Lumberjack::Utils.hostname).to be_a(String)
      expect(Lumberjack::Utils.hostname.encoding).to eq(Encoding::UTF_8)
    end

    it "caches the hostname" do
      expect(Lumberjack::Utils.hostname.object_id).to eq(Lumberjack::Utils.hostname.object_id)
    end

    it "returns an explicitly set hostname" do
      hostname = Lumberjack::Utils.hostname
      begin
        Lumberjack::Utils.hostname = "test-host"
        expect(Lumberjack::Utils.hostname).to eq("test-host")
      ensure
        Lumberjack::Utils.hostname = hostname
      end
    end
  end

  describe ".global_pid" do
    it "generates a global process ID" do
      expect(Lumberjack::Utils.global_pid).to eq "#{Lumberjack::Utils.hostname}-#{Process.pid}"
    end
  end

  describe ".global_thread_id" do
    it "generates a global thread ID" do
      expect(Lumberjack::Utils.global_thread_id).to eq "#{Lumberjack::Utils.global_pid}-#{Lumberjack::Utils.thread_name}"
    end
  end

  describe ".thread_name" do
    it "generates a name based on the object id if there is no thread name" do
      thread = Thread.new { sleep 0.001 }
      expect(Lumberjack::Utils.thread_name(thread)).to eq thread.object_id.to_s(36)
    end

    it "generates a sluggified name based on the thread name" do
      thread = Thread.new { sleep 0.001 }
      thread.name = "Test Thread"
      expect(Lumberjack::Utils.thread_name(thread)).to eq "Test-Thread"
    end
  end
end
