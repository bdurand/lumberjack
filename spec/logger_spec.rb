require 'spec_helper'
require 'pathname'

describe Lumberjack::Logger do

  context "initialization" do

    before :all do
      create_tmp_dir
    end

    after :all do
      delete_tmp_dir
    end

    it "should wrap an IO stream in a device" do
      output = StringIO.new
      logger = Lumberjack::Logger.new(output)
      expect(logger.device.class).to eq(Lumberjack::Device::Writer)
    end

    it "should have a formatter" do
      output = StringIO.new
      logger = Lumberjack::Logger.new(output)
      expect(logger.formatter).to be
    end

    it "should open a file path in a device" do
      logger = Lumberjack::Logger.new(File.join(tmp_dir, "log_file_1.log"))
      expect(logger.device.class).to eq(Lumberjack::Device::LogFile)
    end

    it "should open a pathname in a device" do
      logger = Lumberjack::Logger.new(Pathname.new(File.join(tmp_dir, "log_file_1.log")))
      expect(logger.device.class).to eq(Lumberjack::Device::LogFile)
    end

    it "should use the null device if the stream is :null" do
      logger = Lumberjack::Logger.new(:null)
      expect(logger.device.class).to eq(Lumberjack::Device::Null)
    end

    it "should set the level with a numeric" do
      logger = Lumberjack::Logger.new(:null, :level => Lumberjack::Severity::WARN)
      expect(logger.level).to eq(Lumberjack::Severity::WARN)
    end

    it "should set the level with a level" do
      logger = Lumberjack::Logger.new(:null, :level => :warn)
      expect(logger.level).to eq(Lumberjack::Severity::WARN)
    end

    it "should default the level to INFO" do
      logger = Lumberjack::Logger.new(:null)
      expect(logger.level).to eq(Lumberjack::Severity::INFO)
    end

    it "should set the progname"do
      logger = Lumberjack::Logger.new(:null, :progname => "app")
      expect(logger.progname).to eq("app")
    end

    it "should create a thread to flush the device" do
      expect(Thread).to receive(:new)
      logger = Lumberjack::Logger.new(:null, :flush_seconds => 10)
    end
  end

  context "attributes" do
    it "should have a level" do
      logger = Lumberjack::Logger.new
      logger.level = Lumberjack::Severity::DEBUG
      expect(logger.level).to eq(Lumberjack::Severity::DEBUG)
    end

    it "should have a progname" do
      logger = Lumberjack::Logger.new
      logger.progname = "app"
      expect(logger.progname).to eq("app")
    end

    it "should be able to silence the log in a block" do
      output = StringIO.new
      logger = Lumberjack::Logger.new(output, :buffer_size => 0, :level => Lumberjack::Severity::INFO, :template => ":message")
      logger.info("one")
      logger.silence do
        expect(logger.level).to eq(Lumberjack::Severity::ERROR)
        logger.info("two")
        logger.error("three")
      end
      logger.info("four")
      expect(output.string.split).to eq(["one", "three", "four"])
    end

    it "should be able to customize the level of silence in a block" do
      output = StringIO.new
      logger = Lumberjack::Logger.new(output, :buffer_size => 0, :level => Lumberjack::Severity::INFO, :template => ":message")
      logger.info("one")
      logger.silence(Lumberjack::Severity::FATAL) do
        expect(logger.level).to eq(Lumberjack::Severity::FATAL)
        logger.info("two")
        logger.error("three")
        logger.fatal("woof")
      end
      logger.info("four")
      expect(output.string.split).to eq(["one", "woof", "four"])
    end

    it "should not be able to silence the logger if silencing is disabled" do
      output = StringIO.new
      logger = Lumberjack::Logger.new(output, :buffer_size => 0, :level => Lumberjack::Severity::INFO, :template => ":message")
      logger.silencer = false
      logger.info("one")
      logger.silence do
        expect(logger.level).to eq(Lumberjack::Severity::INFO)
        logger.info("two")
        logger.error("three")
      end
      logger.info("four")
      expect(output.string.split).to eq(["one", "two", "three", "four"])
    end

    it "should be able to set the progname in a block" do
      logger = Lumberjack::Logger.new
      logger.set_progname("app")
      expect(logger.progname).to eq("app")
      block_executed = false
      logger.set_progname("xxx") do
        block_executed = true
        expect(logger.progname).to eq("xxx")
      end
      expect(block_executed).to eq(true)
      expect(logger.progname).to eq("app")
    end

    it "should only affect the current thread when silencing the logger" do
      output = StringIO.new
      logger = Lumberjack::Logger.new(output, :buffer_size => 0, :level => Lumberjack::Severity::INFO, :template => ":message")
      # status is used to make sure the two threads are executing at the same time
      status = 0
      begin
        Thread.new do
          logger.silence do
            logger.info("inner")
            status = 1
            loop{ sleep(0.001); break if status == 2}
          end
        end
        loop{ sleep(0.001); break if status == 1}
        logger.info("outer")
        status = 2
        logger.close
        expect(output.string).to include("outer")
        expect(output.string).not_to include("inner")
      ensure
        status = 2
      end
    end

    it "should only affect the current thread when changing the progname in a block" do
      output = StringIO.new
      logger = Lumberjack::Logger.new(output, :progname => "thread1", :buffer_size => 0, :level => Lumberjack::Severity::INFO, :template => ":progname :message")
      # status is used to make sure the two threads are executing at the same time
      status = 0
      begin
        Thread.new do
          logger.set_progname("thread2") do
            logger.info("inner")
            status = 1
            loop{ sleep(0.001); break if status == 2}
          end
        end
        loop{ sleep(0.001); break if status == 1}
        logger.info("outer")
        status = 2
        logger.close
        expect(output.string).to include("thread1")
        expect(output.string).to include("thread2")
      ensure
        status = 2
      end
    end
  end

  context "flushing" do
    it "should autoflush the buffer if it hasn't been flushed in a specified number of seconds" do
      output = StringIO.new
      logger = Lumberjack::Logger.new(output, :flush_seconds => 0.1, :level => Lumberjack::Severity::INFO, :template => ":message", :buffer_size => 32767)
      logger.info("message 1")
      logger.info("message 2")
      expect(output.string).to eq("")
      sleep(0.15)
      expect(output.string.split(Lumberjack::LINE_SEPARATOR)).to eq(["message 1", "message 2"])
      logger.info("message 3")
      expect(output.string).not_to include("message 3")
      sleep(0.15)
      expect(output.string.split(Lumberjack::LINE_SEPARATOR)).to eq(["message 1", "message 2", "message 3"])
    end

    it "should write the log entries to the device on flush and update the last flushed time" do
      output = StringIO.new
      logger = Lumberjack::Logger.new(output, :level => Lumberjack::Severity::INFO, :template => ":message", :buffer_size => 32767)
      logger.info("message 1")
      expect(output.string).to eq("")
      last_flushed_at = logger.last_flushed_at
      logger.flush
      expect(output.string.split(Lumberjack::LINE_SEPARATOR)).to eq(["message 1"])
      expect(logger.last_flushed_at).to be >= last_flushed_at
    end

    it "should flush the buffer and close the devices" do
      output = StringIO.new
      logger = Lumberjack::Logger.new(output, :level => Lumberjack::Severity::INFO, :template => ":message", :buffer_size => 32767)
      logger.info("message 1")
      expect(output.string).to eq("")
      logger.close
      expect(output.string.split(Lumberjack::LINE_SEPARATOR)).to eq(["message 1"])
      expect(output).to be_closed
    end
  end

  context "logging" do
    let(:output){ StringIO.new }
    let(:device){ Lumberjack::Device::Writer.new(output, :buffer_size => 0) }
    let(:logger){ Lumberjack::Logger.new(device, :level => Lumberjack::Severity::INFO, :progname => "test") }
    let(:n){ Lumberjack::LINE_SEPARATOR }

    it "should add entries with a numeric severity and a message" do
      time = Time.parse("2011-01-30T12:31:56.123")
      allow(Time).to receive_messages(:now => time)
      logger.add(Lumberjack::Severity::INFO, "test")
      expect(output.string).to eq("[2011-01-30T12:31:56.123 INFO test(#{$$}) #] test#{n}")
    end

    it "should add entries with a severity label" do
      time = Time.parse("2011-01-30T12:31:56.123")
      allow(Time).to receive_messages(:now => time)
      logger.add(:info, "test")
      expect(output.string).to eq("[2011-01-30T12:31:56.123 INFO test(#{$$}) #] test#{n}")
    end

    it "should add entries with a custom progname and message" do
      time = Time.parse("2011-01-30T12:31:56.123")
      allow(Time).to receive_messages(:now => time)
      logger.add(Lumberjack::Severity::INFO, "test", "app")
      expect(output.string).to eq("[2011-01-30T12:31:56.123 INFO app(#{$$}) #] test#{n}")
    end

    it "should add entries with a local progname and message" do
      time = Time.parse("2011-01-30T12:31:56.123")
      allow(Time).to receive_messages(:now => time)
      logger.set_progname("block") do
        logger.add(Lumberjack::Severity::INFO, "test")
      end
      expect(output.string).to eq("[2011-01-30T12:31:56.123 INFO block(#{$$}) #] test#{n}")
    end

    it "should add entries with a progname but no message or block" do
      time = Time.parse("2011-01-30T12:31:56.123")
      allow(Time).to receive_messages(:now => time)
      logger.set_progname("default") do
        logger.add(Lumberjack::Severity::INFO, nil, "message")
      end
      expect(output.string).to eq("[2011-01-30T12:31:56.123 INFO default(#{$$}) #] message#{n}")
    end

    it "should add entries with a block" do
      time = Time.parse("2011-01-30T12:31:56.123")
      allow(Time).to receive_messages(:now => time)
      logger.add(Lumberjack::Severity::INFO){"test"}
      expect(output.string).to eq("[2011-01-30T12:31:56.123 INFO test(#{$$}) #] test#{n}")
    end

    it "should log entries (::Logger compatibility)" do
      time = Time.parse("2011-01-30T12:31:56.123")
      allow(Time).to receive_messages(:now => time)
      logger.log(Lumberjack::Severity::INFO, "test")
      expect(output.string).to eq("[2011-01-30T12:31:56.123 INFO test(#{$$}) #] test#{n}")
    end

    it "should append messages with unknown severity to the log" do
      time = Time.parse("2011-01-30T12:31:56.123")
      allow(Time).to receive_messages(:now => time)
      logger << "test"
      expect(output.string).to eq("[2011-01-30T12:31:56.123 UNKNOWN test(#{$$}) #] test#{n}")
    end

    it "should ouput entries to STDERR if they can't be written the the device" do
      stderr = $stderr
      $stderr = StringIO.new
      begin
        time = Time.parse("2011-01-30T12:31:56.123")
        allow(Time).to receive_messages(:now => time)
        expect(device).to receive(:write).and_raise(StandardError.new("Cannot write to device"))
        logger.add(Lumberjack::Severity::INFO, "test")
        expect($stderr.string).to include("[2011-01-30T12:31:56.123 INFO test(#{$$})] test")
        expect($stderr.string).to include("StandardError: Cannot write to device")
      ensure
        $stderr = stderr
      end
    end

    context "log helper methods" do
      let(:device){ Lumberjack::Device::Writer.new(output, :buffer_size => 0, :template => ":message") }

      it "should only add messages whose severity is greater or equal to the logger level" do
        logger.add(Lumberjack::Severity::DEBUG, "debug")
        logger.add(Lumberjack::Severity::INFO, "info")
        logger.add(Lumberjack::Severity::ERROR, "error")
        expect(output.string).to eq("info#{n}error#{n}")
      end

      it "should only log fatal messages when the level is set to fatal" do
        logger.level = Lumberjack::Severity::FATAL
        logger.fatal("fatal")
        expect(logger.fatal?).to eq(true)
        logger.error("error")
        expect(logger.error?).to eq(false)
        logger.warn("warn")
        expect(logger.warn?).to eq(false)
        logger.info("info")
        expect(logger.info?).to eq(false)
        logger.debug("debug")
        expect(logger.debug?).to eq(false)
        logger.unknown("unknown")
        expect(output.string).to eq("fatal#{n}unknown#{n}")
      end

      it "should only log error messages and higher when the level is set to error" do
        logger.level = Lumberjack::Severity::ERROR
        logger.fatal("fatal")
        expect(logger.fatal?).to eq(true)
        logger.error("error")
        expect(logger.error?).to eq(true)
        logger.warn("warn")
        expect(logger.warn?).to eq(false)
        logger.info("info")
        expect(logger.info?).to eq(false)
        logger.debug("debug")
        expect(logger.debug?).to eq(false)
        logger.unknown("unknown")
        expect(output.string).to eq("fatal#{n}error#{n}unknown#{n}")
      end

      it "should only log warn messages and higher when the level is set to warn" do
        logger.level = Lumberjack::Severity::WARN
        logger.fatal("fatal")
        expect(logger.fatal?).to eq(true)
        logger.error("error")
        expect(logger.error?).to eq(true)
        logger.warn("warn")
        expect(logger.warn?).to eq(true)
        logger.info("info")
        expect(logger.info?).to eq(false)
        logger.debug("debug")
        expect(logger.debug?).to eq(false)
        logger.unknown("unknown")
        expect(output.string).to eq("fatal#{n}error#{n}warn#{n}unknown#{n}")
      end

      it "should only log info messages and higher when the level is set to info" do
        logger.level = Lumberjack::Severity::INFO
        logger.fatal("fatal")
        expect(logger.fatal?).to eq(true)
        logger.error("error")
        expect(logger.error?).to eq(true)
        logger.warn("warn")
        expect(logger.warn?).to eq(true)
        logger.info("info")
        expect(logger.info?).to eq(true)
        logger.debug("debug")
        expect(logger.debug?).to eq(false)
        logger.unknown("unknown")
        expect(output.string).to eq("fatal#{n}error#{n}warn#{n}info#{n}unknown#{n}")
      end

      it "should log all messages when the level is set to debug" do
        logger.level = Lumberjack::Severity::DEBUG
        logger.fatal("fatal")
        expect(logger.fatal?).to eq(true)
        logger.error("error")
        expect(logger.error?).to eq(true)
        logger.warn("warn")
        expect(logger.warn?).to eq(true)
        logger.info("info")
        expect(logger.info?).to eq(true)
        logger.debug("debug")
        expect(logger.debug?).to eq(true)
        logger.unknown("unknown")
        expect(output.string).to eq("fatal#{n}error#{n}warn#{n}info#{n}debug#{n}unknown#{n}")
      end

      it "should only log unkown messages when the level is set above fatal" do
        logger.level = Lumberjack::Severity::FATAL + 1
        logger.fatal("fatal")
        expect(logger.fatal?).to eq(false)
        logger.error("error")
        expect(logger.error?).to eq(false)
        logger.warn("warn")
        expect(logger.warn?).to eq(false)
        logger.info("info")
        expect(logger.info?).to eq(false)
        logger.debug("debug")
        expect(logger.debug?).to eq(false)
        logger.unknown("unknown")
        expect(output.string).to eq("unknown#{n}")
      end
    end
  end

end
