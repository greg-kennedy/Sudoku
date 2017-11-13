#!/usr/bin/env perl
use strict;
use warnings;
use v5.010;

use SudokuPuzzle;

die "Specify a puzzle string on command line" unless scalar @ARGV == 1;
my $puzzle = new SudokuPuzzle($ARGV[0]);

while ($puzzle->is_solvable && ! $puzzle->is_solved)
{
  $puzzle->print;

  # row
  print "Row? "; my $row = <STDIN>;
  if ($row !~ m/^[A-I]$/) {
    say "Invalid row.";
    redo;
  }
  $row = ord($row) - ord('A');

  # col
  print "Col? "; my $col = <STDIN>;
  if ($col !~ m/^[1-9]$/) {
    say "Invalid col.";
    redo;
  }
  $col = ord($col) - ord('1');

  # retrieve data for this cell
  my ($cur_value, $is_clue, $candidates) = $puzzle->get_cell($row, $col);
  if (defined $cur_value)
  {
    say "That cell is already filled with '$cur_value' by " . ($is_clue ? 'Clue' : 'Player');
    redo;
  }

  # digit
  print "Digit (" . join(',', @$candidates) . ")? "; my $digit = <STDIN>;
  if ($digit !~ m/^[1-9]$/) {
    say "Invalid digit.";
    redo;
  }
  $digit = ord($digit) - ord('0');
  if (scalar ( grep { $_ == $digit } @$candidates ) == 0 ) {
    say "Digit not in candidates list.";
    redo;
  }

  # Apply move
  $puzzle->set_cell($row, $col, $digit);
}

# The end.
if ($puzzle->is_solved)
{
  say "YOU WIN!";
} else {
  say "GAME OVER.";
}
