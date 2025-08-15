# frozen_string_literal: true

require "ruby-prof"
require "memory_profiler"

require_relative "lib/lumberjack"

type, implementation = ARGV[0].split(":")
out = StringIO.new
logger = (implementation == "logger") ? Logger.new(out) : Lumberjack::Logger.new(out)
message = "foobar"

if type == "cpu"
  result = RubyProf.profile do
    1000.times { logger.info(message) }
  end
  printer = RubyProf::FlatPrinter.new(result)
  printer.print($stdout)
elsif type == "memory"
  MemoryProfiler.report do
    1000.times { logger.info(message) }
  end.pretty_print
end
