  $ source $TESTDIR/scaffold

test-macro:

  $ use <<EOF
  > (use judge)
  > (test-macro (let [x 1] x))
  > EOF

  $ judge script.janet
  ! <dim># script.janet</>
  ! 
  ! <red>(test-macro (let [x 1] x))</>
  ! <grn>(test-macro (let [x 1] x)
  !   (do
  !     (def x 1)
  !     x))</>
  ! 
  ! 0 passed 1 failed
  [1]

  $ cat script.janet.tested
  (use judge)
  (test-macro (let [x 1] x)
    (do
      (def x 1)
      x))

test-macro simplifies gensyms:

  $ use <<EOF
  > (use judge)
  > (test-macro (each x x))
  > EOF

  $ judge script.janet
  ! <dim># script.janet</>
  ! 
  ! <red>(test-macro (each x x))</>
  ! <grn>(test-macro (each x x)
  !   (do
  !     (def <1> x)
  !     (var <2> (@next <1> nil))
  !     (while
  !       (@not= nil <2>)
  !       (def x (@in <1> <2>))
  !       (set <2> (@next <1> <2>)))))</>
  ! 
  ! 0 passed 1 failed
  [1]

  $ cat script.janet.tested
  (use judge)
  (test-macro (each x x)
    (do
      (def <1> x)
      (var <2> (@next <1> nil))
      (while
        (@not= nil <2>)
        (def x (@in <1> <2>))
        (set <2> (@next <1> <2>)))))

  $ mv script.janet{.tested,}
  $ judge script.janet
  ! <dim># script.janet</>
  ! 
  ! 1 passed

Macros that raise are gracefully handled:

  $ use <<EOF
  > (use judge)
  > (defmacro oh-no [] (error "oh no"))
  > (test-macro (oh-no))
  > EOF

  $ judge script.janet
  ! <dim># script.janet</>
  ! 
  ! <red># oh no</>
  ! <red>(test-macro (oh-no))</>
  ! 
  ! 0 passed 1 failed
  [1]

Macros with incorrect expansions do not insert extra newlines:

  $ use <<EOF
  > (use judge)
  > (defmacro foo [] ~(do (print "one") (print "two")))
  > (test-macro (foo)
  >   (do
  >     (print "two")
  >     (print "one")))
  > EOF

  $ judge script.janet -a
  ! <dim># script.janet</>
  ! 
  ! <red>(test-macro (foo)
  !   (do
  !     (print "two")
  !     (print "one")))</>
  ! <grn>(test-macro (foo)
  !   (do
  !     (print "one")
  !     (print "two")))</>
  ! 
  ! 0 passed 1 failed
  [1]

  $ cat script.janet
  (use judge)
  (defmacro foo [] ~(do (print "one") (print "two")))
  (test-macro (foo)
    (do
      (print "one")
      (print "two")))

Macros with crazy formatting do not keep crazy formatting after correction:

  $ use <<EOF
  > (use judge)
  > (defmacro foo [] ~(do (print "one") (print "two")))
  > (test-macro (foo) (do      
  > (print "two")
  >         (print "one")))
  > EOF

  $ judge script.janet -a
  ! <dim># script.janet</>
  ! 
  ! <red>(test-macro (foo) (do      
  ! (print "two")
  !         (print "one")))</>
  ! <grn>(test-macro (foo)
  !   (do
  !     (print "one")
  !     (print "two")))</>
  ! 
  ! 0 passed 1 failed
  [1]

  $ cat script.janet
  (use judge)
  (defmacro foo [] ~(do (print "one") (print "two")))
  (test-macro (foo)
    (do
      (print "one")
      (print "two")))

Correct macros can keep whatever crazy formatting they want:

  $ use <<EOF
  > (use judge)
  > (defmacro foo [] ~(do (print "one") (print "two")))
  > (test-macro (foo) (do      
  > (print "one")
  >         (print "two")))
  > EOF

  $ judge script.janet -a
  ! <dim># script.janet</>
  ! 
  ! 1 passed

  $ cat script.janet
  (use judge)
  (defmacro foo [] ~(do (print "one") (print "two")))
  (test-macro (foo) (do      
  (print "one")
          (print "two")))
