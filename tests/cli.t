  $ source $TESTDIR/scaffold

Exported symbols:

  $ use test.janet <<<''
  $ run test.janet --help
  usage: test.janet [option] ... 
  
  Runs matching tests. If no tests are added explicitly, all tests are added.
  
   Optional:
   -a, --accept                                overwrite files with .corrected files
       --at VALUE                              add a test by file:line:col
   -h, --help                                  Show this help message.
       --name VALUE                            add a test by name (prefix match)
       --name-exact VALUE                      add a test by name (exact match)
       --not-at VALUE                          remove a test by file:line:col
       --not-name VALUE                        remove a test by name (prefix match)
       --not-name-exact VALUE                  remove a test by name (exact match)
  
  ! error: expected string|symbol|keyword|array|tuple|table|struct|buffer, got nil
  !   in get-arg [jpm_tree/lib/judge/runner.janet] on line 154, column 9
  !   in run-tests [jpm_tree/lib/judge/runner.janet] (tailcall) on line 156, column 31
  !   in run-main [boot.janet] on line 3795, column 16
  !   in cli-main [boot.janet] on line 3940, column 17
  [1]

  $ use test.janet <<EOF
  > (test "first"
  >   (expect 1 1))
  > (test "second"
  >   (expect 1 1))
  > EOF

Runs everything by default:

  $ run test.janet
  ! running test: first
  ! running test: second
  ! 2 passed 0 failed 0 excluded 0 skipped

Name matches prefix:

  $ run test.janet --name fir
  ! running test: first
  ! 1 passed 0 failed 1 excluded 0 skipped

Name exact does not match prefix:

  $ run test.janet --name-exact fir
  ! 0 passed 0 failed 2 excluded 0 skipped

At:

  $ run test.janet --at test.janet:1:1
  ! running test: first
  ! 1 passed 0 failed 1 excluded 0 skipped

At should work for any position in between start and end:

  $ run test.janet --at test.janet:1:20
  ! running test: first
  ! 1 passed 0 failed 1 excluded 0 skipped

TODO: this is a weird bug
At should work for any position even if it exceeds the length of the file:

  $ run test.janet --at test.janet:1:100
  ! 0 passed 0 failed 2 excluded 0 skipped

You can exclude files:

  $ run test.janet --not-name first
  ! running test: second
  ! 1 passed 0 failed 1 excluded 0 skipped

Accepting tests overwrites the file:

  $ use test.janet <<EOF
  > (test "test"
  >   (expect 1))
  > EOF

  $ run test.janet -a
  ! running test: test
  ! <red>- (expect 1)</>
  ! <grn>+ (expect 1 1)</>
  ! 0 passed 1 failed 0 excluded 0 skipped
  [1]
  $ show_file test.janet
  (test "test"
    (expect 1 1))
