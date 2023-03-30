  $ source $TESTDIR/scaffold

  $ use main.janet <<EOF
  > (use judge)
  > (print "hello")
  > EOF

  $ mkdir -p tests

  $ use tests/one.janet <<EOF
  > (use judge)
  > (print "test one")
  > EOF

  $ use tests/two.janet <<EOF
  > (use judge)
  > (print "test two")
  > EOF

By default, Judge recursively finds all Janet files:

  $ judge
  hello
  test one
  test two
  ! 0 passed 0 failed 0 skipped 0 unreachable
  [1]

Judge errors if you pass it a file that does not exist:

  $ judge foo.janet
  ! error: could not read "foo.janet"
  [1]

You need to specify an extension:

  $ judge tests/one
  ! error: could not read "tests/one"
  [1]

Single files work:

  $ judge main.janet
  hello
  ! 0 passed 0 failed 0 skipped 0 unreachable
  [1]

Directories work:

  $ judge tests
  test one
  test two
  ! 0 passed 0 failed 0 skipped 0 unreachable
  [1]

And combinations of the two:

  $ judge tests main.janet
  test one
  test two
  hello
  ! 0 passed 0 failed 0 skipped 0 unreachable
  [1]

Simplest possible test:

  $ use <<EOF
  > (use judge)
  > (deftest "hello"
  >   (print "running test")
  >   (test (+ 1 2)))
  > EOF

  $ judge script.janet
  running test
  ! running test: hello
  ! <red>- (test (+ 1 2))</>
  ! <grn>+ (test (+ 1 2) 3)</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]

Tests passes:

  $ use <<EOF
  > (use judge)
  > (deftest "hello"
  >   (print "running test")
  >   (test (+ 1 2) 3))
  > EOF
  $ judge script.janet
  running test
  ! running test: hello
  ! 1 passed 0 failed 0 skipped 0 unreachable

Tests fails due to error (this should probably also patch!):

  $ use <<EOF
  > (use judge)
  > (deftest "hello"
  >   (test (+ 1 2) 0)
  >   (error "oh no")
  >   (test (+ 1 2) 0))
  > EOF
  $ judge script.janet
  ! running test: hello
  ! <red>test raised:</>
  ! error: oh no
  !   in <anonymous> [script.janet] on line 2, column 1
  ! <red>- (test (+ 1 2) 0)</>
  ! <grn>+ (test (+ 1 2) 3)</>
  ! <red>did not reach expectation</>
  ! <red>- (test (+ 1 2) 0)</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]

Exception in test expression:

  $ use <<EOF
  > (use judge)
  > (deftest "hello"
  >   (test (error "oh no") 0))
  > EOF
  $ judge script.janet
  ! running test: hello
  ! <red>oh no</>
  ! <red>- (test (error "oh no") 0)</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]

Unreachable test:

  $ use <<EOF
  > (use judge)
  > (when false
  >   (deftest "hello"
  >     (print "running test")
  >     (test (+ 1 2) 3)))
  > EOF
  $ judge script.janet
  ! <red>hello did not run</>
  ! 0 passed 0 failed 0 skipped 1 unreachable
  [1]

Unreachable expectation:

  $ use <<EOF
  > (use judge)
  > (deftest "hello"
  >   (print "running test")
  >   (when false
  >     (test (+ 1 2) 3)))
  > EOF
  $ judge script.janet
  running test
  ! running test: hello
  ! <red>did not reach expectation</>
  ! <red>- (test (+ 1 2) 3)</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]

Expectation runs multiple times (same result, no expected value):

  $ use <<EOF
  > (use judge)
  > (deftest "hello"
  >   (for i 0 2
  >     (test (+ 1 1))))
  > EOF
  $ judge script.janet
  ! running test: hello
  ! <red>- (test (+ 1 1))</>
  ! <grn>+ (test (+ 1 1) 2)</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]

Expectation runs multiple times (same result, correct expected value):

  $ use <<EOF
  > (use judge)
  > (deftest "hello"
  >   (for i 0 2
  >     (test (+ 1 1) 2)))
  > EOF
  $ judge script.janet
  ! running test: hello
  ! 1 passed 0 failed 0 skipped 0 unreachable

Expectation runs multiple times (same result, incorrect expected value):

  $ use <<EOF
  > (use judge)
  > (deftest "hello"
  >   (for i 0 2
  >     (test (+ 1 1) 3)))
  > EOF
  $ judge script.janet
  ! running test: hello
  ! <red>- (test (+ 1 1) 3)</>
  ! <grn>+ (test (+ 1 1) 2)</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]

Expectation runs multiple times (different results):

  $ use <<EOF
  > (use judge)
  > (deftest "hello"
  >   (for i 0 2
  >     (test i)))
  > EOF
  $ judge script.janet
  ! running test: hello
  ! <red>inconsistent results</>
  ! <red>- (test i)</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]

Test types:

  $ use <<EOF
  > (use judge)
  > (deftest-type stateful-test :setup (fn [] @{:num 0}))
  > (deftest: stateful-test "hello" [state]
  >   (test (state :num) 0))
  > EOF
  $ judge script.janet
  ! running test: hello
  ! 1 passed 0 failed 0 skipped 0 unreachable

Top-level test:

  $ use <<EOF
  > (use judge)
  > (test (+ 1 2))
  > (test (+ 1 2) 0)
  > EOF
  $ judge script.janet
  ! running test: script.janet:2:1
  ! <red>- (test (+ 1 2))</>
  ! <grn>+ (test (+ 1 2) 3)</>
  ! running test: script.janet:3:1
  ! <red>- (test (+ 1 2) 0)</>
  ! <grn>+ (test (+ 1 2) 3)</>
  ! 0 passed 2 failed 0 skipped 0 unreachable
  [1]

  $ cat script.janet.tested
  (use judge)
  (test (+ 1 2) 3)
  (test (+ 1 2) 3)

test-error:

  $ use <<EOF
  > (use judge)
  > (test-error (error "hello"))
  > (deftest "okay"
  >   (test-error (+ 1 2) 0))
  > EOF
  $ judge script.janet
  ! running test: script.janet:2:1
  ! <red>- (test-error (error "hello"))</>
  ! <grn>+ (test-error (error "hello") "hello")</>
  ! running test: okay
  ! <red>did not error</>
  ! <red>- (test-error (+ 1 2) 0)</>
  ! 0 passed 2 failed 0 skipped 0 unreachable
  [1]

  $ cat script.janet.tested
  (use judge)
  (test-error (error "hello") "hello")
  (deftest "okay"
    (test-error (+ 1 2) 0))

Tests run as soon as they're encountered:

  $ use <<EOF
  > (use judge)
  > (var x 0)
  > (test x 0)
  > (++ x)
  > (test x 1)
  > EOF
  $ judge script.janet
  ! running test: script.janet:3:1
  ! running test: script.janet:5:1
  ! 2 passed 0 failed 0 skipped 0 unreachable

Multiple expectations:

  $ use <<EOF
  > (use judge)
  > (test 0 0 1 2)
  > EOF
  $ judge script.janet
  ! running test: script.janet:2:1
  ! <red>- (test 0 0 1 2)</>
  ! <grn>+ (test 0 0)</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]
