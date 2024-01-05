  $ source $TESTDIR/scaffold

Cyclic data structures don't cause an infinite loop:

  $ use <<EOF
  > (use judge)
  > (def foo @{})
  > (put foo :foo foo)
  > (test foo)
  > EOF
  $ judge
  ! <dim># script.janet</>
  ! 
  ! <red># error: Cycle detected! Judge is not currently smart enough to round-trip cyclic data structures.
  ! #   in <anonymous> [$PWD/jpm_tree/lib/judge/init.janet] on line 136, column 7
  ! #   in stably-clone-aux [$PWD/jpm_tree/lib/judge/init.janet] (tailcall) on line LINE, column COL
  ! #   in walk-dict [boot.janet] (tailcall) on line LINE, column COL
  ! #   in stably-clone-aux [$PWD/jpm_tree/lib/judge/init.janet] (tailcall) on line LINE, column COL
  ! #   in <anonymous> [script.janet] on line 4, column 1</>
  ! <red>(test foo)</>
  ! 
  ! 0 passed 1 failed
  [1]
