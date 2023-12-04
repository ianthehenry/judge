  $ source $TESTDIR/scaffold

Mutated values at the top level:

  $ use <<EOF
  > (use judge)
  > (def t @{})
  > (test t)
  > (put t :a 1)
  > (test t)
  > EOF

  $ judge
  ! <dim># script.janet</>
  ! 
  ! <red>(test t)</>
  ! <grn>(test t @{})</>
  ! 
  ! <red>(test t)</>
  ! <grn>(test t @{:a 1})</>
  ! 
  ! 0 passed 2 failed
  [1]

Mutated values in deftest:

  $ use <<EOF
  > (use judge)
  > (deftest "test"
  >   (def t @{})
  >   (test t)
  >   (put t :a 1)
  >   (test t))
  > EOF
  $ judge
  ! <dim># script.janet</>
  ! 
  ! (deftest "test"
  !   (def t @{})
  !   <red>(test t)</>
  !   <grn>(test t @{})</>
  !   (put t :a 1)
  !   <red>(test t)</>
  !   <grn>(test t @{:a 1})</>)
  ! 
  ! 0 passed 1 failed
  [1]

  $ show_tested
  (use judge)
  (deftest "test"
    (def t @{})
    (test t @{})
    (put t :a 1)
    (test t @{:a 1}))

  $ mv script.janet{.tested,}

  $ judge
  ! <dim># script.janet</>
  ! 
  ! 1 passed
