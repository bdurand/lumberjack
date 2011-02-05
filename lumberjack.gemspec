Gem::Specification.new do |s|
  s.name = 'lumberjack'
  s.version = File.read(File.expand_path("../VERSION", __FILE__)).strip
  s.summary = "A simple, powerful, and very fast logging utility that can be a drop in replacement for Logger or ActiveSupport::BufferedLogger."
  s.description = "A simple, powerful, and very fast logging utility that can be a drop in replacement for Logger or ActiveSupport::BufferedLogger. Provides support for automatically rolling log files even with multiple processes writing the same log file."

  s.authors = ['Brian Durand']
  s.email = ['bdurand@embellishedvisions.com']
  s.homepage = "http://github.com/bdurand/lumberjack"

  s.files = ['README.rdoc', 'VERSION', 'Rakefile', 'MIT_LICENSE'] +  Dir.glob('lib/**/*'), Dir.glob('spec/**/*')
  s.require_path = 'lib'
  
  s.has_rdoc = true
  s.rdoc_options = ["--charset=UTF-8", "--main", "README.rdoc"]
  s.extra_rdoc_files = ["README.rdoc"]
end
