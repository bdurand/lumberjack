require 'spec_helper'
require 'pathname'

describe Lumberjack::Logger do

  describe "compatibility" do
    it "should implement the same public API as the ::Logger class" do
      logger = ::Logger.new(STDOUT)
      lumberjack = Lumberjack::Logger.new(STDOUT)
      (logger.public_methods - Object.public_methods).each do |method_name|
        logger_method = logger.method(method_name)
        lumberjack_method = lumberjack.method(method_name)
        if logger_method.arity != lumberjack_method.arity
          fail "Lumberjack::Logger.#{method_name} has arity of #{lumberjack_method.arity} instead of #{logger_method.arity}"
        end
      end
    end
  end

  describe "initialization" do

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
      logger = Lumberjack::Logger.new(:null, :level => Logger::WARN)
      expect(logger.level).to eq(Logger::WARN)
    end

    it "should set the level with a level" do
      logger = Lumberjack::Logger.new(:null, :level => :warn)
      expect(logger.level).to eq(Logger::WARN)
    end

    it "should default the level to INFO" do
      logger = Lumberjack::Logger.new(:null)
      expect(logger.level).to eq(Logger::INFO)
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

  describe "attributes" do
    it "should have a level" do
      logger = Lumberjack::Logger.new
      logger.level = Logger::DEBUG
      expect(logger.level).to eq(Logger::DEBUG)
    end

    it "should have a progname" do
      logger = Lumberjack::Logger.new
      logger.progname = "app"
      expect(logger.progname).to eq("app")
    end

    it "should be able to silence the log in a block" do
      output = StringIO.new
      logger = Lumberjack::Logger.new(output, :buffer_size => 0, :level => Logger::INFO, :template => ":message")
      logger.info("one")
      logger.silence do
        expect(logger.level).to eq(Logger::ERROR)
        logger.info("two")
        logger.error("three")
      end
      logger.info("four")
      expect(output.string.split).to eq(["one", "three", "four"])
    end

    it "should be able to customize the level of silence in a block" do
      output = StringIO.new
      logger = Lumberjack::Logger.new(output, :buffer_size => 0, :level => Logger::INFO, :template => ":message")
      logger.info("one")
      logger.silence(Logger::FATAL) do
        expect(logger.level).to eq(Logger::FATAL)
        logger.info("two")
        logger.error("three")
        logger.fatal("woof")
      end
      logger.info("four")
      expect(output.string.split).to eq(["one", "woof", "four"])
    end

    it "should be able to customize the level of silence in a block with a symbol" do
      output = StringIO.new
      logger = Lumberjack::Logger.new(output, :buffer_size => 0, :level => Logger::INFO, :template => ":message")
      logger.info("one")
      logger.silence(:fatal) do
        expect(logger.level).to eq(Logger::FATAL)
        logger.info("two")
        logger.error("three")
        logger.fatal("woof")
      end
      logger.info("four")
      expect(output.string.split).to eq(["one", "woof", "four"])
    end

    it "should not be able to silence the logger if silencing is disabled" do
      output = StringIO.new
      logger = Lumberjack::Logger.new(output, :buffer_size => 0, :level => Logger::INFO, :template => ":message")
      logger.silencer = false
      logger.info("one")
      logger.silence do
        expect(logger.level).to eq(Logger::INFO)
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
      logger = Lumberjack::Logger.new(output, :buffer_size => 0, :level => Logger::INFO, :template => ":message")
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
      logger = Lumberjack::Logger.new(output, :progname => "thread1", :buffer_size => 0, :level => Logger::INFO, :template => ":progname :message")
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

  describe "datetime_format" do
    it "should be able to set the datetime format for timestamps on the log device" do
      output = StringIO.new
      logger = Lumberjack::Logger.new(output, :template => ":time :message", datetime_format: "%Y-%m-%d")
      expect(logger.datetime_format).to eq "%Y-%m-%d"
      Timecop.freeze do
        logger.info("one")
        logger.datetime_format = "%m-%d-%Y"
        expect(logger.datetime_format).to eq "%m-%d-%Y"
        logger.info("two")
        logger.flush
        expect(output.string).to eq "#{Time.now.strftime('%Y-%m-%d')} one\n#{Time.now.strftime('%m-%d-%Y')} two\n"
      end
    end
  end

  describe "flushing" do
    it "should autoflush the buffer if it hasn't been flushed in a specified number of seconds" do
      output = StringIO.new
      logger = Lumberjack::Logger.new(output, :flush_seconds => 0.1, :level => Logger::INFO, :template => ":message", :buffer_size => 32767)
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
      logger = Lumberjack::Logger.new(output, :level => Logger::INFO, :template => ":message", :buffer_size => 32767)
      logger.info("message 1")
      expect(output.string).to eq("")
      last_flushed_at = logger.last_flushed_at
      logger.flush
      expect(output.string.split(Lumberjack::LINE_SEPARATOR)).to eq(["message 1"])
      expect(logger.last_flushed_at).to be >= last_flushed_at
    end

    it "should flush the buffer and close the devices" do
      output = StringIO.new
      logger = Lumberjack::Logger.new(output, :level => Logger::INFO, :template => ":message", :buffer_size => 32767)
      logger.info("message 1")
      expect(output.string).to eq("")
      expect(logger.closed?).to eq false
      logger.close
      expect(output.string.split(Lumberjack::LINE_SEPARATOR)).to eq(["message 1"])
      expect(output).to be_closed
      expect(logger.closed?).to eq true
    end

    it "should reopen the devices" do
      output = StringIO.new
      logger = Lumberjack::Logger.new(output, :level => Logger::INFO, :template => ":message", :buffer_size => 32767)
      logger.close
      expect(logger.device).to receive(:reopen).and_call_original
      logger.reopen
      expect(logger.closed?).to eq false
    end
  end

  describe "logging" do
    let(:output){ StringIO.new }
    let(:device){ Lumberjack::Device::Writer.new(output, :buffer_size => 0, template: "[:time :severity :progname(:pid)] :message :tags") }
    let(:logger){ Lumberjack::Logger.new(device, :level => Logger::INFO, :progname => "app") }
    let(:n){ Lumberjack::LINE_SEPARATOR }

    describe "add" do
      it "should add entries with a numeric severity and a message" do
        time = Time.parse("2011-01-30T12:31:56.123")
        allow(Time).to receive_messages(:now => time)
        logger.add(Logger::INFO, "test")
        expect(output.string.chomp).to eq("[2011-01-30T12:31:56.123 INFO app(#{$$})] test")
      end

      it "should add entries with a severity label" do
        time = Time.parse("2011-01-30T12:31:56.123")
        allow(Time).to receive_messages(:now => time)
        logger.add(:info, "test")
        expect(output.string.chomp).to eq("[2011-01-30T12:31:56.123 INFO app(#{$$})] test")
      end

      it "should add entries with a custom progname and message" do
        time = Time.parse("2011-01-30T12:31:56.123")
        allow(Time).to receive_messages(:now => time)
        logger.add(Logger::INFO, "test", "spec")
        expect(output.string.chomp).to eq("[2011-01-30T12:31:56.123 INFO spec(#{$$})] test")
      end

      it "should add entries with a local progname and message" do
        time = Time.parse("2011-01-30T12:31:56.123")
        allow(Time).to receive_messages(:now => time)
        logger.set_progname("block") do
          logger.add(Logger::INFO, "test")
        end
        expect(output.string.chomp).to eq("[2011-01-30T12:31:56.123 INFO block(#{$$})] test")
      end

      it "should add entries with a progname but no message or block" do
        time = Time.parse("2011-01-30T12:31:56.123")
        allow(Time).to receive_messages(:now => time)
        logger.set_progname("default") do
          logger.add(Logger::INFO, nil, "message")
        end
        expect(output.string.chomp).to eq("[2011-01-30T12:31:56.123 INFO default(#{$$})] message")
      end

      it "should add entries with a block" do
        time = Time.parse("2011-01-30T12:31:56.123")
        allow(Time).to receive_messages(:now => time)
        logger.add(Logger::INFO) { "test" }
        expect(output.string.chomp).to eq("[2011-01-30T12:31:56.123 INFO app(#{$$})] test")
      end

      it "should log entries (::Logger compatibility)" do
        time = Time.parse("2011-01-30T12:31:56.123")
        allow(Time).to receive_messages(:now => time)
        logger.log(Logger::INFO, "test")
        expect(output.string.chomp).to eq("[2011-01-30T12:31:56.123 INFO app(#{$$})] test")
      end

      it "should append messages with unknown severity to the log" do
        time = Time.parse("2011-01-30T12:31:56.123")
        allow(Time).to receive_messages(:now => time)
        logger << "test"
        expect(output.string.chomp).to eq("[2011-01-30T12:31:56.123 UNKNOWN app(#{$$})] test")
      end
    end

    describe "add_entry" do
      it "should add entries with tags" do
        time = Time.parse("2011-01-30T12:31:56.123")
        allow(Time).to receive_messages(:now => time)
        logger.add_entry(Logger::INFO, "test", "spec", "tag" => "ABCD")
        expect(output.string.chomp).to eq("[2011-01-30T12:31:56.123 INFO spec(#{$$})] test [tag:ABCD]")
      end

      it "should handle malformed tags" do
        time = Time.parse("2011-01-30T12:31:56.123")
        allow(Time).to receive_messages(:now => time)
        logger.add_entry(Logger::INFO, "test", "spec", "ABCD")
        expect(output.string.chomp).to eq("[2011-01-30T12:31:56.123 INFO spec(#{$$})] test")
      end

      it "should ouput entries to STDERR if they can't be written the the device" do
        stderr = $stderr
        $stderr = StringIO.new
        begin
          time = Time.parse("2011-01-30T12:31:56.123")
          allow(Time).to receive_messages(:now => time)
          expect(device).to receive(:write).and_raise(StandardError.new("Cannot write to device"))
          logger.add_entry(Logger::INFO, "test")
          expect($stderr.string).to include("[2011-01-30T12:31:56.123 INFO app(#{$$})] test")
          expect($stderr.string).to include("StandardError: Cannot write to device")
        ensure
          $stderr = stderr
        end
      end

      it "should call Proc tag values" do
        time = Time.parse("2011-01-30T12:31:56.123")
        allow(Time).to receive_messages(:now => time)
        logger.add_entry(Logger::INFO, "test", "spec", tag: lambda { "foo" })
        expect(output.string.chomp).to eq("[2011-01-30T12:31:56.123 INFO spec(#{$$})] test [tag:foo]")
      end

      it "should not get into infinite loops by logging entries while logging entries" do
        time = Time.parse("2011-01-30T12:31:56.123")
        allow(Time).to receive_messages(:now => time)
        logger.add_entry(Logger::INFO, "test", "spec", tag: lambda { logger.warn("inner logging"); "foo" })
        expect(output.string.chomp).to eq("[2011-01-30T12:31:56.123 INFO spec(#{$$})] test [tag:foo]")
      end
    end

    describe "level helpers" do
      it "should set the level using bang methods" do
        logger.fatal!
        expect(logger.level).to eq Logger::FATAL
        logger.error!
        expect(logger.level).to eq Logger::ERROR
        logger.warn!
        expect(logger.level).to eq Logger::WARN
        logger.info!
        expect(logger.level).to eq Logger::INFO
        logger.debug!
        expect(logger.level).to eq Logger::DEBUG
      end
    end

    %w(fatal error warn info debug).each do |level|
      describe level do
        around :each do |example|
          Timecop.freeze(time) do
            example.call
          end
        end

        before :each do
          logger.level = level
        end

        let(:time) { Time.at(1296419516) }
        let(:timestamp) { time.strftime("%Y-%m-%dT%H:%M:%S.%3N") }

        it "should log a message string" do
          logger.send(level, "test")
          expect(output.string.chomp).to eq("[#{timestamp} #{level.upcase} app(#{$$})] test")
        end

        it "should log a message string with a progname" do
          logger.send(level, "test", "spec")
          expect(output.string.chomp).to eq("[#{timestamp} #{level.upcase} spec(#{$$})] test")
        end

        it "should log a message string with tags" do
          logger.send(level, "test", tag: 1)
          expect(output.string.chomp).to eq("[#{timestamp} #{level.upcase} app(#{$$})] test [tag:1]")
        end

        it "should log a message block" do
          logger.send(level) { "test" }
          expect(output.string.chomp).to eq("[#{timestamp} #{level.upcase} app(#{$$})] test")
        end

        it "should log a message block with a progname" do
          logger.send(level, "spec") { "test" }
          expect(output.string.chomp).to eq("[#{timestamp} #{level.upcase} spec(#{$$})] test")
        end

        it "should log a message block with tags" do
          logger.send(level, tag: 1) { "test" }
          expect(output.string.chomp).to eq("[#{timestamp} #{level.upcase} app(#{$$})] test [tag:1]")
        end

        it "should log a message block with a progname and tags" do
          logger.send(level, "spec", tag: 1) { "test" }
          expect(output.string.chomp).to eq("[#{timestamp} #{level.upcase} spec(#{$$})] test [tag:1]")
        end

        it "should log a message block with a progname and tags" do
          logger.send(level, {tag: 1}, "spec") { "test" }
          expect(output.string.chomp).to eq("[#{timestamp} #{level.upcase} spec(#{$$})] test [tag:1]")
        end
      end
    end

    describe "tags" do
      let(:device){ Lumberjack::Device::Writer.new(output, :buffer_size => 0, template: ":message - :count - :tags") }

      it "should be able to add tags to the logs" do
        logger.level = :debug
        logger.debug("debug", count: 1, tag: "a")
        logger.info("info", count: 2, tag: "b")
        logger.warn("warn", count: 3, tag: "c")
        logger.error("error", count: 4, tag: "d")
        logger.fatal("fatal", count: 5, tag: "e", foo: "bar")
        lines = output.string.split(n)
        expect(lines[0]).to eq 'debug - 1 - [tag:a]'
        expect(lines[1]).to eq 'info - 2 - [tag:b]'
        expect(lines[2]).to eq 'warn - 3 - [tag:c]'
        expect(lines[3]).to eq 'error - 4 - [tag:d]'
        expect(lines[4]).to eq 'fatal - 5 - [tag:e] [foo:bar]'
      end

      it "should merge logger and context tags" do
        Lumberjack.context do
          Lumberjack.tag(foo: "bar")
          logger.tag(baz: "boo") do
            logger.info("one", count: 1, tag: "b")
            logger.info("two", count: 2, tag: "c", foo: "other")
            logger.info("three", count: 3, tag: "d", baz: "thing")
          end
        end
        lines = output.string.split(n)
        expect(lines[0]).to eq 'one - 1 - [foo:bar] [baz:boo] [tag:b]'
        expect(lines[1]).to eq 'two - 2 - [foo:other] [baz:boo] [tag:c]'
        expect(lines[2]).to eq 'three - 3 - [foo:bar] [baz:thing] [tag:d]'
      end

      it "should add and remove tags only in a tag block" do
        logger.tag(baz: "boo", count: 1) do
          logger.info("one")
          logger.tag(foo: "bar", count: 2)
          logger.info("two")
        end
        logger.info("three")

        lines = output.string.split(n)
        expect(lines[0]).to eq 'one - 1 - [baz:boo]'
        expect(lines[1]).to eq 'two - 2 - [baz:boo] [foo:bar]'
        expect(lines[2]).to eq 'three -  -'
      end

      it "should add and remove tags in the global scope if there is no block" do
        logger.tag(count: 1, foo: "bar")
        logger.info("one")
        logger.remove_tag(:foo)
        logger.info("two")

        lines = output.string.split(n)
        expect(lines[0]).to eq 'one - 1 - [foo:bar]'
        expect(lines[1]).to eq 'two - 1 -'
      end

      it "should apply a tag formatter to the tags" do
        logger.tag_formatter.add(:foo, &:reverse).add(:count) { |val| val * 100 }
        logger.info("message", count: 2, foo: "abc")
        line = output.string.chomp
        expect(line).to eq "message - 200 - [foo:cba]"
      end

      it "should work with a frozen hash" do
        logger.tag({foo: "bar"}.freeze)
        logger.tag(other: 1) do
          expect(logger.tags).to eq("foo" => "bar", "other" => 1)
        end
      end
    end

    describe "log helper methods" do
      let(:device){ Lumberjack::Device::Writer.new(output, :buffer_size => 0, :template => ":message") }

      it "should only add messages whose severity is greater or equal to the logger level" do
        logger.add_entry(Logger::DEBUG, "debug")
        logger.add_entry(Logger::INFO, "info")
        logger.add_entry(Logger::ERROR, "error")
        expect(output.string).to eq("info#{n}error#{n}")
      end

      it "should only log fatal messages when the level is set to fatal" do
        logger.level = Logger::FATAL
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
        logger.level = Logger::ERROR
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
        logger.level = Logger::WARN
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
        logger.level = Logger::INFO
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
        logger.level = Logger::DEBUG
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

      it "should only log unknown messages when the level is set above fatal" do
        logger.level = Logger::FATAL + 1
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
