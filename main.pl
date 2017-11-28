#!/usr/bin/env perl
use strict;
use warnings;
use v5.010;

use SudokuPuzzle;
use GD;

##############################################################################
# Open novel for output : )
open (FP, '>', 'out/novel.md') or die "Couldn't open 'out/novel.md' for writing: $!";

# Really, don't do this in actual code
$\ = "\n";

##############################################################################
### CONST
# Puzzles selected from the top2365, graded by forks and backtracks, and curated from the easier entries.
my @puzzles = ("000079065000003002005060093340050106000000000608020059950010600700600000820390000",
               "...28.94.1.4...7......156.....8..57.4.......8.68..9.....196......5...8.3.43.28...",
               "..3....5....1....9..6...3.........8.4....1....7.982..42........9...48.3..4.5....6",
               ".7..8.946......3....6.....5...4.6.........7195.3..7....9..23...2.5..46........1..",
               "..2.7.4...8.....3....1.9.........1.652...7......82...3....5..7...64....5..4...69.",
               "...6...5....3......2..947..6.9..23.8.1.....26.......4.3....6..9..89.3...4..27....",
               "86.....2495.2.......2.3.......8.6.7....9.7.624....3.........9..5......186...89.4.",
# ok, this last one is just to hit 50k
               "3..14.....7...354..6....9...1...6.......8.2.....9..4.8..........2...1..7..5.6..8.",
);

##############################################################################
### GLOBAL VARIABLES
my $forks = 0;
my $backtracks = 0;
# Backtrack position should be unique across all games
my $puzzle_position = 'A';

##############################################################################
### TEXT FUNCTIONS
# chooses a random sentence from an array
sub pick { return $_[int(rand(@_))]; }
# event occurs with probability 0 to 1
sub chance { return rand(1) < $_[0]; }

##############################################################################
### PUZZLE RENDER
#   Most of this is also in render.pl
my @img_num;
my @img_clue;
for my $i (1 .. 9) {
  $img_num[$i] = GD::Image->newFromPng("./img/$i.png",1) or die "Failed to load image: $!";
  $img_num[$i]->transparent($img_num[$i]->colorClosest(255,255,255));
  $img_clue[$i] = GD::Image->newFromPng("./img/clue$i.png",1) or die "Failed to load image: $!";
  $img_clue[$i]->transparent($img_clue[$i]->colorClosest(255,255,255));
}
my $img_board = GD::Image->newFromPng('./img/empty.png',1) or die "Failed to load image: $!";

# Render a puzzle, save to disk, return filename
sub render {
  my $puzzle = shift;

  # duplicate the empty board
  my $image = $img_board->clone;

  for (my $row = 0; $row < 9; $row ++) {
    for (my $col = 0; $col < 9; $col ++) {
      my ($digit, $is_clue, $candidates) = $puzzle->get_cell($row, $col);
      next if (!defined $digit);

      # blit proper number to this location
      my $n = ($is_clue ? $img_clue[$digit] : $img_num[$digit]);
      my $alpha = ($is_clue ? 100 : 50);
      # calculate ranges
      my $dstX = ($col + .5) * 72 - ($n->width / 2);
      my $dstY = ($row + .5) * 72 - ($n->height / 2);
      # blit
      $image->copyMerge($n,$dstX,$dstY,0,0,$n->width,$n->height,$alpha);
    }
  }

  my $fname = $puzzle->get_string;
  $fname =~ s/\./0/g;
  $fname = $fname . '.png';
  open (PNG, '>', 'out/' . $fname);
  binmode(PNG);
  print PNG $image->png(9);
  close PNG;

  return $fname;
}

