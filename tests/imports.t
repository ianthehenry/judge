  $ source $TESTDIR/scaffold

Judge populates the module cache correctly regardless of import type:

  $ use one.janet <<EOF
  > (print "one")
  > EOF
  $ use two.janet <<EOF
  > (print "two")
  > EOF

  $ use three.janet <<EOF
  > (print "three")
  > (import ./one)
  > EOF

  $ use four.janet <<EOF
  > (print "four")
  > (import /two)
  > EOF

  $ judge one.janet
  one
  ! 
  ! 0 passed
  [1]

  $ judge two.janet
  two
  ! 
  ! 0 passed
  [1]

  $ judge three.janet
  three
  one
  ! 
  ! 0 passed
  [1]

  $ judge four.janet
  four
  two
  ! 
  ! 0 passed
  [1]

  $ judge one.janet three.janet
  one
  three
  ! 
  ! 0 passed
  [1]

  $ judge two.janet four.janet
  two
  four
  ! 
  ! 0 passed
  [1]

Exploring relative path imports:

  $ mkdir something
  $ cd something
  $ use two.janet <<EOF
  > (print "subdirectory two")
  > EOF
  $ judge ../four.janet
  four
  subdirectory two
  ! 
  ! 0 passed
  [1]

  $ judge two.janet ../four.janet
  subdirectory two
  four
  ! 
  ! 0 passed
  [1]

This is a bug that happens because we import something/two.janet
in two different ways: once as ../something/two.janet and once as
just two.janet. These are the same file, but different paths, so
they get separate entries in the module cache. I don't think that
this is really worth guarding against.

  $ judge two.janet ../something/two.janet
  subdirectory two
  subdirectory two
  ! 
  ! 0 passed
  [1]

You can still import by absolute path if you want, but it will
get yet another module cache entry:

  $ judge two.janet ../something/two.janet $PWD/two.janet
  subdirectory two
  subdirectory two
  subdirectory two
  ! 
  ! 0 passed
  [1]

Judge will not run tests for the same file more than once even if a top-level error occurs:

  $ rm *

  $ use one.janet <<EOF
  > (use judge)
  > (use ./two)
  > (test (+ 1 1))
  > EOF

  $ use two.janet <<EOF
  > (use judge)
  > (test (+ 2 2))
  > (error "oh no")
  > EOF

  $ judge one.janet two.janet
  ! <dim># two.janet</>
  ! 
  ! <red>(test (+ 2 2))</>
  ! <grn>(test (+ 2 2) 4)</>
  ! error: oh no
  !   in _thunk [two.janet] (tailcall) on line 3, column 1
  !   in dofile [boot.janet] (tailcall) on line LINE, column COL
  !   in source-loader [boot.janet] on line LINE, column COL
  !   in require-1 [boot.janet] on line LINE, column COL
  !   in import* [boot.janet] (tailcall) on line LINE, column COL
  !   in dofile [boot.janet] (tailcall) on line LINE, column COL
  !   in source-loader [boot.janet] on line LINE, column COL
  !   in require-1 [boot.janet] (tailcall) on line LINE, column COL
  ! 
  ! 0 passed 1 failed
  [2]

  $ judge two.janet one.janet
  ! <dim># two.janet</>
  ! 
  ! <red>(test (+ 2 2))</>
  ! <grn>(test (+ 2 2) 4)</>
  ! error: oh no
  !   in _thunk [two.janet] (tailcall) on line 3, column 1
  !   in dofile [boot.janet] (tailcall) on line LINE, column COL
  !   in source-loader [boot.janet] on line LINE, column COL
  !   in require-1 [boot.janet] (tailcall) on line LINE, column COL
  ! error: oh no
  !   in _thunk [two.janet] (tailcall) on line 3, column 1
  !   in dofile [boot.janet] (tailcall) on line LINE, column COL
  !   in source-loader [boot.janet] on line LINE, column COL
  !   in require-1 [boot.janet] on line LINE, column COL
  !   in import* [boot.janet] (tailcall) on line LINE, column COL
  !   in dofile [boot.janet] (tailcall) on line LINE, column COL
  !   in source-loader [boot.janet] on line LINE, column COL
  !   in require-1 [boot.janet] (tailcall) on line LINE, column COL
  ! 
  ! 0 passed 1 failed
  [2]

  $ judge
  ! <dim># two.janet</>
  ! 
  ! <red>(test (+ 2 2))</>
  ! <grn>(test (+ 2 2) 4)</>
  ! error: oh no
  !   in _thunk [two.janet] (tailcall) on line 3, column 1
  !   in dofile [boot.janet] (tailcall) on line LINE, column COL
  !   in source-loader [boot.janet] on line LINE, column COL
  !   in require-1 [boot.janet] on line LINE, column COL
  !   in import* [boot.janet] (tailcall) on line LINE, column COL
  !   in dofile [boot.janet] (tailcall) on line LINE, column COL
  !   in source-loader [boot.janet] on line LINE, column COL
  !   in require-1 [boot.janet] (tailcall) on line LINE, column COL
  ! 
  ! 0 passed 1 failed
  [2]

Judge might still double-evaluate files with no tests in the case of a top-level error:

  $ use one.janet <<EOF
  > (use ./two)
  > EOF

  $ use two.janet <<EOF
  > (error "oh no")
  > EOF

  $ judge one.janet two.janet
  ! error: oh no
  !   in _thunk [two.janet] (tailcall) on line 1, column 1
  !   in dofile [boot.janet] (tailcall) on line LINE, column COL
  !   in source-loader [boot.janet] on line LINE, column COL
  !   in require-1 [boot.janet] on line LINE, column COL
  !   in import* [boot.janet] (tailcall) on line LINE, column COL
  !   in dofile [boot.janet] (tailcall) on line LINE, column COL
  !   in source-loader [boot.janet] on line LINE, column COL
  !   in require-1 [boot.janet] (tailcall) on line LINE, column COL
  ! error: oh no
  !   in _thunk [two.janet] (tailcall) on line 1, column 1
  !   in dofile [boot.janet] (tailcall) on line LINE, column COL
  !   in source-loader [boot.janet] on line LINE, column COL
  !   in require-1 [boot.janet] (tailcall) on line LINE, column COL
  ! 
  ! 0 passed
  [2]
