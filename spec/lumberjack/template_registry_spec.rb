# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::TemplateRegistry do
  it "has :default, :stdlib, :local, :development, and :test registered by default" do
    expect(Lumberjack::TemplateRegistry.registered_templates).to eq({
      default: Lumberjack::Template::DEFAULT_FIRST_LINE_TEMPLATE,
      stdlib: Lumberjack::Template::STDLIB_FIRST_LINE_TEMPLATE,
      local: Lumberjack::LocalLogTemplate,
      development: Lumberjack::LocalLogTemplate,
      test: Lumberjack::LocalLogTemplate
    })
  end

  it "can add new templates to the registry" do
    template = lambda { |entry| "foobar" }
    Lumberjack::TemplateRegistry.add(:foobar, template)
    expect(Lumberjack::TemplateRegistry.template(:foobar)).to eq template
    expect(Lumberjack::TemplateRegistry.template(:other)).to be_nil
  ensure
    Lumberjack::TemplateRegistry.remove(:foobar)
  end

  it "can instantiate a template class by name and options" do
    template = Lumberjack::TemplateRegistry.template(:test, exclude_pid: false)
    expect(template).to be_a(Lumberjack::LocalLogTemplate)
    expect(template.exclude_pid?).to be false
  end

  it "can instantiate a template string by name and options" do
    template = Lumberjack::TemplateRegistry.template(:stdlib)
    expect(template).to be_a(Lumberjack::Template)
    entry = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "test message", "myapp", 1234, "foo" => "bar", "baz.bax" => "qux")
    formatted = template.call(entry)
    expected = "I, [#{entry.time.strftime("%Y-%m-%dT%H:%M:%S.%3N")} 1234] INFO  -- myapp: test message [foo:bar] [baz.bax:qux]\n"
    expect(formatted).to eq(expected)
  end
end
