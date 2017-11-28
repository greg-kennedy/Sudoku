#!/usr/bin/env perl
use strict;
use warnings;
use v5.010;

use SudokuPuzzle;

my $debug = 0;

### Helper
sub p {
  return sprintf('%c%c', ord('A') + $_[0], ord('1') + $_[1]);
}

### SOLUTION
# "Solves" the provided puzzle.  (This alters the original!)
# Returns 1 on success, or 0 if the puzzle is unsolvable.
# If 0, the puzzle state is left where no more obvious moves
#  can be made.
# Does NOT check for "multiple solutions"
sub rec_solve
{
  my $puzzle = shift;

  SCAN: while (! $puzzle->is_solved && $puzzle->is_solvable)
  {
    if ($debug) { $puzzle->print; }

    # Running "best" list of moves.
    my @best_move_list;

    # Candidate-checking first
    for (my $row = 0; $row < 9; $row ++) {
      for (my $col = 0; $col < 9; $col ++) {
        # Get cell details, and advance to next cell if this one is already filled.
        my ($digit, $is_clue, $candidates) = $puzzle->get_cell($row, $col);
        next if (defined $digit);

        # A singular candidate is a forced move and can be filled ASAP.
        if (scalar @$candidates == 1) {
          if ($debug) { say "CC: Forced: " . p($row, $col) . " MUST be a $candidates->[0]." }
          $puzzle->set_cell($row, $col, $candidates->[0]);
          next SCAN;
        }

        # If there are fewer candidates than what was in the best list, use this one instead.
        if (!@best_move_list || scalar @best_move_list > scalar @$candidates) {
          @best_move_list = map { [ $row, $col, $_ ] } @$candidates;
        }
      }
    }

    # Place-finding digit by digit
    for (my $digit = 1; $digit < 10; $digit ++) {
      ROW: for (my $row = 0; $row < 9; $row ++) {
        my @cols;

        # search for digit on the row
        for (my $col = 0; $col < 9; $col ++) {
          my ($o_digit, $o_is_clue, $o_candidates) = $puzzle->get_cell($row, $col);

          # Digit already exists on this row
          next ROW if (defined $o_digit && $o_digit == $digit);

          # See if digit is in candidates list.
          if (scalar(grep { $_ == $digit } @$o_candidates)) {
            push @cols, $col;
          }
        }

        # Placement search for this digit returned only one position.
        if (scalar @cols == 1) {
          if ($debug) { say "PR: Forced: " . p($row, $cols[0]) . " MUST be a $digit." }
          $puzzle->set_cell($row, $cols[0], $digit);
          next SCAN;
        }
        if (!@best_move_list || scalar @best_move_list > scalar @cols) {
          @best_move_list = map { [ $row, $_, $digit ] } @cols;
        }
      }

      COL: for (my $col = 0; $col < 9; $col ++) {
        my @rows;

        # search for digit on the column
        for (my $row = 0; $row < 9; $row ++) {
          my ($o_digit, $o_is_clue, $o_candidates) = $puzzle->get_cell($row, $col);

          # Digit already exists on this column
          next COL if (defined $o_digit && $o_digit == $digit);

          # See if digit is in candidates list.
          if (scalar(grep { $_ == $digit } @$o_candidates)) {
            push @rows, $row;
          }
        }

        # Placement search for this digit returned only one position.
        if (scalar @rows == 1) {
          if ($debug) { say "PC: Forced: " . p($rows[0], $col) . " MUST be a $digit." }
          $puzzle->set_cell($rows[0], $col, $digit);
          next SCAN;
        }
        if (!@best_move_list || scalar @best_move_list > scalar @rows) {
          @best_move_list = map { [ $_, $col, $digit ] } @rows;
        }
      }

      BOX: for (my $box = 0; $box < 9; $box ++) {
        my @pos;

        # search for digit in the box
        for (my $row = 3 * int($box / 3); $row < 3 * (1 + int($box / 3)); $row ++) {
          for (my $col = 3 * ($box % 3); $col < 3 * (1 + ($box % 3)); $col ++) {
            my ($o_digit, $o_is_clue, $o_candidates) = $puzzle->get_cell($row, $col);

            # Digit already exists on this column
            next BOX if (defined $o_digit && $o_digit == $digit);

            # See if digit is in candidates list.
            if (scalar(grep { $_ == $digit } @$o_candidates)) {
              push @pos, [$row, $col];
            }
          }
        }
        if (scalar @pos == 1) {
          if ($debug) { say "PB: Forced: " . p($pos[0][0], $pos[0][1]) . " MUST be a $digit." }
          $puzzle->set_cell($pos[0][0], $pos[0][1], $digit);
          next SCAN;
        }
        if (!@best_move_list || scalar @best_move_list > scalar @pos) {
          @best_move_list = map { [ $_->[0], $_->[1], $digit ] } @pos;
        }
      }
    }

    # Multiple options, snapshot here
    if ($debug) { say "PRE-FORK: Move list is: [" . join(',', map{ p($_->[0], $_->[1]) . "=" . $_->[2] } @best_move_list) . "]" }
    foreach my $move ( @best_move_list )
    {
      # Try each solution through recursive solver.
      if ($debug) { say "FORK: trying $move->[2] for " . p($move->[0], $move->[1]) . "." }

      # Duplicate the position
      my $test_puzzle = $puzzle->clone;
      # Make the move
      $test_puzzle->set_cell(@$move);
      # Try a solve
      my $result = rec_solve($test_puzzle);

      # Well, it worked...
      if ($result->is_solved)
      {
        return $result;
      }
    }

    # failure on all counts
    $puzzle->{is_solvable} = 0;
  }

  # did not arrive at a solution
  return $puzzle;
}

sub solve
{
  my $puzzle = shift;
  return rec_solve($puzzle->clone);
}

## USAGE
die "Specify a puzzle string on command line" unless scalar @ARGV == 1;

# Create input puzzle from command line
my $puzzle = new SudokuPuzzle($ARGV[0]);

# Print parsed puzzle
say "Input:";
$puzzle->print;

# Attempt to solve puzzle.
my $result = solve($puzzle);

# Print result and exit.
if ($result->is_solved) {
  say "Solution:";
} else {
  say "Puzzle appears unsolvable.  Progress:";
}
$result->print;
