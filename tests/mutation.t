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
  $ judge -a >/dev/null
  [1]

  $ cat script.janet
  (use judge)
  (deftest "test"
    (def t @{})
    (test t @{})
    (put t :a 1)
    (test t @{:a 1}))

  $ judge
  ! <dim># script.janet</>
  ! 
  ! 1 passed

Mutated values in tuples:

  $ use <<EOF
  > (use judge)
  > (deftest "test"
  >   (def t @{})
  >   (test [t])
  >   (put t :a 1)
  >   (test [t]))
  > EOF
  $ judge -a >/dev/null
  [1]

  $ cat script.janet
  (use judge)
  (deftest "test"
    (def t @{})
    (test [t] [@{}])
    (put t :a 1)
    (test [t] [@{:a 1}]))

  $ judge
  ! <dim># script.janet</>
  ! 
  ! 1 passed
