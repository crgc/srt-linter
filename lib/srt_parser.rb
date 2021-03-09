require_relative 'srt_validator'
require_relative 'srt_parser_state'

class SRTParser
  include SRTValidator
  attr_reader :parser_state, :lines, :path, :offenses

  PARSER_STATE_MACHINE = {
    SRTParserState::NUMERIC_SEQUENCE => SRTParserState::TIMECODE,
    SRTParserState::TIMECODE => SRTParserState::TEXT,
    SRTParserState::TEXT => SRTParserState::SUBTITLE_END,
    SRTParserState::SUBTITLE_END => SRTParserState::NUMERIC_SEQUENCE
  }.freeze

  def initialize(path)
    @path = path
    @offenses = []
    @lines = []
    @lines_total = 0
  end

  def read_lines
    @lines = IO.readlines(@path)
    @lines_total = @lines.size
    @lines
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

  def offenses?
    @offenses.size.positive?
  end

  private

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

  def element_or_empty(element)
    element.nil? ? '' : element
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

  def empty_line?
    @current_line.strip.empty?
  end

  def check_subtitle_end
    return if check_empty_line
    return unless @current_line.to_i.positive?

    next_parser_state
    check_numeric_sequence
  end

  def next_parser_state
    @parser_state = PARSER_STATE_MACHINE[@parser_state]
  end

  def index_in_line(actual)
    @current_line.index(actual.to_s)
  end
end
