  $ source $TESTDIR/scaffold
  $ export NO_COLOR=1

Does not export ANSI color codes:

  $ use <<EOF
  > (use judge)
  > (deftest "test"
  >   (test (+ 1 2)))
  > EOF
  $ judge
  ! # script.janet
  ! 
  ! (deftest "test"
  !   (test (+ 1 2))
  !   (test (+ 1 2) 3))
  ! 
  ! 0 passed 1 failed
  [1]

  $ show_tested
  (use judge)
  (deftest "test"
    (test (+ 1 2) 3))

