# Lumberjack

[![Continuous Integration](https://github.com/bdurand/lumberjack/actions/workflows/continuous_integration.yml/badge.svg)](https://github.com/bdurand/lumberjack/actions/workflows/continuous_integration.yml)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)
[![Gem Version](https://badge.fury.io/rb/lumberjack.svg)](https://badge.fury.io/rb/lumberjack)


Lumberjack is an extension to the Ruby standard library `Logger` class, designed to provide advanced, flexible, and structured logging for Ruby applications. It builds on the familiar `Logger` API, adding powerful features for modern logging needs:

- **Attributes for Structured Logging:** Use attributes (formerly called tags) to attach structured, machine-readable metadata to log entries, enabling better filtering, searching, and analytics.
- **Context Isolation:** Isolate specific logging behavior to isolated blocks of code. The attributes, level, and progname for the logger can all be changed in a context block and only impact the log messages created within that block.
- **Formatters:** Control how objects are logged with customizable formatters for messages and attributes.
- **Devices and Templates:** Choose from a variety of output devices and templates to define the format and destination of your logs, including compatibility with standard library log devices and support for custom output formats.
- **Testing Tools:** Built-in testing devices and helpers make it easy to assert logging behavior in your test suite.

Lumberjack is ideal for applications that require structured, context-aware logging, and integrates seamlessly with Ruby’s standard logging ecosystem.

## Usage

### Structured Logging With Attributes

### Context Isolation

#### Context Blocks

#### Local Loggers

### Formatters

#### Object Formatters

#### Tag Formatters

#### Building An Entry Formatter

### Output Devices

#### Built-in Devices

#### Custom Devices

### Testing Utilities

### Using As A Stream

### Rails Integration

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
