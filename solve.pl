#!/usr/bin/env perl
use strict;
use warnings;
use v5.010;

use Time::HiRes qw(clock);

use SudokuPuzzle;

use constant DEBUG => 0;

### Helper
sub p {
  return sprintf('%c%c', ord('A') + $_[0], ord('1') + $_[1]);
}

### SOLUTION

# Lookup Table
#  Convert a (box, box_cell) to a [row, column].
my @box2cell;

for my $i (0 .. 8) {
  for my $j (0 .. 8) {
    $box2cell[$i][$j] = [ 3 * int($i / 3) + int($j / 3),
                          3 * ($i % 3) + $j % 3 ]
  }
}

# "Solves" the provided puzzle.  (This alters the original!)
# Returns the puzzle.  You should check is_solved to see the result:
#  it will be 1 on success, or 0 if the puzzle is unsolvable.
# If 0, the puzzle state is left where no more obvious moves
#  can be made.
# Does NOT check for "multiple solutions"
sub rec_solve
{
  my $puzzle = shift;

  # retrieve the reference to the puzzle-grid
  my $grid = $puzzle->get;

  SCAN: while (! $puzzle->is_solved && $puzzle->is_solvable)
  {
    #if (DEBUG) { $puzzle->pp }

    # Running "best" list of moves.
    my @best_move_list;

    # Candidate-checking first (looking for "naked singles")
    for (my $row = 0; $row < 9; $row ++) {
      for (my $col = 0; $col < 9; $col ++) {
        # Get cell details, and advance to next cell if this one is already filled.
        next if (defined $grid->[$row][$col]);

        # No digit here, so there should be candidates available.
        my $candidates = $puzzle->get_candidates($row, $col);

        # A singular candidate is a forced move and can be filled ASAP.
        if (scalar @$candidates == 1) {
          if (DEBUG) { say "CC: Forced: " . p($row, $col) . " MUST be a $candidates->[0]." }
          $puzzle->set_cell($row, $col, $candidates->[0]);
          next SCAN;
        }

        # If there are fewer candidates than what was in the best list, use this one instead.
        if (!@best_move_list || scalar @best_move_list > scalar @$candidates) {
          @best_move_list = map { [ $row, $col, $_ ] } @$candidates;
        }
      }
    }

    # Place-finding digit by digit (looking for "hidden singles")
    for (my $digit = 1; $digit < 10; $digit ++) {
      ROW: for (my $row = 0; $row < 9; $row ++) {
        # search for digit on the row
        my $cols = $puzzle->get_row($row, $digit);
        next ROW if (!defined $cols);

        # Placement search for this digit returned only one position.
        if (scalar @$cols == 1) {
          if (DEBUG) { say "PR: Forced: " . p($row, $cols->[0]) . " MUST be a $digit." }
          $puzzle->set_cell($row, $cols->[0], $digit);
          next SCAN;
        }

        if (!@best_move_list || scalar @best_move_list > scalar @$cols) {
          @best_move_list = map { [ $row, $_, $digit ] } @$cols;
        }
      }

      COL: for (my $col = 0; $col < 9; $col ++) {
        # search for digit on the column
        my $rows = $puzzle->get_col($col, $digit);
        next COL if (!defined $rows);

        # Placement search for this digit returned only one position.
        if (scalar @$rows == 1) {
          if (DEBUG) { say "PC: Forced: " . p($rows->[0], $col) . " MUST be a $digit." }
          $puzzle->set_cell($rows->[0], $col, $digit);
          next SCAN;
        }
        if (!@best_move_list || scalar @best_move_list > scalar @$rows) {
          @best_move_list = map { [ $_, $col, $digit ] } @$rows;
        }
      }

      BOX: for (my $box = 0; $box < 9; $box ++) {
        # search for digit within the box
        my $cells = $puzzle->get_box($box, $digit);
        next BOX if (!defined $cells);

        # Placement search for this digit returned only one position.
        if (scalar @$cells == 1) {
          if (DEBUG) { say "PB: Forced: " . p( @{$box2cell[$box][$cells->[0]]} ) . " MUST be a $digit." }
          $puzzle->set_cell( @{$box2cell[$box][$cells->[0]]}, $digit);
          next SCAN;
        }
        if (!@best_move_list || scalar @best_move_list > scalar @$cells) {
          @best_move_list = map { [ @{$box2cell[$box][$_]}, $digit ] } @$cells;
        }
      }
    }

    # Multiple options, snapshot here
    if (DEBUG) { say "PRE-FORK: Move list is: [" . join(',', map{ p($_->[0], $_->[1]) . "=" . $_->[2] } @best_move_list) . "]" }
    foreach my $move ( @best_move_list )
    {
      # Try each solution through recursive solver.
      if (DEBUG) { say "FORK: trying $move->[2] for " . p($move->[0], $move->[1]) . "." }

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

  # Regardless, we have no moves left.  Return result.
  return $puzzle;
}

## Convenience function to call rec_solve on a copy of the input puzzle.
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
$puzzle->pp;

# Attempt to solve puzzle.
my $start = clock;
my $result = solve($puzzle);
my $end = clock;

# Print result and exit.
if ($result->is_solved) {
  say "Solution:";
} else {
  say "Puzzle appears unsolvable.  Progress:";
}
$result->pp;

say "Elapsed time: " . ($end - $start) . " seconds.";
