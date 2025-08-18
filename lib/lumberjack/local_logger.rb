# frozen_string_literal: true

module Lumberjack
  class LocalLogger < Logger
    include ContextLogger

    attr_reader :parent_logger

    def initialize(logger)
      init_fiber_locals!
      @parent_logger = logger
      @context = Context.new
      @context.level ||= logger.level
      @context.progname ||= logger.progname
    end

    def add_entry(severity, message, progname = nil, attributes = nil)
      parent_logger.with_level(level || Logger::DEBUG) do
        attributes = merge_attributes(attributes, local_attributes)
        progname ||= self.progname

        if parent_logger.is_a?(ContextLogger)
          parent_logger.add_entry(severity, message, progname, attributes)
        else
          parent_logger.tag(attributes) do
            parent_logger.add(severity, message, progname)
          end
        end
      end
    end

    private

    def default_context
      @context
    end

    def local_attributes
      merge_attributes(default_context&.attributes, local_context&.attributes)
    end
  end
end
