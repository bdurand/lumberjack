# frozen_string_literal: true

require "logger"

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

require_relative "../lib/lumberjack"

RSpec.configure do |config|
  config.warnings = true
  config.order = :random

  config.around(:each, :suppress_warnings) do |example|
    save_val = ENV["LUMBERJACK_NO_DEPRECATION_WARNINGS"]
    ENV["LUMBERJACK_NO_DEPRECATION_WARNINGS"] = "true"
    begin
      example.run
    ensure
      ENV["LUMBERJACK_NO_DEPRECATION_WARNINGS"] = save_val
    end
  end
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
