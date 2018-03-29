## 1.0.13

* Reduce amount of code executed inside a mutex lock when writing to the logger stream.
* Added `:min_roll_check` option to `Lumberjack::Device::RollingLogFile` to reduce file system checks. Default is now to only check if a file needs to be rolled at most once per second.
* Force immutable strings for Ruby versions that support them.

## 1.0.12

* Add support for ActionDispatch request id for better Rails compatibility.

## 1.0.11

* Fix Ruby 2.4 deprecation warning on Fixnum (thanks koic).
* Fix gemspec files to be flat array (thanks e2).

## 1.0.10

* Expose option to manually roll log files.
* Minor code cleanup.

## 1.0.9

* Add method so Formatter is compatible with ActiveSupport logging extensions.

## 1.0.8

* Fix another internal variable name conflict with ActiveSupport logging extensions.

## 1.0.7

* Fix broken formatter attribute method.

## 1.0.6

* Fix internal variable name conflict with ActiveSupport logging extensions.

## 1.0.5

* Update docs.
* Remove autoload calls to make thread safe.
* Make compatible with Ruby 2.1.1 Pathname.
* Make compatible with standard library Logger's use of progname as default message.

## 1.0.4

* Add ability to supply a unit of work id for a block instead of having one generated every time.

## 1.0.3

* Change log file output format to binary to avoid encoding warnings.
* Fixed bug in log file rolling that left the file locked.

## 1.0.2

* Remove deprecation warnings under ruby 1.9.3.
* Add more error checking around file rolling.

## 1.0.1

* Writes are no longer buffered by default.
