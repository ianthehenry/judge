  $ source $TESTDIR/scaffold

Fills in the blank:

  $ use <<EOF
  > (test "test"
  >   (expect (+ 1 2)))
  > EOF
  $ run
  ! running test: test
  ! <red>- (expect (+ 1 2))</>
  ! <grn>+ (expect (+ 1 2) 3)</>
  ! 0 passed 1 failed 0 excluded 0 skipped
  [1]

  $ show_corrected
  (test "test"
    (expect (+ 1 2) 3))

Preserves formatting before result:

  $ use <<EOF
  > (test "test"
  >   (expect (+ 1 
  >      2)))
  > EOF
  $ run >/dev/null
  [1]

  $ show_corrected
  (test "test"
    (expect (+ 1 
       2) 3))

Preserves position of result:

  $ use <<EOF
  > (test "test"
  >   (expect [1 
  >         2]
  >       [1 3]))
  > EOF
  $ run >/dev/null
  [1]

  $ show_corrected
  (test "test"
    (expect [1 
          2]
        [1 2]))

Does not preserve formatting of incorrect result:

  $ use <<EOF
  > (test "test"
  >   (expect [1 
  >         2]
  >       [1 
  >            3]))
  > EOF
  $ run >/dev/null
  [1]

  $ show_corrected
  (test "test"
    (expect [1 
          2]
        [1 2]))

Does not re-format correct results:

  $ use <<EOF
  > (test "test"
  >   (expect [1 
  >         2]
  >       [1 
  >            2]))
  > EOF
  $ run >/dev/null

Uncaught exceptions cause tests to fail:

  $ use <<EOF
  > (test "test"
  >   (error "oh no"))
  > EOF
  $ run
  ! running test: test
  ! <red>test raised:</>
  ! error: oh no
  !   in <anonymous> [script.janet] (tailcall) on line 3, column 3
  ! 0 passed 1 failed 0 excluded 0 skipped
  [1]

Reports multiple failed expectations:

  $ use <<EOF
  > (test "test"
  >   (expect 1 2)
  >   (expect 3 4))
  > EOF
  $ run
  ! running test: test
  ! <red>- (expect 1 2)</>
  ! <grn>+ (expect 1 1)</>
  ! <red>- (expect 3 4)</>
  ! <grn>+ (expect 3 3)</>
  ! 0 passed 1 failed 0 excluded 0 skipped
  [1]

expect-error fills in exception:

  $ use <<EOF
  > (test "errors"
  >   (expect-error (error "raised")))
  > EOF

  $ run
  ! running test: errors
  ! <red>- (expect-error (error "raised"))</>
  ! <grn>+ (expect-error (error "raised") "raised")</>
  ! 0 passed 1 failed 0 excluded 0 skipped
  [1]

expect-error corrects exception:

  $ use <<EOF
  > (test "errors"
  >   (expect-error (error "raised") "braised"))
  > EOF

  $ run
  ! running test: errors
  ! <red>- (expect-error (error "raised") "braised")</>
  ! <grn>+ (expect-error (error "raised") "raised")</>
  ! 0 passed 1 failed 0 excluded 0 skipped
  [1]

expect-error passes:

  $ use <<EOF
  > (test "errors"
  >   (expect-error (error "raised") "raised"))
  > EOF

  $ run
  ! running test: errors
  ! 1 passed 0 failed 0 excluded 0 skipped

expect-error fails if nothing raises:

  $ use <<EOF
  > (test "errors"
  >   (expect-error 123))
  > EOF

  $ run
  ! running test: errors
  ! <red>- (expect-error 123)</>
  ! <grn>+ (expect-error 123 DID-NOT-ERROR)</>
  ! 0 passed 1 failed 0 excluded 0 skipped
  [1]

Expectation runs multiple times:

  $ use <<EOF
  > (test "errors"
  >   (each x [1 2 3]
  >     (expect x)))
  > EOF

  $ run
  ! running test: errors
  ! <red>- (expect x)</>
  ! <grn>+ (expect x 1 2 3)</>
  ! 0 passed 1 failed 0 excluded 0 skipped
  [1]

