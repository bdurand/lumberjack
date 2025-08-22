# Lumberjack Logging Framework Architecture

This document provides a comprehensive overview of the Lumberjack logging framework architecture, illustrating how the various components work together to provide a flexible, high-performance logging solution for Ruby applications.

## Overview

Lumberjack is a structured logging framework that extends Ruby's standard Logger with advanced features including:

- **Structured logging** with attributes (key-value pairs)
- **Context isolation** for scoping logging behavior
- **Flexible output devices** supporting files, streams, and custom destinations  
- **Customizable formatters** for messages and attributes
- **Thread and fiber safety** for concurrent applications
- **Hierarchical logger forking** for component isolation

## Core Architecture

The framework follows a layered architecture with clear separation of concerns:

```mermaid
classDiagram
    %% Core Logger Classes
    class Logger {
        +Device device
        +Context context
        +EntryFormatter formatter
        +initialize(device, options)
        +info(message, attributes)
        +debug(message, attributes)
        +error(message, attributes)
        +add_entry(severity, message, progname, attributes)
        +tag(attributes, &block)
        +context(&block)
        +fork(options) ForkedLogger
    }

    class ContextLogger {
        <<interface>>
        +level() Integer
        +level=(value) void
        +progname() String
        +progname=(value) void
        +add_entry(severity, message, progname, attributes)
        +tag(attributes, &block)
        +context(&block)
        +attributes() Hash
    }

    class ForkedLogger {
        +Logger parent_logger
        +Context context
        +initialize(parent_logger)
        +add_entry(severity, message, progname, attributes)
    }

    %% Context and Attribute Management
    class Context {
        +Hash attributes
        +Integer level
        +String progname
        +Integer default_severity
        +initialize(parent_context)
        +assign_attributes(attributes)
        +clear_attributes()
    }

    class AttributesHelper {
        +Hash attributes
        +initialize(attributes)
        +update(attributes)
        +delete(*names)
        +[](key) Object
        +[]=(key, value)
    }

    %% Entry and Formatting
    class LogEntry {
        +Time time
        +Integer severity
        +String message
        +String progname
        +Integer pid
        +Hash attributes
        +initialize(time, severity, message, progname, pid, attributes)
        +severity_label() String
        +to_s() String
    }

    class EntryFormatter {
        +Formatter message_formatter
        +AttributeFormatter attribute_formatter
        +format(message, attributes) Array
        +call(entry) String
    }

    class Formatter {
        +Hash class_formatters
        +add(klass, formatter, *args, &block)
        +remove(klass)
        +format(message) Object
    }

    class AttributeFormatter {
        +Hash attribute_formatters
        +Formatter class_formatter
        +Formatter default_formatter
        +add(names_or_classes, formatter, &block)
        +add_class(classes, formatter, &block)
        +add_attribute(names, formatter, &block)
        +format(attributes) Hash
    }

    %% Device Architecture
    class Device {
        <<abstract>>
        +write(entry) void
        +flush() void
        +close() void
        +reopen(logdev) void
    }

    class WriterDevice {
        +IO stream
        +Template template
        +initialize(stream, options)
        +write(entry) void
        +flush() void
        +close() void
    }

    class LoggerFileDevice {
        +String path
        +initialize(path, options)
        +path() String
    }

    class MultiDevice {
        +Array devices
        +initialize(*devices)
        +write(entry) void
        +flush() void
        +close() void
    }

    class TestDevice {
        +Array entries
        +Integer max_entries
        +write(entry) void
        +include?(options) Boolean
        +match(**options) LogEntry
    }

    class NullDevice {
        +write(entry) void
    }

    class LoggerDevice {
        +Logger logger
        +initialize(logger)
        +write(entry) void
    }

    %% Template System
    class Template {
        +String template
        +String time_format
        +String attribute_format
        +initialize(template, options)
        +call(entry) String
    }

    %% Utility Classes
    class Utils {
        +deprecated(method, message, &block) Object
        +hostname() String
        +current_line() String
        +flatten_attributes(hash) Hash
        +expand_attributes(hash) Hash
    }

    class Severity {
        +level_to_label(level) String
        +label_to_level(label) Integer
        +coerce(value) Integer
    }

    %% Relationships
    Logger --|> ContextLogger : implements
    ForkedLogger --|> Logger : inherits
    Logger --* Device : uses
    Logger --* Context : has
    Logger --* EntryFormatter : uses
    ForkedLogger --* Logger : forwards to
    
    Context --* AttributesHelper : uses
    EntryFormatter --* Formatter : uses
    EntryFormatter --* AttributeFormatter : uses
    AttributeFormatter --* Formatter : uses
    
    Device <|-- WriterDevice : implements
    Device <|-- LoggerFileDevice : implements  
    Device <|-- MultiDevice : implements
    Device <|-- TestDevice : implements
    Device <|-- NullDevice : implements
    Device <|-- LoggerDevice : implements
    WriterDevice <|-- LoggerFileDevice : inherits
    
    WriterDevice --* Template : uses
    Logger --> LogEntry : creates
    EntryFormatter --> LogEntry : processes
    Device --> LogEntry : receives
    
    MultiDevice --* Device : aggregates
    LoggerDevice --* Logger : forwards to
    TestDevice --* LogEntry : stores
```

