package SudokuPuzzle;
use strict;
use warnings;

use Carp;
use Scalar::Util qw(reftype);

=pod

=head1 NAME

SudokuPuzzle - A class encapsulating a Sudoku puzzle, with additional metadata.

=head1 SYNOPSIS

    use SudokuPuzzle;
    my $puzzle = new SudokuPuzzle($puzzle_string);
    $puzzle->pp;

=head1 DESCRIPTION

This module encapsulates Sudoku puzzles.  It will parse a string of 81
characters into a puzzle.  Internally, it maintains a list of puzzle state
(both "clue" and "written" digits), as well as tracking which numbers
can be entered into each cells ("candidates") without violating the One Rule.

It will also prevent illegal moves, though it is NOT a solver.  That is,
it is possible to put a "wrong" answer (and render the puzzle un-solvable),
as long as the answer does not violate the sequence rules.

=head2 Methods

=over 12

=item C<new>

Returns a new SudokuPuzzle object.

The (optional) single parameter to this object sets the initial puzzle.

It accepts any of the following:
* a string of characters, up to 81 bytes in length.  Allowable values are 1-9
  and space, period, or 0.  Shorter strings will be padded with up to 81 bytes.
* A 9x9 list (or list reference) populated with digits 1-9 or undef,
* A reference to either of the above items.

If puzzle creation succeeds, a blessed reference is returned.

=item C<clone>

Duplicates a SudokuPuzzle object (and returns the resulting new object).

=item C<is_solved>

Returns 1 if the puzzle is completely solved, 0 otherwise.

=item C<is_solvable>

Returns 0 if the puzzle has been rendered "unsolvable", 1 otherwise.

An unsolvable puzzle is one in which an unfilled cell has no available
digits remaining, because of conflict by row, column, or box.

=item C<get>

Returns a reference to a 2d, 9x9 array containing digits 1-9 or undef showing
the current puzzle state.

=item C<get_string>

Returns a flattened version of the array in string form.

=item C<get_cell>

This function accepts two parameters (row and column).  It returns the digit
currently in the cell (1-9 or undef).

For performance, you may want to just retrieve the whole puzzle with get().

=item C<get_candidates>

This function accepts two parameters (row and column). It returns a reference
to a list of "candidates" (digits that can still be placed here.)

Candidates is undef if there is already a digit placed here.

If Candidates is an empty list, is_solvable should return 0.

=item C<get_row>
=item C<get_column>
=item C<get_box>

This function accepts two parameters: row/column/box, and digit.

It returns a reference to a list of "places" (locations within the
row/column/box that can still hold the digit).

The return is undef if there is already a digit placed here.

If the return is an empty list, is_solvable should return 0.

=item C<set>

Given a reference to a 2d, 9x9 array containing digits 1-9 or undef,
set up the current puzzle state.

=item C<set_string>

Given a puzzle string, set up the current puzzle state.

=item C<set_cell>

Makes an update to the puzzle state.  This function takes several parameters.

The first parameter is a numeric value, 1-9, which is to be placed in a box.

The second parameter is the row, and the third is the column.

Returns 1 if the entry was accepted, or 0 if it was not a legal move.

=item C<pp>

Pretty-prints the puzzle.  This is mainly a debug function.

=back

=head1 LICENSE

This is released under the Artistic License. See L<perlartistic>.

=head1 AUTHOR

Greg Kennedy - L<https://greg-kennedy.com/>

=head1 SEE ALSO

L<https://en.wikipedia.org/wiki/Sudoku>

=cut

