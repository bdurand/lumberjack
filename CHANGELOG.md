# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 2.0.0

This is a major update with several breaking changes. See the [upgrade guide](UPGRADE_GUIDE.md) for details on breaking changes.

### Added

- Added `Lumberjack::EntryFormatter` class to provide a unified interface for formatting log entry details. Going forward this is the preferred way to define log entry formatters. `Lumberjack::Logger#formatter` now returns an entry formatter.
- Added `Lumberjack::Logger#tag!` as the preferred method for adding global tags to a logger.
- Added `Lumberjack::Logger#untag!` and `Lumberjack::Logger#untag!` to remove global tags from a logger.
- Added `Lumberjack::Logger#in_context?` as a replacement for `Lumberjack::Logger.in_tag_context?` and `Lumberjack.in_context?` as a replacement for `Lumberjack::Logger.context?`.
- Added IO compatibility methods for logging. Calling `logger.write`, `logger.puts`, `logger.print`, or `logger.printf` will write log entries. The severity of the log entries can be set with `default_severity`.
- Added `Lumberjack::Device::LoggerWrapper` as a device that forwards entries to another Lumberjack logger.
- Added `Lumberjack::Device::Test` class for use in testing logging functionality. This device will buffer log entries and has `match?` and `include?` methods that can be used for assertions in tests.
- Added support for standard library `Logger::Formatter`. This is for compatibility with the standard library `Logger`. If a standard library logger is passed to `Lumberjack::Logger` as the formatter, it will override the template when writing to a stream. Tags are not available in the output when using a standard library formatter.
- Classes can now define their own formatting in logs by implementing the `to_log_format` method. If an object responds to this method, it will be called in lieu of looking up the formatter by class. This allows a pattern of defining log formatting along with the code rather than in a an initializer.
- Tag formatters can now add class formatters by class name using the `add_class` method. This allows setting a class formatter before the class has been loaded.
- A tag format can now be passed to the `Lumberjack::Template` class to specify how to format tag name/value pairs. The default is "[%s:%s]".
- Added `TRACE` logging level for logging at an even lower level than `DEBUG`. `Lumberjack::Logger#trace` can be used to log messages at this level.
- Added `Lumberjack::ForkedLogger` which is a wrapper around a logger with a separate context. A local logger has a parent logger which it will write it's log entries through. It will inherit the level, progname, and tags from a parent logger, but has its own local context isolated from the parent logger. You can change the level, progname, and add tags on the local logger without impacting the parent logger. Local loggers can be gotten from the current logger by calling `Lumberjack::Logger#fork`.
- Added `Lumberjack::Utils.current_line` as a helper method for getting the current line of code.
- Added `Lumberjack.build_formatter` as a helper method for building entry formatters.
- Templates can now be use a left padded severity label with the option `pad_severity: true`. This will left pad the severity strings to five characters so that they can all be aligned in the log output.
- Added `Lumberjack::Formatter::Tags` for formatting attributes as "tags" in the logs. Arrays of values will be formatted as "[val1] [val2]" and hashes will be formatted as "[key1=value1] [key2=value2]".
- Added `Lumberjack::DeviceRegistry` as a means for other devices to be associated with a symbol that can then be passed to the constructor when creating a logger with that device rather than having to instantiate the device first.

### Changed

- `Lumberjack::Logger` now inherits from `::Logger` instead of just having API compatibility with the standard library `Logger` class.
- `Lumberjack::Logger` now takes keyword arguments instead of an options hash. **Breaking Change**
- The default log level is now DEBUG instead of INFO. **Breaking Change**
- The severity label for log entries with an unknown level is now ANY instead of UNKNOWN.
- Changing logger level or progname inside a context block will now only be in effect inside the block. **Breaking Change**
- `LumberJack::Logger#context` now yields a `Lumberjack::Context` rather than a `Lumberjack::TagContext`. It must be called with a block and can no longer be used to return the current context. `Lumberjack#context` must also now be called with a block. **Breaking Change**
- `Lumberjack::TagContext` has been renamed to `Lumberjack::AttributesHelper`.
- `Lumberjack::TagFormatter` has been renamed to `Lumberjack::AttributeFormatter`.
- `Lumberjack::Logger#add_entry` does not check the logger level and will add the entry regardless of the severity. This method is an internal API method and is now documented as such.
- Logging to files will now use the standard library `Logger::LogDevice` class for file output and rolling.
- The `Lumberjack::Device::Writer` class now takes an `autoflush` option. Setting it to false will disable synchronous I/O.
- `Lumberjack#tag` can now be called with a block to set up a new context.

