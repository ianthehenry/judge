  $ source $TESTDIR/scaffold

test-stdout:

  $ use <<EOF
  > (use judge)
  > (test-stdout (print "hi"))
  > EOF

  $ judge script.janet -a
  ! running test: $PWD/script.janet:2:1
  ! <red>- (test-stdout (print "hi"))</>
  ! <grn>+ (test-stdout (print "hi") `
  ! +   hi
  ! + `)</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]

  $ cat script.janet
  (use judge)
  (test-stdout (print "hi") `
    hi
  `)

  $ judge
  ! running test: $PWD/script.janet:2:1
  ! 1 passed 0 failed 0 skipped 0 unreachable

test-stdout includes value if it's not nil:

  $ use <<EOF
  > (use judge)
  > (test-stdout (do (print "hi") 1))
  > EOF

  $ judge script.janet -a
  ! running test: $PWD/script.janet:2:1
  ! <red>- (test-stdout (do (print "hi") 1))</>
  ! <grn>+ (test-stdout (do (print "hi") 1) 1 `
  ! +   hi
  ! + `)</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]

  $ cat script.janet
  (use judge)
  (test-stdout (do (print "hi") 1) 1 `
    hi
  `)
  $ judge
  ! running test: $PWD/script.janet:2:1
  ! 1 passed 0 failed 0 skipped 0 unreachable

test-stdout indents output correctly:

  $ use <<EOF
  > (use judge)
  > (deftest "indentation test"
  >   (test-stdout (do (print "hi") 1)))
  > EOF

  $ judge script.janet -a
  ! running test: indentation test
  ! <red>- (test-stdout (do (print "hi") 1))</>
  ! <grn>+ (test-stdout (do (print "hi") 1) 1 `
  ! +     hi
  ! +   `)</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]

  $ cat script.janet
  (use judge)
  (deftest "indentation test"
    (test-stdout (do (print "hi") 1) 1 `
      hi
    `))

  $ judge
  ! running test: indentation test
  ! 1 passed 0 failed 0 skipped 0 unreachable

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
  ! running test: indentation test
  ! <red>- (test-stdout (greet))</>
  ! <grn>+ (test-stdout (greet) `
  ! +     hi
  ! +     bye
  ! +   `)</>
  ! running test: $PWD/script.janet:7:1
  ! <red>- (test-stdout (greet))</>
  ! <grn>+ (test-stdout (greet) `
  ! +   hi
  ! +   bye
  ! + `)</>
  ! 0 passed 2 failed 0 skipped 0 unreachable
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
  ! running test: indentation test
  ! running test: $PWD/script.janet:10:1
  ! 2 passed 0 failed 0 skipped 0 unreachable

Quotes with a sufficient number of backticks:

  $ use <<EOF
  > (use judge)
  > (deftest "indentation test"
  >   (test-stdout (do (print "\`\`hi\`") (prin "b\`\`\`\`ye"))))
  > EOF

  $ judge script.janet -a
  ! running test: indentation test
  ! <red>- (test-stdout (do (print "``hi`") (prin "b````ye")))</>
  ! <grn>+ (test-stdout (do (print "``hi`") (prin "b````ye")) `````
  ! +     ``hi`
  ! +     b````ye
  ! +   `````)</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]

  $ cat script.janet
  (use judge)
  (deftest "indentation test"
    (test-stdout (do (print "``hi`") (prin "b````ye")) `````
      ``hi`
      b````ye
    `````))

  $ judge
  ! running test: indentation test
  ! 1 passed 0 failed 0 skipped 0 unreachable

