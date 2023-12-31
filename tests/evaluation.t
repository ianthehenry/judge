  $ source $TESTDIR/scaffold

test returns the expression it evaluates to:

  $ use <<EOF
  > (use judge)
  > (pp (test (+ 1 2) 3))
  > EOF

  $ judge
  3
  ! <dim># script.janet</>
  ! 
  ! 1 passed

test returns the expression it evaluates to even if it has not been filled in yet:

  $ use <<EOF
  > (use judge)
  > (pp (test 123))
  > EOF

  $ judge
  123
  ! <dim># script.janet</>
  ! 
  ! <red>(test 123)</>
  !     <grn>(test 123 123)</>
  ! 
  ! 0 passed 1 failed
  [1]

Named test returns its last expression:

  $ use <<EOF
  > (use judge)
  > (pp (deftest "testing" (test 1 1) (test 2 2) "done"))
  > EOF

  $ judge
  "done"
  ! <dim># script.janet</>
  ! 
  ! 1 passed

If a test expression raises it returns nil, because we can't propagate the exception:

  $ use <<EOF
  > (use judge)
  > (pp (test (error "hi")))
  > EOF

  $ judge
  nil
  ! <dim># script.janet</>
  ! 
  ! <red># error: hi
  ! #   in <anonymous> [script.janet] on line 2, column 5</>
  !     <red>(test (error "hi"))</>
  ! 
  ! 0 passed 1 failed
  [1]

Named test that raises returns nil:

  $ use <<EOF
  > (use judge)
  > (pp (deftest "testing" (test 1 1) (error "oh no") (test 2 2) "done"))
  > EOF

  $ judge
  nil
  ! <dim># script.janet</>
  ! 
  ! (deftest "testing" (test 1 1) (error "oh no") <red># did not reach expectation</>
  !                                                   <red>(test 2 2)</> "done")
  ! 
  ! error: oh no
  !   in <anonymous> [script.janet] on line 2, column 5
  ! 
  ! 0 passed 1 failed
  [1]

test-stdout returns stdout and the expression:

  $ use <<EOF
  > (use judge)
  > (pp (test-stdout (do (print "hi") 123)))
  > EOF

  $ judge
  (@"hi\n" 123)
  ! <dim># script.janet</>
  ! 
  ! <red>(test-stdout (do (print "hi") 123))</>
  !     <grn>(test-stdout (do (print "hi") 123) `
  !       hi
  !     ` 123)</>
  ! 
  ! 0 passed 1 failed
  [1]

test-stdout returns a two-element tuple even when it only splices a single element:

  $ use <<EOF
  > (use judge)
  > (pp (test-stdout (do (print "hi"))))
  > EOF

  $ judge
  (@"hi\n" nil)
  ! <dim># script.janet</>
  ! 
  ! <red>(test-stdout (do (print "hi")))</>
  !     <grn>(test-stdout (do (print "hi")) `
  !       hi
  !     `)</>
  ! 
  ! 0 passed 1 failed
  [1]

test-macro returns the expanded form, which can be used to hack a very janky multi-step expansion:

  $ use <<EOF
  > (use judge)
  > (defmacro base [] "expanded")
  > (defmacro n+1 [] ~(base))
  > (defmacro n+2 [] ~(n+1))
  > (defmacro expand [x] (macex1 (eval x)))
  > (def step-one (test-macro (n+2)))
  > (test-macro (expand step-one))
  > (test-macro (expand (expand step-one)))
  > EOF

  $ judge
  ! <dim># script.janet</>
  ! 
  ! <red>(test-macro (n+2))</>
  !               <grn>(test-macro (n+2)
  !                 (n+1))</>
  ! 
  ! <red>(test-macro (expand step-one))</>
  ! <grn>(test-macro (expand step-one)
  !   (base))</>
  ! 
  ! <red>(test-macro (expand (expand step-one)))</>
  ! <grn>(test-macro (expand (expand step-one))
  !   "expanded")</>
  ! 
  ! 0 passed 3 failed
  [1]

Nested testing:

  $ use <<EOF
  > (use judge)
  > (test (test 5))
  > (test (test 5 5))
  > (test (test 5) 5)
  > (test (test 5 5) 5)
  > EOF

  $ judge
  ! <dim># script.janet</>
  ! 
  ! <dim># overlapping replacements</>
  ! <red>(test (test 5))</>
  ! 
  ! <red>(test (test 5 5))</>
  ! <grn>(test (test 5 5) 5)</>
  ! 
  ! (test <red>(test 5)</>
  !       <grn>(test 5 5)</> 5)
  ! 
  ! 1 passed 3 failed
  [1]
