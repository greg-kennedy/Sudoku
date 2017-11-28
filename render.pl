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

for my $i (1 .. 9) {
  $num[$i] = load("./img/clue$i.png");
  $num[$i]->transparent($num[$i]->colorClosest(255,255,255));
}
my $empty_board = load('./img/empty.png');

# Render a puzzle
sub render {
  my $puzzle = shift;

  # duplicate the empty board
  my $image = $empty_board->clone;

  for (my $row = 0; $row < 9; $row ++) {
    for (my $col = 0; $col < 9; $col ++) {
      my $digit = $puzzle->[$row][$col];
      next if (!defined $digit);

      # blit proper number to this location
      my $n = $num[$digit];
      # calculate ranges
      my $dstX = ($col + .5) * 72 - ($n->width / 2);
      my $dstY = ($row + .5) * 72 - ($n->height / 2);
      # blit
      $image->copy($n,$dstX,$dstY,0,0,$n->width,$n->height);
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
print FP render($puzzle->get);
close FP;
