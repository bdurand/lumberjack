# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Device::DateRollingLogFile do
  it "is a deprecated alias for Lumberjack::Device::LogFile", deprecation_mode: :silent do
    file = Tempfile.new("lumberjack_test")
    begin
      device = Lumberjack::Device::DateRollingLogFile.new(file.path, roll: :daily)
      expect(device).to be_a(Lumberjack::Device::LogFile)
      expect(device.send(:stream).instance_variable_get(:@shift_age)).to eq("daily")
    ensure
      file.close
      file.unlink
    end
  end
end
