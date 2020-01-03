require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => :appraisals

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
