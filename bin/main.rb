# lines = ['1', '00:00:05,000 --> 00:00:12,000', '[ Shouting ]']
# lines.each_index do  |line, i|
#   subtitle_timestamp = line.split(' ')
#   validate_subtitle_timestamp(subtitle_timestamp)
# end
#
# def validate_subtitle_timestamp(subtitle_timestamp)
#
# end

# TIMESTAMP_FORMAT = /(\d{1,2}:\d{1,2}:\d{1,2}\d{1,3}) (-->) (\d{1,2}:\d{1,2}:\d{1,2}\d{1,3})/

Line = Struct.new(:appear, :arrow, :disappear)
TIMESTAMP_FORMAT = /^(\d{2}\:\d{2}\:\d{2}\,\d{3}) (-->) (\d{2}\:\d{2}\:\d{2}\,\d{3})$/

def parse_line(line)
  line.match(TIMESTAMP_FORMAT) { |m| Line.new(*m.captures) }
end

# puts parse_line("00:00:12,473 --> 00:00:15,567")
puts parse_line("00:00:12,473 --> 00:00:15,567")