### Removed

- Removed deprecated unit of work id code. These have been replaced with tags. **Breaking Change**
- Removed deprecated support for setting global tags with `Lumberjack::Logger#tag`. Now calling `tag` outside of a block or context will be ignored. Use `tag!` to set default tags on a logger. **Breaking Change**
- Removed the devices that handled logging to files (`Lumberjack::Device::LogFile`, `Lumberjack::Device::RollingLogFile`, `Lumberjack::Device::DateRollingLogFile`, and `Lumberjack::Device::SizeRollingLogFile`) since file logging is now handled by the standard library `Logger::LogDevice` class. **Breaking Change**
- Removed internal buffer from the `Lumberjack::Device::Writer` class. This functionality was more useful in the days of slower I/O operations when logs were written to spinning hard disks. The functionality is no longer as useful and is not worth the overhead. The `Lumberjack::Logger.last_flushed_at` method has also been removed.
- Removed support for Ruby versions < 2.7.

### Deprecated

- "Tags" are now called "attributes" to better align with best practices. In logging parlance "tags" are generally an array of strings. The main interface to adding log attributes with `Lumberjack::Logger#tag` has not changed. In this case we are using "tag" as a verb as in "to tag a log entry with attributes". The public interfaces that used "tag" in the method names have all been deprecated and will be removed in a future release.
  - `Lumberjack.context_tags`
  - `Lumberjack::Logger#tags`
  - `Lumberjack::Logger#tag_value`
  - `Lumberjack::Logger#tag_formatter`
  - `Lumberjack::Logger#in_tag_context?`
  - `Lumberjack::Logger#tag_globally`
  - `Lumberjack::Logger#remove_tag`
  - `Lumberjack::LogEntry#tag`
  - `Lumberjack::LogEntry#tags`
  - `Lumberjack::LogEntry#nested_tags`
  - `Lumberjack::Logger#set_progname`
  - `Lumberjack::Logger::Utils.flatten_tags`
  - `Lumberjack::Logger::Utils.expand_tags`
  - `Lumberjack::Logger::TagContext`
  - `Lumberjack::Logger::TagFormatter`
  - `Lumberjack::Logger::Tags`
