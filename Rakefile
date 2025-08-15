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

task release: :verify_release_branch

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

def profile_cpu(implementation)
  require "ruby-prof"
  require_relative "lib/lumberjack"

  out = StringIO.new
  logger = (implementation == :logger) ? Logger.new(out) : Lumberjack::Logger.new(out)
  message = "foobar"

  result = RubyProf.profile do
    1000.times { logger.info(message) }
  end
  printer = RubyProf::FlatPrinter.new(result)
  printer.print($stdout)
end

def profile_memory(implementation)
  require "memory_profiler"
  require_relative "lib/lumberjack"

  out = StringIO.new
  logger = (implementation == :logger) ? Logger.new(out) : Lumberjack::Logger.new(out)
  message = "foobar"

  MemoryProfiler.report do
    1000.times { logger.info(message) }
  end.pretty_print
end

namespace :profile do
  desc "Profile Lumberjack::Logger CPU usage"
  task :cpu do |t, args|
    profile_cpu(:lumberjack)
  end

  desc "Profile Lumberjack::Logger memory usage"
  task :memory do |t, args|
    profile_memory(:lumberjack)
  end

  namespace :logger do
    desc "Profile ::Logger CPU usage"
    task :cpu do |t, args|
      profile_cpu(:logger)
    end

    desc "Profile ::Logger memory usage"
    task :memory do |t, args|
      profile_memory(:logger)
    end
  end
end
