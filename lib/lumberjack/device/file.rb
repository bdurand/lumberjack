# frozen_string_literal: true

module Lumberjack
  # Wrapper around the ::Logger::LogDevice class in the standard library which handles rolling
  # log files by size or age.
  class Device::File < Device::Writer
    def initialize(stream, options = {})
      # Filter options to only include keyword arguments supported by Logger::LogDevice#initialize
      supported_kwargs = ::Logger::LogDevice.instance_method(:initialize).parameters
        .select { |type, _| type == :key || type == :keyreq }
        .map { |_, name| name }

      filtered_options = options.slice(*supported_kwargs)

      logdev = ::Logger::LogDevice.new(stream, **filtered_options)

      super(logdev, options)
    end

    def path
      stream.filename
    end
  end
end
