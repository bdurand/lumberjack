# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::LocalLogTemplate do
  let(:entry) do
    Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test message", "myapp", 1234, "foo" => "bar", "baz.bax" => "qux")
  end

  it "formats log entries with values pertinent to test environments" do
    template = Lumberjack::LocalLogTemplate.new
    formatted = template.call(entry)
    expected = <<~STRING.chomp
      INFO test message
          progname: myapp
          baz.bax: qux
          foo: bar
    STRING
    expect(formatted).to eq(expected)
  end

  it "can add the time" do
    template = Lumberjack::LocalLogTemplate.new(exclude_time: false)
    formatted = template.call(entry)
    expected = <<~STRING.chomp
      #{entry.time.strftime("%Y-%m-%d %H:%M:%S.%6N")} INFO test message
          progname: myapp
          baz.bax: qux
          foo: bar
    STRING
    expect(formatted).to eq(expected)
  end

  it "can add the pid" do
    template = Lumberjack::LocalLogTemplate.new(exclude_pid: false)
    formatted = template.call(entry)
    expected = <<~STRING.chomp
      INFO test message
          progname: myapp
          pid: 1234
          baz.bax: qux
          foo: bar
    STRING
    expect(formatted).to eq(expected)
  end

  it "can exclude the progname" do
    template = Lumberjack::LocalLogTemplate.new(exclude_progname: true)
    formatted = template.call(entry)
    expected = <<~STRING.chomp
      INFO test message
          baz.bax: qux
          foo: bar
    STRING
    expect(formatted).to eq(expected)
  end

  it "can exclude all attributes" do
    template = Lumberjack::LocalLogTemplate.new(exclude_attributes: true)
    formatted = template.call(entry)
    expected = <<~STRING.chomp
      INFO test message
          progname: myapp
    STRING
    expect(formatted).to eq(expected)
  end

  it "can exclude specific attributes" do
    template = Lumberjack::LocalLogTemplate.new(exclude_attributes: ["foo"])
    formatted = template.call(entry)
    expected = <<~STRING.chomp
      INFO test message
          progname: myapp
          baz.bax: qux
    STRING
    expect(formatted).to eq(expected)
  end

  it "can exclude specific nested attributes" do
    template = Lumberjack::LocalLogTemplate.new(exclude_attributes: ["baz"])
    formatted = template.call(entry)
    expected = <<~STRING.chomp
      INFO test message
          progname: myapp
          foo: bar
    STRING
    expect(formatted).to eq(expected)
  end
end
