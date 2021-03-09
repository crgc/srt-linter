#!/usr/bin/env ruby
require_relative '../lib/srt_parser'

def print_offenses_report(parser)
  print_line('Offenses:')
  offenses = parser.offenses

  offenses.each do |offense|
    print_line(offense)
  end

  print_line("\n#{offenses.size} offenses detected.")
end

def print_no_offenses
  print_line("\n0 offenses detected.")
end

def print_line(text)
  puts "\n" << text << "\n"
end

def run_linter
  parser = SRTParser.new(ARGV.first)
  return print_line('No file detected.') if parser.path.nil? || !File.file?(parser.path)

  parser.read_lines

  print_line("Inspecting file: #{parser.path}\n..........")
  parser.run
  parser.check_last_empty_line

  if parser.offenses?
    print_offenses_report(parser)
  else
    print_no_offenses
  end
end

run_linter
