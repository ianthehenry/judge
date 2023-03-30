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
  ! 0 passed 0 failed 0 skipped 0 unreachable
  [1]

  $ judge two.janet
  two
  ! 0 passed 0 failed 0 skipped 0 unreachable
  [1]

  $ judge three.janet
  three
  one
  ! 0 passed 0 failed 0 skipped 0 unreachable
  [1]

  $ judge four.janet
  four
  two
  ! 0 passed 0 failed 0 skipped 0 unreachable
  [1]

  $ judge one.janet three.janet
  one
  three
  ! 0 passed 0 failed 0 skipped 0 unreachable
  [1]

  $ judge two.janet four.janet
  two
  four
  ! 0 passed 0 failed 0 skipped 0 unreachable
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
  ! 0 passed 0 failed 0 skipped 0 unreachable
  [1]

  $ judge two.janet ../four.janet
  subdirectory two
  four
  ! 0 passed 0 failed 0 skipped 0 unreachable
  [1]

This is a bug that happens because we import something/two.janet
in two different ways: once as ../something/two.janet and once as
just two.janet. These are the same file, but different paths, so
they get separate entries in the module cache. I don't think that
this is really worth guarding against.

  $ judge two.janet ../something/two.janet
  subdirectory two
  subdirectory two
  ! 0 passed 0 failed 0 skipped 0 unreachable
  [1]

You can still import by absolute path if you want, but it will
get yet another module cache entry:

  $ judge two.janet ../something/two.janet $PWD/two.janet
  subdirectory two
  subdirectory two
  subdirectory two
  ! 0 passed 0 failed 0 skipped 0 unreachable
  [1]
