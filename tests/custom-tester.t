  $ source $TESTDIR/scaffold

deftest-wrapper:

  $ use test.janet <<EOF
  > (use judge)
  > (defmacro* test-loudly [exp & args]
  >   ~(test (string/ascii-upper ,exp) ,;args))
  > (test-loudly "hi")
  > EOF
  $ judge
  ! <dim># test.janet</>
  ! 
  ! <red>(test-loudly "hi")</>
  ! <grn>(test-loudly "hi" "HI")</>
  ! 
  ! 0 passed 1 failed
  [1]
