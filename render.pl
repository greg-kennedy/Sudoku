#!/usr/bin/env perl
use strict;
use warnings;
use v5.010;

use SudokuPuzzle;
use GD;

sub load {
  my $img = GD::Image->newFromPng($_[0],1) or die "Failed to load image '$_[0]': $!";
  return $img;
}

# Load the images
my @num;
my @clue;

for my $i (1 .. 9) {
  $num[$i] = load("./img/$i.png");
  $clue[$i] = load("./img/clue$i.png");
}
my $empty_board = load('./img/empty.png');

# Render a puzzle
sub render {
  my $puzzle = shift;

  # duplicate the empty board
  my $image = $empty_board->clone;

  for (my $row = 0; $row < 9; $row ++) {
    for (my $col = 0; $col < 9; $col ++) {
      my ($digit, $is_clue, $candidates) = $puzzle->get_cell($row, $col);
      next if (!defined $digit);

      # blit proper number to this location
      my $n = ($is_clue ? $clue[$digit] : $num[$digit]);
      my $alpha = ($is_clue ? 100 : 50);
      # calculate ranges
      my $dstX = ($col + .5) * ($image->width / 9) - ($n->width / 2);
      my $dstY = ($row + .5) * ($image->height / 9) - ($n->height / 2);
      # blit
      $image->copyMerge($n,$dstX,$dstY,0,0,$n->width,$n->height,$alpha);
    }
  }

  return $image->png;
}

## USAGE
die "Specify a puzzle string on command line" unless scalar @ARGV == 1;

# Create input puzzle from command line
my $puzzle = new SudokuPuzzle($ARGV[0]);

my $fname = $puzzle->get_string;
$fname =~ s/\./0/g;
$fname .= '.png';
open (FP, '>', $fname) or die "Couldn't open $fname for writing: $!";
binmode FP;
print FP render($puzzle);
close FP;
