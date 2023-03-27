  $ source $TESTDIR/scaffold

Fills in the blank:

  $ use <<EOF
  > (use judge)
  > (deftest "test"
  >   (test (+ 1 2)))
  > EOF
  $ judge
  ! running test: test
  ! <red>- (test (+ 1 2))</>
  ! <grn>+ (test (+ 1 2) 3)</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]

  $ show_tested
  (use judge)
  (deftest "test"
    (test (+ 1 2) 3))

Preserves formatting before result:

  $ use <<EOF
  > (use judge)
  > (deftest "test"
  >   (test (+ 1
  >      2)))
  > EOF
  $ judge >/dev/null
  [1]

  $ show_tested
  (use judge)
  (deftest "test"
    (test (+ 1
       2) 3))

Preserves position of result:

  $ use <<EOF
  > (use judge)
  > (deftest "test"
  >   (test [1
  >         2]
  >       [1 3]))
  > EOF
  $ judge >/dev/null
  [1]

  $ show_tested
  (use judge)
  (deftest "test"
    (test [1
          2]
        [1 2]))

Does not preserve formatting of incorrect result:

  $ use <<EOF
  > (use judge)
  > (deftest "test"
  >   (test [1
  >         2]
  >       [1
  >            3]))
  > EOF
  $ judge >/dev/null
  [1]

  $ show_tested
  (use judge)
  (deftest "test"
    (test [1
          2]
        [1 2]))

Does not re-format correct results:

  $ use <<EOF
  > (use judge)
  > (deftest "test"
  >   (test [1
  >         2]
  >       [1
  >            2]))
  > EOF
  $ judge >/dev/null

Uncaught exceptions cause tests to fail:

  $ use <<EOF
  > (use judge)
  > (deftest "test"
  >   (error "oh no"))
  > EOF
  $ judge
  ! running test: test
  ! <red>test raised:</>
  ! error: oh no
  !   in <anonymous> [$PWD/script.janet] on line 2, column 1
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]

Reports multiple failed expectations:

  $ use <<EOF
  > (use judge)
  > (deftest "test"
  >   (test 1 2)
  >   (test 3 4))
  > EOF
  $ judge
  ! running test: test
  ! <red>- (test 1 2)</>
  ! <grn>+ (test 1 1)</>
  ! <red>- (test 3 4)</>
  ! <grn>+ (test 3 3)</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]

test-error fills in error:

  $ use <<EOF
  > (use judge)
  > (deftest "errors"
  >   (test-error (error "raised")))
  > EOF

  $ judge
  ! running test: errors
  ! <red>- (test-error (error "raised"))</>
  ! <grn>+ (test-error (error "raised") "raised")</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]

test-error corrects error:

  $ use <<EOF
  > (use judge)
  > (deftest "errors"
  >   (test-error (error "raised") "braised"))
  > EOF

  $ judge
  ! running test: errors
  ! <red>- (test-error (error "raised") "braised")</>
  ! <grn>+ (test-error (error "raised") "raised")</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]

test-error passes:

  $ use <<EOF
  > (use judge)
  > (deftest "errors"
  >   (test-error (error "raised") "raised"))
  > EOF

  $ judge
  ! running test: errors
  ! 1 passed 0 failed 0 skipped 0 unreachable

test-error fails if nothing raises:

  $ use <<EOF
  > (use judge)
  > (deftest "errors"
  >   (test-error 123))
  > EOF

  $ judge
  ! running test: errors
  ! <red>did not error</>
  ! <red>- (test-error 123)</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]
