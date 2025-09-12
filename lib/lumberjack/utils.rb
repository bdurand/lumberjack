# frozen_string_literal: true

require "socket"

module Lumberjack
  # Error raised when a deprecated method is called and the deprecation mode is set to "raise".
  class DeprecationError < StandardError
  end

  # Utils provides utility methods and helper functions used throughout the Lumberjack logging framework.
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
      # by setting the environment variable `LUMBERJACK_DEPRECATION_WARNINGS` to "false".
      #
      # In order to cut down on noise, each deprecated method will only print a warning once per process.
      # You can change this by setting `LUMBERJACK_DEPRECATION_WARNINGS` to "verbose".
      #
      # @param method [String, Symbol] The name of the deprecated method.
      # @param message [String] The deprecation message explaining what to use instead.
      # @yield The block containing the deprecated functionality to execute.
      # @return [Object] The result of the yielded block.
      #
      # @example
      #   def old_method
      #     Utils.deprecated(:old_method, "Use new_method instead.") do
      #       # deprecated implementation
      #     end
      #   end
      def deprecated(method, message)
        if Lumberjack.deprecation_mode != "silent" && !@deprecations&.include?(method)
          @deprecations_lock ||= Mutex.new
          @deprecations_lock.synchronize do
            @deprecations ||= {}
            unless @deprecations.include?(method)
              trace = ($VERBOSE && Lumberjack.deprecation_mode != "raise") ? caller[3..] : caller[3, 1]
              if trace.first.start_with?(__dir__) && !$VERBOSE
                non_lumberjack_caller = caller[4..].detect { |line| !line.start_with?(__dir__) }
                trace = [non_lumberjack_caller] if non_lumberjack_caller
              end
              message = "DEPRECATION WARNING: #{message} Called from #{trace.join("\n")}"

              if Lumberjack.deprecation_mode == "raise"
                raise DeprecationError, message
              end

              unless Lumberjack.deprecation_mode == "verbose"
                @deprecations[method] = true
              end

              warn(message)
            end
          end
        end

        yield if block_given?
      end

      # Helper method for tests to silence deprecation warnings within a block. You should
      # not use this in production code since it will silence all deprecation warnings
      # globally across all threads.
      #
      # @param mode [String, Symbol] The deprecation mode to set within the block. Valid values are
      #   "normal", "verbose", "silent", and "raise".
      # @yield The block in which to silence deprecation warnings.
      # @return [Object] The result of the yielded block.
      def with_deprecation_mode(mode)
        save_mode = Lumberjack.deprecation_mode
        begin
          Lumberjack.deprecation_mode = mode
          yield
        ensure
          Lumberjack.deprecation_mode = save_mode
        end
      end

      # Get the hostname of the machine. The returned value will be in UTF-8 encoding.
      # The hostname is cached after the first call for performance.
      #
      # @return [String] The hostname of the machine in UTF-8 encoding.
      def hostname
        if @hostname.equal?(UNDEFINED)
          @hostname = force_utf8(Socket.gethostname)
        end
        @hostname
      end

      # Get the current line of code that calls this method. This is useful for debugging
      # purposes to record the exact location in your code that generated a log entry.
      #
      # @param root_path [String, Pathname, nil] An optional root path to strip from the file path.
      # @return [String] A string representation of the caller location (file:line:method).
      #
      # @example Adding source location to log entries
      #   logger.info("Something happened", source: Lumberjack::Utils.current_line)
      #   # Logs: "Something happened" with source: "/path/to/file.rb:123:in `method_name'"
      def current_line(root_path = nil)
        location = caller_locations(1, 1)[0]
        path = location.path
        if root_path
          root_path = root_path.to_s
          root_path = "#{root_path}#{File::SEPARATOR}" unless root_path.end_with?(File::SEPARATOR)
          path = path.delete_prefix(root_path)
        end
        "#{path}:#{location.lineno}:in `#{location.label}'"
      end

      # Set the hostname to a specific value. This overrides the system hostname.
      # Useful for testing or when you want to use a specific identifier.
      #
      # @param hostname [String] The hostname to use.
      # @return [void]
      def hostname=(hostname)
        @hostname = force_utf8(hostname)
      end

      # Generate a global process identifier that includes the hostname and process ID.
      # This creates a unique identifier that can distinguish processes across different machines.
      #
      # @return [String] The global process ID in the format "hostname-pid".
      #
      # @example
      #   Lumberjack::Utils.global_pid
      #   # => "server1-12345"
      def global_pid(pid = Process.pid)
        if hostname
          "#{hostname}-#{pid}"
        else
          pid.to_s
        end
      end

      # Generate a global thread identifier that includes the global process ID and thread name.
      # This creates a unique identifier for threads across processes and machines.
      #
      # @return [String] The global thread ID in the format "hostname-pid-threadname".
      #
      # @example
      #   Lumberjack::Utils.global_thread_id
      #   # => "server1-12345-main" or "server1-12345-worker-1"
      def global_thread_id
        "#{global_pid}-#{thread_name}"
      end

      # Get a safe name for a thread. Uses the thread's assigned name if available,
      # otherwise generates a unique identifier based on the thread's object ID.
      # Non-alphanumeric characters (except underscores, dashes, and periods) are replaced
      # with dashes to create URL-safe identifiers.
      #
      # @param thread [Thread] The thread to get the name for. Defaults to the current thread.
      # @return [String] A safe string identifier for the thread.
      #
      # @example
      #   Thread.current.name = "worker-thread"
      #   Lumberjack::Utils.thread_name  # => "worker-thread"
      #
      #   # For unnamed threads
      #   Lumberjack::Utils.thread_name  # => "2c001a80c" (based on object_id)
      def thread_name(thread = Thread.current)
        thread.name ? slugify(thread.name) : thread.object_id.to_s(36)
      end

      # Force encode a string to UTF-8, handling invalid byte sequences gracefully.
      # Any invalid or undefined byte sequences will be replaced with an empty string,
      # ensuring the result is always valid UTF-8.
      #
      # @param str [String, nil] The string to encode. Returns nil if input is nil.
      # @return [String, nil] The UTF-8 encoded string, or nil if input was nil.
      #
      # @example
      #   # Handles strings with invalid encoding
      #   bad_string = "Hello\xff\xfeWorld".force_encoding("ASCII-8BIT")
      #   Lumberjack::Utils.force_utf8(bad_string)  # => "HelloWorld"
      def force_utf8(str)
        return nil if str.nil?

        str.dup.force_encoding("ASCII-8BIT").encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
      end

      # Flatten a nested attribute hash into a single-level hash using dot notation for nested keys.
      # This is useful for converting structured data into a flat format suitable for logging systems
      # that don't support nested structures.
      #
      # @param attr_hash [Hash] The hash to flatten. Non-hash values are ignored.
      # @return [Hash<String, Object>] A flattened hash with dot-notation keys.
      #
      # @example Basic flattening
      #   hash = {user: {id: 123, profile: {name: "Alice"}}, action: "login"}
      #   Lumberjack::Utils.flatten_attributes(hash)
      #   # => {"user.id" => 123, "user.profile.name" => "Alice", "action" => "login"}
      #
      # @example With mixed types
      #   hash = {config: {db: {host: "localhost", port: 5432}}, debug: true}
      #   Lumberjack::Utils.flatten_attributes(hash)
      #   # => {"config.db.host" => "localhost", "config.db.port" => 5432, "debug" => true}
      def flatten_attributes(attr_hash)
        return {} unless attr_hash.is_a?(Hash)

        flatten_hash_recursive(attr_hash)
      end

      # Alias for {.flatten_attributes} to provide compatibility with the 1.x API.
      # This method will eventually be removed in a future version.
      #
      # @param tag_hash [Hash] The hash to flatten.
      # @return [Hash<String, Object>] The flattened hash.
      # @deprecated Use {.flatten_attributes} instead.
      def flatten_tags(tag_hash)
        Utils.deprecated("Lumberjack::Utils.flatten_tags", "Lumberjack::Utils.flatten_tags is deprecated; use flatten_attributes instead.") do
          flatten_attributes(tag_hash)
        end
      end

      # Expand a hash containing dot notation keys into a nested hash structure.
      # This is the inverse operation of {.flatten_attributes} and is useful for converting
      # flat attribute structures back into nested hashes.
      #
      # @param attributes [Hash] The hash with dot notation keys to expand. Non-hash values are ignored.
      # @return [Hash] A nested hash with dot notation keys expanded into nested structures.
      #
      # @example Basic expansion
      #   flat = {"user.id" => 123, "user.name" => "Alice", "action" => "login"}
      #   Lumberjack::Utils.expand_attributes(flat)
      #   # => {"user" => {"id" => 123, "name" => "Alice"}, "action" => "login"}
      #
      # @example Deep nesting
      #   flat = {"app.db.host" => "localhost", "app.db.port" => 5432, "app.debug" => true}
      #   Lumberjack::Utils.expand_attributes(flat)
      #   # => {"app" => {"db" => {"host" => "localhost", "port" => 5432}, "debug" => true}}
      #
      # @example Mixed with existing nested structures
      #   mixed = {"user.id" => 123, "settings" => {"theme" => "dark"}}
      #   Lumberjack::Utils.expand_attributes(mixed)
      #   # => {"user" => {"id" => 123}, "settings" => {"theme" => "dark"}}
      def expand_attributes(attributes)
        return {} unless attributes.is_a?(Hash)

        expand_dot_notation_hash(attributes)
      end

      # Alias for {.expand_attributes} to provide compatibility with the 1.x API.
      # This method will eventually be removed in a future version.
      #
      # @param tags [Hash] The hash to expand.
      # @return [Hash] The expanded hash.
      # @deprecated Use {.expand_attributes} instead.
      def expand_tags(tags)
        Utils.deprecated("Lumberjack::Utils.expand_tags", "Lumberjack::Utils.expand_tags is deprecated; use expand_attributes instead.") do
          expand_attributes(tags)
        end
      end

      private

      # Recursively flatten a hash, building dot notation keys for nested structures.
      #
      # @param hash [Hash] The hash to flatten.
      # @param prefix [String, nil] The current key prefix for nested structures.
      # @return [Hash<String, Object>] The flattened hash.
      # @api private
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

      # Convert a string to a URL-safe slug by replacing non-alphanumeric characters
      # (except underscores, dashes, and periods) with dashes, and removing leading/trailing dashes.
      #
      # @param str [String, nil] The string to slugify.
      # @return [String, nil] The slugified string, or nil if input was nil.
      # @api private
      def slugify(str)
        return nil if str.nil?

        str = str.gsub(NON_SLUGGABLE_PATTERN, "-")
        str.delete_prefix!("-")
        str.chomp!("-")
        str
      end

      # Recursively expand dot notation keys in a hash into nested structures.
      #
      # @param hash [Hash] The hash containing dot notation keys to expand.
      # @param expanded [Hash] The target hash to store expanded results.
      # @return [Hash] The expanded hash with nested structures.
      # @api private
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
