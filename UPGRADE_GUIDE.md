# Lumberjack Upgrade Guide

Version 2.0 is a major update to the framework with several changes to the public API.

## Constructor

`Lumberjack::Logger` now takes keyword arguments instead of an options hash in order to be compatible with the standard library `Logger` class. If you were previously using an options hash, you will need to double splat the hash to convert them to keyword arguments.

```ruby
logger = Lumberjack::Logger.new(stream, **options)
```

## Log Files

One of the original goals of Lumberjack was to properly handle rotating log files in a multi-process, production environment. The standard library `Logger` class in modern versions of Ruby now does this properly, so log rotation devices have been removed from Lumberjack.

The `:roll` and `:max_size` constructor options are no longer used. Log file rotation is specified with the same constructor arguments that standard library `Logger` class uses.

```ruby
# Rotate the logs daily
logger = Lumberjack::Logger.new(stream, :daily)

# Rotate the logs when they reach 10MB and keeping the last 4 files
logger = Lumberjack::Logger.new(stream, 4, 10 * 1024 * 1024)
```

These devices have been removed:

- `Lumberjack::Device::LogFile`
- `Lumberjack::Device::RollingLogFile`
- `Lumberjack::Device::SizeRollingLogFile`
- `Lumberjack::Device::DateRollingLogFile`

## Attributes

Tags have been renamed "attributes" to keep inline with terminology used in other logging frameworks.

The method name `tag` is still used as the main interface as verb (i.e. "to tag logs with attributes").

```ruby
logger.tag(attributes) do
  logger.info("Somthing happened")
end
```

Internal uses of the word "tag" have all been updated to use "attribute" instead. The "tag" versions of the methods will still work, but they have been marked as deprecated and will be removed in a future version.

Templates use the placeholder `:attributes` instead of `:tags`.

Global attributes are now set with the `tag!` method instead of `tag_globally` or calling `tag` outside of a context.

```ruby
logger.tag!(host: Lumberjack::Utils.hostname)
```

## Rails Integration

Rails has it's own extensions for logging. The support for these has been removed from the main `lumberjack` gem and moved to the `lumberjack_rails` gem. This change allows for much better support for integrating Lumberjack into the Rails ecosystem.

Using the `tagged` method in Rails will now add the tags to the `"tags"` attribute. Previously it had added it to the `"tagged"` attribute.
