  $ source $TESTDIR/scaffold

Exported symbols:

  $ use <<EOF
  > (loop [[sym entry]
  >        :pairs (require "judge")
  >        :when (table? entry)
  >        :let [{:private private} entry]
  >        :when (and (symbol? sym) (not private))]
  >   (pp sym))
  > EOF
  $ run
  expect
  deftest
  expect-error
  test
  main
  ! 0 passed 0 failed 0 excluded 0 skipped
