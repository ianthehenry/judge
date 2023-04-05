  $ source $TESTDIR/scaffold

Interactive mode allows you to select which tests to patch:

  $ use <<EOF
  > (use judge)
  > (test 1)
  > (test 2)
  > EOF

  $ (echo n; echo y) | judge script.janet -i
  ! <dim># script.janet</>
  ! 
  ! <red>(test 1)</>
  ! <grn>(test 1 1)</>
  ! 
  ! Verdict? <dim>[y]naAdqQ?</> 
  ! 
  ! <red>(test 2)</>
  ! <grn>(test 2 2)</>
  ! 
  ! Verdict? <dim>[y]naAdqQ?</> 
  ! 
  ! 0 passed 2 failed
  [1]

  $ cat script.janet
  (use judge)
  (test 1)
  (test 2 2)

Default interactive response is yes:

  $ use <<EOF
  > (use judge)
  > (test 1)
  > (test 2)
  > EOF

  $ (echo; echo) | judge script.janet -i
  ! <dim># script.janet</>
  ! 
  ! <red>(test 1)</>
  ! <grn>(test 1 1)</>
  ! 
  ! Verdict? <dim>[y]naAdqQ?</> 
  ! 
  ! <red>(test 2)</>
  ! <grn>(test 2 2)</>
  ! 
  ! Verdict? <dim>[y]naAdqQ?</> 
  ! 
  ! 0 passed 2 failed
  [1]

  $ cat script.janet
  (use judge)
  (test 1 1)
  (test 2 2)

Interactive mode prompts for each test, not each expectation:

  $ use <<EOF
  > (use judge)
  > (deftest "group one"
  >   (test 1)
  >   (test 2))
  > (deftest "group two"
  >   (test 3)
  >   (test 4))
  > EOF

  $ (echo n; echo y) | judge script.janet -i
  ! <dim># script.janet</>
  ! 
  ! (deftest "group one"
  !   <red>(test 1)</>
  !   <grn>(test 1 1)</>
  !   <red>(test 2)</>
  !   <grn>(test 2 2)</>)
  ! 
  ! Verdict? <dim>[y]naAdqQ?</> 
  ! 
  ! (deftest "group two"
  !   <red>(test 3)</>
  !   <grn>(test 3 3)</>
  !   <red>(test 4)</>
  !   <grn>(test 4 4)</>)
  ! 
  ! Verdict? <dim>[y]naAdqQ?</> 
  ! 
  ! 0 passed 2 failed
  [1]

  $ cat script.janet
  (use judge)
  (deftest "group one"
    (test 1)
    (test 2))
  (deftest "group two"
    (test 3 3)
    (test 4 4))

Interactive help:

  $ use <<EOF
  > (use judge)
  > (test 1)
  > EOF

  $ (echo "?"; echo y) | judge script.janet -i
  ! <dim># script.janet</>
  ! 
  ! <red>(test 1)</>
  ! <grn>(test 1 1)</>
  ! 
  ! Verdict? <dim>[y]naAdqQ?</> 
  ! y - patch this test
  ! n - do not patch this test
  ! a - patch this and all subsequent tests in this file
  ! A - patch this and all subsequent tests in all files
  ! d - don't patch this or any subsequent tests in this file
  ! q - quit, patching any selected tests
  ! Q - abort: exit immediately without patching any files
  ! ? - print help
  ! 
  ! Verdict? <dim>[y]naAdqQ?</> 
  ! 
  ! 0 passed 1 failed
  [1]

Interactive help triggers on any unknown input:

  $ use <<EOF
  > (use judge)
  > (test 1)
  > EOF

  $ (echo "yes"; echo y) | judge script.janet -i
  ! <dim># script.janet</>
  ! 
  ! <red>(test 1)</>
  ! <grn>(test 1 1)</>
  ! 
  ! Verdict? <dim>[y]naAdqQ?</> 
  ! 
  ! 0 passed 1 failed
  [1]

Interactive [a] stops prompting for the current file only:

  $ use one.janet <<EOF
  > (use judge)
  > (test 1)
  > (test 2)
  > EOF
  $ use two.janet <<EOF
  > (use judge)
  > (test 1)
  > (test 2)
  > (test 3)
  > EOF

  $ (echo a; echo n; echo a) | judge one.janet two.janet -i
  ! <dim># one.janet</>
  ! 
  ! <red>(test 1)</>
  ! <grn>(test 1 1)</>
  ! 
  ! Verdict? <dim>[y]naAdqQ?</> 
  ! 
  ! <red>(test 2)</>
  ! <grn>(test 2 2)</>
  ! 
  ! <dim># two.janet</>
  ! 
  ! <red>(test 1)</>
  ! <grn>(test 1 1)</>
  ! 
  ! Verdict? <dim>[y]naAdqQ?</> 
  ! 
  ! <red>(test 2)</>
  ! <grn>(test 2 2)</>
  ! 
  ! Verdict? <dim>[y]naAdqQ?</> 
  ! 
  ! <red>(test 3)</>
  ! <grn>(test 3 3)</>
  ! 
  ! 0 passed 5 failed
  [1]

  $ cat one.janet
  (use judge)
  (test 1 1)
  (test 2 2)
  $ cat two.janet
  (use judge)
  (test 1)
  (test 2 2)
  (test 3 3)

