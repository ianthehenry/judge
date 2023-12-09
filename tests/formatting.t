  $ source $TESTDIR/scaffold

Named functions and cfunctions become `@`-prefixed symbols:

  $ use <<EOF
  > (use judge)
  > (test pos?)
  > (test int?)
  > EOF
  $ judge -a
  ! <dim># script.janet</>
  ! 
  ! <red>(test pos?)</>
  ! <grn>(test pos? @pos?)</>
  ! 
  ! <red>(test int?)</>
  ! <grn>(test int? @int?)</>
  ! 
  ! 0 passed 2 failed
  [1]
  $ judge
  ! <dim># script.janet</>
  ! 
  ! 2 passed

Pointers are replaced with unique strings:

  $ use <<EOF
  > (use judge)
  > (test (fn []))
  > (test (peg/compile "a"))
  > (def x (peg/compile "a"))
  > (test [x x (peg/compile "a") x])
  > EOF
  $ judge -a
  ! <dim># script.janet</>
  ! 
  ! <red>(test (fn []))</>
  ! <grn>(test (fn []) "<function 0x1>")</>
  ! 
  ! <red>(test (peg/compile "a"))</>
  ! <grn>(test (peg/compile "a") "<core/peg 0x1>")</>
  ! 
  ! <red>(test [x x (peg/compile "a") x])</>
  ! <grn>(test [x x (peg/compile "a") x]
  !   ["<core/peg 0x1>"
  !    "<core/peg 0x1>"
  !    "<core/peg 0x2>"
  !    "<core/peg 0x1>"])</>
  ! 
  ! 0 passed 3 failed
  [1]

Distinguishes mutable and immutable types:

  $ use <<EOF
  > (use judge)
  > (test "a")
  > (test @"a")
  > (test {:a 1})
  > (test @{:a 1})
  > EOF
  $ judge -a
  ! <dim># script.janet</>
  ! 
  ! <red>(test "a")</>
  ! <grn>(test "a" "a")</>
  ! 
  ! <red>(test @"a")</>
  ! <grn>(test @"a" @"a")</>
  ! 
  ! <red>(test {:a 1})</>
  ! <grn>(test {:a 1} {:a 1})</>
  ! 
  ! <red>(test @{:a 1})</>
  ! <grn>(test @{:a 1} @{:a 1})</>
  ! 
  ! 0 passed 4 failed
  [1]

Tuples render with brackets:

  $ use <<EOF
  > (use judge)
  > (test [1 2 3])
  > EOF
  $ judge
  ! <dim># script.janet</>
  ! 
  ! <red>(test [1 2 3])</>
  ! <grn>(test [1 2 3] [1 2 3])</>
  ! 
  ! 0 passed 1 failed
  [1]

Nested tuples still render with brackets:

  $ use <<EOF
  > (use judge)
  > (test [1 [2] 3])
  > EOF
  $ judge
  ! <dim># script.janet</>
  ! 
  ! <red>(test [1 [2] 3])</>
  ! <grn>(test [1 [2] 3] [1 [2] 3])</>
  ! 
  ! 0 passed 1 failed
  [1]

Arrays and other @-prefixed forms don't correct incorrectly:

  $ use <<EOF
  > (use judge)
  > (test @[1 2 3] @[1 2])
  > (test @[1 2] [1 2])
  > (test [1 2] @[1 2])
  > (test @{1 2 3 4} @[1 2])
  > (test @"1 2 3" @[1 2])
  > EOF
  $ judge
  ! <dim># script.janet</>
  ! 
  ! <red>(test @[1 2 3] @[1 2])</>
  ! <grn>(test @[1 2 3] @[1 2 3])</>
  ! 
  ! <red>(test @[1 2] [1 2])</>
  ! <grn>(test @[1 2] @[1 2])</>
  ! 
  ! <red>(test [1 2] @[1 2])</>
  ! <grn>(test [1 2] [1 2])</>
  ! 
  ! <red>(test @{1 2 3 4} @[1 2])</>
  ! <grn>(test @{1 2 3 4} @{1 2 3 4})</>
  ! 
  ! <red>(test @"1 2 3" @[1 2])</>
  ! <grn>(test @"1 2 3" @"1 2 3")</>
  ! 
  ! 0 passed 5 failed
  [1]

Does not distinguish bracketed tuples:

  $ use <<EOF
  > (use judge)
  > (test [1 '[2] 3])
  > EOF
  $ judge -a
  ! <dim># script.janet</>
  ! 
  ! <red>(test [1 '[2] 3])</>
  ! <grn>(test [1 '[2] 3] [1 [2] 3])</>
  ! 
  ! 0 passed 1 failed
  [1]
  $ judge
  ! <dim># script.janet</>
  ! 
  ! 1 passed

Long output starts on its own line:

  $ use <<EOF
  > (use judge)
  > (test (array/new-filled 10 100))
  > (test 
  >   (array/new-filled 10 100))
  > EOF
  $ judge >/dev/null
  [1]
  $ show_tested
  (use judge)
  (test (array/new-filled 10 100)
    @[100
      100
      100
      100
      100
      100
      100
      100
      100
      100])
  (test 
    (array/new-filled 10 100)
    @[100
      100
      100
      100
      100
      100
      100
      100
      100
      100])

Number of backticks does not affect the indentation of subsequent forms using the stdout printer:

  $ use <<EOF
  > (use judge)
  > (test-stdout (do (print "\`\`\`") (array/new-filled 10 100)))
  > EOF
  $ judge >/dev/null
  [1]
  $ show_tested
  (use judge)
  (test-stdout (do (print "```") (array/new-filled 10 100)) ````
    ```
  ````
    @[100
      100
      100
      100
      100
      100
      100
      100
      100
      100])

Short output starts on its own line iff the test form spans multiple lines:

  $ use <<EOF
  > (use judge)
  > (test [1 2 3])
  > (test [1 2 3
  >  ])
  > (test
  >   [1 2 3])
  > EOF
  $ judge >/dev/null
  [1]
  $ show_tested
  (use judge)
  (test [1 2 3] [1 2 3])
  (test [1 2 3
   ]
    [1 2 3])
  (test
    [1 2 3]
    [1 2 3])
