# Lumberjack

[![Continuous Integration](https://github.com/bdurand/lumberjack/actions/workflows/continuous_integration.yml/badge.svg)](https://github.com/bdurand/lumberjack/actions/workflows/continuous_integration.yml)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)
[![Gem Version](https://badge.fury.io/rb/lumberjack.svg)](https://badge.fury.io/rb/lumberjack)

Lumberjack is an extension to the Ruby standard library `Logger` class, designed to provide advanced, flexible, and structured logging for Ruby applications. It builds on the familiar `Logger` API, adding powerful features for modern logging needs:

- **Attributes for Structured Logging:** Use attributes to attach structured, machine-readable metadata to log entries, enabling better filtering, searching, and analytics.
- **Context Isolation:** Isolate logging behavior to specific blocks of code. The attributes, level, and progname for the logger can all be changed in a context block and only impact the log messages created within that block.
- **Formatters:** Control how objects are logged with customizable formatters for messages and attributes.
- **Devices and Templates:** Choose from a variety of output devices and templates to define the format and destination of your logs.
- **Forked Loggers:** Create independent logger instances that inherit context from a parent logger, allowing for isolated logging configurations in different parts of your application.
- **Testing Tools:** Built-in testing devices and helpers make it easy to assert logging behavior in your test suite.

The philosophy behind the library is to promote use of structured logging with the standard Ruby Logger API as a foundation. The developer of a piece of functionality should only need to worry about the data that needs to be logged for that functionality and not how it is logged or formatted. Loggers can be setup with global attributes and formatters that handle these concerns.

## Table of Contents

- [Usage](#usage)
   - [Context Isolation](#context-isolation)
     - [Context Blocks](#context-blocks)
     - [Nested Context Blocks](#nested-context-blocks)
     - [Forking Loggers](#forking-loggers)
     - [Isolation Level](#isolation-level)
   - [Structured Logging With Attributes](#structured-logging-with-attributes)
     - [Basic Attribute Logging](#basic-attribute-logging)
     - [Adding attributes to the logger](#adding-attributes-to-the-logger)
     - [Global Logger Attributes](#global-logger-attributes)
     - [Nested Attributes and Complex Data](#nested-attributes-and-complex-data)
     - [Attribute Inheritance and Merging](#attribute-inheritance-and-merging)
     - [Working with Array Attributes](#working-with-array-attributes)
   - [Formatters](#formatters)
     - [Message Formatters](#message-formatters)
     - [Attribute Formatters](#attribute-formatters)
     - [Built-in Formatters](#built-in-formatters)
     - [Custom Formatters](#custom-formatters)
     - [Building An Entry Formatter](#building-an-entry-formatter)
     - [Merging Formatters](#merging-formatters)
   - [Devices and Templates](#devices-and-templates)
     - [Built-in Devices](#built-in-devices)
     - [Custom Devices](#custom-devices)
     - [Templates](#templates)
   - [Testing Utilities](#testing-utilities)
   - [Using As A Stream](#using-as-a-stream)
   - [Integrations](#integrations)
- [Installation](#installation)
- [Contributing](#contributing)
- [License](#license)

## Usage

### Context Isolation

Lumberjack provides context isolation that allow you to temporarily modify logging behavior for specific blocks of code or create independent logger instances. This is particularly useful for isolating logging configuration in different parts of your application without affecting the global logger state.

#### Context Blocks

Context blocks allow you to temporarily change the logger's configuration (level, progname, and attributes) for a specific block of code. When the block exits, the logger returns to its previous state.

Context blocks and forked loggers are thread and fiber-safe, maintaining isolation across concurrent operations:

```ruby
logger.level = :info

# Temporarily change log level for debugging a specific section
logger.context do
  logger.level = :debug
  logger.debug("This debug message will be logged")
end

# Back to info level - debug messages are filtered out again
logger.debug("This won't be logged")
```

You can use `with_level`, `with_progname`, and `tag` to setup a context block with a specific level, progname, or attributes.

As a best practice, every main unit of work in your application (i.e. HTTP request, background job, etc.) should have a context block. This ensures that any attributes or changes to the logger are scoped to that unit of work and do not leak into other parts of the application.

##### Nested Context Blocks

Context blocks can be nested, with inner contexts inheriting and potentially overriding outer context settings:

```ruby
logger.context do
  logger.tag(user_id: 123, service: "api")
  logger.info("API request started") # Includes user_id: 123, service: "api"

  logger.context(endpoint: "/users", service: "user_service") do
    logger.tag(service: "user_service", endpoint: "/users")
    logger.info("Processing user data") # Includes: user_id: 123, service: "user_service", endpoint: "/users"
  end

  logger.info("API request completed") # Back to: user_id: 123, service: "api"
end
```

#### Forking Loggers

Logger forking creates independent logger instances that inherit the parent logger's current context. Changes made to the forked logger will not affect the parent logger.

Forked loggers are useful when there is a section of your application that requires different logging behavior. Forked loggers are cheap to create, so you can use them liberally.

```ruby
main_logger = Lumberjack::Logger.new
main_logger.tag!(version: "1.0.0")

# Create a forked logger for a specific component
user_service_logger = main_logger.fork(progname: "UserService", level: :debug)
user_service_logger.tag!(component: "user_management")

user_service_logger.debug("Debug info")    # Includes version and component attributes
main_logger.info("Main logger info")       # Includes only version attribute
main_logger.debug("Main logger debug info") # Not logged since level is :info
```

#### Isolation Level

By default each fiber will have its own logging context. This is useful in asynchronous applications where multiple fibers may be running concurrently. You can change the isolation level to `:thread` if you want each thread to have its own logging context instead.

```ruby
Lumberjack.isolation_level = :thread # Set isolation level globally

logger = Lumberjack::Logger.new(STDOUT, isolation_level: :thread) # Set isolation level per logger
```

Fiber isolation is the safest behavior since it completely isolates local contexts. However, in applications where threads are the main unit of work and fibers are never shared across threads, thread isolation may be more appropriate. Otherwise you can end up with logger losing the context block when switching fibers within the same thread.

### Structured Logging With Attributes

Lumberjack extends standard logging with **attributes** (structured key-value pairs) that add context and metadata to your log entries. This enables powerful filtering, searching, and analytics capabilities.

#### Basic Attribute Logging

Add attributes with any logging method:

```ruby
# Add attributes to individual log calls
logger.info("User logged in", user_id: 123, ip_address: "192.168.1.100")
logger.error("Payment failed", user_id: 123, amount: 29.99, error: "card_declined")

# Attributes can be any type
logger.debug("Processing data",
  records_count: 1500,
  processing_time: 2.34,
  metadata: { batch_id: "abc-123", source: "api" },
  timestamp: Time.now
)
```

> [!Note]
> Attributes are passed in log statements in the little used `progname` argument that is defined in the standard Ruby Logger API. This attribute is normally used to set a specific program name for the log entry that overrides the default program name on the logger.
>
> The only difference in the API is that Lumberjack loggers can take a Hash to set attributes instead of just a string. You can still pass a string to override the program name.

#### Adding attributes to the logger

Use the  `tag` method to tag the the current context with attributes. The attributes will be included in all log entries within that context.

```ruby
logger.context do
  logger.tag(user_id: current_user.id, session: "abc-def")
  logger.info("Session started")           # Includes user_id and session
  logger.debug("Loading user preferences") # Includes user_id and session
  logger.info("Dashboard rendered")        # Includes user_id and session
end

logger.info("Outside of context") # Does not include user_id or session
```

You can also use the `tag` method with a block to open a new context and assign attributes.

```ruby
# Apply attributes to all log entries within the block
logger.tag(user_id: 123, session: "abc-def") do
  logger.info("Session started")
  logger.debug("Loading user preferences")
  logger.info("Dashboard rendered")
end
```

Calling `tag` outside of a context without a block is a no-op and has no effect on the logger.

You can also use the `tag_all_contexts` method to add attributes to all parent context blocks. This can be useful in cases where you need to set an attribute that should be included in all subsequent log entries for the duration of the process defined by the outermost context.

Consider this example where we want to include the `user_id` attribute in all log entries. We need to set it on all parent contexts in order to have it extend beyond the current context block.

```ruby
logger.context do
  logger.tag(request_id: "req-123") do
    logger.info("Processing request") # Includes request_id

    logger.tag(action: "login") do
      user_id = login_user(params)

      logger.tag(login_method: params[:login_method])
      logger.tag_all_contexts(user_id: user_id)

      logger.info("User logged in") # Includes request_id, action, login_method, and user_id
    end

    logger.info("Request completed") # Includes request_id and user_id
  end
```

#### Global Logger Attributes

You can add global attributes that apply to all log entries with the `tag!` method.

```ruby
logger.tag!(
  version: "1.2.3",
  env: Rails.env,
  request_id: -> { Current.request_id }
)
```

If the value of an attribute is a `Proc`, it will be evaluated at runtime when the log entries are created. So in the above example, `request_id` will be dynamically set to the current request ID whenever a log entry is created.

Note that blank attributes are never included in the log output, so if `Current.request_id` is `nil`, the `request_id` attribute will be omitted from the log entry.

There is also a global `Lumberjack` context that applies to all Lumberjack loggers.

```ruby
Lumberjack.tag(version: "1.2.3") do
  logger_1.info("Something happened")       # Includes version
  logger_2.info("Something else happened")  # Includes version
end
```

#### Nested Attributes and Complex Data

Attributes support nested structures and complex data types:

```ruby
logger.info("API request completed",
  request: {
    method: "POST",
    path: "/api/users",
    headers: { "Content-Type" => "application/json" }
  },
  response: {
    status: 201,
    duration_ms: 45.2,
    size_bytes: 1024
  },
  user: {
    id: 123,
    role: "admin",
    permissions: ["read", "write", "delete"]
  }
)
```

#### Attribute Inheritance and Merging

Attributes from different sources are merged together, with more specific attributes taking precedence:

```ruby
# Persistent logger attributes
logger.tag!(service: "web", datacenter: "us-east-1")

logger.tag(request_id: "req-123") do
  # Block-level attributes override any conflicts
  logger.tag(datacenter: "us-west-2") do
    logger.info("Processing request",
      user_id: 456,
      datacenter: "eu-central-1"  # This takes highest precedence
    )
    # Final attributes: { service: "web", request_id: "req-123", user_id: 456, datacenter: "eu-central-1" }
  end
end
```

Attributes use dot notation for nested structures, so there is no difference between these statements:

```ruby
logger.info("User signed in", user: {id: 123})
logger.info("User signed in", "user.id" => 123)
```

#### Working with Array Attributes

A common practice is to add an array of values to a specific attribute. You can use the `append_to` method to append values to an array attribute in the current context. Like the `tag` method, this method can be called with a block to create a new context or without a block to update the current context.

```ruby
logger.append_to(:tags, "api", "v1") do
  logger.info("API request started") # Includes tags: ["api", "v1"]

  logger.append_to(:tags, "users")
  logger.info("Processing user data") # Includes tags: ["api", "v1", "users"]
end

# You can also append to other array attributes
logger.append_to(:categories, "billing", "premium") do
  logger.info("Processing premium billing") # Includes categories: ["billing", "premium"]
end
```

### Formatters

Lumberjack provides a powerful formatting system that controls how objects are converted to strings in log entries. With this feature you can pass objects to the logger and rely on the formatters to handle formatting thereby simplifying the logging code and improving consistency.

There are two types of formatters.

#### Message Formatters

Message formatters control how different types of objects are converted to strings when logged as messages. Message formatters are registered for specific classes or modules. When you log an object, the formatter will be looked up based on the object's class.

```ruby
logger.formatter.format_message(Array) { |arr| arr.join(", ") }

logger.info([1, 2, 3]) # Logs "1, 2, 3"
```

For log messages you can use the `Lumberjack::MessageAttributes` class to extract structured data from a log message. This can be used to allow logging objects directly and extracting metadata from the objects in the log attributes.

```ruby
logger.formatter.format_message(Exception) do |error|
  Lumberjack::MessageAttributes.new(
    error.inspect, # This will be used as the log message
    error: { # This will be added to the log attributes
      type: error.class.name,
      message: error.message,
      backtrace: error.backtrace
    }
  )
end

# This will now log the message as `exception.inspect` and pull
# out the type, message, and backtrace into attributes. With this
# you won't need to figure out how to log each exception and just
# just log the object itself and let the formatter deal with it.
logger.error(exception)
```

#### Attribute Formatters

Attribute formatters control how attribute values (the key-value pairs in structured logging) are formatted. They provide fine-grained control over different attributes and data types.

You can specify how to format object types when they are logged as attributes:

```ruby
logger.formatter.format_attributes(Time, :date_time, "%Y-%m-%d %H:%M:%S")
logger.formatter.format_attributes([Float, BigDecimal], :round, 2)

logger.info("Data processed",
  created_at: Time.now,          # → "2025-08-22 14:30:00"
  price: 29.099,                 # → 29.10
)
```

You can also format attributes based on the attribute name:

```ruby
# Configure attribute formatting
logger.formatter.format_attribute_name("password") { |pwd| "[REDACTED]" }
logger.formatter.format_attribute_name("email") { |email| email.downcase }
logger.formatter.format_attribute_name("cost", :round, 2)

# Now attributes are formatted according to the rules
logger.info("User created",
  email: "JOHN@EXAMPLE.COM",     # → "john@example.com"
  password: "secret123",         # → "[REDACTED]"
  cost: 29.129999                # → 29.13
)
```

You can remap attributes to other attribute names by returning a `Lumberjack::RemapAttribute` instance.

```ruby
# Move the email attribute under the user attributes.
logger.formatter.format_attribute_name("email") do |value|
  Lumberjack::RemapAttribute.new("user.email" => value)
end

# Transform duration_millis and duration_micros to seconds and move to
# the duration attribute.
logger.formatter.format_attribute_name("duration_ms") do |value|
  Lumberjack::RemapAttribute.new("duration" => value.to_f / 1000)
end
logger.formatter.format_attribute_name("duration_micros") do |value|
  Lumberjack::RemapAttribute.new("duration" => value.to_f / 1_000_000)
end
```

Finally, you can add a default formatter for all other attributes:

```ruby
logger.formatter.default_attribute_format { |value| value.to_s.strip[0..100] }
```

#### Built-in Formatters

Lumberjack provides several predefined formatters that can be referenced by symbol:

```ruby
logger = Lumberjack::Logger.new

# Configure the formatter
logger.formatter.format_class(Float, :round, 2)           # Round floats to 2 decimals
logger.formatter.format_class(Time, :date_time, "%H:%M")  # Custom time format

# Now these objects will be formatted according to the rules
logger.info(3.14159)                             # "3.14"
logger.info(Time.now)                            # "14:30"
```

**Available Built-in Formatters:**

| Formatter | Purpose |
|-----------|---------|
| `:date_time` | Format time/date objects |
| `:exception` | Format exceptions with stack traces |
| `:id` | Extract object ID or specified field |
| `:inspect` | Use Ruby's inspect method |
| `:multiply` | Multiply numeric values |
| `:object` | Generic object formatter |
| `:pretty_print` | Pretty print using PP library |
| `:redact` | Redact sensitive information |
| `:round` | Round numeric values |
| `:string` | Convert to string using to_s |
| `:strip` | Strip whitespace from strings |
| `:structured` | Recursively format collections |
| `:tags` | Format values as tags in the format "[val1] [val2]" for arrays or "[key=value]" for hashes |
| `:truncate` | Truncate long strings |

#### Custom Formatters

You can create custom formatters using blocks, callable objects, or custom classes:

```ruby
# Block-based formatters
logger.formatter.format_class(User) { |user| "User[#{user.id}:#{user.name}]" }
logger.formatter.format_class(BigDecimal) { |decimal| "$#{decimal.round(2)}" }

# Callable object formatters
class TimeFormatter
  def call(time)
    time.strftime("%Y-%m-%d %H:%M:%S")
  end
end

logger.formatter.format_class(SecureString, PasswordFormatter.new)
```

Classes can also implement `to_log_format` to define how instances should be serialized for logging. This will apply to both message and attribute formatting.

```ruby
class User
  attr_accessor :id, :name

  def to_log_format
    "User[id: #{ id }, name: #{ name }]"
  end
end
```

Primitive classes (`String`, `Integer`, `Float`, `TrueClass`, `FalseClass`, `NilClass`, `BigDecimal`) will not use `to_log_format`.

#### Building An Entry Formatter

The Entry Formatter coordinates both message and attribute formatting, providing a unified configuration interface:

##### Complete Entry Formatter Setup

```ruby
# Build a comprehensive entry formatter
entry_formatter = Lumberjack.build_formatter do |formatter|
  # Format for ActiveRecord models that applies to both messages and attributes.
  formatter.format_class(ActiveRecord::Base, :id)

  # Format for the User class when it is logged as the log message.
  formatter.format_message(User) { |user| "User[#{user.id}:#{user.username}]" }

  # Attribute formatting
  formatter.format_attributes(Time, :date_time, "%Y-%m-%d %H:%M:%S")
  formatter.format_attributes([Float, BigDecimal], :round, 6)
  formatter.format_attribute_name("email", :redact)
end

# Use with logger
logger = Lumberjack::Logger.new(STDOUT, formatter: entry_formatter)
```

#### Merging Formatters

You can merge other formatters into your formatter with the `include` method. Doing so will copy all of the format definitions.

```ruby
# Translate the duration tag to microseconds.
duration_formatter = Lumberjack::EntryFormatter.build do |formatter|
  formatter.format_attribute_name(:duration) { |seconds| (seconds.to_f * 1_000_000).round }
end

entry_formatter = Lumberjack::EntryFormatter.build do |formatter|
  # Adds the duration attribute formatter
  formatter.include(duration_formatter)
end
```

You can also call `prepend` in which case any formats already defined will take precedence over the formats being included.

### Devices and Templates

Devices control where and how log entries are written. Lumberjack provides a variety of built-in devices that can write to files, streams, multiple destinations, or serve special purposes like testing. All devices implement a common interface, making them interchangeable.

#### Built-in Devices

##### Writer Device

The `Writer` device is the foundation for most logging output, writing formatted log entries to any IO stream. It will be used if you pass an IO object to the logger.

```ruby
logger = Lumberjack::Logger.new(STDOUT)
```

##### LogFile Device

The `LogFile` device handles logging to a file. It has the same log rotation capabilities as the `Logger::LogDevice` class in the standard library logger.

```ruby
# Daily log rotation
logger = Lumberjack::Logger.new("/var/log/app.log", 'daily')
```

##### Multi Device

The `Multi` device broadcasts log entries to multiple devices simultaneously. You can instantiate a multi device by passing in an array of values.

```ruby
# Log to both file and STDOUT; the logs to STDOUT will only contain the log message.
logger = Lumberjack::Logger.new(["/var/log/app.log", [:stdout, {template: "{{message}}"}]])

logger.info("Application started")  # Appears in both file AND STDOUT
```

##### LoggerWrapper Device

The `LoggerWrapper` device forwards entries to another Logger instance. It is most useful when you want to route logs from one logger to another, possibly with different configurations.

```ruby
target_logger = Lumberjack::Logger.new("/var/log/target.log")
logger = Lumberjack::Logger.new(target_logger)
```

> [!NOTE]
> Note that the level of the outer logger will take precedence. So if the outer logger is set to `:warn`, then only warning messages or higher will be forwarded to the target logger.

> [!TIP]
> You can also pass in a standard Ruby `Logger` instance. This allows you to use the enhanced Lumberjack logging features with a standard library logger.

##### Test Device

The `Test` device logs entries in memory and is intended for use in test suites where you want to make assertions that specific log entries are recorded.

```ruby
logger = Lumberjack::Logger.new(:test)
```

> [!TIP]
> See the [testing utilities](#testing-utilities) section for more information.

##### Null Device

The `Null` device discards all output.

```ruby
logger = Lumberjack::Logger.new(:null)
```

#### Custom Devices

You can create custom devices by implementing the `write` method. The `write` method will receive a `Lumberjack::LogEntry` object and is free to process it in any way.

```ruby
class DatabaseDevice < Lumberjack::Device
  def initialize(database_connection)
    @db = database_connection
  end

  def write(entry)
    @db.execute(
      "INSERT INTO logs (timestamp, level, message, attributes, pid) VALUES (?, ?, ?, ?, ?)",
      entry.time,
      entry.severity_label,
      entry.message,
      JSON.generate(entry.attributes),
      entry.pid
    )
  end

  def close
    @db.close
  end
end

# Usage
db_device = DatabaseDevice.new(SQLite3::Database.new("logs.db"))
logger = Lumberjack::Logger.new(db_device)
```

There are separate gems implementing custom devices for different use cases:

- [lumberjack_json_device](https://github.com/bdurand/lumberjack_json_device) - Output logs to JSON
- [lumberjack_datadog_device](https://github.com/bdurand/lumberjack_datadog) - Output logs in JSON using the Datadog standard attributes.
- [lumberjack_capture_device](https://github.com/bdurand/lumberjack_capture_device) - Device designed for capturing logs in tests to make assertions easier
- [lumberjack_syslog_device](https://github.com/bdurand/lumberjack_syslog_device) - Device for logging to a syslog server
- [lumberjack_redis_device](https://github.com/bdurand/lumberjack_redis_device) - Device for logging to a Redis database

You can register a custom device with Lumberjack using the device registry. This associates the device with the device class and can make using the device easier to setup since the user can pass the symbol and options when instantiating the Logger rather than having to instantiate the device separately.

```ruby
  Lumberjack::Device.register(:my_device, MyDevice)

  # Now logger can be instantiated with the name and all options will be passed to
  # the MyDevice constructor.
  logger = Lumberjack::Logger.new(:my_device, autoflush: true)
```

#### Templates

The output devices writing to a stream or file can define templates that formats how log entries are written. Templates use mustache-style placeholders that are replaced with values from the log entry.

##### Basic Template Usage

```ruby
# Simple template with common fields
logger = Lumberjack::Logger.new(STDOUT, template: "{{time}} {{severity}} {{message}}")

logger.info("Application started")
# Output: 2025-09-03T14:30:15.123456 INFO Application started
```

##### Available Template Variables

Templates support the following placeholder variables:

| Variable | Description |
|----------|-------------|
| `time` | Timestamp |
| `severity` | Severity level |
| `progname` | Program name |
| `pid` | Process ID |
| `message` | Log message |
| `attributes` | Formatted attributes |

In addition you can put any attribute name in a placeholder. The attribute will be inserted in the log line where the placeholder is defined and will be removed from the general list of attributes.

```ruby
# The user_id attribute will appear separately on the log line from the
# rest of the attributes.
logger = Lumberjack::Logger.new(STDOUT,
  template: "[{{time}} {{severity}} {{user_id}}] {{message}} {{attributes}}"
)
```

The severity can also have an optional formatting argument added to it.

| Variable | Description |
|----------|-------------|
| `severity` | Uppercase case severity label (INFO, WARN, etc.) |
| `severity(padded)` | Severity label padded to 5 characters |
| `severity(char)` | First character of severity label |
| `severity(emoji)` | Emoji representation of severity level |
| `severity(level)` | Numeric severity level |

##### Template Options

You can customize how template variables are formatted using template options:

```ruby
logger = Lumberjack::Logger.new(STDOUT,
  template: "[{{time}} {{severity(padded)}} {{progname}}({{pid}})] [{{http.request_id}}] {{message}} {{attributes}}",
  time_format: "%Y-%m-%d %H:%M:%S", # Custom time format
  additional_lines: "\n> [{{http.request_id}}] {{message}}", # Template for additional lines on multiline messages
  attribute_format: "[%s=%s]", # Format for attributes using printf syntax
  colorize: true # Colorize log output according to entry severity
)

logger.info("Test message", user_id: 123, status: "active")
# Output: 2025-09-03 14:30:15  INFO Test message [user_id=123] [status=active]
```

##### Built-in Templates

You can use symbols to refer to built-in templates:

- `:default` - The default log template. This is the same as not specifying a template.
- `:stdlib` - A template that mimics the default format of the standard library Logger.
- `:local` - A simple, human readable template intended for local development and test environments. This template removes the time and pid from the log line since they are generally not needed in these environments. You can also exclude attributes by setting the `exclude_attributes` option to the list of attributes names to exclude. For example, you may want to add a `host` attribute for your production logs, but this just creates clutter in development logs since it is always the same value.

```ruby
logger = Lumberjack::Logger.new(STDOUT, template: :local, exclude_attributes: ["host", "env", "version"])
```

### Testing Utilities

The `Test` device captures log entries in memory for testing and assertions:

```ruby
logger = Lumberjack::Logger.new(:test)

# Log some entries
logger.info("User logged in", user_id: 123)
logger.error("Payment failed", amount: 29.99)

# You can make assertions against the logs (using rspec in this case)
expect(logger.device.entries.size).to eq(2)
expect(logger.device.last_entry.message).to eq("Payment failed")

# Use pattern matching
expect(logger.device).to include(
  severity: :info,
  message: "User logged in",
  attributes: { user_id: 123 }
)

expect(logger.device).to include(severity: :error, message: /Payment/)
```

You should make sure to call `logger.device.clear` between tests to clear the captured logs on any global loggers that are using the `Test` device.

> [!NOTE]
> Log entries are captured after formatters have been applied. This provides a mechanism for including the formatting logic in your tests.

> [!TIP]
> The [lumberjack_capture_device](https://github.com/bdurand/lumberjack_capture_device) gem provides some additional testing utilities and rspec integration.

You can also use the `write_to` method on the `Test` device to write the captured log entries to another logger or device. This can be useful in scenarios where you want to preserve log output for failed tests.

```ruby
# Set up test logger (presumably in an initializer)
Application.logger = Lumberjack::Logger.new(:test)

# Hook into your test framework; in this example using rspec.
RSpec.configure do |config|
  failed_test_logs = Lumberjack::Logger.new("log/test_failures.log")
  config.around do |example|
    # Clear the captured logs so we start with a clean slate.
    Application.logger.clear

    example.run

    if example.exception
      failed_test_logs.error("Test failed: #{example.full_description} @ #{example.location}")
      Application.logger.device.write_to(failed_test_logs)
    end
  end
end
```

Lumberjack will catch any errors raised when logging and output the error message and backtrace to STDERR. This prevents logging errors from crashing your application. You should disable this behavior in your test suite so that logging errors are raised and can be fixed.

```ruby
Lumberjack.raise_logging_errors = true
```

### Using As A Stream

Lumberjack loggers implement methods necessary for treating them like a stream. You can use this to augment output from components that write output to a stream with metadata like a timestamp and attributes.

```ruby
logger = Lumberjack::Logger.new($stderr, progname: "MyApp")
$stderr = logger

# These statements will now do the same thing
logger.unknown("Something went wrong")
$stderr.puts "Something went wrong"

# You can set the default level to set the level when using the I/O methods
logger.default_level = :warn
$stderr.puts "This is a warning message" # logged as a warning
```

### Integrations

#### Rails

> [!WARNING]
> If you are using Rails, you must use the [lumberjack_rails](https://github.com/bdurand/lumberjack_rails) gem.
>
> Rails does its own monkey patching to the standard library Logger to support tagged logging, silencing logs, and broadcast logging.

#### Other Integrations

- [lumberjack_sidekiq](https://github.com/bdurand/lumberjack_sidekiq) - Integrates Lumberjack with Sidekiq for background job logging.
- [lumberjack_datadog](https://github.com/bdurand/lumberjack_datadog) - Integrates Lumberjack with Datadog by outputting logs in JSON using Datadog's standard attributes.
- [lumberjack_local_logger](https://github.com/bdurand/lumberjack_local_logger) - Lightweight wrapper around Lumberjack::Logger that allows contextual logging with custom levels, prognames, and attributes without affecting the parent logger.
- Check [RubyGems](https://rubygems.org/gems) for other integrations

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
