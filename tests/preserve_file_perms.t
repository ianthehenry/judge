  $ source $TESTDIR/scaffold

Accepting changes on a file preserves the permissions on that file:

  $ use test.janet <<EOF
  > #!/usr/bin/env janet
  > (use judge)
  > (test 1 2)
  > EOF

  $ chmod 523 test.janet
  $ ls -l test.janet | cut -d ' ' -f 1
  -r-x-w--wx

  $ judge test.janet --accept >/dev/null
  [1]

  $ ls -l test.janet | cut -d ' ' -f 1
  -r-x-w--wx
