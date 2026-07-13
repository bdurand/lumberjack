# frozen_string_literal: true

begin
  require "bundler/setup"
rescue LoadError
  puts "You must `gem install bundler` and `bundle install` to run rake tasks"
end

require "bundler/gem_tasks"

task :verify_release_branch do
  unless `git rev-parse --abbrev-ref HEAD`.chomp == "main"
    warn "Gem can only be released from the main branch"
    exit 1
  end
end

Rake::Task[:release].prerequisites.prepend("verify_release_branch")

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task default: [:spec]

namespace :appraisal do
  desc "Update the appraisal gemfiles"
  task :update do
    Dir.glob("gemfiles/*.gemfile*") do |file|
      File.delete(file) if File.file?(file)
    end

    system "bundle exec appraisal generate" || abort("appraisal generate failed")

    Dir.glob("gemfiles/*.gemfile") do |file|
      puts "Locking #{file}"
      Bundler.with_unbundled_env do
        system(
          {
            "BUNDLE_GEMFILE" => file
          },
          "bundle", "lock", "--update"
        ) || abort("appraisal lock failed on #{file}")
      end
    end
  end
end

namespace :profile do
  desc "Profile logger CPU usage. Set LOGGER=Logger to profile the standard libary logger. Set LOG_LEVEL=warn to profile with a higher log level."
  task :cpu do |t, args|
    require "ruby-prof"
    require_relative "lib/lumberjack"

    out = StringIO.new
    logger_class = (ENV["LOGGER"] == "Logger") ? Logger : Lumberjack::Logger
    log_level = ENV.fetch("LOG_LEVEL", "debug")
    logger = logger_class.new(out, level: log_level)
    message = "foobar"

    result = RubyProf::Profile.profile do
      1000.times { logger.info(message) }
    end
    printer = RubyProf::FlatPrinter.new(result)
    printer.print($stdout)
  end

  desc "Profile logger memory usage. Set LOGGER=Logger to profile the standard libary logger. Set LOG_LEVEL=warn to profile with a higher log level."
  task :memory do |t, args|
    require "memory_profiler"
    require_relative "lib/lumberjack"

    out = StringIO.new
    logger_class = (ENV["LOGGER"] == "Logger") ? Logger : Lumberjack::Logger
    log_level = ENV.fetch("LOG_LEVEL", "debug")
    logger = logger_class.new(out, level: log_level)
    message = "foobar"

    MemoryProfiler.report do
      1000.times { logger.info(message) }
    end.pretty_print
  end
end

namespace :colors do
  desc "Print the color codes for each severity level"
  task :print do
    require_relative "lib/lumberjack"

    logger = Lumberjack::Logger.new($stdout, level: :trace, template: "{{severity(emoji)}} {{severity(padded)}} {{message}}", colorize: true)
    logger.trace("Test message")
    logger.debug("Test message")
    logger.info("Test message")
    logger.warn("Test message")
    logger.error("Test message")
    logger.fatal("Test message")
    logger.unknown("Test message")
  end
end
