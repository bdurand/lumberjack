# frozen_string_literal: true

require "spec_helper"

describe Lumberjack::ContextLogger do
  let(:logger) { TestContextLogger.new }
  let(:logger_with_default_context) { TestContextLogger.new(default_context) }
  let(:default_context) { Lumberjack::Context.new }

  it "needs to be tested"
end
