  $ source $TESTDIR/scaffold

  $ use <<EOF
  > (test "test"
  >   (expect '(+ 2 2))
  >   (expect [1 2 3])
  >   (def x 10)
  >   (expect ~(identity ,x)))
  > EOF

  $ run
  ! running test: test
  ! <red>- (expect [1 2 3])</>
  ! <grn>+ (expect [1 2 3] [1 2 3])</>
  ! <red>- (expect (quasiquote (identity (unquote x))))</>
  ! <grn>+ (expect (quasiquote (identity (unquote x))) [identity 10])</>
  ! <red>- (expect (quote (+ 2 2)))</>
  ! <grn>+ (expect (quote (+ 2 2)) (+ 2 2))</>
  ! 0 passed 1 failed 0 excluded 0 skipped
  [1]

  $ show_corrected
  (test "test"
    (expect '(+ 2 2) (+ 2 2))
    (expect [1 2 3] [1 2 3])
    (def x 10)
    (expect ~(identity ,x) [identity 10]))
