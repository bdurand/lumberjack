# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::Severity do
  describe "#level_to_label" do
    it "converts a level to a label" do
      expect(Lumberjack::Severity.level_to_label(Logger::DEBUG)).to eq("DEBUG")
      expect(Lumberjack::Severity.level_to_label(Logger::INFO)).to eq("INFO")
      expect(Lumberjack::Severity.level_to_label(Logger::WARN)).to eq("WARN")
      expect(Lumberjack::Severity.level_to_label(Logger::ERROR)).to eq("ERROR")
      expect(Lumberjack::Severity.level_to_label(Logger::FATAL)).to eq("FATAL")
      expect(Lumberjack::Severity.level_to_label(Lumberjack::Logger::TRACE)).to eq("TRACE")
      expect(Lumberjack::Severity.level_to_label(Logger::UNKNOWN)).to eq("ANY")
      expect(Lumberjack::Severity.level_to_label(100)).to eq("ANY")
    end
  end

  describe "#label_to_level" do
    it "converts a label to a level" do
      expect(Lumberjack::Severity.label_to_level("DEBUG")).to eq(Logger::DEBUG)
      expect(Lumberjack::Severity.label_to_level(:info)).to eq(Logger::INFO)
      expect(Lumberjack::Severity.label_to_level(:warn)).to eq(Logger::WARN)
      expect(Lumberjack::Severity.label_to_level("Error")).to eq(Logger::ERROR)
      expect(Lumberjack::Severity.label_to_level("FATAL")).to eq(Logger::FATAL)
      expect(Lumberjack::Severity.label_to_level("TRACE")).to eq(Lumberjack::Logger::TRACE)
      expect(Lumberjack::Severity.label_to_level("???")).to eq(Logger::UNKNOWN)
    end
  end

  describe "#coerce" do
    it "coerces integer levels to themselves" do
      expect(Lumberjack::Severity.coerce(Logger::DEBUG)).to eq(Logger::DEBUG)
    end

    it "coerces a symbol to a level" do
      expect(Lumberjack::Severity.coerce(:debug)).to eq(Logger::DEBUG)
    end

    it "coerces a string to a level" do
      expect(Lumberjack::Severity.coerce("Info")).to eq(Logger::INFO)
    end

    it "coerces unknown values to UNKNOWN" do
      expect(Lumberjack::Severity.coerce("???")).to eq(Logger::UNKNOWN)
    end

    it "coerces trace labels to TRACE" do
      expect(Lumberjack::Severity.coerce("TRACE")).to eq(Lumberjack::Logger::TRACE)
    end
  end
end
