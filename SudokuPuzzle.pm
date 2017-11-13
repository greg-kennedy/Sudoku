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
    $puzzle->print;

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

=item C<assign_from>

Copies the provided SudokuPuzzle object's contents, overwriting this one.

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

This function accepts two parameters (row and column).

It returns a list with details of the cell, in the following format:

( CellValue, IsClue, [ Candidates ] )

where CellValue is the digit currently in the cell (1-9 or undef),
IsClue is 1 for "yes", 0 for "no" (user entered or empty),
and Candidates is a list of digits that can still be placed here.

Candidates is undef if CellValue is set.

If Candidates is an empty list, is_solvable should return 0.

=item C<set>

Given a reference to a 2d, 9x9 array containing digits 1-9 or undef,
set up the current puzzle state.  All values are entered as Clues.

=item C<set_string>

Given a puzzle string, set up the current puzzle state.  All values are
entered as Clues.

=item C<set_cell>

Makes an update to the puzzle state.  This function takes several parameters.

The first parameter is a numeric value, 1-9, which is to be placed in a box.

The second parameter is the row, and the third is the column.

An optional fourth parameter is the IsClue setting, which defaults to 0.

Returns 1 if the entry was accepted, or 0 if it was not a legal move.

=item C<print>

Pretty-prints the puzzle.  This is mainly a debug function.

=back

=head1 LICENSE

This is released under the Artistic License. See L<perlartistic>.

=head1 AUTHOR

Greg Kennedy - L<https://greg-kennedy.com/>

=head1 SEE ALSO

L<https://en.wikipedia.org/wiki/Sudoku>

=cut

# Constant: box designation
my @box = ( [0,0,0,1,1,1,2,2,2],
            [0,0,0,1,1,1,2,2,2],
            [0,0,0,1,1,1,2,2,2],
            [3,3,3,4,4,4,5,5,5],
            [3,3,3,4,4,4,5,5,5],
            [3,3,3,4,4,4,5,5,5],
            [6,6,6,7,7,7,8,8,8],
            [6,6,6,7,7,7,8,8,8],
            [6,6,6,7,7,7,8,8,8] );

# Create new SudokuPuzzle object
sub new
{
  my $class = shift;

  # Create empty object
  my $self = {
    puzzle => [ map { [ (undef) x 9 ] } ( 1 .. 9 ) ],
    clues => [ map { [ (0) x 9 ] } ( 1 .. 9 ) ],
    candidates => [ map { [ map { [ ( 1 .. 9 ) ] } ( 1 .. 9 ) ] } ( 1 .. 9 ) ],

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
  my $clone = (ref $self)->new;
  # Copy details from original
  $clone->assign_from($self);

  # Return the clone
  return $clone;
}

# Copy guts from other into self
sub assign_from
{
  my $self = shift;
  my $other = shift;

  $self->{remaining} = $other->{remaining};
  $self->{is_solvable} = $other->{is_solvable};

  # copy all values
  for (my $row = 0; $row < 9; $row ++) {
    for (my $col = 0; $col < 9; $col ++) {
      $self->{puzzle}[$row][$col] = $other->{puzzle}[$row][$col];
      $self->{clues}[$row][$col] = $other->{clues}[$row][$col];
      $self->{candidates}[$row][$col] = \@{$other->{candidates}[$row][$col]};
    }
  }
}

# Helper function: returns true if cell2 is a "peer" of cell1
#  Cells are not a peer of themselves
sub _is_peer
{
  my ($row, $col, $p_row, $p_col) = @_;

  return 0 if ($row == $p_row && $col == $p_col);

  return ($row == $p_row || $col == $p_col || $box[$row][$col] == $box[$p_row][$p_col]);
}

sub set_cell
{
  my $self = shift;

  my $row = shift;
  my $col = shift;
  my $digit = shift;

  my $is_clue = shift || 0;

  # Retrieve cell info
  my ($cur_digit, $cur_is_clue, $cur_list) = $self->get_cell($row, $col);

  if (defined $cur_digit)
  {
    confess "Can't place $digit at $row, $col: is already marked $cur_digit (" . ($cur_is_clue == 1 ? 'Is Clue' : 'Player entry') . ")";
  }

  # Check if move is in available list
  if (scalar(grep { $_ eq $digit } @$cur_list) == 0)
  {
    confess "Can't place $digit at $row, $col: digit is not in candidates list";
  }

  # Place digit, update clue status, delete candidates list
  $self->{puzzle}[$row][$col] = $digit;
  $self->{clues}[$row][$col] = $is_clue;
  $self->{candidates}[$row][$col] = undef;

  $self->{remaining} --;

  # Puzzle meta update: delete digit from candidates of all peers,
  #  also update is_solvable
  for (my $i = 0; $i < 9; $i ++) {
    for (my $j = 0; $j < 9; $j ++) {
      # non-peer cells are unaffected by adding a digit
      next if (! _is_peer($row, $col, $i, $j));

      # don't touch if value already filled
      next if (defined $self->{puzzle}[$i][$j]);

      # strip digit from candidates for target cell
      my @new_candidates = grep { $_ != $digit } @{$self->{candidates}[$i][$j]};

      # empty list means puzzle is not solvable any more
      if (scalar @new_candidates == 0) { $self->{is_solvable} = 0; }

      # update candidates list with shortened new list
      $self->{candidates}[$i][$j] = \@new_candidates;
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
      $self->set_cell($row, $col, $digit, 1);
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
  my $self = shift;

  my $row = shift;
  my $col = shift;

  # Retrieve cell info
  return ($self->{puzzle}[$row][$col], $self->{clues}[$row][$col], $self->{candidates}[$row][$col]);
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

sub print
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
