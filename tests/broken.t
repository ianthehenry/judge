  $ source $TESTDIR/scaffold

Unreachable expectations should fail, but don't:

  $ use <<EOF
  > (test "hello"
  >   (if false
  >     (expect 1 2)))
  > EOF
  $ run
  ! running test: hello
  ! 1 passed 0 failed 0 excluded 0 skipped

expect-error uses magic DID-NOT-ERROR value:

  $ use <<EOF
  > (test "errors"
  >   (expect-error 123 DID-NOT-ERROR))
  > EOF

  $ run
  ! running test: errors
  ! 1 passed 0 failed 0 excluded 0 skipped
