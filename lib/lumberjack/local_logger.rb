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

    def add_entry(severity, message, progname = nil, tags = nil)
      parent_logger.with_level(level || Logger::DEBUG) do
        tags = merge_tags(tags, local_tags)
        progname ||= self.progname

        if parent_logger.is_a?(ContextLogger)
          parent_logger.add_entry(severity, message, progname, tags)
        else
          parent_logger.tag(tags) do
            parent_logger.add(severity, message, progname)
          end
        end
      end
    end

    private

    def default_context
      @context
    end

    def local_tags
      merge_tags(default_context&.tags, local_context&.tags)
    end
  end
end
