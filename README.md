# Lumberjack

[![Continuous Integration](https://github.com/bdurand/lumberjack/actions/workflows/continuous_integration.yml/badge.svg)](https://github.com/bdurand/lumberjack/actions/workflows/continuous_integration.yml)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)
[![Gem Version](https://badge.fury.io/rb/lumberjack.svg)](https://badge.fury.io/rb/lumberjack)

Lumberjack is a simple, powerful, and fast logging implementation in Ruby. It uses nearly the same API as the Logger class in the Ruby standard library and as ActiveSupport::BufferedLogger in Rails. It is designed with structured logging in mind, but can be used for simple text logging as well.

## Usage

This code aims to be extremely simple to use and matches the standard Ruby `Logger` interface. The core interface is the Lumberjack::Logger which is used to log messages (which can be any object) with a specified Severity. Each logger has a level associated with it and messages are only written if their severity is greater than or equal to the level.

```ruby
  logger = Lumberjack::Logger.new("logs/application.log")  # Open a new log file with INFO level
  logger.info("Begin request")
  logger.debug(request.params)  # Message not written unless the level is set to DEBUG
  begin
    # do something
  rescue => exception
    logger.error(exception)
    raise
  end
  logger.info("End request")
```

## Features

### Metadata

When messages are added to the log, additional data about the message is kept in a Lumberjack::LogEntry. This means you don't need to worry about adding the time or process id to your log messages as they will be automatically recorded.

The following information is recorded for each message:

- severity - The severity recorded for the message.
- time - The time at which the message was recorded.
- program name - The name of the program logging the message. This can be either set for all messages or customized with each message.
- process id - The process id (pid) of the process that logged the message.
- tags - A map of name value pairs for additional information about the log context.

### Tags

You can use tags to provide additional meta data about a log message or the context that the log message is being made in. Using tags can keep your log messages clean. You can avoid string interpolation to add additional meta data. Tags enable a structured logging approach where you can add additional information to log messages without changing the message format.

Each of the logger methods includes an additional argument that can be used to specify tags on a message:

```ruby
logger.info("request completed", duration: elapsed_time, status: response.status)
```

You can also specify tags on a logger that will be included with every log message.

```ruby
logger.tag(host: Socket.gethostname)
```

You can specify tags that will only be applied to the logger in a block as well.

```ruby
logger.tag(thread_id: Thread.current.object_id) do
  logger.info("here") # Will include the `thread_id` tag
  logger.tag(count: 15)
  logger.info("with count") # Will include the `count` tag
end
logger.info("there") # Will not include the `thread_id` or `count` tag
```

You can also set tags to `Proc` objects that will be evaluated when creating a log entry.

```ruby
logger.tag(thread_id: lambda { Thread.current.object_id })
Thread.new do
  logger.info("inside thread") # Will include the `thread_id` tag with id of the spawned thread
end
logger.info("outside thread") # Will include the `thread_id` tag with id of the main thread
```

Finally, you can specify a logging context with tags that apply within a block to all loggers.

```ruby
Lumberjack.context do
  Lumberjack.tag(request_id: SecureRandom.hex)
  logger.info("begin request") # Will include the `request_id` tag
end
logger.info("no requests") # Will not include the `request_id` tag
```

Tag keys are always converted to strings. Tags are inherited so that message tags take precedence over block tags which take precedence over global tags.

#### Structured Logging with Tags

Tags are particularly powerful for structured logging, where you want to capture machine-readable data alongside human-readable log messages. Instead of embedding variable data directly in log messages (which makes parsing difficult), you can use tags to separate the static message from the dynamic data.

```ruby
# Instead of this (harder to parse)
logger.info("User john_doe logged in from IP 192.168.1.100 in 0.25 seconds")

# Do this (structured and parseable)
logger.info("User logged in", {
  user_id: "john_doe",
  ip_address: "192.168.1.100",
  duration: 0.25,
  action: "login"
})
```

This approach provides several benefits:

- **Consistent message format** - The base message stays the same while data varies
- **Easy filtering and searching** - You can search by specific tag values
- **Better analytics** - Aggregate data by tag values (e.g., average login duration)
- **Machine processing** - Automated systems can easily extract and process tag data

You can also use nested structures in tags for complex data:

```ruby
logger.info("API request completed", {
  request: {
    method: "POST",
    path: "/api/users",
    user_agent: request.user_agent
  },
  response: {
    status: 201,
    duration_ms: 150
  },
  user: {
    id: current_user.id,
    role: current_user.role
  }
})
```

When combined with structured output devices (like [`lumberjack_json_device`](https://github.com/bdurand/lumberjack_json_device)), this creates logs that are both human-readable and machine-processable, making them ideal for log aggregation systems, monitoring, and analytics.

#### Compatibility with ActiveSupport::TaggedLogging

`Lumberjack::Logger` version 1.1.2 or greater is compatible with `ActiveSupport::TaggedLogging`. This is so that other code that expects to have a logger that responds to the `tagged` method will work. Any tags added with the `tagged` method will be appended to an array in the "tagged" tag.

```ruby
logger.tagged("foo", "bar=1", "other") do
  logger.info("here") # will include tags: {"tagged" => ["foo", "bar=1", "other"]}
end
```

#### Templates

The built in `Lumberjack::Device::Writer` class has built in support for including tags in the output using the `Lumberjack::Template` class.

You can specify any tag name you want in a template as well as the `:tags` macro for all tags. If a tag name has been used as its own macro, it will not be included in the `:tags` macro.

### Pluggable Devices

When a Logger logs a LogEntry, it sends it to a Lumberjack::Device. Lumberjack comes with a variety of devices for logging to IO streams or files.

- Lumberjack::Device::Writer - Writes log entries to an IO stream.
- Lumberjack::Device::LogFile - Writes log entries to a file.
- Lumberjack::Device::DateRollingLogFile - Writes log entries to a file that will automatically roll itself based on date.
- Lumberjack::Device::SizeRollingLogFile - Writes log entries to a file that will automatically roll itself based on size.
- Lumberjack::Device::Multi - This device wraps multiple other devices and will write log entries to each of them.
- Lumberjack::Device::Null - This device produces no output and is intended for testing environments.

If you'd like to send your log to a different kind of output, you just need to extend the Device class and implement the `write` method. Or check out these plugins:

- [lumberjack_json_device](https://github.com/bdurand/lumberjack_json_device) - output your log messages as stream of JSON objects for structured logging.
- [lumberjack_syslog_device](https://github.com/bdurand/lumberjack_syslog_device) - send your log messages to the system wide syslog service
- [lumberjack_mongo_device](https://github.com/bdurand/lumberjack_mongo_device) - store your log messages to a [MongoDB](http://www.mongodb.org/) NoSQL data store
- [lumberjack_redis_device](https://github.com/bdurand/lumberjack_redis_device) - store your log messages in a [Redis](https://redis.io/) data store
- [lumberjack-couchdb-driver](https://github.com/narkisr/lumberjack-couchdb-driver) - store your log messages to a [CouchDB](http://couchdb.apache.org/) NoSQL data store
- [lumberjack_heroku_device](https://github.com/tonycoco/lumberjack_heroku_device) - log to Heroku's logging system
- [lumberjack_capture_device](https://github.com/bdurand/lumberjack_capture_device) - capture log messages in memory in test environments so that you can include log output assertions in your tests.

### Customize Formatting

#### Formatters

The message you send to the logger can be any object type and does not need to be a string. You can specify how to format different object types with a formatter. The formatter is responsible for converting the object into a string representation for logging. You do this by mapping classes or modules to formatter code. This code can be either a block or an object that responds to the `call` method. The formatter will be called with the object logged as the message and the returned value will be what is sent to the device.

```ruby
  # Format all floating point numbers with three significant digits.
  logger.formatter.add(Float) { |value| value.round(3) }

  # Format all enumerable objects as a comma delimited string.
  logger.formatter.add(Enumerable) { |value| value.join(", ") }
```

There are several built in classes you can add as formatters. You can use a symbol to reference built in formatters.

```ruby
  logger.formatter.add(Hash, :pretty_print)  # use the Formatter::PrettyPrintFormatter for all Hashes
  logger.formatter.add(Hash, Lumberjack::Formatter::PrettyPrintFormatter.new)  # alternative using a formatter instance
```

- `:object` - `Lumberjack::Formatter::ObjectFormatter` - no op conversion that returns the object itself.
- `:string` - `Lumberjack::Formatter::StringFormatter` - calls `to_s` on the object.
- `:strip` - `Lumberjack::Formatter::StripFormatter` - calls `to_s.strip` on the object.
- `:inspect` - `Lumberjack::Formatter::InspectFormatter` - calls `inspect` on the object.
- `:exception` - `Lumberjack::Formatter::ExceptionFormatter` - special formatter for exceptions which logs them as multi-line statements with the message and backtrace.
- `:date_time` - `Lumberjack::Formatter::DateTimeFormatter` - special formatter for dates and times to format them using `strftime`.
- `:pretty_print` - `Lumberjack::Formatter::PrettyPrintFormatter` - returns the pretty print format of the object.
- `:id` - `Lumberjack::Formatter::IdFormatter` - returns a hash of the object with keys for the id attribute and class.
- `:structured` - `Lumberjack::Formatter::StructuredFormatter` - crawls the object and applies the formatter recursively to Enumerable objects found in it (arrays, hashes, etc.).

To define your own formatter, either provide a block or an object that responds to `call` with a single argument.

#### Default Formatter

The default formatter is applied to all objects being logged. This includes both messages and tags.

The default formatter will pass through values for strings, numbers, and booleans, and use the `:inspect` formatter for all objects except for exceptions which will be formatted with the `:exception` formatter.

#### Message Formatter

You can add a formatter for just the log message with the `message_formatter` method. This formatter will only apply to the message and not to any tags.

```ruby
logger.message_formatter.add(String, :truncate, 1000)  # Will truncate all string messages to 1000 characters
```

##### Extracting Tags from Messages

If you are using structured logging, you can use a formatter to extract tags from the log message by adding a formatter that returns a `Lumberjack::Formatter::TaggedMessage`. For example, if you want to extract metadata from exceptions and add them as tags, you could do this:

```ruby
logger.message_formatter.add(Exception, ->(e) {
  Lumberjack::Formatter::TaggedMessage.new(e.inspect, {
    "error.message": e.message,
    "error.class": e.class.name,
    "error.trace": e.backtrace
  })
})

logger.error(exception)  # Will log the exception and add tags for the message, class, and trace.
```

#### Tag Formatters

The `logger.formatter` will only apply to log messages. You can use `logger.tag_formatter` to register formatters for tags. You can register both default formatters that will apply to all tag values, as well as tag specific formatters that will apply only to objects with a specific tag name.

The formatter values can be either a `Lumberjack::Formatter` or a block or an object that responds to `call`. If you supply a `Lumberjack::Formatter`, the tag value will be passed through the rules for that formatter. If you supply a block or other object, it will be called with the tag value.

```ruby
# These will all do the same thing formatting all tag values with `inspect`
logger.tag_formatter.default(Lumberjack::Formatter.new.clear.add(Object, :inspect))
logger.tag_formatter.default(Lumberjack::Formatter::InspectFormatter.new)
logger.tag_formatter.default { |value| value.inspect }

# This will register formatters only on specific tag names
logger.tag_formatter.add(:thread) { |thread| "Thread(#{thread.name})" }
logger.tag_formatter.add(:current_user, Lumberjack::Formatter::IdFormatter.new)

# You can also register formatters for tag values by class
logger.tag_formatter.add(Numeric, &:round)

# Tag formatters will be applied to nested hashes and arrays as well.

# Name formatters use dot syntax to apply to nested hashes.
logger.tag_formatter.add("user.username", &:upcase)
# logger.tag(user: {username: "john_doe"}) # Will log the tag as {"user" => "username" => "JOHN_DOE"}
```

#### Templates

If you use the built-in `Lumberjack::Writer` derived devices, you can also customize the Template used to format the LogEntry.

See `Lumberjack::Template` for a complete list of macros you can use in the template. You can also use a block that receives a `Lumberjack::LogEntry` as a template.

```ruby
  # Change the format of the time in the log
  Lumberjack::Logger.new("application.log", :time_format => "%m/%d/%Y %H:%M:%S")

  # Use a simple template that only includes the time and the message
  Lumberjack::Logger.new("application.log", :template => ":time - :message")

  # Use a simple template that includes tags, but handles the `duration` tag separately.
  # All tags will appear at the end of the message except for `duration` which will be at the beginning.
  Lumberjack::Logger.new("application.log", :template => ":time (:duration) - :message - :tags")

  # Use a custom template as a block that only includes the first character of the severity
  template = lambda{|e| "#{e.severity_label[0, 1]} #{e.time} - #{e.message}"}
  Lumberjack::Logger.new("application.log", :template => template)
```

### Buffered Logging

The logger has hooks for devices that support buffering to potentially increase performance by batching physical writes. Log entries are not guaranteed to be written until the Lumberjack::Logger#flush method is called. Buffering can improve performance if I/O is slow or there is high overhead writing to the log device.

You can use the `:flush_seconds` option on the logger to periodically flush the log. This is usually a good idea so you can more easily debug hung processes. Without periodic flushing, a process that hangs may never write anything to the log because the messages are sitting in a buffer. By turning on periodic flushing, the logged messages will be written which can greatly aid in debugging the problem.

The built in stream based logging devices use an internal buffer. The size of the buffer (in bytes) can be set with the `:buffer_size` options when initializing a logger. The default behavior is to not to buffer.

```ruby
  # Set buffer to flush after 8K has been written to the log.
  logger = Lumberjack::Logger.new("application.log", :buffer_size => 8192)

  # Turn off buffering so entries are immediately written to disk.
  logger = Lumberjack::Logger.new("application.log", :buffer_size => 0)
```

### Automatic Log Rolling

The built in devices include two that can automatically roll log files based either on date or on file size. When a log file is rolled, it will be renamed with a suffix and a new file will be created to receive new log entries. This can keep your log files from growing to unusable sizes and removes the need to schedule an external process to roll the files.

There is a similar feature in the standard library Logger class, but the implementation here is safe to use with multiple processes writing to the same log file.

## Integrations

Lumberjack has built in support for logging extensions in Rails.

You can use the [`lumberjack_sidekiq`](https://github.com/bdurand/lumberjack_sidekiq) gem to replace Sidekiq's default logger with Lumberjack. This allows you to use all of Lumberjack's features, such as structured logging and tag support, in your Sidekiq jobs.

If you are using DataDog for logging, you can use the [`lumberjack_data_dog`](https://github.com/bdurand/lumberjack_data_dog) gem to format your logs in DataDog's standard attributes format.

## Differences from Standard Library Logger

`Lumberjack::Logger` does not extend from the `Logger` class in the standard library, but it does implement a compatible API. The main difference is in the flow of how messages are ultimately sent to devices for output.

The standard library Logger logic converts the log entries to strings and then sends the string to the device to be written to a stream. Lumberjack, on the other hand, sends structured data in the form of a `Lumberjack::LogEntry` to the device and lets the device worry about how to format it. The reason for this flip is to better support structured data logging. Devices (even ones that write to streams) can format the entire payload including non-string objects and tags however they need to.

The logging methods (`debug`, `info`, `warn`, `error`, `fatal`) are overloaded with an additional argument for setting tags on the log entry.

## Examples

These examples are for Rails applications, but there is no dependency on Rails for using this gem. Most of the examples are applicable to any Ruby application.

In a Rails application you can replace the default production logger by adding this to your config/environments/production.rb file:

```ruby
  # Add the ActionDispatch request id as a global tag on all log entries.
  config.middleware.insert_after(
    ActionDispatch::RequestId,
    Lumberjack::Rack::Context,
    request_id: ->(env) { env["action_dispatch.request_id"] }
  )
  # Change the logger to use Lumberjack
  log_file = Rails.root + "log" + "#{Rails.env}.log"
  # log_file = $stdout # or write to stdout instead of a file
  config.logger = Lumberjack::Logger.new(log_file, :level => :warn)
```

To set up a logger to roll every day at midnight, you could use this code (you can also specify :weekly or :monthly):

```ruby
  config.logger = Lumberjack::Logger.new(log_file_path, :roll => :daily)
```

To set up a logger to roll log files when they get to 100Mb, you could use this:

```ruby
  config.logger = Lumberjack::Logger.new(log_file_path, :max_size => 100.megabytes)
```

To change the log message format, you could use this code:

```ruby
  config.logger = Lumberjack::Logger.new(log_file_path, :template => ":time - :message")
```

To change the log message format to output JSON, you could use this code:

```ruby
  config.logger = Lumberjack::Logger.new(log_file_path, :template => lambda{|e| JSON.dump(time: e.time, level: e.severity_label, message: e.message)})
```

To send log messages to syslog instead of to a file, you could use this (require the lumberjack_syslog_device gem):

```ruby
  config.logger = Lumberjack::Logger.new(Lumberjack::SyslogDevice.new)
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem "lumberjack"
```

And then execute:
```bash
$ bundle install
```

Or install it yourself as:
```bash
$ gem install lumberjack
```

## Contributing

Open a pull request on GitHub.

Please use the [standardrb](https://github.com/testdouble/standard) syntax and lint your code with `standardrb --fix` before submitting.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
