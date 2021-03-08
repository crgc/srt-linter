require_relative 'srt_validator'
require_relative 'srt_parser_state'

class SRTParser
  PARSER_STATE_MACHINE = {
    SRTParserState::SUBTITLE_END => SRTParserState::NUMERIC_SEQUENCE,
    SRTParserState::NUMERIC_SEQUENCE => SRTParserState::TIMESTAMP,
    SRTParserState::TIMESTAMP => SRTParserState::TEXT,
    SRTParserState::TEXT => SRTParserState::SUBTITLE_END
  }.freeze

  TIMECODE_SEPARATOR = '-->'.freeze
  TIMECODE_FORMAT = /^(\d{2}\:\d{2}\:\d{2}\,\d{3}) (-->) (\d{2}\:\d{2}\:\d{2}\,\d{3})$/.freeze
  TimestampLine = Struct.new(:appear, :arrow, :disappear)

  def initialize(path)
    @path = path
    @offenses = []
    @lines = IO.readlines(path)
    @numeric_sequence = 1
    @parser_state = SRTParserState::NUMERIC_SEQUENCE
  end

  def run
    @lines.each_with_index do |line, i|
      @current_line = line
      @current_line_index = i

      check_current_line unless check_empty_line
    end
  end

  def check_current_line
    check_leading_whitespace
    check_trailing_whitespace

    case @parser_state
    when SRTParserState::NUMERIC_SEQUENCE
      check_numeric_sequence
    when SRTParserState::TIMESTAMP
      check_timecode
    end
  end

  def check_numeric_sequence
    counter = @current_line.to_i

    if @numeric_sequence == counter
      next_parser_state
    else
      add_numeric_sequence_error(counter)
    end
  end

  def check_timecode
    return unless parse_timestamp(@current_line).nil?

    timestamp_elements = @current_line.split(' ')
    timecode_appear = element_or_empty(timestamp_elements[0])
    timecode_separator = element_or_empty(timestamp_elements[1])
    timecode_disappear = element_or_empty(timestamp_elements[2])

    check_appear_timecode(timecode_appear)
    check_timecode_separator(timecode_separator)
    check_disappear_timecode(timecode_disappear)
  end

  def check_appear_timecode(timecode_appear)
    if timecode_appear.empty?
      add_missing_timecode_error('Appear')
    else
      add_timecode_error(timecode_appear) unless timecode?(timecode_appear)
    end
  end

  def check_timecode_separator(timecode_separator)
    add_timecode_separator_error unless timecode_separator == TIMECODE_SEPARATOR
  end

  def check_disappear_timecode(timecode_disappear)
    if timecode_disappear.empty?
      add_missing_timecode_error('Disappear')
    else
      add_timecode_error(timecode_disappear) unless timecode?(timecode_disappear)
    end
  end

  def element_or_empty(element)
    element.nil? ? ' ' : element
  end

  def parse_timestamp(line)
    line.match(TIMECODE_FORMAT) { |m| TimestampLine.new(*m.captures) }
  end

  def timecode?(str)
    str.match(/^(\d{2}\:\d{2}\:\d{2}\,\d{3})$/)
  end

  def check_leading_whitespace
    return unless @current_line[0] == ' '

    old_length = @current_line.size
    @current_line = @current_line.lstrip
    new_length = @current_line.size

    add_warning('Leading whitespace detected.', (old_length - new_length) - 1)
    true
  end

  def check_trailing_whitespace
    return unless @current_line[-1] == ' '

    @current_line = @current_line.rstrip
    new_length = @current_line.size

    add_warning('Trailing whitespace detected.', new_length)
    true
  end

  def check_empty_line
    return unless @current_line.strip.empty?

    add_warning('Extra blank line detected.')
    true
  end

  def add_numeric_sequence_error(actual)
    add_expected_actual_error('Numeric counter does not match sequence.', @numeric_sequence, actual)
  end

  def add_missing_timecode_error(type)
    add_error("Expected #{type} timecode.", index_in_line(actual))
  end

  def add_timecode_error(timecode)
    add_expected_actual_error('Timecode does not match format.', '00:00:00,000', timecode)
  end

  def add_timecode_separator_error
    add_error('Expected --> separator')
  end

  def add_expected_actual_error(msg, expected, actual)
    add_error(msg << " Expected: #{expected}, Actual: #{actual}", index_in_line(actual))
  end

  def add_error(msg, line_char_count = 0)
    add_offense(msg, 'Error', line_char_count)
  end

  def add_warning(msg, line_char_count = 0)
    add_offense(msg, 'Warning', line_char_count)
  end

  def add_offense(msg, severity, line_char_count = 0)
    @offenses << "#{@path}:#{line_number}:#{line_char_count}: #{severity}: #{msg}"
  end

  def line_number
    @current_line_index + 1
  end

  def next_parser_state
    @parser_state = PARSER_STATE_MACHINE[@parser_state]
  end

  def errors?
    @offenses.size.positive?
  end

  def print_errors_report
    puts @offenses
  end

  private

  def index_in_line(actual)
    @current_line.index(actual)
  end
end

parser = SRTParser.new(ARGV.first)
parser.run
parser.print_errors_report if parser.errors?