## Component Responsibilities

### Core Logger Components

**Logger**
- Main entry point for logging operations
- Manages device, context, and formatting coordination
- Provides standard logging methods (info, debug, error, etc.)
- Handles context creation and attribute management

**ContextLogger**
- Mixin providing context-aware logging capabilities
- Manages level, progname, and attribute scoping
- Supports hierarchical contexts and attribute inheritance
- Thread and fiber-safe context isolation

**ForkedLogger**
- Creates isolated logger instances that forward to parent loggers
- Enables component-specific logging configuration
- Maintains independent context while sharing output infrastructure

### Context and Attribute Management

**Context**
- Stores scoped logging configuration (level, progname, attributes)
- Supports hierarchical inheritance from parent contexts
- Provides isolation for block-scoped logging behavior

**AttributesHelper**
- Manages attribute hash manipulation and access
- Supports dot notation for nested attribute access
- Handles attribute merging and deletion operations

### Entry Processing Pipeline

**LogEntry**
- Immutable data structure representing a single log event
- Contains all metadata: timestamp, severity, message, attributes
- Provides formatted string representation for output

**EntryFormatter**
- Coordinates message and attribute formatting
- Delegates to specialized formatters for different data types
- Handles complex formatting scenarios with embedded attributes

**Formatter & AttributeFormatter**
- Class-based and name-based formatting rules
- Recursive formatting for nested data structures
- Extensible formatting system with built-in formatters

### Device Architecture

**Device (Abstract Base)**
- Defines interface for log output destinations
- Supports lifecycle methods (flush, close, reopen)
- Enables pluggable output architecture

**WriterDevice**
- Writes formatted entries to IO streams
- Supports templated output formatting
- Handles encoding and error recovery

**MultiDevice**
- Broadcasts entries to multiple target devices
- Enables redundant logging and output splitting
- Maintains consistent state across all targets

**Specialized Devices**
- **LoggerFileDevice**: File-based logging with rotation
- **TestDevice**: In-memory capture for testing
- **NullDevice**: Silent operation for performance testing
- **LoggerDevice**: Forwards to other Logger instances

## Logging Flow Sequence

The following sequence diagram illustrates the complete flow of a log entry through the Lumberjack framework:

```mermaid
sequenceDiagram
    participant App as Application
    participant Logger as Logger
    participant Context as Context
    participant EntryFormatter as EntryFormatter
    participant MsgFormatter as Message Formatter
    participant AttrFormatter as Attribute Formatter
    participant Device as Device
    participant Template as Template
    participant Output as Output Stream

    %% Context Setup
    App->>Logger: context do |ctx|
    Logger->>Context: new(parent_context)
    Context-->>Logger: context instance
    App->>Logger: tag(user_id: 123)
    Logger->>Context: assign_attributes({user_id: 123})

    %% Logging Call
    App->>Logger: info("User login", ip: "192.168.1.1")
    Logger->>Logger: check level >= INFO
    
    %% Entry Creation
    Logger->>Logger: merge_all_attributes()
    Note over Logger: Combines global, context, and local attributes
    Logger->>LogEntry: new(time, severity, message, progname, pid, attributes)
    LogEntry-->>Logger: entry instance

    %% Entry Formatting
    Logger->>EntryFormatter: format(message, attributes)
    EntryFormatter->>MsgFormatter: format("User login")
    MsgFormatter-->>EntryFormatter: formatted message
    EntryFormatter->>AttrFormatter: format({user_id: 123, ip: "192.168.1.1"})
    AttrFormatter-->>EntryFormatter: formatted attributes
    EntryFormatter-->>Logger: [formatted_message, formatted_attributes]

    %% Device Writing
    Logger->>Device: write(entry)
    
    alt WriterDevice
        Device->>Template: call(entry)
        Template-->>Device: formatted string
        Device->>Output: write(formatted_string)
        Output-->>Device: success
    else MultiDevice
        Device->>Device: devices.each
        loop Each Target Device
            Device->>Device: target.write(entry)
        end
    else TestDevice
        Device->>Device: entries << entry
    end
    
    Device-->>Logger: success
    Logger-->>App: true

    %% Context Cleanup
    Note over Logger,Context: Context automatically cleaned up when block exits
```