# Create new SudokuPuzzle object
sub new
{
  my $class = shift;

  # Create empty object
  my $self = {
    # the puzzle itself
    puzzle => [ map { [ (undef) x 9 ] } ( 1 .. 9 ) ],

    # for each cell, the remaining possible digits that could fill it
    candidates => [ map { [ map { [ 1 .. 9 ] } ( 1 .. 9 ) ] } ( 1 .. 9 ) ],

    # for each digit, the remaining possible cells that could house it
    row => [ map { [ map { [ 0 .. 8 ] } ( 0 .. 8 ) ] } ( 1 .. 9 ) ],
    col => [ map { [ map { [ 0 .. 8 ] } ( 0 .. 8 ) ] } ( 1 .. 9 ) ],
    box => [ map { [ map { [ 0 .. 8 ] } ( 0 .. 8 ) ] } ( 1 .. 9 ) ],

    remaining => 81,
    is_solvable => 1,
  };

  # Bless object
  bless $self, $class;

  # Apply any passed parameters
  if (scalar @_ == 1) {
    # passed in one more parameter - probably a puzzle string, ref. to puzzle string, or ref. to puzzle array
    my $type = reftype $_[0];
    if (! defined $type) {
      $self->set_string($_[0]);
    } elsif ($type eq 'SCALAR') {
      $self->set_string(${$_[0]});
    } elsif ($type eq 'ARRAY') {
      $self->set($_[0]);
    } else {
      confess "Can't create a SudokuObject given parameter $_[0]";
    }
  } elsif (scalar @_ > 1) {
    # Passed a raw array, send the array ref on
    $self->set(\@_);
  }

  return $self;
}

# Duplicates a puzzle and returns the copy
sub clone
{
  my $self = shift;

  # Make new empty object
  my $clone;

  # Copy details from original
  $clone->{remaining} = $self->{remaining};
  $clone->{is_solvable} = $self->{is_solvable};

  # copy all values
  for (my $i = 0; $i < 9; $i ++) {
    for (my $j = 0; $j < 9; $j ++) {
      $clone->{puzzle}[$i][$j] = $self->{puzzle}[$i][$j];

      if (defined $self->{candidates}[$i][$j]) { $clone->{candidates}[$i][$j] = [ @{$self->{candidates}[$i][$j]} ] }

      if (defined $self->{row}[$i][$j]) { $clone->{row}[$i][$j] = [ @{$self->{row}[$i][$j]} ] }
      if (defined $self->{col}[$i][$j]) { $clone->{col}[$i][$j] = [ @{$self->{col}[$i][$j]} ] }
      if (defined $self->{box}[$i][$j]) { $clone->{box}[$i][$j] = [ @{$self->{box}[$i][$j]} ] }
    }
  }

  # Return the clone
  return bless $clone, ref $self;
}

# Constant for fast conversion between box and the cells it contains

# lookup for row,col to box
my @_box;
# lookup for row,col to cell ID within box
my @_box_cell;
# box,id to row
my @_box_row;
# box,id to col
my @_box_col;

# all the computations for the above
#  the conversion is neatly symmetrical
foreach my $i (0 .. 8) {
  foreach my $j (0 .. 8) {
    $_box[$i][$j] = 3 * int($i / 3) + int($j / 3);
    $_box_cell[$i][$j] = 3 * ($i % 3) + $j % 3;

    $_box_row[$i][$j] = 3 * int($i / 3) + int($j / 3);
    $_box_col[$i][$j] = 3 * ($i % 3) + $j % 3;
  }
}

