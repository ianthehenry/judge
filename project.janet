(declare-project
  :name "judge"
  :author "Ian Henry <ianthehenry@gmail.com>"
  :description "Self-modifying test framework"
  :license "MIT"
  :url "https://github.com/ianthehenry/judge"
  :repo "git+https://github.com/ianthehenry/judge"
  :dependencies [
    {:url "https://github.com/ianthehenry/cmd"
     :tag "v1.1.0"}
  ])

(declare-source
  :prefix "judge"
  :source [
    "src/fmt.janet"
    "src/shared.janet"
    "src/colorize.janet"
    "src/init.janet"
    "src/rewriter.janet"
    "src/runner.janet"
    "src/util.janet"
  ])

(declare-binscript :main "src/judge"
  :hardcode-syspath true)