## Key Design Patterns

### 1. **Layered Architecture**
- Clear separation between logging interface, processing, and output
- Each layer has well-defined responsibilities and interfaces
- Enables independent testing and component replacement

### 2. **Strategy Pattern**
- Devices implement pluggable output strategies
- Formatters provide pluggable formatting strategies  
- Templates enable customizable output formatting

### 3. **Composite Pattern**
- MultiDevice composes multiple output devices
- AttributeFormatter composes class and attribute formatters
- Context inherits from parent contexts

### 4. **Chain of Responsibility**
- Formatting pipeline processes entries through multiple stages
- Context resolution follows inheritance chain
- Attribute merging follows precedence rules

### 5. **Facade Pattern**
- Logger provides simplified interface to complex subsystem
- ContextLogger abstracts context management complexity
- Utils module provides common functionality access

## Performance Characteristics

### **Memory Management**
- Immutable LogEntry objects prevent accidental modification
- Context inheritance minimizes memory duplication
- Attribute compaction removes empty values automatically

### **Thread Safety**
- Fiber-local storage for context isolation
- Mutex-protected device operations where needed
- Immutable data structures prevent race conditions

### **Lazy Evaluation**
- Block-based message generation for expensive operations
- Conditional formatting based on log levels
- On-demand context resolution

### **Efficient Routing**
- Level checking before entry creation
- Direct device writing without intermediate buffers
- Optimized formatter selection for common types

## Extension Points

The framework provides several extension points for customization:

### **Custom Devices**
```ruby
class DatabaseDevice < Lumberjack::Device
  def write(entry)
    database.insert_log(
      timestamp: entry.time,
      level: entry.severity_label,
      message: entry.message,
      attributes: entry.attributes
    )
  end
end
```

### **Custom Formatters**
```ruby
class JsonFormatter
  def call(obj)
    JSON.generate(obj)
  end
end

logger.formatter.add(Hash, JsonFormatter.new)
```

### **Custom Templates**
```ruby
json_template = ->(entry) do
  JSON.generate(
    timestamp: entry.time.iso8601,
    level: entry.severity_label,
    message: entry.message,
    attributes: entry.attributes
  )
end

device = Lumberjack::Device::Writer.new(STDOUT, template: json_template)
```

## Integration Patterns

### **Web Application Integration**
```ruby
# Rack middleware for request context
use Lumberjack::Rack::Context, {
  request_id: ->(env) { env["HTTP_X_REQUEST_ID"] },
  user_id: ->(env) { env["warden"]&.user&.id }
}
```

### **Component Isolation**
```ruby
# Component-specific loggers
class UserService
  def initialize(logger)
    @logger = logger.fork(progname: "UserService")
    @logger.tag!(component: "user_service", version: "1.2.3")
  end
end
```

### **Testing Integration**
```ruby
# Test environment setup
logger = Lumberjack::Logger.new(:test)
logger.info("Test message", user_id: 123)
expect(logger.device).to include(
  severity: :info,
  message: "Test message",
  attributes: {user_id: 123}
)
```

## Configuration Best Practices

### **Production Configuration**
```ruby
logger = Lumberjack::Logger.new("/var/log/app.log") do |config|
  config.level = :info
  config.shift_age = 10    # Keep 10 old files
  config.shift_size = 50.megabytes
  
  # Structured attribute formatting
  config.attribute_formatter.add("password") { |value| "[REDACTED]" }
  config.attribute_formatter.add(Time, :iso8601)
end
```

### **Development Configuration**
```ruby
logger = Lumberjack::Logger.new(STDOUT) do |config|
  config.level = :debug
  config.template = "[:time :severity] :message :attributes"
  
  # Pretty-print complex objects
  config.formatter.add(Hash, :pretty_print)
  config.formatter.add(Array, :pretty_print)
end
```

### **Multi-Environment Setup**
```ruby
file_device = Lumberjack::Device::LoggerFile.new("/var/log/app.log")
console_device = Lumberjack::Device::Writer.new(STDOUT)
error_device = Lumberjack::Device::Writer.new(STDERR)

multi_device = Lumberjack::Device::Multi.new(
  file_device,
  Rails.env.development? ? console_device : nil
).compact

logger = Lumberjack::Logger.new(multi_device)
```

This architecture enables Lumberjack to provide a powerful, flexible logging solution that scales from simple applications to complex, multi-component systems while maintaining excellent performance and developer experience.
