require 'rspec'
require './lib/srt_parser.rb'

describe SRTParser do
  let(:good_srt) { SRTParser.new('./srt/good_subs.srt') }
  let(:bad_srt) { SRTParser.new('./srt/bad_subs.srt') }

  let(:bad_timecode_srt) { SRTParser.new('./srt/bad_subs__bad_timecode_format.srt') }
  let(:no_separator_srt) { SRTParser.new('./srt/bad_subs__no_separator.srt') }
  let(:bad_sequence_srt) { SRTParser.new('./srt/bad_subs__bad_sequence.srt') }
  let(:missing_eof_line_srt) { SRTParser.new('./srt/bad_subs__missing_eof_line.srt') }
  let(:empty_lines_srt) { SRTParser.new('./srt/bad_subs__extra_empty_line.srt') }

  describe '#read_lines' do
    it 'reads a file and stores its content in an array' do
      expect(good_srt.read_lines.size).to eql(8)
    end
  end

  describe '#offenses?' do
    context 'when the file is structured correctly' do
      it 'returns false' do
        good_srt.read_lines
        good_srt.run
        expect(good_srt.offenses?).to be(false)
      end
    end

    context 'when the file is not structured correctly' do
      it 'returns true' do
        bad_srt.read_lines
        bad_srt.run
        expect(bad_srt.offenses?).to be(true)
      end
    end
  end

  describe '#run' do
    context 'when the timecode format is wrong' do
      it 'adds an Error to the offenses array' do
        bad_timecode_srt.read_lines
        bad_timecode_srt.run
        expect(bad_timecode_srt.offenses.last).to include('Timecode does not match expected format')
      end
    end

    context 'when the timecode separator is absent' do
      it 'adds an Error to the offenses array' do
        no_separator_srt.read_lines
        no_separator_srt.run
        expect(no_separator_srt.offenses[0]).to include('Expected --> separator')
      end
    end

    context 'when the subtitle sequence is not sequential' do
      it 'adds an Error to the offenses array' do
        bad_sequence_srt.read_lines
        bad_sequence_srt.run
        expect(bad_sequence_srt.offenses.last).to include('Numeric counter does not match sequence')
      end
    end

    context 'when the end-of-file empty line is absent' do
      it 'adds a Warning to the offenses array' do
        missing_eof_line_srt.read_lines
        missing_eof_line_srt.run
        missing_eof_line_srt.check_last_empty_line
        expect(missing_eof_line_srt.offenses.last).to include('Expected an empty line containing no text')
      end
    end

    context 'when there are extra empty lines in between subtitles' do
      it 'adds a Warning to the offenses array' do
        empty_lines_srt.read_lines
        empty_lines_srt.run
        expect(empty_lines_srt.offenses.last).to include('Extra blank line detected')
      end
    end
  end
end
