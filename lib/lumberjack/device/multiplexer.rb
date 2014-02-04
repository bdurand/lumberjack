module Lumberjack
  class Device
    class Multiplexer
      attr_accessor :devices

      def initialize(devices)
        @devices = devices
      end

      def write(entry)
        @devices.each {|device| device.write(entry)}
      end

      def flush
        @devices.each {|device| device.flush }
      end

      def close
        @devices.each {|device| device.close }
      end

      private 
      def method_missing(method, *args, &block)
        @devices.each do |device|
          device.send(method, *args, &block)
        end
      end

    end
  end
end