sub set_cell
{
  my ($self, $row, $col, $digit) = @_;

  # box ID within a box
  my $box = $_box[$row][$col];
  my $box_cell = $_box_cell[$row][$col];

  # Retrieve cell info
  if (defined $self->{puzzle}[$row][$col])
  {
    confess "Can't place $digit at $row, $col: is already marked " . ($self->{puzzle}[$row][$col]);
  }

  # Check if move is in available list
  if (scalar(grep { $_ eq $digit } @{$self->{candidates}[$row][$col]}) == 0)
  {
    confess "Can't place $digit at $row, $col: digit is not in candidates list";
  }

  # Place digit
  $self->{puzzle}[$row][$col] = $digit;

  $self->{remaining} --;

  # Candidate list cleanup
  #  Placing a number removes all other candidates from this spot.
  $self->{candidates}[$row][$col] = undef;

  for (my $d = 0; $d < 9; $d ++)
  {
    if ($d == $digit - 1)
    {
      # Handling for other placements of this digit
      for (my $i = 0; $i < 9; $i ++) {
# ROW
        if ($row == $i) {
          # This digit was placed on this row, so remove its "columns" list
          $self->{row}[$i][$d] = undef;

          # Also, remove this digit from all other candidates on the row
          for (my $j = 0; $j < 9; $j ++) {
            if (defined $self->{candidates}[$i][$j]) {
              my @new_candidates = grep { $_ != $digit } @{$self->{candidates}[$i][$j]};
              if (scalar @new_candidates == 0) { $self->{is_solvable} = 0 }
              $self->{candidates}[$i][$j] = \@new_candidates;
            }
          }
        } else {
          # On all other rows, the digit cannot be on this column.
          for (my $j = 0; $j < 9; $j ++) {
            if (defined $self->{row}[$j][$d]) {
              my @new_cells = grep { $_ != $col } @{$self->{row}[$j][$d]};
              #if (scalar @new_cells == 0) { $self->{is_solvable} = 0 }
              $self->{row}[$j][$d] = \@new_cells;
            }

            # Also, iterate through box/cell that matches and prune that item.
            my $box = $_box[$j][$col];
            if (defined $self->{box}[$box][$d]) {
              my $box_cell = $_box_cell[$j][$col];
              my @new_cells = grep { $_ != $box_cell } @{$self->{box}[$box][$d]};
              #if (scalar @new_cells == 0) { $self->{is_solvable} = 0 }
              $self->{box}[$box][$d] = \@new_cells;
            }
          }
        }

#COL
        if ($col == $i) {
          # This digit was placed on this col, so remove its "columns" list
          $self->{col}[$i][$d] = undef;

          # Also, remove this digit from all other candidates on the col
          for (my $j = 0; $j < 9; $j ++) {
            if (defined $self->{candidates}[$j][$i]) {
              my @new_candidates = grep { $_ != $digit } @{$self->{candidates}[$j][$i]};
              if (scalar @new_candidates == 0) { $self->{is_solvable} = 0 }
              $self->{candidates}[$j][$i] = \@new_candidates;
            }
          }
        } else {
          # On all other cols, the digit cannot be on this row.
          for (my $j = 0; $j < 9; $j ++) {
            if (defined $self->{col}[$j][$d]) {
              my @new_cells = grep { $_ != $row } @{$self->{col}[$j][$d]};
              #if (scalar @new_cells == 0) { $self->{is_solvable} = 0 }
              $self->{col}[$j][$d] = \@new_cells;
            }

            # Also, iterate through box/cell that matches and prune that item.
            my $box = $_box[$row][$j];
            if (defined $self->{box}[$box][$d]) {
              my $box_cell = $_box_cell[$row][$j];
              my @new_cells = grep { $_ != $box_cell } @{$self->{box}[$box][$d]};
              #if (scalar @new_cells == 0) { $self->{is_solvable} = 0 }
              $self->{box}[$box][$d] = \@new_cells;
            }
          }
        }

#BOX
        if ($box == $i) {
          # This digit was placed on this box, so remove its "boxes" list
          $self->{box}[$i][$d] = undef;

          # Also, remove this digit from all other candidates in the box
          for (my $j = 0; $j < 9; $j ++) {
            # convert box, box_cell to row, col
            my $box_row = $_box_row[$i][$j];
            my $box_col = $_box_col[$i][$j];
            if (defined $self->{candidates}[$box_row][$box_col]) {
              my @new_candidates = grep { $_ != $digit } @{$self->{candidates}[$box_row][$box_col]};
              if (scalar @new_candidates == 0) { $self->{is_solvable} = 0 }
              $self->{candidates}[$box_row][$box_col] = \@new_candidates;
            }
          }
        } else {
          # On all other rows and columns, remove the box-shaped hole.
          for (my $j = 0; $j < 9; $j ++) {
            my $box_row = $_box_row[$box][$j];
            next if ($box_row == $row);

            my $box_col = $_box_col[$box][$j];
            next if ($box_col == $col);

            if (defined $self->{row}[$box_row][$d]) {
              my @new_cells = grep { $_ != $box_col } @{$self->{row}[$box_row][$d]};
              #if (scalar @new_cells == 0) { $self->{is_solvable} = 0 }
              $self->{row}[$box_row][$d] = \@new_cells;
            }

            if (defined $self->{col}[$box_col][$d]) {
              my @new_cells = grep { $_ != $box_row } @{$self->{col}[$box_col][$d]};
              #if (scalar @new_cells == 0) { $self->{is_solvable} = 0 }
              $self->{col}[$box_col][$d] = \@new_cells;
            }
          }
        }
      }
    } else {
      # On this row, col, and box: no other number can take this spot.
      if (defined $self->{row}[$row][$d]) {
        my @new_cells = grep { $_ != $col } @{$self->{row}[$row][$d]};
        #if (scalar @new_cells == 0) { $self->{is_solvable} = 0 }
        $self->{row}[$row][$d] = \@new_cells;
      }

      if (defined $self->{col}[$col][$d]) {
        my @new_cells = grep { $_ != $row } @{$self->{col}[$col][$d]};
        #if (scalar @new_cells == 0) { $self->{is_solvable} = 0 }
        $self->{col}[$col][$d] = \@new_cells;
      }

      if (defined $self->{box}[$box][$d]) {
        my @new_cells = grep { $_ != $box_cell } @{$self->{box}[$box][$d]};
        #if (scalar @new_cells == 0) { $self->{is_solvable} = 0 }
        $self->{box}[$box][$d] = \@new_cells;
      }
    }
  }
}