- Deprecated Rails compatibility methods on `Lumberjack::Logger` (`tagged`, `silence`, `log_at`). Rails support is now moved to the [lumberjack_rails](https://github.com/bdurand/lumberjack_rails) gem.

## 1.4.0

### Changed

- Tags are consistently flattened internally to dot notation keys. This makes tag handling more consistent when using nested hashes as tag values. This changes how nested tags are merged, though. Now when new nested tags are set they will be merged into the existing tags rather than replacing them entirely. So `logger.tag(foo: {bar: "baz"})` will now merge the `foo.bar` tag into the existing tags rather than replacing the entire `foo` tag.
- The `Lumberjack::Logger#context` method can now be called without a block. When called with a block it sets up a new tag context for the block. When called without a block, it returns the current tag context in a `Lumberjack::TagContext` object which can be used to add tags to the current context.
- Tags in `Lumberjack::LogEntry` are now always stored as a hash of flattened keys. This means that when tags are set on a log entry, they will be automatically flattened to dot notation keys. The `tag` method will return a hash of sub-tags if the tag name is a tag prefix.

### Added

- Added `Lumberjack::LogEntry#nested_tags` method to return the tags as a nested hash structure.

## 1.3.4

### Added

- Added `Lumberjack::Logger#with_progname` alias for `set_progname` to match the naming convention used for setting temporary levels.

### Fixed

- Ensure that the safety check for circular calls to `Lumberjack::Logger#add_entry` cannot lose state.

## 1.3.3

### Added

- Added `Lumberjack::Utils#expand_tags` method to expand a hash of tags that may contain nested hashes or dot notation keys.

### Changed

- Updated `Lumberjack::Utils#flatten_tags` to convert all keys to strings.

## 1.3.2

### Fixed

- Fixed `NoMethodError` when setting the device via the `Lumberjack::Logger#device=` method.

## 1.3.1

### Added

- Added `Lumberjack::Logger#context` method to set up a context block for the logger. This is the same as calling `Lumberjack::Logger#tag` with an empty hash.
- Log entries now remove empty tag values so they don't have to be removed downstream.

### Fixed

- ActiveSupport::TaggedLogger now calls `Lumberjack::Logger#tag_globally` to prevent deprecation warnings.

## 1.3.0

### Added

- Added `Lumberjack::Formatter::TaggedMessage` to allow extracting tags from log messages via a formatter in order to better support structured logging of objects.
- Added built in `:round` formatter to round numbers to a specified number of decimal places.
- Added built in `:redact` formatter to redact sensitive information from log tags.
- Added support in `Lumberjack::TagFormatter` for class formatters. Class formatters will be applied to any tag values that match the class.
- Apply formatters to enumerable values in tags. Name formatters are applied using dot syntax when a tag value contains a hash.
- Added support for a dedicated message formatter that can override the default formatter on the log message.
- Added support for setting tags from the request environment in `Lumberjack::Rack::Context` middleware.
- Added helper methods to generate global PID's and thread ids.
- Added `Lumberjack::Logger#tag_globally` to explicitly set a global tag for all loggers.
- Added `Lumberjack::Logger#tag_value` to get the value of a tag by name from the current tag context.
- Added `Lumberjack::Utils.hostname` to get the hostname in UTF-8 encoding.
- Added `Lumberjack::Utils.global_pid` to get a global process id in a consistent format.
- Added `Lumberjack::Utils.global_thread_id` to get a thread id in a consistent format.
- Added `Lumberjack::Utils.thread_name` to get a thread name in a consistent format.
- Added support for `ActiveSupport::Logging.logger_outputs_to?` to check if a logger is outputting to a specific IO stream.
- Added `Lumberjack::Logger#log_at` method to temporarily set the log level for a block of code for compatibility with ActiveSupport loggers.

### Changed

- Default date/time format for log entries is now ISO-8601 with microsecond precision.
- Tags that are set to hash values will now be flattened into dot-separated keys in templates.

### Removed

- Removed support for Ruby versions < 2.5.

### Deprecated

- All unit of work related functionality from version 1.0 has been officially deprecated and will be removed in version 2.0. Use tags instead to set a global context for log entries.
- Calling `Lumberjack::Logger#tag` without a block is deprecated. Use `Lumberjack::Logger#tag_globally` instead.

## 1.2.10

### Added

- Added `with_level` method for compatibility with the latest standard library logger gem.

### Fixed

- Fixed typo in magic frozen string literal comments. (thanks @andyw8 and @steveclarke)

## 1.2.9

### Added

- Allow passing in formatters as class names when adding them.
- Allow passing in formatters initialization arguments when adding them.
- Add truncate formatter for capping the length of log messages.

## 1.2.8

### Added

- Add `Logger#untagged` to remove previously set logging tags from a block.
- Return result of the block when a block is passed to `Logger#tag`.

## 1.2.7

### Fixed

- Allow passing frozen hashes to `Logger#tag`. Tags passed to this method are now duplicated so the logger maintains it's own copy of the hash.

## 1.2.6

### Added

- Add Logger#remove_tag

### Fixed

- Fix `Logger#tag` so it only ads to the current block's logger tags instead of the global tags if called inside a `Logger#tag` block.


## 1.2.5

### Added

- Add support for bang methods (error!) for setting the log level.

### Fixed

- Fixed logic with recursive reference guard in StructuredFormatter so it only suppresses Enumerable references.

## 1.2.4

### Added

- Enhance `ActiveSupport::TaggedLogging` support so code that Lumberjack loggers can be wrapped with a tagged logger.

## 1.2.3

### Fixed

- Fix structured formatter so no-recursive, duplicate references are allowed.

## 1.2.2

### Fixed

- Prevent infinite loops in the structured formatter where objects have backreferences to each other.

## 1.2.1

### Fixed

- Prevent infinite loops where logging a statement triggers the logger.

## 1.2.0

### Added

- Enable compatibility with `ActiveSupport::TaggedLogger` by calling `tagged_logger!` on a logger.
- Add `tag_formatter` to logger to specify formatting of tags for output.
- Allow adding and removing classes by name to formatters.
- Allow adding and removing multiple classes in a single call to a formatter.
- Allow using symbols and strings as log level for silencing a logger.
- Ensure flusher thread gets stopped when logger is closed.
- Add writer for logger device attribute.
- Handle passing an array of devices to a multi device.
- Helper method to get a tag with a specified name.
- Add strip formatter to strip whitespace from strings.
- Support non-alpha numeric characters in template variables.
- Add backtrace cleaner to ExceptionFormatter.

## 1.1.1

### Added

- Replace Procs in tag values with the value of calling the Proc in log entries.

## 1.1.0

### Added

- Change `Lumberjack::Logger` to inherit from ::Logger
- Add support for tags on log messages
- Add global tag context for all loggers
- Add per logger tags and tag contexts
- Reimplement unit of work id as a tag on log entries
- Add support for setting datetime format on log devices
- Performance optimizations
- Add Multi device to output to multiple devices
- Add `DateTimeFormatter`, `IdFormatter`, `ObjectFormatter`, and `StructuredFormatter`
- Add rack `Context` middleware for setting thread global context
- Add support for modules in formatters

### Removed

- End support for ruby versions < 2.3

## 1.0.13

### Added

- Added `:min_roll_check` option to `Lumberjack::Device::RollingLogFile` to reduce file system checks. Default is now to only check if a file needs to be rolled at most once per second.
- Force immutable strings for Ruby versions that support them.

### Changed

- Reduce amount of code executed inside a mutex lock when writing to the logger stream.

## 1.0.12

### Added

- Add support for `ActionDispatch` request id for better Rails compatibility.

## 1.0.11

### Fixed

- Fix Ruby 2.4 deprecation warning on Fixnum (thanks @koic).
- Fix gemspec files to be flat array (thanks @e2).

## 1.0.10

### Added

- Expose option to manually roll log files.

### Changed

- Minor code cleanup.

## 1.0.9

### Added

- Add method so Formatter is compatible with `ActiveSupport` logging extensions.

## 1.0.8

### Fixed

- Fix another internal variable name conflict with `ActiveSupport` logging extensions.

## 1.0.7

### Fixed

- Fix broken formatter attribute method.

## 1.0.6

### Fixed

- Fix internal variable name conflict with `ActiveSupport` logging extensions.

## 1.0.5

### Changed

- Update docs.
- Remove autoload calls to make thread safe.
- Make compatible with Ruby 2.1.1 Pathname.
- Make compatible with standard library Logger's use of progname as default message.

## 1.0.4

### Added

- Add ability to supply a unit of work id for a block instead of having one generated every time.

## 1.0.3

### Fixed

- Change log file output format to binary to avoid encoding warnings.
- Fixed bug in log file rolling that left the file locked.

## 1.0.2

### Fixed

- Remove deprecation warnings under ruby 1.9.3.
- Add more error checking around file rolling.

## 1.0.1

### Fixed

- Writes are no longer buffered by default.

## 1.0.0

### Added

- Initial release
