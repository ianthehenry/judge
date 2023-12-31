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
  !     (while (@not= nil <2>)
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
      (while (@not= nil <2>)
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
  ! <red># error: oh no
  ! #   in oh-no [script.janet] (tailcall) on line LINE, column COL
  ! #   in macex1 [boot.janet] on line LINE, column COL
  ! #   in <anonymous> [script.janet] on line 3, column 1</>
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

Smartish macro formatting:

  $ use <<EOF
  > (use judge)
  > (defmacro foo [] ~(do 
  >   (coro one two three)
  >   (for i 0 3 (print i))
  >   (while true (print "hi"))
  >   (three)))
  > (test-macro (foo))
  > EOF

  $ judge script.janet -a
  ! <dim># script.janet</>
  ! 
  ! <red>(test-macro (foo))</>
  ! <grn>(test-macro (foo)
  !   (do
  !     (coro
  !       one
  !       two
  !       three)
  !     (for i 0 3
  !       (print i))
  !     (while true
  !       (print "hi"))
  !     (three)))</>
  ! 
  ! 0 passed 1 failed
  [1]

Custom macros can control how they're pretty-printed with metadata:

  $ use <<EOF
  > (use judge)
  > (defmacro foo [] ~(scope one two three))
  > (defmacro scope [exprs] ~(do ,;exprs))
  > (test-macro (foo))
  > (defmacro scope :fmt/block [exprs] ~(do ,;exprs))
  > (test-macro (foo))
  > (defmacro scope :fmt/control [exprs] ~(do ,;exprs))
  > (test-macro (foo))
  > EOF

  $ judge script.janet -a
  ! <dim># script.janet</>
  ! 
  ! <red>(test-macro (foo))</>
  ! <grn>(test-macro (foo)
  !   (scope one two three))</>
  ! 
  ! <red>(test-macro (foo))</>
  ! <grn>(test-macro (foo)
  !   (scope
  !     one
  !     two
  !     three))</>
  ! 
  ! <red>(test-macro (foo))</>
  ! <grn>(test-macro (foo)
  !   (scope one
  !     two
  !     three))</>
  ! 
  ! 0 passed 3 failed
  [1]

Judge attempts to peer through as-macro to find macro metadata:

  $ use <<EOF
  > (use judge)
  > (defmacro scope [exprs] ~(do ,;exprs))
  > (defmacro foo [] ~(as-macro ,scope one two three))
  > (test-macro (foo))
  > (defmacro scope :fmt/block [exprs] ~(do ,;exprs))
  > (test-macro (foo))
  > EOF

  $ judge script.janet -a
  ! <dim># script.janet</>
  ! 
  ! <red>(test-macro (foo))</>
  ! <grn>(test-macro (foo)
  !   (as-macro @scope one two three))</>
  ! 
  ! <red>(test-macro (foo))</>
  ! <grn>(test-macro (foo)
  !   (as-macro @scope
  !     one
  !     two
  !     three))</>
  ! 
  ! 0 passed 2 failed
  [1]
