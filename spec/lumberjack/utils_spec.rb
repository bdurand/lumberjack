# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Utils do
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

  describe ".flatten_attributes" do
    it "flattens a nested attribute hash" do
      attribute_hash = {"user" => {"id" => 123, "name" => "Alice"}, "action" => "login"}
      expect(Lumberjack::Utils.flatten_attributes(attribute_hash)).to eq(
        "user.id" => 123,
        "user.name" => "Alice",
        "action" => "login"
      )
    end

    it "flattens a deeply nested attribute hash" do
      attribute_hash = {"a" => {"b" => {"c" => 3, "d" => 4}}, "e" => 5}
      expect(Lumberjack::Utils.flatten_attributes(attribute_hash)).to eq(
        "a.b.c" => 3,
        "a.b.d" => 4,
        "e" => 5
      )
    end

    it "returns an empty hash for non-hash input" do
      expect(Lumberjack::Utils.flatten_attributes("not a hash")).to eq({})
    end

    it "handles mixing dot notation with nested attributes with dot notation attributes first" do
      attribute_hash = {"user.id" => 123, user: {"name" => "Alice"}, "user.action": "login"} # rubocop:disable Style/HashSyntax
      expect(Lumberjack::Utils.flatten_attributes(attribute_hash)).to eq(
        "user.id" => 123,
        "user.name" => "Alice",
        "user.action" => "login"
      )
    end

    it "handles mixing dot notation with structured attributes first" do
      attribute_hash = {user: {id: 123, name: "Alice"}, "user.action": "login"}
      expect(Lumberjack::Utils.flatten_attributes(attribute_hash)).to eq(
        "user.id" => 123,
        "user.name" => "Alice",
        "user.action" => "login"
      )
    end
  end

  describe ".expand_attributes" do
    it "expands a hash with nested hashes and dot notation keys" do
      attribute_hash = {"user.id" => 123, "user.name" => "Alice", "action" => "login"}
      expect(Lumberjack::Utils.expand_attributes(attribute_hash)).to eq(
        "user" => {"id" => 123, "name" => "Alice"},
        "action" => "login"
      )
    end

    it "handles mixed dot notation and nested hashes with dot notation attributes first" do
      attribute_hash = {"user.id" => 123, user: {"name" => "Alice"}, "user.action": "login"} # rubocop:disable Style/HashSyntax
      expect(Lumberjack::Utils.expand_attributes(attribute_hash)).to eq(
        "user" => {"id" => 123, "name" => "Alice", "action" => "login"}
      )
    end

    it "handles mix dot notation with structured attributes first" do
      attribute_hash = {user: {id: 123, name: "Alice"}, "user.action": "login"}
      expect(Lumberjack::Utils.expand_attributes(attribute_hash)).to eq(
        "user" => {"id" => 123, "name" => "Alice", "action" => "login"}
      )
    end
  end

  describe ".deprecated" do
    around do |example|
      original_verbose = $VERBOSE
      original_deprecated = Warning[:deprecated]
      begin
        $VERBOSE = false
        Warning[:deprecated] = true
        example.run
      ensure
        $VERBOSE = original_verbose
        Warning[:deprecated] = original_deprecated
      end
    end

    it "prints a deprecation warning the first time a deprecated method is called" do
      retval = nil
      expect { retval = Lumberjack::Utils.deprecated("test_method_1", "This is deprecated") { :foo } }.to output.to_stderr
      expect(retval).to eq :foo
    end

    it "does not print the warning again for subsequent calls" do
      expect { Lumberjack::Utils.deprecated("test_method_2", "This is deprecated") { :foo } }.to output(/DEPRECATION WARNING: This is deprecated/).to_stderr
      expect { Lumberjack::Utils.deprecated("test_method_2", "This is deprecated") { :bar } }.not_to output.to_stderr
    end
  end

  describe ".current_line" do
    it "returns the line of code that calls the method" do
      expect(Lumberjack::Utils.current_line).to start_with("#{__FILE__}:#{__LINE__}")
    end
  end
end
