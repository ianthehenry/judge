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
  ! <red>(test foo)</>
  ! <grn>(test foo @{:foo <cycle>})</>
  ! 
  ! 0 passed 1 failed
  [1]

Mutually-recursive cyclic data structures still work:

  $ use <<EOF
  > (use judge)
  > (def foo @{})
  > (def bar @{})
  > (put bar :foo foo)
  > (put foo :bar bar)
  > (test foo)
  > (test bar)
  > EOF
  $ judge
  ! <dim># script.janet</>
  ! 
  ! <red>(test foo)</>
  ! <grn>(test foo @{:bar @{:foo <cycle>}})</>
  ! 
  ! <red>(test bar)</>
  ! <grn>(test bar @{:foo @{:bar <cycle>}})</>
  ! 
  ! 0 passed 2 failed
  [1]

You can repeat mutable data structures without issue, although
there is no indication that they match:

  $ use <<EOF
  > (use judge)
  > (def foo @{:x 1})
  > (def bar @[foo foo foo])
  > (test bar)
  > EOF
  $ judge
  ! <dim># script.janet</>
  ! 
  ! <red>(test bar)</>
  ! <grn>(test bar @[@{:x 1} @{:x 1} @{:x 1}])</>
  ! 
  ! 0 passed 1 failed
  [1]