##############################################################################
### TEMPLATES
# template for writing in a digit
sub add_num {
  my ($digit, $cell) = @_;

  my @syn = ('sketched ','pencilled ','wrote ','added ','placed ','put ','drew ','etched ','inserted ');
  return pick(
    "She " . pick('carefully ','lightly ','quickly ','') . pick(@syn) . pick('in ','') . "a $digit" . pick(" at $cell"," in $cell",'') . ". ",
    "So she " . pick(@syn) . pick('it ','one ') . 'there. ',
  );
}
# some fancy wording for a forced position
sub forced {
  my ($type, $row, $col, $digit) = @_;
  my $cell = p($row, $col);
  my $phrase = pick(
    "A " . pick('careful ','thorough ','quick ','') . pick('scan ','search ','check ','review ') . pick('through ','of ') . "$type " . pick('revealed ','showed ','uncovered ') . "that cell $cell " . pick('definitely ','absolutely ','surely ','') . pick('HAD to be ','must be ','was ') . "a $digit. ",
    ucfirst($type) . " " . pick('contained ','included ','had ') . "a cell $cell which, " . pick('Alice ','she ') . pick('realized','reasoned','figured','determined','discovered') . ", could only " . pick('hold ','contain ','be ') . "a $digit. ",
    "There was " . pick('clearly ','obviously ','really ','') . "only one " . pick('choice ','option ','home ','location ','spot ','square ','cell ') . "for a $digit on $type" . pick(": "," - ",", and that was ") . "cell $cell. ",
  );

  return $phrase . add_num($digit, $cell);
}

##############################################################################
### SOLUTION
#   This is a "noisy" version of solve() from solve.pl

