# frozen_string_literals: true

module Lumberjack
  # A template converts entries to strings. Templates can contain the following place holders to
  # reference log entry values:
  #
  # * <tt>:time</tt>
  # * <tt>:severity</tt>
  # * <tt>:progname</tt>
  # * <tt>:tags</tt>
  # * <tt>:message</tt>
  #
  # Any other words prefixed with a colon will be substituted with the value of the tag with that name.
  class Template
    TEMPLATE_ARGUMENT_ORDER = %w(:time :severity :progname :pid :message :tags).freeze
    MILLISECOND_TIME_FORMAT = "%Y-%m-%dT%H:%M:%S.%3N"
    MICROSECOND_TIME_FORMAT = "%Y-%m-%dT%H:%M:%S.%6N"

    # Create a new template from the markup. The +first_line+ argument is used to format only the first
    # line of a message. Additional lines will be added to the message unformatted. If you wish to format
    # the additional lines, use the <tt>:additional_lines</tt> options to specify a template. Note that you'll need
    # to provide the line separator character in this template if you want to keep the message on multiple lines.
    #
    # The time will be formatted as YYYY-MM-DDTHH:MM:SSS.SSS by default. If you wish to change the format, you
    # can specify the <tt>:time_format</tt> option which can be either a time format template as documented in
    # +Time#strftime+ or the values +:milliseconds+ or +:microseconds+ to use the standard format with the
    # specified precision.
    #
    # Messages will have white space stripped from both ends.
    def initialize(first_line, options = {})
      @first_line_template, @first_line_tags = compile(first_line)
      additional_lines = options[:additional_lines] || "#{Lumberjack::LINE_SEPARATOR}:message"
      @additional_line_template, @additional_line_tags = compile(additional_lines)
      # Formatting the time is relatively expensive, so only do it if it will be used
      @template_include_time = first_line.include?(":time") || additional_lines.include?(":time")
      self.datetime_format = (options[:time_format] || :milliseconds)
    end

    def datetime_format=(format)
      if format == :milliseconds
        format = MILLISECOND_TIME_FORMAT
      elsif format == :microseconds
        format = MICROSECOND_TIME_FORMAT
      end
      @time_formatter = Formatter::DateTimeFormatter.new(format)
    end

    def datetime_format
      @time_formatter.format
    end

    # Convert an entry into a string using the template.
    def call(entry)
      return entry unless entry.is_a?(LogEntry)

      first_line = entry.message.to_s.strip
      additional_lines = nil
      if entry.message.include?(Lumberjack::LINE_SEPARATOR)
        additional_lines = entry.message.strip.split(Lumberjack::LINE_SEPARATOR)
        first_line = additional_lines.shift
      end

      formatted_time = @time_formatter.call(entry.time) if @template_include_time
      format_args = [formatted_time, entry.severity_label, entry.progname, entry.pid, first_line]
      tag_arguments = tag_args(entry.tags, @first_line_tags)
      message = @first_line_template % (format_args + tag_arguments)

      if additional_lines && !additional_lines.empty?
        tag_arguments = tag_args(entry.tags, @additional_line_tags) unless @additional_line_tags == @first_line_tags
        additional_lines.each do |line|
          format_args[format_args.size - 1] = line
          line_message = @additional_line_template % (format_args + tag_arguments)
          message << line_message
        end
      end
      message
    end

    private

    def tag_args(tags, tag_vars)
      return [nil] * (tag_vars.size + 1) if tags.nil? || tags.size == 0

      tags_string = String.new
      tags.each do |name, value|
        unless tag_vars.include?(name)
          tags_string << "[#{name}:#{value.inspect}] "
        end
      end

      args = [tags_string.chop]
      tag_vars.each do |name|
        args << tags[name]
      end
      args
    end

    # Compile the template string into a value that can be used with sprintf.
    def compile(template) #:nodoc:
      tag_vars = []
      template = template.gsub(/:[a-z0-9_]+/) do |match|
        position = TEMPLATE_ARGUMENT_ORDER.index(match)
        if position
          "%#{position + 1}$s"
        else
          tag_vars << match[1, match.length]
          "%#{TEMPLATE_ARGUMENT_ORDER.size + tag_vars.size}$s"
        end
      end
      [template, tag_vars]
    end
  end
end
