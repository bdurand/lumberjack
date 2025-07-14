# frozen_string_literal: true

module Lumberjack
  module Rack
    # @deprecated Use the Lumberjack::Rack::Context middleware instead to set a global tag
    # with an identifier to tie log entries together in a unit of work. Will be removed in version 2.0.
    class UnitOfWork
      def initialize(app)
        @app = app
      end

      def call(env)
        Lumberjack.unit_of_work do
          @app.call(env)
        end
      end
    end
  end
end
