  $ source $TESTDIR/scaffold

Named functions and cfunctions become `@`-prefixed symbols:

  $ use <<EOF
  > (use judge)
  > (test pos?)
  > (test int?)
  > EOF
  $ judge -a
  ! running test: script.janet:2:1
  ! <red>- (test pos?)</>
  ! <grn>+ (test pos? @pos?)</>
  ! running test: script.janet:3:1
  ! <red>- (test int?)</>
  ! <grn>+ (test int? @int?)</>
  ! 0 passed 2 failed 0 skipped 0 unreachable
  [1]
  $ judge
  ! running test: script.janet:2:1
  ! running test: script.janet:3:1
  ! 2 passed 0 failed 0 skipped 0 unreachable

Pointers are replaced with unique strings:

  $ use <<EOF
  > (use judge)
  > (test (fn []))
  > (test (peg/compile "a"))
  > (def x (peg/compile "a"))
  > (test [x x (peg/compile "a") x])
  > EOF
  $ judge -a
  ! running test: script.janet:2:1
  ! <red>- (test (fn []))</>
  ! <grn>+ (test (fn []) "<function 0x1>")</>
  ! running test: script.janet:3:1
  ! <red>- (test (peg/compile "a"))</>
  ! <grn>+ (test (peg/compile "a") "<core/peg 0x1>")</>
  ! running test: script.janet:5:1
  ! <red>- (test [x x (peg/compile "a") x])</>
  ! <grn>+ (test [x x (peg/compile "a") x] ["<core/peg 0x1>" "<core/peg 0x1>" "<core/peg 0x2>" "<core/peg 0x1>"])</>
  ! 0 passed 3 failed 0 skipped 0 unreachable
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
  ! running test: script.janet:2:1
  ! <red>- (test "a")</>
  ! <grn>+ (test "a" "a")</>
  ! running test: script.janet:3:1
  ! <red>- (test @"a")</>
  ! <grn>+ (test @"a" @"a")</>
  ! running test: script.janet:4:1
  ! <red>- (test {:a 1})</>
  ! <grn>+ (test {:a 1} {:a 1})</>
  ! running test: script.janet:5:1
  ! <red>- (test @{:a 1})</>
  ! <grn>+ (test @{:a 1} @{:a 1})</>
  ! 0 passed 4 failed 0 skipped 0 unreachable
  [1]

Tuples render with brackets:

  $ use <<EOF
  > (use judge)
  > (test [1 2 3])
  > EOF
  $ judge
  ! running test: script.janet:2:1
  ! <red>- (test [1 2 3])</>
  ! <grn>+ (test [1 2 3] [1 2 3])</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]

Nested tuples still render with brackets:

  $ use <<EOF
  > (use judge)
  > (test [1 [2] 3])
  > EOF
  $ judge
  ! running test: script.janet:2:1
  ! <red>- (test [1 [2] 3])</>
  ! <grn>+ (test [1 [2] 3] [1 [2] 3])</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]
