  $ source $TESTDIR/scaffold

Custom macros can wrap test:

  $ use <<EOF
  > (use judge)
  > (defmacro* test-loudly [exp & args]
  >   ~(test (string/ascii-upper ,exp) ,;args))
  > (test-loudly "hi")
  > EOF
  $ judge
  ! <dim># script.janet</>
  ! 
  ! <red>(test-loudly "hi")</>
  ! <grn>(test-loudly "hi" "HI")</>
  ! 
  ! 0 passed 1 failed
  [1]

Custom macros can wrap test-stdout:

  $ use <<EOF
  > (use judge)
  > (defmacro* test-greeting [name & args]
  >   ~(test-stdout (do (prin "hello ") (print ,name)) ,;args))
  > (deftest "indentation test"
  >   (test-greeting "name"))
  > (test-greeting "name")
  > EOF

  $ judge script.janet -a
  ! <dim># script.janet</>
  ! 
  ! (deftest "indentation test"
  !   <red>(test-greeting "name")</>
  !   <grn>(test-greeting "name" `
  !     hello name
  !   `)</>)
  ! 
  ! <red>(test-greeting "name")</>
  ! <grn>(test-greeting "name" `
  !   hello name
  ! `)</>
  ! 
  ! 0 passed 2 failed
  [1]

  $ cat script.janet
  (use judge)
  (defmacro* test-greeting [name & args]
    ~(test-stdout (do (prin "hello ") (print ,name)) ,;args))
  (deftest "indentation test"
    (test-greeting "name" `
      hello name
    `))
  (test-greeting "name" `
    hello name
  `)

  $ judge
  ! <dim># script.janet</>
  ! 
  ! 2 passed