sub p {
  return sprintf('%c%c', ord('A') + $_[0], ord('1') + $_[1]);
}
sub rec_solve {
  my $puzzle = shift;

  print FP "Alice " . pick('began ','resumed ','continued ','started ') . "looking for squares to fill on her puzzle. ";

  my $time_since_last_pause = 0;
  SCAN: while (! $puzzle->is_solved && $puzzle->is_solvable) {
    # Consider taking a break, Alice!
    if ($time_since_last_pause > (3 + rand(7)))
    {
      $time_since_last_pause = 0;

      # checkpoint
      print FP "Her puzzle now looked like this.\n";
      my $p_str = $puzzle->get_string;
      my $fname = render($puzzle);
      print FP "![$p_str]($fname \"$p_str\")\n";

      # do a couple things from the list
      my @opts = (
        "brushed the hair away from her eyes",
        "wiped off her glasses with a cloth",
        "sharpened her pencil to a point",
        "gazed out the window at the rising sun",
        "took a deep breath",
        "studied the puzzle intently",
        "took a sip of her coffee",
        "checked her phone for notices",
        "sighed softly",
      );

      my $opt1 = pick(@opts);
      my $opt2;
      do { $opt2 = pick(@opts) } while ($opt1 eq $opt2);
      print FP "Alice $opt1. She $opt2.\n";

      # think about some other stuff
      my @topics = ('Bob','Hannah','the party','her children','work','writing','computers','the news');
      my @more_opts = (
        "Her mind called up images of " . pick(@topics) . ".",
        "She thought idly of " . pick(@topics) . ".",
        "She couldn't help playing out some scenarios involving " . pick(@topics) . ".",
        "Something about " . pick(@topics) . " was making her uncomfortable.",
        "She was troubled about " . pick(@topics) . ".",
        "Thoughts of " . pick(@topics) . " nagged at the edge of her consciousness.",
        "Thinking about " . pick(@topics) . " usually soothed her, but...",
        "She had a recollection about " . pick(@topics) . ".",
        "Some of her visions were mixing with the numbers on her page.",
        "What was it they'd said?",
        pick("Drab","Dreary","Muted","Faded") . " colors filled her mind.",
        "People often told her not to focus on negative things, but it was difficult.",
      );

      # play a few sentences about daydreaming
      $opt1 = pick(@more_opts);
      do { $opt2 = pick(@more_opts) } while ($opt1 eq $opt2);
      my $opt3; do { $opt3 = pick(@more_opts) } while ($opt2 eq $opt3 || $opt1 eq $opt3);
      my $opt4; do { $opt4 = pick(@more_opts) } while ($opt3 eq $opt4 || $opt2 eq $opt4 || $opt1 eq $opt4);
      print FP "Alice " . pick('allowed her mind to wander. ','began to daydream. ','started to reminisce. ','let her thoughts drift. ');
      print FP "$opt1 $opt2 $opt3 $opt4\n";

      # Back to work!
      print FP pick("Alice " . pick("refocused ","returned ") . "her attention on her puzzle.");

      # Actually let's say a bit about the puzzle.
      if ($puzzle->{remaining} < 10) {
        print FP "She was getting quite close to a solution!";
      } elsif ($puzzle->{remaining} < 20) {
        print FP "She felt she was making good headway, but still had some work to do.";
      } elsif ($puzzle->{remaining} < 30) {
        print FP "Many of the cells remained unfilled.";
      } else {
        print FP "Most of the puzzle was still unsolved.";
      }
    }
    $time_since_last_pause ++;

    # flavor
    if (chance(0.25)) {
      print FP "\n" . pick(
        pick('Alice','She') . ' ' . pick('looked','scanned') . ' for the ' . pick('next','best') . ' move.',
        pick('Once again','Again') . ' ' . pick('Alice','she') . ' checked for a ' . pick('cell','move') . '.',
        pick('Alice','She') . ' ' . pick('reviewed','scanned','looked over','checked') . ' the puzzle ' . pick('carefully','again') . '.'
      );
    }

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
          my $digit = $candidates->[0];
          my $cell = p($row, $col);
          print FP pick(
            pick("Alice ","She ") . "found that cell $cell could only contain a $digit: all other digits were blocked somehow. ",
            "This left cell $cell with only one option: a $digit. ",
          );
          print FP add_num($digit,$cell);
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
          print FP forced("row " . chr(ord('A') + $row), $row, $cols[0], $digit);
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
          print FP forced("column " . chr(ord('1') + $col), $rows[0], $col, $digit);
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
          print FP forced("box " . chr(ord('1') + $box), $pos[0][0], $pos[0][1], $digit);
          $puzzle->set_cell($pos[0][0], $pos[0][1], $digit);
          next SCAN;
        }
        if (!@best_move_list || scalar @best_move_list > scalar @pos) {
          @best_move_list = map { [ $_->[0], $_->[1], $digit ] } @pos;
        }
      }
    }

    # Multiple options, snapshot here
    $forks ++;
    my $bt_position = $puzzle_position; $puzzle_position = chr(ord($puzzle_position) + 1);

    print FP "Alice sighed. There were no obvious moves left.\n";
    print FP "She jotted down a picture of the position on a notepad, and labeled it 'Position $bt_position'.\n";

    print FP "### Position $bt_position\n";
    my $p_str = $puzzle->get_string;
    my $fname = render($puzzle);
    print FP "![$p_str]($fname \"$p_str\")\n";

    print FP "Alice considered her next move. She compiled the shortest list of options. From here, she could ";
    for (my $i = 0; $i < scalar @best_move_list; $i ++ ) {
      my $m = $best_move_list[$i];
      my $str = '';
      if ($i == (scalar @best_move_list) - 1) { $str = "or " }
      $str .= "place a $m->[2] in " . p($m->[0], $m->[1]);
      if ($i == (scalar @best_move_list) - 1) { $str .= ". " } else { $str .= ', ' }
      print FP $str;
    }

    foreach my $move ( @best_move_list ) {
      # Try each solution through recursive solver.
      print FP "Alice decided to try putting a $move->[2] into cell " . p($move->[0], $move->[1]) . ".\n";

      my $test_puzzle = $puzzle->clone;
      $test_puzzle->set_cell(@$move);
      my $result = rec_solve($test_puzzle);

      # Well, it worked...
      if ($result->is_solved)
      {
        return $result;
      }

      # No diggity
      $backtracks ++;
      print FP "Alice sighed, then erased her work, until the board once again matched [position $bt_position](#position-" . lc($bt_position) . ").\n";
    }

    # failure on all counts
    $puzzle->{is_solvable} = 0;
  }

  if ($puzzle->is_solved)
  {
    print FP "Alice stopped. The puzzle was completely filled.\n";
  } else {
    print FP "Alice realized she had reached a dead end. There were no more squares she could fill, and no more moves to try.\n";
  }
  return $puzzle;
}

