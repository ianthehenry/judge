  $ source $TESTDIR/scaffold

Shared state is reset between runs:

  $ use <<EOF
  > (deftest stateful-test
  >   :setup (fn [] @{:n 0})
  >   :reset (fn [context] 
  >     (set (context :n) 0)))
  > 
  > (stateful-test "initial state" [state]
  >   (expect (state :n) 0))
  > (stateful-test "state can be mutated" [state]
  >   (set (state :n) 1)
  >   (expect (state :n) 1))
  > 
  > (stateful-test "state is back to normal" [state]
  >   (expect (state :n) 0))
  > EOF

  $ run 
  ! running test: initial state
  ! running test: state can be mutated
  ! running test: state is back to normal
  ! 3 passed 0 failed 0 excluded 0 skipped

Tests don't run if something fails:

  $ use <<EOF
  > (deftest erroneous-setup
  >   :setup (fn [] (error "oh no")))
  > 
  > (erroneous-setup "test that will be skipped"
  >   (error "unreachable"))
  > 
  > (erroneous-setup "another test that will be skipped"
  >   (error "unreachable"))
  > EOF

  $ run
  ! <red>error initializing context for "erroneous-setup"</><dim> (script.janet:2:1)</>
  ! error: oh no
  !   in <anonymous> [script.janet] (tailcall) on line 3, column 17
  ! <red>unable to run test: test that will be skipped</>
  ! <red>unable to run test: another test that will be skipped</>
  ! 2 passed 0 failed 0 excluded 2 skipped
  [1]

Something else:

  $ use <<EOF
  > (deftest erroneous-reset
  >   :setup (fn [] @{:n 0})
  >   :reset (fn [context]
  >     (print "reset")
  >     (error "oh dear")))
  > 
  > (erroneous-reset "test not called because reset failed"
  >   (error "unreachable"))
  > 
  > (erroneous-reset "test not attempted"
  >   (error "unreachable"))
  > EOF

TODO: reset should only be called once; the entire class of test should be marked
as broken after a single reset failure.

  $ run
  reset
  reset
  ! <red>error resetting context for "erroneous-reset"</><dim> (script.janet:2:1)</>
  ! error: oh dear
  !   in <anonymous> [script.janet] (tailcall) on line 6, column 5
  ! <red>unable to run test: test not called because reset failed</>
  ! <red>error resetting context for "erroneous-reset"</><dim> (script.janet:2:1)</>
  ! error: oh dear
  !   in <anonymous> [script.janet] (tailcall) on line 6, column 5
  ! <red>unable to run test: test not attempted</>
  ! 2 passed 0 failed 0 excluded 2 skipped
  [1]
