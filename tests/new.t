  $ source $TESTDIR/scaffold

  $ use main.janet <<EOF
  > (use judge)
  > (print "hello")
  > EOF

  $ mkdir -p tests

  $ use tests/one.janet <<EOF
  > (use judge)
  > (test 1)
  > EOF

  $ use tests/two.janet <<EOF
  > (use judge)
  > (test 2)
  > EOF

By default, Judge recursively finds all Janet files:

  $ judge -a
  hello
  ! <dim># tests/one.janet</>
  ! 
  ! <red>(test 1)</>
  ! <grn>(test 1 1)</>
  ! 
  ! <dim># tests/two.janet</>
  ! 
  ! <red>(test 2)</>
  ! <grn>(test 2 2)</>
  ! 
  ! 0 passed 2 failed
  [1]

  $ judge
  hello
  ! <dim># tests/one.janet</>
  ! <dim># tests/two.janet</>
  ! 
  ! 2 passed

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
  ! 
  ! 0 passed
  [1]

Directories work:

  $ judge tests
  ! <dim># tests/one.janet</>
  ! <dim># tests/two.janet</>
  ! 
  ! 2 passed

And combinations of the two:

  $ judge tests main.janet
  hello
  ! <dim># tests/one.janet</>
  ! <dim># tests/two.janet</>
  ! 
  ! 2 passed

Simplest possible test:

  $ use <<EOF
  > (use judge)
  > (deftest "hello"
  >   (print "running test")
  >   (test (+ 1 2)))
  > EOF

  $ judge script.janet
  running test
  ! <dim># script.janet</>
  ! 
  ! (deftest "hello"
  !   (print "running test")
  !   <red>(test (+ 1 2))</>
  !   <grn>(test (+ 1 2) 3)</>)
  ! 
  ! 0 passed 1 failed
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
  ! <dim># script.janet</>
  ! 
  ! 1 passed

Tests fails due to error (this should probably also patch!):

  $ use <<EOF
  > (use judge)
  > (deftest "hello"
  >   (test (+ 1 2) 0)
  >   (error "oh no")
  >   (test (+ 1 2) 0))
  > EOF
  $ judge script.janet
  ! <dim># script.janet</>
  ! 
  ! (deftest "hello"
  !   <red>(test (+ 1 2) 0)</>
  !   <grn>(test (+ 1 2) 3)</>
  !   (error "oh no")
  !   <red># did not reach expectation</>
  !   <red>(test (+ 1 2) 0)</>)
  ! 
  ! error: oh no
  !   in <anonymous> [script.janet] on line 2, column 1
  ! 
  ! 0 passed 1 failed
  [1]

Exception in test expression:

  $ use <<EOF
  > (use judge)
  > (deftest "hello"
  >   (test (error "oh no") 0))
  > EOF
  $ judge script.janet
  ! <dim># script.janet</>
  ! 
  ! (deftest "hello"
  !   <red># error: oh no
  ! #   in <anonymous> [script.janet] on line 2, column 1</>
  !   <red>(test (error "oh no") 0)</>)
  ! 
  ! 0 passed 1 failed
  [1]

Control continues after an exception in a test expression:

  $ use <<EOF
  > (use judge)
  > (deftest "hello"
  >   (test (error "oh no") 0)
  >   (test (+ 1 2)))
  > EOF
  $ judge script.janet
  ! <dim># script.janet</>
  ! 
  ! (deftest "hello"
  !   <red># error: oh no
  ! #   in <anonymous> [script.janet] on line 2, column 1</>
  !   <red>(test (error "oh no") 0)</>
  !   <red>(test (+ 1 2))</>
  !   <grn>(test (+ 1 2) 3)</>)
  ! 
  ! 0 passed 1 failed
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
  ! 
  ! 0 passed 1 unreachable
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
  ! <dim># script.janet</>
  ! 
  ! (deftest "hello"
  !   (print "running test")
  !   (when false
  !     <red># did not reach expectation</>
  !     <red>(test (+ 1 2) 3)</>))
  ! 
  ! 0 passed 1 failed
  [1]

Expectation runs multiple times (same result, no expected value):

  $ use <<EOF
  > (use judge)
  > (deftest "hello"
  >   (for i 0 2
  >     (test (+ 1 1))))
  > EOF
  $ judge script.janet
  ! <dim># script.janet</>
  ! 
  ! (deftest "hello"
  !   (for i 0 2
  !     <red>(test (+ 1 1))</>
  !     <grn>(test (+ 1 1) 2)</>))
  ! 
  ! 0 passed 1 failed
  [1]

Expectation runs multiple times (same result, correct expected value):

  $ use <<EOF
  > (use judge)
  > (deftest "hello"
  >   (for i 0 2
  >     (test (+ 1 1) 2)))
  > EOF
  $ judge script.janet
  ! <dim># script.janet</>
  ! 
  ! 1 passed

Expectation runs multiple times (same result, incorrect expected value):

  $ use <<EOF
  > (use judge)
  > (deftest "hello"
  >   (for i 0 2
  >     (test (+ 1 1) 3)))
  > EOF
  $ judge script.janet
  ! <dim># script.janet</>
  ! 
  ! (deftest "hello"
  !   (for i 0 2
  !     <red>(test (+ 1 1) 3)</>
  !     <grn>(test (+ 1 1) 2)</>))
  ! 
  ! 0 passed 1 failed
  [1]

Expectation runs multiple times (different results):

  $ use <<EOF
  > (use judge)
  > (deftest "hello"
  >   (for i 0 2
  >     (test i)))
  > EOF
  $ judge script.janet
  ! <dim># script.janet</>
  ! 
  ! (deftest "hello"
  !   (for i 0 2
  !     <red># inconsistent results</>
  !     <red>(test i)</>))
  ! 
  ! 0 passed 1 failed
  [1]

Test types:

  $ use <<EOF
  > (use judge)
  > (deftest-type stateful-test :setup (fn [] @{:num 0}))
  > (deftest: stateful-test "hello" [state]
  >   (test (state :num) 0))
  > EOF
  $ judge script.janet
  ! <dim># script.janet</>
  ! 
  ! 1 passed

Top-level test:

  $ use <<EOF
  > (use judge)
  > (test (+ 1 2))
  > (test (+ 1 2) 0)
  > EOF
  $ judge script.janet
  ! <dim># script.janet</>
  ! 
  ! <red>(test (+ 1 2))</>
  ! <grn>(test (+ 1 2) 3)</>
  ! 
  ! <red>(test (+ 1 2) 0)</>
  ! <grn>(test (+ 1 2) 3)</>
  ! 
  ! 0 passed 2 failed
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
  ! <dim># script.janet</>
  ! 
  ! <red>(test-error (error "hello"))</>
  ! <grn>(test-error (error "hello") "hello")</>
  ! 
  ! (deftest "okay"
  !   <red># error: did not error
  ! #   in <anonymous> [script.janet] on line 3, column 1</>
  !   <red>(test-error (+ 1 2) 0)</>)
  ! 
  ! 0 passed 2 failed
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
  ! <dim># script.janet</>
  ! 
  ! 2 passed

Multiple expectations:

  $ use <<EOF
  > (use judge)
  > (test 0 0 1 2)
  > EOF
  $ judge script.janet
  ! <dim># script.janet</>
  ! 
  ! <red>(test 0 0 1 2)</>
  ! <grn>(test 0 0)</>
  ! 
  ! 0 passed 1 failed
  [1]
