  $ source $TESTDIR/scaffold

Exported symbols:

  $ use <<<'(loop [[sym val] :pairs (curenv) :when (symbol? sym)] (pp sym))'
  $ run
  expect-error
  test
  main
  expect
  deftest
  ! 0 passed 0 failed 0 excluded 0 skipped
