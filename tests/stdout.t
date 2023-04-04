  $ source $TESTDIR/scaffold

test-stdout:

  $ use <<EOF
  > (use judge)
  > (test-stdout (print "hi"))
  > EOF

  $ judge script.janet -a
  ! <dim># script.janet</>
  ! 
  ! <red>(test-stdout (print "hi"))</>
  ! <grn>(test-stdout (print "hi") `
  !   hi
  ! `)</>
  ! 
  ! 0 passed 1 failed
  [1]

  $ cat script.janet
  (use judge)
  (test-stdout (print "hi") `
    hi
  `)

  $ judge
  ! <dim># script.janet</>
  ! 
  ! 1 passed

test-stdout includes value if it's not nil:

  $ use <<EOF
  > (use judge)
  > (test-stdout (do (print "hi") 1))
  > EOF

  $ judge script.janet -a
  ! <dim># script.janet</>
  ! 
  ! <red>(test-stdout (do (print "hi") 1))</>
  ! <grn>(test-stdout (do (print "hi") 1) `
  !   hi
  ! ` 1)</>
  ! 
  ! 0 passed 1 failed
  [1]

  $ cat script.janet
  (use judge)
  (test-stdout (do (print "hi") 1) `
    hi
  ` 1)
  $ judge
  ! <dim># script.janet</>
  ! 
  ! 1 passed

test-stdout indents output correctly:

  $ use <<EOF
  > (use judge)
  > (deftest "indentation test"
  >   (test-stdout (do (print "hi") 1)))
  > EOF

  $ judge script.janet -a
  ! <dim># script.janet</>
  ! 
  ! (deftest "indentation test"
  !   <red>(test-stdout (do (print "hi") 1))</>
  !   <grn>(test-stdout (do (print "hi") 1) `
  !     hi
  !   ` 1)</>)
  ! 
  ! 0 passed 1 failed
  [1]

  $ cat script.janet
  (use judge)
  (deftest "indentation test"
    (test-stdout (do (print "hi") 1) `
      hi
    ` 1))

  $ judge
  ! <dim># script.janet</>
  ! 
  ! 1 passed

Trailing newline is always added, due to craziness of the Janet backtick string parser:

  $ use <<EOF
  > (use judge)
  > (defn greet []
  >   (print "hi") 
  >   (prin "bye"))
  > (deftest "indentation test"
  >   (test-stdout (greet)))
  > (test-stdout (greet))
  > EOF

  $ judge script.janet -a
  ! <dim># script.janet</>
  ! 
  ! (deftest "indentation test"
  !   <red>(test-stdout (greet))</>
  !   <grn>(test-stdout (greet) `
  !     hi
  !     bye
  !   `)</>)
  ! 
  ! <red>(test-stdout (greet))</>
  ! <grn>(test-stdout (greet) `
  !   hi
  !   bye
  ! `)</>
  ! 
  ! 0 passed 2 failed
  [1]

  $ cat script.janet
  (use judge)
  (defn greet []
    (print "hi") 
    (prin "bye"))
  (deftest "indentation test"
    (test-stdout (greet) `
      hi
      bye
    `))
  (test-stdout (greet) `
    hi
    bye
  `)

  $ judge
  ! <dim># script.janet</>
  ! 
  ! 2 passed

Quotes with a sufficient number of backticks:

  $ use <<EOF
  > (use judge)
  > (deftest "indentation test"
  >   (test-stdout (do (print "\`\`hi\`") (prin "b\`\`\`\`ye"))))
  > EOF

  $ judge script.janet -a
  ! <dim># script.janet</>
  ! 
  ! (deftest "indentation test"
  !   <red>(test-stdout (do (print "``hi`") (prin "b````ye")))</>
  !   <grn>(test-stdout (do (print "``hi`") (prin "b````ye")) `````
  !     ``hi`
  !     b````ye
  !   `````)</>)
  ! 
  ! 0 passed 1 failed
  [1]

  $ cat script.janet
  (use judge)
  (deftest "indentation test"
    (test-stdout (do (print "``hi`") (prin "b````ye")) `````
      ``hi`
      b````ye
    `````))

  $ judge
  ! <dim># script.janet</>
  ! 
  ! 1 passed

