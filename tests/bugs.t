  $ source $TESTDIR/scaffold

There is a bizarre bug that I don't understand where if you try to evaluate
tests in a loop it ends up *expanding* the tests multiple times for some
reason:

  $ use <<EOF
  > (use judge)
  > (for i 0 5
  >   (test (+ 1 1)))
  > EOF
  $ judge -a
  ! <dim># script.janet</>
  ! 
  ! <red>(test (+ 1 1))</>
  !   <grn>(test (+ 1 1) 2)</>
  ! <red>script.janet:3:3 ran multiple times</>
  ! <red>script.janet:3:3 ran multiple times</>
  ! <red>script.janet:3:3 ran multiple times</>
  ! <red>script.janet:3:3 ran multiple times</>
  ! <red>script.janet:3:3 did not run</>
  ! 
  ! 0 passed 1 failed 1 unreachable
  [1]

  $ cat script.janet
  (use judge)
  (for i 0 5
    (test (+ 1 1) 2))
