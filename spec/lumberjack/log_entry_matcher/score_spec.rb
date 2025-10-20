# frozen_string_literal: true

require_relative "../../spec_helper"

RSpec.describe Lumberjack::LogEntryMatcher::Score do
  let(:logger) { Lumberjack::Logger.new(:test) }

  # Create real log entries using the capture device
  let(:entries) do
    logger.info("User logged in successfully")
    logger.warn("Database connection slow")
    logger.error("Failed to authenticate user")
    logger.debug("Processing request", user_id: 123, action: "login")
    logger.progname = "TestApp"
    logger.info("Service started", service: "test")
    logger.device.entries
  end

  let(:entry_info) { entries[0] }      # "User logged in successfully"
  let(:entry_warn) { entries[1] }      # "Database connection slow"
  let(:entry_error) { entries[2] }     # "Failed to authenticate user"
  let(:entry_debug) { entries[3] }     # "Processing request" with attributes
  let(:entry_with_progname) { entries[4] } # "Service started" with progname

  describe ".calculate_match_score" do
    it "returns 1.0 for perfect matches" do
      score = Lumberjack::LogEntryMatcher::Score.calculate_match_score(
        entry_info,
        message: "User logged in successfully",
        severity: Logger::INFO,
        attributes: {},
        progname: nil
      )
      expect(score).to eq 1.0
    end

    it "returns 0.0 when no criteria are provided" do
      score = Lumberjack::LogEntryMatcher::Score.calculate_match_score(entry_info)
      expect(score).to eq 0.0
    end

    it "returns partial scores for partial matches" do
      score = Lumberjack::LogEntryMatcher::Score.calculate_match_score(
        entry_info,
        message: "User logged in successfully",
        severity: Logger::WARN # Different severity
      )
      expect(score).to be > 0.5
      expect(score).to be < 1.0
    end

    it "considers severity proximity for nearby severitys" do
      exact_score = Lumberjack::LogEntryMatcher::Score.calculate_match_score(
        entry_info,
        severity: Logger::INFO
      )

      nearby_score = Lumberjack::LogEntryMatcher::Score.calculate_match_score(
        entry_info,
        severity: Logger::WARN # One severity away
      )

      distant_score = Lumberjack::LogEntryMatcher::Score.calculate_match_score(
        entry_info,
        severity: Logger::FATAL # Far away
      )

      expect(exact_score).to be > nearby_score
      expect(nearby_score).to be > distant_score
    end

    it "scores entries below minimum threshold as 0" do
      score = Lumberjack::LogEntryMatcher::Score.calculate_match_score(
        entry_info,
        message: "completely different message",
        severity: Logger::FATAL,
        attributes: {different: "attributes"},
        progname: "DifferentApp"
      )
      expect(score).to be < Lumberjack::LogEntryMatcher::Score::MIN_SCORE_THRESHOLD
    end

    it "handles attribute matching" do
      score = Lumberjack::LogEntryMatcher::Score.calculate_match_score(
        entry_debug,
        attributes: {user_id: 123}
      )
      expect(score).to be > 0.0
    end

    it "handles progname matching" do
      score = Lumberjack::LogEntryMatcher::Score.calculate_match_score(
        entry_with_progname,
        progname: "TestApp"
      )
      expect(score).to be > 0.0
    end
  end

  describe ".calculate_field_score" do
    context "with string filters" do
      it "returns 1.0 for exact matches" do
        score = Lumberjack::LogEntryMatcher::Score.calculate_field_score("test message", "test message")
        expect(score).to eq 1.0
      end

      it "returns 0.7 for substring matches" do
        score = Lumberjack::LogEntryMatcher::Score.calculate_field_score("test message", "test")
        expect(score).to eq 0.7
      end

      it "returns similarity score for partial matches" do
        score = Lumberjack::LogEntryMatcher::Score.calculate_field_score("test message", "test mesage") # typo
        expect(score).to be > 0.0
        expect(score).to be < 0.7
      end

      it "returns 0.0 for completely different strings" do
        score = Lumberjack::LogEntryMatcher::Score.calculate_field_score("test message", "xyz")
        expect(score).to eq 0.0
      end
    end

    context "with regex filters" do
      it "returns 1.0 for matching regex" do
        score = Lumberjack::LogEntryMatcher::Score.calculate_field_score("test message", /test/)
        expect(score).to eq 1.0
      end

      it "returns 0.0 for non-matching regex" do
        score = Lumberjack::LogEntryMatcher::Score.calculate_field_score("test message", /xyz/)
        expect(score).to eq 0.0
      end
    end

    context "with other matchers" do
      it "returns 1.0 when matcher returns true" do
        matcher = double("matcher")
        allow(matcher).to receive(:===).with("test").and_return(true)
        score = Lumberjack::LogEntryMatcher::Score.calculate_field_score("test", matcher)
        expect(score).to eq 1.0
      end

      it "returns 0.0 when matcher returns false" do
        matcher = double("matcher")
        allow(matcher).to receive(:===).with("test").and_return(false)
        score = Lumberjack::LogEntryMatcher::Score.calculate_field_score("test", matcher)
        expect(score).to eq 0.0
      end

      it "returns 0.0 when matcher raises an exception" do
        matcher = double("matcher")
        allow(matcher).to receive(:===).with("test").and_raise(StandardError)
        score = Lumberjack::LogEntryMatcher::Score.calculate_field_score("test", matcher)
        expect(score).to eq 0.0
      end
    end

    context "with nil values" do
      it "returns 0.0 when value is nil" do
        score = Lumberjack::LogEntryMatcher::Score.calculate_field_score(nil, "test")
        expect(score).to eq 0.0
      end

      it "returns 0.0 when filter is nil" do
        score = Lumberjack::LogEntryMatcher::Score.calculate_field_score("test", nil)
        expect(score).to eq 0.0
      end

      it "returns 0.0 when both are nil" do
        score = Lumberjack::LogEntryMatcher::Score.calculate_field_score(nil, nil)
        expect(score).to eq 0.0
      end
    end
  end

  describe ".severity_proximity_score" do
    it "returns 1.0 for exact severity match" do
      score = Lumberjack::LogEntryMatcher::Score.severity_proximity_score(
        Logger::INFO,
        Logger::INFO
      )
      expect(score).to eq 1.0
    end

    it "returns 0.7 for one severity difference" do
      score = Lumberjack::LogEntryMatcher::Score.severity_proximity_score(
        Logger::INFO,
        Logger::WARN
      )
      expect(score).to eq 0.7
    end

    it "returns 0.4 for two severity difference" do
      score = Lumberjack::LogEntryMatcher::Score.severity_proximity_score(
        Logger::DEBUG,
        Logger::WARN
      )
      expect(score).to eq 0.4
    end

    it "returns 0.0 for three or more severity difference" do
      score = Lumberjack::LogEntryMatcher::Score.severity_proximity_score(
        Logger::DEBUG,
        Logger::FATAL
      )
      expect(score).to eq 0.0
    end
  end

  describe ".calculate_attributes_score" do
    let(:entry_attributes) { {user_id: 123, action: "login", metadata: {ip: "192.168.1.1"}} }

    it "returns 1.0 for exact attribute matches" do
      score = Lumberjack::LogEntryMatcher::Score.calculate_attributes_score(entry_attributes, {user_id: 123})
      expect(score).to eq 1.0
    end

    it "returns partial score for partially matching attributes" do
      score = Lumberjack::LogEntryMatcher::Score.calculate_attributes_score(
        entry_attributes,
        {user_id: 123, action: "logout"} # One matches, one doesn't
      )
      expect(score).to eq 0.5
    end

    it "returns 0.0 for completely non-matching attributes" do
      score = Lumberjack::LogEntryMatcher::Score.calculate_attributes_score(
        entry_attributes,
        {different_attribute: "value"}
      )
      expect(score).to eq 0.0
    end

    it "handles nested attribute matching" do
      score = Lumberjack::LogEntryMatcher::Score.calculate_attributes_score(
        entry_attributes,
        {metadata: {ip: "192.168.1.1"}}
      )
      expect(score).to eq 1.0
    end

    it "returns 0.0 when entry_attributes is nil" do
      score = Lumberjack::LogEntryMatcher::Score.calculate_attributes_score(nil, {user_id: 123})
      expect(score).to eq 0.0
    end

    it "returns 0.0 when attributes_filter is not a hash" do
      score = Lumberjack::LogEntryMatcher::Score.calculate_attributes_score(entry_attributes, "not a hash")
      expect(score).to eq 0.0
    end
  end
end
