require "ruby-prof"
require "stackprof"
require "flamegraph"
require "memory_profiler"

require_relative "lib/lumberjack"
logger = Lumberjack::Logger.new(File::NULL)
message = "foobar"

if ARGV[0] == "ruby-prof"
  result = RubyProf.profile do
    1000.times { logger.info(message) }
  end
  printer = RubyProf::FlatPrinter.new(result)
  printer.print($stdout)
elsif ARGV[0] == "memory"
  MemoryProfiler.report do
    1000.times { logger.info(message) }
  end.pretty_print
elsif ARGV[0] == "flamegraph"
  Flamegraph.generate("flamegraph.html") do
    1000.times { logger.info(message) }
  end
end
