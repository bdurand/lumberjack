# frozen_string_literal: true

require "logger"

require "stringio"
require "fileutils"
require "timecop"
require "tempfile"

begin
  require "simplecov"
  SimpleCov.start do
    add_filter ["/spec/"]
  end
rescue LoadError
end

require_relative "../lib/lumberjack"

Lumberjack.raise_logger_errors = true
Lumberjack.deprecation_mode = :raise

RSpec.configure do |config|
  config.warnings = true
  config.disable_monkey_patching!
  config.default_formatter = "doc" if config.files_to_run.one?
  config.order = :random
  Kernel.srand config.seed

  config.around(:each, :deprecation_mode) do |example|
    Lumberjack::Utils.with_deprecation_mode(example.metadata[:deprecation_mode]) do
      example.run
    end
  end
end

def tmp_dir
  File.join(Dir.tmpdir, "lumberjack_test")
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

# Minimal implementation of a Lumberjack::ContextLogger for testing to ensure that methods from
# Lumberjack::Logger are not polluting any of the logic.
class TestContextLogger
  include Lumberjack::ContextLogger

  attr_reader :entries

  def initialize(context = nil)
    @context = context
    @entries = []
  end

  def add_entry(severity, message, progname = nil, attributes = nil)
    @entries << {
      severity: severity,
      message: message,
      progname: progname,
      attributes: attributes
    }
  end

  private

  def default_context
    @context
  end
end

class TestToLogFormat
  attr_reader :value

  def initialize(value)
    @value = value
  end

  def to_log_format
    "LOG FORMAT: #{@value}"
  end
end
