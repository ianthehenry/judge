  $ source $TESTDIR/scaffold

exits 2 on compilation errors:

  $ use <<EOF
  > (use judge)
  > (print x)
  > (test (+ 1 2) 3)
  > EOF

  $ judge
  ! error: script.janet:2:1: compile error: unknown symbol x
  !   in dofile [boot.janet] (tailcall) on line 2899, column 7
  !   in source-loader [boot.janet] on line 2909, column 15
  !   in require-1 [boot.janet] (tailcall) on line 2929, column 18
  ! 
  ! 0 passed
  [2]

exits 2 on top-level errors:

  $ use <<EOF
  > (use judge)
  > (error "something bad")
  > (test (+ 1 2) 3)
  > EOF

  $ judge
  ! error: something bad
  !   in _thunk [script.janet] (tailcall) on line 2, column 1
  !   in dofile [boot.janet] (tailcall) on line 2898, column 7
  !   in source-loader [boot.janet] on line 2909, column 15
  !   in require-1 [boot.janet] (tailcall) on line 2929, column 18
  ! 
  ! 0 passed
  [2]

exits 1 on failing tests:

  $ use <<EOF
  > (use judge)
  > (test (+ 1 2) 4)
  > EOF

  $ judge
  ! <dim># script.janet</>
  ! 
  ! <red>(test (+ 1 2) 4)</>
  ! <grn>(test (+ 1 2) 3)</>
  ! 
  ! 0 passed 1 failed
  [1]

exits 1 if no tests found:

  $ use <<EOF
  > (use judge)
  > EOF

  $ judge
  ! 
  ! 0 passed
  [1]

exits 2 on top-level errors in imported files:

  $ use script.janet <<EOF
  > (use judge)
  > (use ./other)
  > (test (+ 1 2) 3)
  > EOF

  $ use other.janet <<EOF
  > (print "evaluating file")
  > (print x)
  > EOF

  $ judge script.janet other.janet
  evaluating file
  evaluating file
  ! error: other.janet:2:1: compile error: unknown symbol x
  !   in dofile [boot.janet] (tailcall) on line 2899, column 7
  !   in source-loader [boot.janet] on line 2909, column 15
  !   in require-1 [boot.janet] on line 2929, column 18
  !   in import* [boot.janet] (tailcall) on line 2960, column 15
  !   in dofile [boot.janet] (tailcall) on line 2898, column 7
  !   in source-loader [boot.janet] on line 2909, column 15
  !   in require-1 [boot.janet] (tailcall) on line 2929, column 18
  ! error: other.janet:2:1: compile error: unknown symbol x
  !   in dofile [boot.janet] (tailcall) on line 2899, column 7
  !   in source-loader [boot.janet] on line 2909, column 15
  !   in require-1 [boot.janet] (tailcall) on line 2929, column 18
  ! 
  ! 0 passed
  [2]

