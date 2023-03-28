  $ source $TESTDIR/scaffold

test-macro:

  $ use <<EOF
  > (use judge)
  > (test-macro (let [x 1] x))
  > EOF

  $ judge script.janet
  ! running test: $PWD/script.janet:2:1
  ! <red>- (test-macro (let [x 1] x))</>
  ! <grn>+ (test-macro (let [x 1] x) (do (def x 1) x))</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]

  $ cat script.janet.tested
  (use judge)
  (test-macro (let [x 1] x) (do (def x 1) x))

test-macro simplifies gensyms:

  $ use <<EOF
  > (use judge)
  > (test-macro (each x x))
  > EOF

  $ judge script.janet
  ! running test: $PWD/script.janet:2:1
  ! <red>- (test-macro (each x x))</>
  ! <grn>+ (test-macro (each x x) (do (def <1> x) (var <2> ("<function next>" <1> nil)) (while ("<function not=>" nil <2>) (def x ("<function in>" <1> <2>)) (set <2> ("<function next>" <1> <2>)))))</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]

  $ cat script.janet.tested
  (use judge)
  (test-macro (each x x) (do (def <1> x) (var <2> ("<function next>" <1> nil)) (while ("<function not=>" nil <2>) (def x ("<function in>" <1> <2>)) (set <2> ("<function next>" <1> <2>)))))

  $ mv script.janet{.tested,}
  $ judge script.janet
  ! running test: $PWD/script.janet:2:1
  ! <red>- (test-macro (each x x) (do (def <1> x) (var <2> ("<function next>" <1> nil)) (while ("<function not=>" nil <2>) (def x ("<function in>" <1> <2>)) (set <2> ("<function next>" <1> <2>)))))</>
  ! <grn>+ (test-macro (each x x) (do (def <1> x) (var <2> ("<function next>" <1> nil)) (while ("<function not=>" nil <2>) (def x ("<function in>" <1> <2>)) (set <2> ("<function next>" <1> <2>)))))</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]

Macros that raise are gracefully handled:

  $ use <<EOF
  > (use judge)
  > (defmacro oh-no [] (error "oh no"))
  > (test-macro (oh-no))
  > EOF

  $ judge script.janet
  ! running test: $PWD/script.janet:3:1
  ! <red>oh no</>
  ! <red>- (test-macro (oh-no))</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]
