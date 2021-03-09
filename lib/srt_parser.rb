require_relative 'srt_validator'
require_relative 'srt_parser_state'

class SRTParser
  attr_reader :parser_state
  attr_reader :lines
  attr_reader :path

  PARSER_STATE_MACHINE = {
    SRTParserState::NUMERIC_SEQUENCE => SRTParserState::TIMECODE,
    SRTParserState::TIMECODE => SRTParserState::TEXT,
    SRTParserState::TEXT => SRTParserState::SUBTITLE_END,
    SRTParserState::SUBTITLE_END => SRTParserState::NUMERIC_SEQUENCE
  }.freeze

  TIMECODE_SEPARATOR = '-->'.freeze
  TIMECODE_FORMAT = /^(\d{2}:\d{2}:\d{2},\d{3}) (-->) (\d{2}:\d{2}:\d{2},\d{3})$/.freeze
  TimestampLine = Struct.new(:appear, :arrow, :disappear)

  def initialize(path)
    @path = path
    @offenses = []
    @lines = []
    @lines_total = 0
  end

  def read_lines
    @lines = IO.readlines(@path)
    @lines_total = @lines.size
  end

  def run
    @numeric_sequence = 0
    @subtitle_line_counter = 0
    @parser_state = SRTParserState::NUMERIC_SEQUENCE

    @lines.each_with_index do |line, i|
      @current_line = line
      @current_line_index = i

      check_current_line
    end
  end

  def check_current_line
    check_leading_whitespace
    check_trailing_whitespace

    case @parser_state
    when SRTParserState::NUMERIC_SEQUENCE
      check_numeric_sequence
    when SRTParserState::TIMECODE
      check_timecode
    when SRTParserState::TEXT
      check_subtitle_text
    else
      check_subtitle_end
    end
  end

  def check_numeric_sequence
    @numeric_sequence += 1
    counter = @current_line.to_i

    add_numeric_sequence_error(counter) unless @numeric_sequence == counter
    next_parser_state
  end

  def check_timecode
    timestamp_elements = @current_line.split(' ')
    timecode_appear = element_or_empty(timestamp_elements[0])
    timecode_separator = element_or_empty(timestamp_elements[1])
    timecode_disappear = element_or_empty(timestamp_elements[2])

    check_appear_timecode(timecode_appear)
    check_timecode_separator(timecode_separator)
    check_disappear_timecode(timecode_disappear)

    next_parser_state
  end

  def check_subtitle_text
    empty_line = empty_line?
    @subtitle_line_counter += 1 unless empty_line

    if @previous_line.nil?
      add_blank_subtitle_line_error if empty_line
    end

    @previous_line = @current_line

    if empty_line
      @subtitle_line_counter = 0
      next_parser_state
    elsif @subtitle_line_counter > 2
      @subtitle_line_counter = 0
      add_expected_sub_end_warning
      next_parser_state
    end
  end

  def check_subtitle_end
    return if check_empty_line
    return unless @current_line.to_i.positive?

    next_parser_state
    check_numeric_sequence
  end

  def eof?
    @current_line_index == (@lines.size - 1)
  end

  def check_appear_timecode(timecode_appear)
    if timecode_appear.empty?
      add_missing_timecode_error('Appear')
    else
      add_timecode_error(timecode_appear) unless timecode?(timecode_appear)
    end
  end

  def check_timecode_separator(timecode_separator)
    add_timecode_separator_error(@current_line.size) unless timecode_separator == TIMECODE_SEPARATOR
  end

  def check_disappear_timecode(timecode_disappear)
    if timecode_disappear.empty?
      add_missing_timecode_error('Disappear', @current_line.size)
    else
      add_timecode_error(timecode_disappear) unless timecode?(timecode_disappear)
    end
  end

  def element_or_empty(element)
    element.nil? ? '' : element
  end

  def parse_timestamp(line)
    line.match(TIMECODE_FORMAT) { |m| TimestampLine.new(*m.captures) }
  end

  def timecode?(str)
    str.match(/^(\d{2}:\d{2}:\d{2},\d{3})$/)
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

  def check_last_empty_line
    add_expected_last_empty_line unless @lines.last.strip.empty?
  end

  def add_expected_last_empty_line
    add_warning('Expected an empty line containing no text, indicating the end of the file.')
  end

  def add_expected_sub_end_warning
    add_error('Expected an empty line containing no text, indicating the end of this subtitle.')
  end

  def add_blank_subtitle_line_error
    add_error('Empty subtitle line detected.')
  end

  def add_numeric_sequence_error(actual)
    add_expected_actual_error('Numeric counter does not match sequence.', @numeric_sequence, actual)
  end

  def add_missing_timecode_error(type, line_char_index = 0)
    add_error("Expected #{type} timecode.", line_char_index)
  end

  def add_timecode_error(timecode)
    add_expected_actual_error('Timecode does not match expected format.', '00:00:00,000', timecode)
  end

  def add_timecode_separator_error(line_char_index = 0)
    add_error('Expected --> separator', line_char_index)
  end

  def add_expected_actual_error(msg, expected, actual)
    add_error(msg << " Expected: #{expected}, Actual: #{actual}", index_in_line(actual))
  end

  def add_error(msg, line_char_index = 0)
    add_offense(msg, 'Error', line_char_index)
  end

  def add_warning(msg, line_char_index = 0)
    add_offense(msg, 'Warning', line_char_index)
  end

  def add_offense(msg, severity, line_char_index = 0)
    @offenses << "#{@path}:#{line_number}:#{line_char_index}: #{severity}: #{msg}"
  end

  def empty_line?
    @current_line.strip.empty?
  end

  def line_number
    @current_line_index + 1
  end

  def next_parser_state
    @parser_state = PARSER_STATE_MACHINE[@parser_state]
  end

  def offenses?
    @offenses.size.positive?
  end

  def print_offenses_report
    print_line('Offenses:')
    @offenses.each do |offense|
      print_line(offense)
    end

    print_line("\n#{@offenses.size} offenses detected.")
  end

  def print_no_offenses
    print_line("\n0 offenses detected.")
  end

  def index_in_line(actual)
    @current_line.index(actual.to_s)
  end

  def print_line(text)
    puts "\n" << text << "\n"
  end
end

parser = SRTParser.new(ARGV.first)
parser.read_lines

parser.print_line("Inspecting file: #{parser.path}\n..........")
parser.run
parser.check_last_empty_line

if parser.offenses?
  parser.print_offenses_report
else
  parser.print_no_offenses
end
