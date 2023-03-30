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
