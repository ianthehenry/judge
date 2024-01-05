  $ source $TESTDIR/scaffold

Floats always round-trip:

  $ use <<EOF
  > (use judge)
  > (test (/ 1 3))
  > EOF
  $ judge -a
  ! <dim># script.janet</>
  ! 
  ! <red>(test (/ 1 3))</>
  ! <grn>(test (/ 1 3) 0.33333333333333331)</>
  ! 
  ! 0 passed 1 failed
  [1]
  $ judge
  ! <dim># script.janet</>
  ! 
  ! 1 passed

Floats don't round-trip with unnecessary precision:

  $ use <<EOF
  > (use judge)
  > (test 10.001)
  > EOF
  $ judge -a
  ! <dim># script.janet</>
  ! 
  ! <red>(test 10.001)</>
  ! <grn>(test 10.001 10.001)</>
  ! 
  ! 0 passed 1 failed
  [1]
  $ judge
  ! <dim># script.janet</>
  ! 
  ! 1 passed

Various precision tests

  $ use <<EOF
  > (use judge)
  > (test (math/sqrt 2))
  > (test (math/sqrt 5))
  > (test (* 1e-5 (math/sqrt 5)))
  > (test 1e100)
  > (test 1e-100)
  > (test 1e100)
  > (test 1e-1000)
  > (test 1e1000)
  > (test -1e1000)
  > (test math/pi)
  > (test (- 1 0.1))
  > (test (/ 0 0))
  > EOF
  $ judge -a
  ! <dim># script.janet</>
  ! 
  ! <red>(test (math/sqrt 2))</>
  ! <grn>(test (math/sqrt 2) 1.4142135623730951)</>
  ! 
  ! <red>(test (math/sqrt 5))</>
  ! <grn>(test (math/sqrt 5) 2.23606797749979)</>
  ! 
  ! <red>(test (* 1e-5 (math/sqrt 5)))</>
  ! <grn>(test (* 1e-5 (math/sqrt 5)) 2.23606797749979e-05)</>
  ! 
  ! <red>(test 1e100)</>
  ! <grn>(test 1e100 1e+100)</>
  ! 
  ! <red>(test 1e-100)</>
  ! <grn>(test 1e-100 1e-100)</>
  ! 
  ! <red>(test 1e100)</>
  ! <grn>(test 1e100 1e+100)</>
  ! 
  ! <red>(test 1e-1000)</>
  ! <grn>(test 1e-1000 0)</>
  ! 
  ! <red>(test 1e1000)</>
  ! <grn>(test 1e1000 9e999)</>
  ! 
  ! <red>(test -1e1000)</>
  ! <grn>(test -1e1000 -9e999)</>
  ! 
  ! <red>(test math/pi)</>
  ! <grn>(test math/pi 3.1415926535897931)</>
  ! 
  ! <red>(test (- 1 0.1))</>
  ! <grn>(test (- 1 0.1) 0.9)</>
  ! 
  ! <red>(test (/ 0 0))</>
  ! <grn>(test (/ 0 0) math/nan)</>
  ! 
  ! 0 passed 12 failed
  [1]
  $ judge
  ! <dim># script.janet</>
  ! 
  ! 12 passed
