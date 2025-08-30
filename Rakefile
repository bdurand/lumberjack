begin
  require "bundler/setup"
rescue LoadError
  puts "You must `gem install bundler` and `bundle install` to run rake tasks"
end

require "yard"
YARD::Rake::YardocTask.new(:yard)

require "bundler/gem_tasks"

task :verify_release_branch do
  unless `git rev-parse --abbrev-ref HEAD`.chomp == "main"
    warn "Gem can only be released from the main branch"
    exit 1
  end
end

Rake::Task[:release].enhance([:verify_release_branch])

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task default: :spec

desc "run the specs using appraisal"
task :appraisals do
  exec "bundle exec appraisal rake spec"
end

namespace :appraisals do
  desc "install all the appraisal gemspecs"
  task :install do
    exec "bundle exec appraisal install"
  end
end

require "standard/rake"

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

    result = RubyProf.profile do
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
