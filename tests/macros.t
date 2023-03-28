  $ source $TESTDIR/scaffold

TODO: make this print with round parens
test-macro:

  $ use <<EOF
  > (use judge)
  > (test-macro (let [x 1] x))
  > EOF
  $ judge script.janet
  ! running test: $PWD/script.janet:2:1
  ! <red>- (test-macro (let [x 1] x))</>
  ! <grn>+ (test-macro (let [x 1] x) (do (def x 1) x))</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]

  $ cat script.janet.tested
  (use judge)
  (test-macro (let [x 1] x) (do (def x 1) x))
