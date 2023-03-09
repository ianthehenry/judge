  $ source $TESTDIR/scaffold

Fills in the blank:

  $ use <<EOF
  > (test "hello"
  >   (expect (+ 1 2)))
  > EOF
  $ run
  ! running test: hello
  ! \x1b[31m- (expect (+ 1 2))\x1b[0m (esc)
  ! \x1b[32m+ (expect (+ 1 2) 3)\x1b[0m (esc)
  ! 0 passed 1 failed 0 excluded 0 skipped
  [1]
