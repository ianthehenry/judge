  $ source $TESTDIR/scaffold

trust expressions are run if there's no expectation already:

  $ use <<EOF
  > (use judge)
  > (trust (+ 1 2))
  > EOF

  $ judge
  ! <dim># script.janet</>
  ! 
  ! <red>(trust (+ 1 2))</>
  ! <grn>(trust (+ 1 2) 3)</>
  ! 
  ! 0 passed 1 failed
  [1]

trust expressions don't run if they have an expectation:

  $ use <<EOF
  > (use judge)
  > (trust (+ 1 2) 4)
  > EOF

  $ judge
  ! <dim># script.janet</>
  ! 
  ! 1 passed

trust expressions don't even evaluate their expression if they already have an expectation:

  $ use <<EOF
  > (use judge)
  > (trust (error "oh no") 4)
  > EOF

  $ judge
  ! <dim># script.janet</>
  ! 
  ! 1 passed

trust expressions evaluate to the trusted expression:

  $ use <<EOF
  > (use judge)
  > (pp (trust (error "oh no") @{:hi 123}))
  > EOF

  $ judge
  @{:hi 123}
  ! <dim># script.janet</>
  ! 
  ! 1 passed

trust expressions don't evaluate their expectations:

  $ use <<EOF
  > (use judge)
  > (def x 10)
  > (print (trust (+ 1 2) x))
  > EOF

  $ judge
  x
  ! <dim># script.janet</>
  ! 
  ! 1 passed

trust expressions remove extra arguments:

  $ use <<EOF
  > (use judge)
  > (trust (+ 1 2) 4 5)
  > EOF

  $ judge
  ! <dim># script.janet</>
  ! 
  ! <red>(trust (+ 1 2) 4 5)</>
  ! <grn>(trust (+ 1 2) 4)</>
  ! 
  ! 0 passed 1 failed
  [1]

readme example:

  $ use <<EOF
  > (use judge)
  > (def posts 
  >   (trust (download-posts-from-the-internet) 
  >     [{:id 4322
  >       :content "test post please ignore"}
  >      {:id 4321
  >       :content "is anybody here?"}]))
  > (defn format-posts [posts]
  >   (string/join (seq [[i {:content content}] :pairs posts] (string/format "%d. %s" (+ i 1) content)) "\n"))
  > (test (format-posts posts)
  >   "1. test post please ignore\n2. is anybody here?")
  > EOF

  $ judge
  ! <dim># script.janet</>
  ! 
  ! 2 passed

--untrusting:

  $ use <<EOF
  > (use judge)
  > (trust (+ 1 2) 4) 
  > EOF

  $ judge
  ! <dim># script.janet</>
  ! 
  ! 1 passed
  $ judge --untrusting
  ! <dim># script.janet</>
  ! 
  ! <red>(trust (+ 1 2) 4)</>
  ! <grn>(trust (+ 1 2) 3)</>
  ! 
  ! 0 passed 1 failed
  [1]
