# frozen_string_literal: true

require "socket"

module Lumberjack
  module Utils
    UNDEFINED = Object.new.freeze
    private_constant :UNDEFINED

    NON_SLUGGABLE_PATTERN = /[^A-Za-z0-9_.-]+/.freeze
    private_constant :NON_SLUGGABLE_PATTERN

    @deprecations = nil
    @deprecations_lock = nil
    @hostname = UNDEFINED

    class << self
      # Print warning when deprecated methods are called the first time. This can be disabled
      # by setting the environment variable `LUMBERJACK_NO_DEPRECATION_WARNINGS` to "true".
      # You can see every usage of a deprecated method along with a full stack trace by setting
      # the environment variable `VERBOSE_LUMBERJACK_DEPRECATION_WARNING` to "true".
      #
      # @param method [String] The name of the deprecated method.
      # @param message [String] Optional message to include in the warning.
      # @yield The block to execute after the warning.
      def deprecated(method, message)
        @deprecations_lock ||= Mutex.new
        unless @deprecations&.include?(method)
          @deprecations_lock.synchronize do
            @deprecations ||= {}
            unless @deprecations.include?(method)
              trace = caller[3..-1]
              unless ENV["VERBOSE_LUMBERJACK_DEPRECATION_WARNING"] == "true"
                trace = [trace.first]
                @deprecations[method] = true
              end
              message = "DEPRECATION WARNING: #{message} Called from #{trace.join("\n")}"
              warn(message) unless ENV["LUMBERJACK_NO_DEPRECATION_WARNINGS"] == "true"
            end
          end
        end

        yield
      end

      # Get the hostname of the machine. The returned value will be in UTF-8 encoding.
      #
      # @return [String] The hostname of the machine.
      def hostname
        if @hostname.equal?(UNDEFINED)
          @hostname = force_utf8(Socket.gethostname)
        end
        @hostname
      end

      # Set the hostname to a specific value. If this is not specified, it will use the system hostname.
      #
      # @param hostname [String]
      # @return [void]
      def hostname=(hostname)
        @hostname = force_utf8(hostname)
      end

      # Generate a global process ID that includes the hostname and process ID.
      #
      # @return [String] The global process ID.
      def global_pid
        if hostname
          "#{hostname}-#{Process.pid}"
        else
          Process.pid.to_s
        end
      end

      # Generate a global thread ID that includes the global process ID and the thread name.
      #
      # @return [String] The global thread ID.
      def global_thread_id
        "#{global_pid}-#{thread_name}"
      end

      # Get the name of a thread. The value will be based on the thread's name if it exists.
      # Otherwise a unique id is generated based on the thread's object id. Only alphanumeric
      # characters, underscores, dashes, and periods are kept in thread name.
      #
      # @param thread [Thread] The thread to get the name for. Defaults to the current thread.
      # @return [String] The name of the thread.
      def thread_name(thread = Thread.current)
        thread.name ? slugify(thread.name) : thread.object_id.to_s(36)
      end

      # Force encode a string to UTF-8. Any invalid byte sequences will be
      # ignored and replaced with an empty string.
      #
      # @param str [String] The string to encode.
      # @return [String] The UTF-8 encoded string.
      def force_utf8(str)
        return nil if str.nil?

        str.dup.force_encoding("ASCII-8BIT").encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
      end

      # Flatten a tag hash to a single level hash with dot notation for nested keys.
      #
      # @param tag_hash [Hash] The hash to flatten.
      # @return [Hash] The flattened hash.
      def flatten_tags(tag_hash)
        return {} unless tag_hash.is_a?(Hash)

        tag_hash.each_with_object({}) do |(key, value), result|
          if value.is_a?(Hash)
            value.each do |sub_key, sub_value|
              result["#{key}.#{sub_key}"] = sub_value
            end
          else
            result[key] = value
          end
        end
      end

      private

      def slugify(str)
        return nil if str.nil?

        str = str.gsub(NON_SLUGGABLE_PATTERN, "-")
        str.delete_prefix!("-")
        str.chomp!("-")
        str
      end
    end
  end
end
