# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Device::SizeRollingLogFile do
  it "is a deprecated alias for Lumberjack::Device::LogFile", deprecation_mode: :silent do
    file = Tempfile.new("lumberjack_test")
    begin
      device = Lumberjack::Device::SizeRollingLogFile.new(file.path, max_size: 1024 * 1024)
      expect(device).to be_a(Lumberjack::Device::LogFile)
      expect(device.send(:stream).instance_variable_get(:@shift_size)).to eq(1024 * 1024)
    ensure
      file.close
      file.unlink
    end
  end
end
