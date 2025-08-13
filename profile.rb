require "ruby-prof"

profile = RubyProf::Profile.new

require_relative "lib/lumberjack"
logger = Lumberjack::Logger.new(File::NULL)
message = "foobar"

profile.start
1000.times { logger.info(message) }
result = profile.stop

# print a flat profile to text
printer = RubyProf::FlatPrinter.new(result)
printer.print($stdout)
