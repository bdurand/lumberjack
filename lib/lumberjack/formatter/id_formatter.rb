# frozen_string_literal: true

module Lumberjack
  class Formatter
    # Format an object that has an id as a hash with keys for class and id. This formatter is useful
    # as a default formatter for objects pulled from a data store. By default it will use :id as the
    # id attribute.
    #
    # The formatter creates a standardized representation of objects by extracting their class name
    # and identifier, making it easy to identify objects in logs without exposing all their data.
    # This is particularly useful for ActiveRecord models, database objects, or any objects that
    # have a unique identifier attribute.
    class IdFormatter
      FormatterRegistry.add(:id, self)

      # @param id_attribute [Symbol, String] The attribute to use as the id (defaults to :id).
      def initialize(id_attribute = :id)
        @id_attribute = id_attribute
      end

      # Format an object by extracting its class name and ID attribute.
      #
      # @param obj [Object] The object to format. Must respond to the configured ID attribute.
      # @return [Hash, String] A hash with "class" and "id" keys if the object has the ID attribute,
      #   otherwise returns the object's string representation.
      def call(obj)
        if obj.respond_to?(@id_attribute)
          id = obj.send(@id_attribute)
          {"class" => obj.class.name, "id" => id}
        else
          obj.to_s
        end
      end
    end
  end
end
