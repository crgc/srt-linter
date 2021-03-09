module SRTValidator
  TIMECODE_SEPARATOR = '-->'.freeze
  TIMECODE_FORMAT = /^(\d{2}:\d{2}:\d{2},\d{3})$/.freeze

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

  def timecode?(str)
    str.match(TIMECODE_FORMAT)
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

  private

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

  def line_number
    @current_line_index + 1
  end
end