sub solve
{
  my $puzzle = shift;
  return rec_solve($puzzle->clone);
}


##############################################################################
### DREAM
sub load_simple {
  open (my $fh, '<', $_[0]) or die "Couldn't open file $_[0]: $!";
  chomp(my @lines = <$fh>);
  close $fh;
  return @lines;
}

my @objects = load_simple('res/objects.txt');
my @venues = load_simple('res/venues.txt');

#   Just some filler
sub dream_filler {
  for my $i (0 .. (3 + rand 4)) {
    print FP pick(
      "Things were " . pick('weird','strange','odd','out of place'),
      "She " . pick("could not", "could") . " " . pick('escape','run','see','hear','feel') . ' ' . pick('her way out','anything','the way forward','her companion','her situation','the environment'),
      "The " . pick("path", "way forward",'directions','route') . " was " . pick('clouded','unclear','dangerous','broken','confusing','confounding'),
      "There was a " . pick(@objects) . ' she ' . pick('found intriguing','disliked','feared','wanted'),
      "They were being " . pick('hunted','chased','pursued','attacked') . ' by a ' . pick('shadowy','fierce','wild','frightening') . ' ' . pick('figure','monster','serpent','ghost','spirit','animal'),
      "She needed to " . pick('find','hide','take','seek','attain','acquire') . ' a ' . pick('rare','unique','dark','golden','powerful') . ' ' . pick(@objects),
      pick('Intense','Strong','Powerful') . ' ' . pick('feelings','sensations','ideas','emotions') . ' of ' . pick('fear','worry','anxiety','dread','fright','danger') . ' ' . pick('overcame','gnawed at','overwhelmed','washed over') . ' her'
    ) . ".";
  }
}

#   This (sometimes recursive) function produces dreams.
sub dream {
  my $depth = shift || 1;

  my $person = pick('Bob','Hannah','the children','a coworker','a stranger','her mother','a politician','an actor','a celebrity','a cartoon character');
  my $place = pick(@venues);
  my $mode = pick('on horseback','by car','on a train','on foot');

  print FP "Alice and $person " . pick('approached','were going to','travelled to','wanted to go to') . " the $place $mode.";
  dream_filler;
  if (chance(0.9 ** $depth)) { dream($depth + 1) }
  dream_filler;
  print FP pick("Alice and $person continued on to the $place","They returned to their travel $mode") . ".";
  dream_filler;
  if (chance(0.9 ** $depth)) { dream($depth + 1) }
  dream_filler;
  print FP pick("But they never made it to the $place","They arrived at the $place") . ".\n";
}

##############################################################################
##############################################################################
### MAIN NOVEL GENERATION
##############################################################################
##############################################################################

# starting time is also the random seed (sometimes)
my $initial_timestamp = 1503920068;
#srand $initial_timestamp;

# track the passage of time
my $timestamp = $initial_timestamp;

### Book Preface / Boilerplate
print FP "# Dial \"S\" for Sudoku\n";
print FP "*In which our intrepid Heroine solves a few Puzzles, before Continuing with her Day.*\n";
print FP "A NaNoGenMo 2017 entry.\n";
print FP "Written by the open-source \"Sudoku\" software (https://github.com/greg-kennedy/Sudoku), by **Greg Kennedy** (<kennedy.greg\@gmail.com>).\n";
print FP "Generated on " . scalar(localtime()) . ".\n";

### Table of Contents
print FP "## Contents\n";
print FP "* [Introduction](#introduction)";
for my $p_num (1 .. scalar @puzzles)
{
  print FP "* [Puzzle #$p_num](#puzzle-$p_num)";
  if ($p_num < scalar @puzzles) { print FP "* [Nightmare #$p_num](#nightmare-$p_num)" }
}
print FP "* [Conclusion](#conclusion)\n";

