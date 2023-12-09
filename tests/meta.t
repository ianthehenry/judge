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
  defmacro*
  deftest
  deftest-type
  deftest:
  test
  test-error
  test-macro
  test-stdout
  trust

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
  |       |-- fmt.janet
  |       |-- init.janet
  |       |-- rewriter.janet
  |       |-- runner.janet
  |       |-- shared.janet
  |       `-- util.janet
  `-- man
  
  6 directories, 14 files
