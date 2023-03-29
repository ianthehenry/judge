  $ source $TESTDIR/scaffold

Exported symbols:

  $ use <<EOF
  > (each sym (sort (seq [[sym entry]
  >        :pairs (require "judge")
  >        :when (table? entry)
  >        :let [{:private private} entry]
  >        :when (and (symbol? sym) (not private))] sym))
  >   (pp sym))
  > EOF
  $ run
  deftest
  deftest-type
  deftest:
  test
  test-error
  test-macro
  test-stdout

Installed files:

  $ tree jpm_tree
  jpm_tree
  |-- bin
  |   `-- judge
  |-- lib
  |   |-- cmd
  |   |   |-- arg-parser.janet
  |   |   |-- bridge.janet
  |   |   |-- help.janet
  |   |   |-- init.janet
  |   |   |-- param-parser.janet
  |   |   `-- util.janet
  |   `-- judge
  |       |-- colorize.janet
  |       |-- init.janet
  |       |-- rewriter.janet
  |       |-- runner.janet
  |       |-- shared.janet
  |       `-- util.janet
  `-- man
  
  5 directories, 13 files
