# ActiveSupport is only available on some Appraisal runs.
begin
  require "active_support/all"
rescue LoadError => e
end

require "stringio"
require "fileutils"
require "timecop"

begin
  require "simplecov"
  SimpleCov.start do
    add_filter ["/spec/"]
  end
rescue LoadError
end

require File.expand_path("../../lib/lumberjack.rb", __FILE__)

RSpec.configure do |config|
  config.warnings = true
  config.order = :random
end

def tmp_dir
  File.expand_path("../tmp", __FILE__)
end

def create_tmp_dir
  FileUtils.rm_r(tmp_dir) if File.exist?(tmp_dir)
  FileUtils.mkdir_p(tmp_dir)
end

def delete_tmp_dir
  FileUtils.rm_r(tmp_dir)
end

def delete_tmp_files
  Dir.glob(File.join(tmp_dir, "*")) do |file|
    File.delete(file)
  end
end
