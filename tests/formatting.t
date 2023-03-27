  $ source $TESTDIR/scaffold

  $ use <<EOF
  > (use judge)
  > (deftest "test"
  >   (test '(+ 2 2))
  >   (test [1 2 3])
  >   (def x 10)
  >   (test ~(identity ,x)))
  > EOF

  $ judge
  ! running test: test
  ! <red>- (test '(+ 2 2))</>
  ! <grn>+ (test '(+ 2 2) (+ 2 2))</>
  ! <red>- (test [1 2 3])</>
  ! <grn>+ (test [1 2 3] [1 2 3])</>
  ! <red>- (test ~(identity ,x))</>
  ! <grn>+ (test ~(identity ,x) [identity 10])</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]

  $ show_tested
  (use judge)
  (deftest "test"
    (test '(+ 2 2) (+ 2 2))
    (test [1 2 3] [1 2 3])
    (def x 10)
    (test ~(identity ,x) [identity 10]))