sub set_string
{
  my $self = shift;
  my $puzzle_string = shift // confess "Cannot call set_string without a puzzle string.";

  my $pad_length = 81 - length($puzzle_string);
  confess "Puzzle string is over 81 characters" if $pad_length < 0;

  # pad
  $puzzle_string .= (' ' x $pad_length);

  # check format
  if ($puzzle_string !~ m/^[\d .]{81}$/) {
    confess "'$puzzle_string' seems to be in the wrong format.";
  }

  # seems OK
  my @puzzle;
  for (my $row = 0; $row < 9; $row ++)
  {
    my $row_string = substr($puzzle_string, $row * 9, 9);
    my @cols = map { $_ =~ /[1-9]/ ? $_ + 0 : undef } split //, $row_string;
    push @puzzle, \@cols;
  }

  $self->set(\@puzzle);
}

# helper: Construct an internal representation
sub set
{
  my $self = shift;
  my $puzzle_ref = shift // confess "Cannot call set without a puzzle array reference.";

  if (scalar @{$puzzle_ref} != 9) {
    confess "set(): array does not have 9 rows";
  }

  for (my $row = 0; $row < 9; $row ++)
  {
    if (scalar @{$puzzle_ref->[$row]} != 9) {
      confess "set(): row $row does not have 9 columns";
    }
    for (my $col = 0; $col < 9; $col ++)
    {
      my $digit = $puzzle_ref->[$row][$col];
      next unless defined $digit;
      #confess "set(): puzzle contains illegal moves" unless $self->set_cell($row, $col, $puzzle_ref->[$row][$col]);
      $self->set_cell($row, $col, $digit);
    }
  }
}

sub is_solvable
{
  return $_[0]->{is_solvable};
}

sub is_solved
{
  return ($_[0]->{remaining} == 0);
}

sub get_cell
{
  # Retrieve cell info
  return $_[0]->{puzzle}[$_[1]][$_[2]];
}

sub get_candidates
{
  # Retrieve candidate info for a cell
  return $_[0]->{candidates}[$_[1]][$_[2]];
}

sub get_row
{
  # Retrieve row info
  return $_[0]->{row}[$_[1]][$_[2] - 1];
}

sub get_col
{
  # Retrieve col info
  return $_[0]->{col}[$_[1]][$_[2] - 1];
}

sub get_box
{
  # Retrieve box info
  return $_[0]->{box}[$_[1]][$_[2] - 1];
}

sub get_string
{
  my $self = shift;

  my $string;
  for (my $row = 0; $row < 9; $row ++)
  {
    $string .= join ('', map { defined $_ ? $_ : '.' } @{$self->{puzzle}[$row]});
  }

  return $string;
}

sub get
{
  return $_[0]->{puzzle};
}

sub pp
{
  my $self = shift;

  for (my $i = 0; $i < 9; $i ++) {
    print ' ';
    print ('+-' x 9);
    print "+\n";

    print chr(ord('A') + $i);
    for (my $j = 0; $j < 9; $j ++) {
      my $digit = $self->{puzzle}[$i][$j];
      printf("|%s", (defined $digit ? $digit : ' '));
    }
    print "|\n";
  }

  print ' ';
  print ('+-' x 9);
  print "+\n";

  print "  1 2 3 4 5 6 7 8 9\n";
}

1;
