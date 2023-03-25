(declare-project
  :name "judge"
  :author "Ian Henry <ianthehenry@gmail.com>"
  :description "Self-modifying test framework"
  :license "MIT"
  :url "https://github.com/ianthehenry/judge"
  :repo "git+https://github.com/ianthehenry/judge"
  :dependencies ["https://github.com/janet-lang/argparse"])

(declare-source
  :prefix "judge"
  :source [
    "src/colorize.janet"
    "src/init.janet"
    "src/rewriter.janet"
    "src/runner.janet"
    "src/util.janet"
  ])
