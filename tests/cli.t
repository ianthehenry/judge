  $ source $TESTDIR/scaffold

Usage:

  $ judge --help
  Test runner for Judge.
  
    judge [FILE[:LINE:COL]]...
  
  If no targets are given on the command line, Judge will look for tests in the
  current working directory.
  
  Targets can be file names, directory names, or FILE:LINE:COL to run a test at a
  specific location (which is mostly useful for editor tooling).
  
  === flags ===
  
    [--help]                   : Print this help text and exit
    [-a], [--accept]           : overwrite all source files with .tested files
    [--not FILE[:LINE:COL]]... : skip all tests in this target
    [-i], [--interactive]      : select which replacements to include
    [--not-name-exact NAME]... : skip tests whose name is exactly this prefix
    [--name-exact NAME]...     : only run tests with this exact name
    [--not-name PREFIX]...     : skip tests whose name starts with this prefix
    [--name PREFIX]...         : only run tests whose name starts with the given
                                 prefix
    [--color], [--no-color]    : default is --color unless the NO_COLOR environment
                                 variable is set
    [-u], [--untrusting]       : re-evaluate all trust expressions
    [-v], [--verbose]          : verbose output

  $ use test.janet <<EOF
  > (use judge)
  > (deftest "first"
  >   (test 1 1))
  > (deftest "second"
  >   (test 1 1))
  > EOF

Runs everything by default:

  $ judge test.janet -v
  ! <dim># test.janet</>
  ! running test: first
  ! running test: second
  ! 
  ! 2 passed

Name matches prefix:

  $ judge test.janet --name fir -v
  ! <dim># test.janet</>
  ! running test: first
  ! 
  ! 1 passed 1 skipped

Name exact does not match prefix:

  $ judge test.janet --name-exact fir -v
  ! 
  ! 0 passed 2 skipped
  [1]

At:

  $ judge test.janet:2:1 -v
  ! <dim># test.janet</>
  ! running test: first
  ! 
  ! 1 passed 1 skipped

At should work for any position in between start and end:

  $ judge test.janet:2:20 -v
  ! <dim># test.janet</>
  ! running test: first
  ! 
  ! 1 passed 1 skipped

TODO: this is a weird bug
At should work for any column position even if it exceeds the length of the file:

  $ judge test.janet:1:1000 -v
  ! 
  ! 0 passed 2 skipped
  [1]

You can exclude tests:

  $ judge test.janet --not-name first -v
  ! <dim># test.janet</>
  ! running test: second
  ! 
  ! 1 passed 1 skipped

Accepting tests overwrites the file:

  $ use test.janet <<EOF
  > (use judge)
  > (deftest "test"
  >   (test 1))
  > EOF

  $ judge test.janet -a
  ! <dim># test.janet</>
  ! 
  ! (deftest "test"
  !   <red>(test 1)</>
  !   <grn>(test 1 1)</>)
  ! 
  ! 0 passed 1 failed
  [1]
  $ cat test.janet
  (use judge)
  (deftest "test"
    (test 1 1))

Does not traverse hidden files or folders:

  $ rm *.janet
  $ mkdir .hidden

  $ cat >.hidden/hello.janet <<EOF
  > (use judge)
  > (print "hello")
  > (test 1 1)
  > EOF

  $ cat >.foo.janet <<EOF
  > (use judge)
  > (print "hidden file")
  > (test 1 1)
  > EOF

  $ judge
  ! 
  ! 0 passed
  [1]

  $ judge test.janet
  ! error: could not read "test.janet"
  [1]

Will run hidden files or folders by explicit request:

  $ judge .foo.janet -v
  hidden file
  ! <dim># .foo.janet</>
  ! running test: .foo.janet:3:1
  ! 
  ! 1 passed

  $ judge .hidden
  hello
  ! <dim># .hidden/hello.janet</>
  ! 
  ! 1 passed

  $ judge .hidden/hello.janet
  hello
  ! <dim># .hidden/hello.janet</>
  ! 
  ! 1 passed

Can be used as a jpm task:

  $ use test.janet <<EOF
  > (use judge)
  > (test 1 1)
  > EOF

  $ cat >project.janet <<EOF
  > (task "test" [] (shell "jpm_tree/bin/judge"))
  > EOF

  $ jpm test 2>&1 | sanitize
  <dim># test.janet</>
  
  1 passed

Files that are only imported are not tested:

  $ use util.janet <<EOF
  > (use judge)
  > (deftest "invisible" (test 1 1))
  > EOF

  $ use test.janet <<EOF
  > (use judge)
  > (use ./util)
  > (deftest "first"
  >   (test 1 1))
  > (deftest "second"
  >   (test 1 1))
  > EOF

  $ judge -v
  ! <dim># util.janet</>
  ! running test: invisible
  ! <dim># test.janet</>
  ! running test: first
  ! running test: second
  ! 
  ! 3 passed
  $ judge -v test.janet
  ! <dim># test.janet</>
  ! running test: first
  ! running test: second
  ! 
  ! 2 passed

Explicit file exclusion:

  $ judge --not util.janet -v
  ! <dim># test.janet</>
  ! running test: first
  ! running test: second
  ! 
  ! 2 passed 1 skipped

Explicit test exclusion:

  $ judge --not test.janet:5:1 -v
  ! <dim># util.janet</>
  ! running test: invisible
  ! 
  ! 1 passed

Excluded files will not even by evaluated:

  $ use erroneous.janet <<EOF
  > this file cannot compile
  > EOF

  $ judge -v 2>&1 | head -n1
  ! error: erroneous.janet:1:1: compile error: unknown symbol this
  [2]
  $ judge --not erroneous.janet -v
  ! <dim># util.janet</>
  ! running test: invisible
  ! <dim># test.janet</>
  ! running test: first
  ! running test: second
  ! 
  ! 3 passed

foo and ./foo are the same path:

  $ use foo.janet <<EOF
  > (use judge)
  > (test (+ 1 1))
  > EOF

  $ judge foo.janet ./foo.janet
  ! <dim># foo.janet</>
  ! 
  ! <red>(test (+ 1 1))</>
  ! <grn>(test (+ 1 1) 2)</>
  ! 
  ! 0 passed 1 failed
  [1]

