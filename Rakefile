require 'rubygems'
require 'rake'
require 'rake/gempackagetask'
require 'rake/rdoctask'

desc 'Default: run unit tests.'
task :default => :test

desc 'RVM likes to call it tests'
task :tests => :test

begin
  require 'rspec'
  require 'rspec/core/rake_task'
  desc 'Run the unit tests'
  RSpec::Core::RakeTask.new(:test)
rescue LoadError
  task :test do
    STDERR.puts "You must have rspec 2.0 installed to run the tests"
  end
end

desc 'Generate rdoc.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.options << '--title' << 'Lumberjack' << '--line-numbers' << '--inline-source' << '--main' << 'README.rdoc'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

namespace :rbx do
  desc "Cleanup *.rbc files in lib directory"
  task :delete_rbc_files do
    FileList["lib/**/*.rbc"].each do |rbc_file|
      File.delete(rbc_file)
    end
    nil
  end
end

spec_file = File.expand_path('../lumberjack.gemspec', __FILE__)
if File.exist?(spec_file)
  spec = eval(File.read(spec_file))

  Rake::GemPackageTask.new(spec) do |p|
    p.gem_spec = spec
  end
  Rake.application["package"].prerequisites.unshift("rbx:delete_rbc_files")

  desc "Release to rubygems.org"
  task :release => :package do
    require 'rake/gemcutter'
    Rake::Gemcutter::Tasks.new(spec).define
    Rake::Task['gem:push'].invoke
  end
end