### Introduction
print FP "## Introduction\n";
print FP "*" . scalar(localtime($timestamp)) . "*\n";
print FP "Bob had gone off to work, and the children were at school. Alice was alone in the house, with her cat and her thoughts.\n";
print FP "Alice sat down at the kitchen table. She placed a full coffee cup nearby, and her Sudoku puzzle book in the space before her.\n";
print FP "Alice was not a very good Sudoku player. She knew a few tricks, but they worked only for the easiest puzzles. Usually when Alice got stuck, she would copy the position, and take a guess. It was often frustrating. Alice was tenacious though; besides, the repetition helped take her mind off things.\n";
print FP "She took up a sharpened pencil, then opened the puzzle book to the next unsolved problem.\n";

# setting up takes some time
$timestamp += (30 + rand(30));

### Big loop for novel structure
for (my $i = 0; $i < scalar @puzzles; $i ++) {
  ### Solve problems
  print FP "## Puzzle #" . ($i+1);
  print FP "*" . scalar(localtime($timestamp)) . "*\n";
  my $puzzle = new SudokuPuzzle($puzzles[$i]);

  # Write image of initial puzzle to disk
  my $p_str = $puzzle->get_string;
  my $fname = render($puzzle);
  print FP "![$p_str]($fname \"$p_str\")\n";

  # reset difficulty settings
  $forks = 0;
  $backtracks = 0; 
  # go solve the puzzle 
  my $result = solve($puzzle);

  # A puzzle takes ~5 mins to solve.
  $timestamp += (450 + rand(300));
  # Forks are costly
  $timestamp += $forks * (10 + rand(20));
  # Backtracks very much so
  $timestamp += $backtracks * (45 + rand(60));

  print FP "### Solution\n";
  # print the result
  $p_str = $result->get_string;
  $fname = render($result);
  print FP "![$p_str]($fname \"$p_str\")\n";

  # Alice thinks about the puzzle she just solved.
  print FP "Alice " . pick('took a moment','paused','stopped') . ' to ' . pick('review','consider','think about','reflect on') . ' the ' . pick('puzzle','problem') . ' she had just ' . pick('completed','finished','solved') . '. ';
  if ($forks > 0) {
    # that was a hard problem
    print FP "This Sudoku layout was somewhat more complicated, and she felt it was " . pick('rather tough','tricky','pretty hard') . '. ';
    if ($backtracks > 1) {
      # that was a frustrating problem
      print FP "All that backtracking made it frustrating, too. Alice had made made a mess of her paper by erasing so many things. Still, she was pleased with the end result.";
    } else {
      # but she got lucky
      print FP "Her guesses were fortunate, though... she didn't have to erase very much to find the solution. ";
    }
    print FP "Maybe the next problem would be even more difficult!\n";
  } else {
    # that was an easy problem
    print FP "This Sudoku was very straightforward, and she felt it was " . pick('too simple','very easy','not difficult at all') . '. ';
    print FP "She hoped the next problem would provide more of a challenge. Easy puzzles could be boring sometimes.\n";
  }
  print FP "Alice checked the time again, wondering if there was time for another puzzle.\n";

  ## Have dreams
  if (($i+1) < scalar @puzzles) {
    print FP "## Nightmare #" . ($i+1);
    my $nightmare_time = $initial_timestamp - (86400 * int(rand(120))) - rand(28800) - 3600;
    print FP "*" . scalar(localtime($nightmare_time)) . "*\n";

    ## Gotta hit 50k words...
    dream (scalar(@puzzles) - $i - 1);
    print FP "Alice wondered what it all meant.\n";
  }
}

### Ending
print FP "## Conclusion";
print FP "*" . scalar(localtime($timestamp)) . "*\n";
print FP "Alice closed the puzzle book. Her coffee had grown cold, and she had a lot of things to accomplish today.\n";
print FP "She was pretty sure that Bob was having an affair.";

close FP;
