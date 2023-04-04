  $ source $TESTDIR/scaffold

Shared state is reset between runs:

  $ use <<EOF
  > (use judge)
  > (deftest-type stateful-test
  >   :setup (fn [] @{:n 0})
  >   :reset (fn [context]
  >     (set (context :n) 0)))
  > 
  > (deftest: stateful-test "initial state" [state]
  >   (test (state :n) 0))
  > (deftest: stateful-test "state can be mutated" [state]
  >   (set (state :n) 1)
  >   (test (state :n) 1))
  > 
  > (deftest: stateful-test "state is back to normal" [state]
  >   (test (state :n) 0))
  > EOF

  $ judge -v
  ! <dim># script.janet</>
  ! running test: initial state
  ! running test: state can be mutated
  ! running test: state is back to normal
  ! 
  ! 3 passed

Tests don't run if something fails:

  $ use <<EOF
  > (use judge)
  > (deftest-type erroneous-setup
  >   :setup (fn [] (error "oh no")))
  > 
  > (deftest: erroneous-setup "test that will be skipped" [_]
  >   (error "unreachable"))
  > 
  > (deftest: erroneous-setup "another test that will be skipped" [_]
  >   (error "unreachable"))
  > EOF

  $ judge
  ! <dim># script.janet</>
  ! 
  ! (deftest: erroneous-setup "test that will be skipped" [_]
  !   (error "unreachable"))
  ! 
  ! error: failed to initialize context: oh no
  !   in <anonymous> [script.janet] on line 3, column 17
  !   in <anonymous> [$PWD/jpm_tree/lib/judge/init.janet] on line 32, column 17
  !   in <anonymous> [script.janet] on line 5, column 1
  ! 
  ! (deftest: erroneous-setup "another test that will be skipped" [_]
  !   (error "unreachable"))
  ! 
  ! error: failed to initialize context: oh no
  !   in <anonymous> [script.janet] on line 3, column 17
  !   in <anonymous> [$PWD/jpm_tree/lib/judge/init.janet] on line 32, column 17
  !   in <anonymous> [script.janet] on line 8, column 1
  ! 
  ! 0 passed 2 failed
  [1]

Something else:

  $ use <<EOF
  > (use judge)
  > (deftest-type erroneous-reset
  >   :setup (fn [] @{:n 0})
  >   :reset (fn [context]
  >     (print "reset")
  >     (error "oh dear")))
  > 
  > (deftest: erroneous-reset "test not called because reset failed" [_]
  >   (error "unreachable"))
  > 
  > (deftest: erroneous-reset "test not attempted" [_]
  >   (error "unreachable"))
  > EOF

No tests of this type can run after a reset failure:

  $ judge
  reset
  ! <dim># script.janet</>
  ! 
  ! (deftest: erroneous-reset "test not called because reset failed" [_]
  !   (error "unreachable"))
  ! 
  ! error: failed to initialize context: oh dear
  !   in <anonymous> [script.janet] on line 6, column 5
  !   in <anonymous> [$PWD/jpm_tree/lib/judge/init.janet] on line 37, column 18
  !   in <anonymous> [script.janet] on line 8, column 1
  ! 
  ! (deftest: erroneous-reset "test not attempted" [_]
  !   (error "unreachable"))
  ! 
  ! error: failed to initialize context: oh dear
  !   in <anonymous> [script.janet] on line 6, column 5
  !   in <anonymous> [$PWD/jpm_tree/lib/judge/init.janet] on line 37, column 18
  !   in <anonymous> [script.janet] on line 11, column 1
  ! 
  ! 0 passed 2 failed
  [1]

Teardown failures are reported:

  $ use <<EOF
  > (use judge)
  > (deftest-type erroneous-teardown
  >   :setup (fn [] @{:n 0})
  >   :reset (fn [context]
  >     (put context :n 0))
  >   :teardown (fn [_] (error "oh no")))
  > 
  > (deftest: erroneous-teardown "test" [_]
  >   nil)
  > EOF

  $ judge
  ! <dim># script.janet</>
  ! <red>failed to teardown erroneous-teardown test context</>
  ! error: oh no
  !   in <anonymous> [script.janet] (tailcall) on line 6, column 21
  ! 
  ! 1 passed
  [1]
