  $ source $TESTDIR/scaffold

Functions become strings:

  $ use <<EOF
  > (use judge)
  > (test pos?)
  > EOF
  $ judge -a
  ! running test: $PWD/script.janet:2:1
  ! <red>- (test pos?)</>
  ! <grn>+ (test pos? "<function pos?>")</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]
  $ judge
  ! running test: $PWD/script.janet:2:1
  ! 1 passed 0 failed 0 skipped 0 unreachable

Pointers are replaced with unique strings:

  $ use <<EOF
  > (use judge)
  > (test (fn []))
  > (test (peg/compile "a"))
  > (def x (peg/compile "a"))
  > (test [x x (peg/compile "a") x])
  > EOF
  $ judge -a
  ! running test: $PWD/script.janet:2:1
  ! <red>- (test (fn []))</>
  ! <grn>+ (test (fn []) "<function 0x1>")</>
  ! running test: $PWD/script.janet:3:1
  ! <red>- (test (peg/compile "a"))</>
  ! <grn>+ (test (peg/compile "a") "<core/peg 0x1>")</>
  ! running test: $PWD/script.janet:5:1
  ! <red>- (test [x x (peg/compile "a") x])</>
  ! <grn>+ (test [x x (peg/compile "a") x] ["<core/peg 0x1>" "<core/peg 0x1>" "<core/peg 0x2>" "<core/peg 0x1>"])</>
  ! 0 passed 3 failed 0 skipped 0 unreachable
  [1]