Interactive [A] stops prompting for all files:

  $ use one.janet <<EOF
  > (use judge)
  > (test 1)
  > (test 2)
  > EOF
  $ use two.janet <<EOF
  > (use judge)
  > (test 1)
  > (test 2)
  > (test 3)
  > EOF

  $ (echo A) | judge one.janet two.janet -i
  ! <dim># one.janet</>
  ! 
  ! <red>(test 1)</>
  ! <grn>(test 1 1)</>
  ! 
  ! Verdict? <dim>[y]naAdqQ?</> 
  ! 
  ! <red>(test 2)</>
  ! <grn>(test 2 2)</>
  ! 
  ! <dim># two.janet</>
  ! 
  ! <red>(test 1)</>
  ! <grn>(test 1 1)</>
  ! 
  ! <red>(test 2)</>
  ! <grn>(test 2 2)</>
  ! 
  ! <red>(test 3)</>
  ! <grn>(test 3 3)</>
  ! 
  ! 0 passed 5 failed
  [1]

  $ cat one.janet
  (use judge)
  (test 1 1)
  (test 2 2)
  $ cat two.janet
  (use judge)
  (test 1 1)
  (test 2 2)
  (test 3 3)

Interactive [q] writes any staged corrections:

  $ use one.janet <<EOF
  > (use judge)
  > (test 1)
  > (test 2)
  > EOF
  $ use two.janet <<EOF
  > (use judge)
  > (test 1)
  > (test 2)
  > (test 3)
  > EOF

  $ (echo y; echo q) | judge one.janet two.janet -i
  ! <dim># one.janet</>
  ! 
  ! <red>(test 1)</>
  ! <grn>(test 1 1)</>
  ! 
  ! Verdict? <dim>[y]naAdqQ?</> 
  ! 
  ! <red>(test 2)</>
  ! <grn>(test 2 2)</>
  ! 
  ! Verdict? <dim>[y]naAdqQ?</> 
  ! 
  ! 0 passed 2 failed
  [1]

  $ cat one.janet
  (use judge)
  (test 1 1)
  (test 2)
  $ cat two.janet
  (use judge)
  (test 1)
  (test 2)
  (test 3)

Interactive [Q] stops the process immediately without writing any corrections:

  $ use one.janet <<EOF
  > (use judge)
  > (test 1)
  > (test 2)
  > EOF
  $ use two.janet <<EOF
  > (use judge)
  > (test 1)
  > (test 2)
  > (test 3)
  > EOF

  $ (echo y; echo Q) | judge one.janet two.janet -i
  ! <dim># one.janet</>
  ! 
  ! <red>(test 1)</>
  ! <grn>(test 1 1)</>
  ! 
  ! Verdict? <dim>[y]naAdqQ?</> 
  ! 
  ! <red>(test 2)</>
  ! <grn>(test 2 2)</>
  ! 
  ! Verdict? <dim>[y]naAdqQ?</> 
  [1]

  $ cat one.janet
  (use judge)
  (test 1)
  (test 2)
  $ cat two.janet
  (use judge)
  (test 1)
  (test 2)
  (test 3)

Interactive [d] stops prompting for the current file only:

  $ use one.janet <<EOF
  > (use judge)
  > (test 1)
  > (test 2)
  > (test 3)
  > EOF
  $ use two.janet <<EOF
  > (use judge)
  > (test 1)
  > (test 2)
  > (test 3)
  > EOF

  $ (echo y; echo d; echo d) | judge one.janet two.janet -i
  ! <dim># one.janet</>
  ! 
  ! <red>(test 1)</>
  ! <grn>(test 1 1)</>
  ! 
  ! Verdict? <dim>[y]naAdqQ?</> 
  ! 
  ! <red>(test 2)</>
  ! <grn>(test 2 2)</>
  ! 
  ! Verdict? <dim>[y]naAdqQ?</> 
  ! 
  ! <red>(test 3)</>
  ! <grn>(test 3 3)</>
  ! 
  ! <dim># two.janet</>
  ! 
  ! <red>(test 1)</>
  ! <grn>(test 1 1)</>
  ! 
  ! Verdict? <dim>[y]naAdqQ?</> 
  ! 
  ! <red>(test 2)</>
  ! <grn>(test 2 2)</>
  ! 
  ! <red>(test 3)</>
  ! <grn>(test 3 3)</>
  ! 
  ! 0 passed 6 failed
  [1]

  $ cat one.janet
  (use judge)
  (test 1 1)
  (test 2)
  (test 3)
  $ cat two.janet
  (use judge)
  (test 1)
  (test 2)
  (test 3)
