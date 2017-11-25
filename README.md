# Dial "S" for Sudoku
A NaNoGenMo 2017 entry by Greg Kennedy, 2017

## [Read the novel here.](./sample/novel.md)

## [View the code here.](./main.pl)

## About
This is a novel about Alice solving Sudoku puzzles.  Alice sits at the kitchen table, methodically working her way through a series of puzzles of increasing difficulty.  She takes frequent breaks to daydream and reminisce.  In between puzzles, there are excerpts from her dream diary - because 50,000 words of Sudoku solving is just plain monotonous.

The algorithm used to solve puzzles is a "backtracking" method, paired with two methods to find cell filling: "candidate checking" (fill a cell when it has only one available digit left), and "place finding" (checking each row, column, and box for cells that can only contain a particular digit).  When these approaches fail, it simply checkpoints and guesses.  I worked out the algorithm myself over the course of a couple days, but later searches turned up that it's the same approach described by e.g. [Peter Norvig](https://norvig.com/sudoku.html) or this helpful programming course from [Cornell University's Math department](https://www.math.cornell.edu/~mec/Summer2009/meerkamp/Site/Introduction.html) - and they describe it waaay better.

Humans would use additional heuristics to avoid all the backtracking and headaches while solving, but Alice is not so bright.  On the other hand, she cracked the [World's Hardest Sudoku](https://sw-amt.ws/sudoku/worlds-hardest-sudoku/xx-world-hardest-sudoku.html) in 12 seconds on a Pentium 4 1.3ghz, so maybe Alice deserves a bit more credit.

## Other
There are other items in this repository that either helped in development, or were useful for testing.

* SudokuPuzzle.pm - This is a class that contains a Sudoku Puzzle, along with to- and from- string methods.  It also maintains the rules of playing and won't accept a move that violates the One Rule.
* play.pl - Test program for SudokuPuzzle.pm, allowing a human to solve puzzles.
* solve.pl - The solving engine from main.pl, but without all the chatter.
* render.pl - Renders a Sudoku Puzzle to a .png image.  Clues are given in a solid computer typeface, while user moves are styled as a light pen/pencil mark.

## License
Released under Perl Artistic 2.0, see LICENSE for full details.
