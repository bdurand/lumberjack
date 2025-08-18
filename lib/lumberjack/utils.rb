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
        if (Warning[:deprecated] || $VERBOSE) && !@deprecations&.include?(method)
          @deprecations_lock ||= Mutex.new
          @deprecations_lock.synchronize do
            @deprecations ||= {}
            unless @deprecations.include?(method)
              trace = caller[3..]
              unless $VERBOSE
                trace = [trace.first]
                @deprecations[method] = true
              end
              message = "DEPRECATION WARNING: #{message} Called from #{trace.join("\n")}"
              warn(message)
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

      # Get the current line of code that calls this method. This can be useful for debugging
      # purposes in your logs to record the line of code that is calling the logger.
      #
      # @return [String] The line of code that called this method.
      #
      # @example
      #   logger.info("Something happened", code: Lumberjack::Utils.current_line)
      def current_line
        caller_locations(1, 1)[0].to_s
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

      # Flatten an attribute hash to a single level hash with dot notation for nested keys.
      #
      # @param attr_hash [Hash] The hash to flatten.
      # @return [Hash<String, Object>] The flattened hash.
      # @example
      #   expand_attributes(user: {id: 123, name: "Alice"}, action: "login")})
      #   # => {"user.id" => 123, "user.name" => "Alice", "action" => "login"}
      def flatten_attributes(attr_hash)
        return {} unless attr_hash.is_a?(Hash)

        flatten_hash_recursive(attr_hash)
      end

      # Alias to flatten_attributes for compatibility with the 1.x API. This method will eventually
      # be removed
      #
      # @return [Hash]
      # @deprecated Use {#flatten_attributes} instead.
      def flatten_tags(tag_hash)
        Utils.deprecated(:flatten_tags, "Use flatten_attributes instead.") do
          flatten_attributes(tag_hash)
        end
      end

      # Expand a hash of attributes that may contain nested hashes or dot notation keys. Dot notation attributes
      # will be expanded into nested hashes.
      #
      # @param attributes [Hash] The hash of attributes to expand.
      # @return [Hash] The expanded hash with dot notation keys.
      #
      # @example
      #   expand_attributes({"user.id" => 123, "user.name" => "Alice", "action" => "login"})
      #   # => {"user" => {"id" => 123, "name" => "Alice"}, "action" => "login"}
      def expand_attributes(attributes)
        return {} unless attributes.is_a?(Hash)

        expand_dot_notation_hash(attributes)
      end

      # Alias to expand_attributes for compatibility with the 1.x API. This method will eventually
      # be removed
      #
      # @return [Hash]
      # @deprecated Use {#expand_attributes} instead.
      def expand_tags(tags)
        Utils.deprecated(:expand_tags, "Use expand_attributes instead.") do
          expand_attributes(tags)
        end
      end

      private

      def flatten_hash_recursive(hash, prefix = nil)
        hash.each_with_object({}) do |(key, value), result|
          full_key = prefix ? "#{prefix}.#{key}" : key.to_s
          if value.is_a?(Hash)
            result.merge!(flatten_hash_recursive(value, full_key))
          else
            result[full_key] = value
          end
        end
      end

      def slugify(str)
        return nil if str.nil?

        str = str.gsub(NON_SLUGGABLE_PATTERN, "-")
        str.delete_prefix!("-")
        str.chomp!("-")
        str
      end

      def expand_dot_notation_hash(hash, expanded = {})
        return hash unless hash.is_a?(Hash)

        hash.each do |key, value|
          key = key.to_s
          if key.include?(".")
            main_key, sub_key = key.split(".", 2)
            main_key_hash = expanded[main_key]
            unless main_key_hash.is_a?(Hash)
              main_key_hash = {}
              expanded[main_key] = main_key_hash
            end
            expand_dot_notation_hash({sub_key => value}, main_key_hash)
          elsif value.is_a?(Hash)
            key_hash = expanded[key]
            unless key_hash.is_a?(Hash)
              key_hash = {}
              expanded[key] = key_hash
            end
            expand_dot_notation_hash(value, key_hash)
          else
            expanded[key] = value
          end
        end

        expanded
      end
    end
  end
end
