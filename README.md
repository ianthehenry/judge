# judge

Judge is a library for writing inline snapshot tests in [Janet](https://github.com/janet-lang/janet). You can install it with `jpm`:

```janet
# project.janet
(declare-project
  :dependencies [
    {:url "https://github.com/ianthehenry/judge.git"
     :tag "v2.8.1"}
  ])
```

Judge tests work a little differently than traditional tests. Instead of assertions, you write expressions to observe. Like this:

```janet
(test (+ 1 1))
```

When you run Judge, it will replace the source code with the result of this expression:

```janet
(test (+ 1 1) 2)
```

The Judge test runner gives you a lot flexibility over how you structure your tests. You *can* put all your tests in a `test/` subdirectory, following standard Janet convention, or you can put tests right next to the code that you're testing:

```janet
# sort.janet
(use judge)

(defn slow-sort [list]
  (case (length list)
    0 list
    1 list
    2 (let [[x y] list] [(min x y) (max x y)])
    (do
      (def pivot (in list (math/floor (/ (length list) 2))))
      (def bigs (filter |(> $ pivot) list))
      (def smalls (filter |(< $ pivot) list))
      [;(slow-sort smalls) pivot ;(slow-sort bigs)])))

(test (slow-sort [3 1 4 2]))
```

Run your tests with the Judge test runner:

```diff
$ judge
# sort.janet

- (test (slow-sort [3 1 4 2]))
+ (test (slow-sort [3 1 4 2]) [1 2 3 4])

0 passed 1 failed
```

And look! It fixed your tests:

```janet
# sort.janet.tested
(use judge)

(defn slow-sort [list]
  (case (length list)
    0 list
    1 list
    2 (let [[x y] list] [(min x y) (max x y)])
    (do
      (def pivot (in list (math/floor (/ (length list) 2))))
      (def bigs (filter |(> $ pivot) list))
      (def smalls (filter |(< $ pivot) list))
      [;(slow-sort smalls) pivot ;(slow-sort bigs)])))

(test (slow-sort [3 1 4 2]) [1 2 3 4])
```

You can then diff the `.tested` file with your original source and interactively merge them using whatever tools you are comfortable with.

Judge supports "anonymous" tests, as seen above, and named tests, which can group multiple `(test)` invocations together:

```janet
(deftest "sorting tests"
  (test (slow-sort [3 1 2 4]) [1 2 3 4])
  (test (slow-sort [1 1 1 1]) [1 1 1 1]))
```

When you aren't using the `judge` test runner, all of the macros exposed by Judge are no-ops. So these tests will never execute during normal evaluation: tests won't slow down your program, and you can freely distribute modules with Judge tests as libraries without your users even knowing.

# Usage

Judge distributes a runner executable called `judge`. When you install Judge using `jpm deps -l`, the runner script will live at `jpm_tree/bin/judge`. You can invoke it directly as `jpm_tree/bin/judge`, or you can add the local bin directory to your `PATH`:

    export PATH="./jpm_tree/bin:$PATH"

So that you can just run it as `judge`.

```
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
```

You can also add this to your `project.janet` file:

```janet
(task "test" [] (shell "jpm_tree/bin/judge"))
```

To run Judge with a normal `jpm test` invocation.

# Writing tests

## `test`

```janet
(test (+ 1 2) 3)
```

## `test-error`

Requires that the provided expression raises an error:

```janet
(test-error (in [1 2 3] 5) "expected integer key for tuple in range [0, 3), got 5")
```

## `test-stdout`

```janet
(test-stdout (print "hello") `
  hello
`)
```

If the expression to test does not evaluate to `nil`, it will be included in the test as well:

```janet
(defn add [a b]
  (printf "adding %q and %q" a b)
  (+ a b))

(test-stdout (add 1 2) `
  adding 1 and 2
` 3)
```

Due to ambiguity in the Janet parser for multi-line strings, a trailing newline will always be added to the output if it does not exist.

## `trust`

`trust` is like `test`, but the expression under test will only be evaluated if there is no expectation already. Once you accept a result, it will be re-used on all subsequent runs.

```janet
(trust (+ 1 2))
```

Will become:

```janet
(trust (+ 1 2) 3)
```

Just like `test`. But:

```janet
(trust (+ 1 2) 4)
```

Will still pass, because `trust` will not re-evaluate `(+ 1 2)` when there is already an expected value.

This is not very useful by itself, but if you save the result of the `trust` expression, you can use it to write deterministic tests against impure functions that you cache literally in your source code:

```janet
(def posts 
  (trust (download-posts-from-the-internet) 
    [{:id 4322
      :content "test post please ignore"}
     {:id 4321
      :content "is anybody here?"}]))
(test (format-posts posts)
  "1. test post please ignore\n2. is anybody here?")
```

Note that the result will be read as a quoted form.

To re-evaluate `trust` expressions, you can either delete specific expectations and re-run Judge, or run Judge with `--untrusting` to re-evaluate all `trust` expressions.

## `test-macro`

`test-macro` is like `test`ing the result of a `macex1` expression, but the output is pretty-printed according to Janet code formatting conventions:

```janet
(test-macro (let [x 1] x)
  (do
    (def x 1)
    x))
```

And `test-macro` will replace `gensym`'d identifiers with stable symbols:

```janet
(test-macro (and x (+ 1 2))
  (if (def <1> x)
    (+ 1 2)
    <1>))
```

`test-macro` tries to format its output nicely, but if you've defined custom macros that you include in the expansion of the macro that you're testing, Judge won't know how to format them correctly. For example:

```janet
(defmacro scope [exprs] ~(do ,;exprs))

(defmacro twice [expr]
  ~(scope
    ,expr
    ,expr))

(test-macro (twice (print "hello")))
```

Will produce the rather ugly:

```janet
(test-macro (twice (print "hello"))
  (scope (print "hello") (print "hello")))
```

You can fix this by applying metadata to your macro binding that tells Judge how to format it. Let's say that `scope` should format like a block by adding the `fmt/block` metadata:

```janet
(defmacro scope :fmt/block [exprs] ~(do ,;exprs))

(defmacro twice [expr]
  ~(scope
    ,expr
    ,expr))

(test-macro (twice (print "hello")))
```

That will produce the much nicer looking:

```janet
(test-macro (twice (print "hello"))
  (scope
    (print "hello")
    (print "hello")))
```

There are only two format specifiers: `fmt/block` and `fmt/control`. A "block" macro formats like `do`: the macro name is on a line of its own. A "control" macro formats like `while`: the first argument is on its own line, and all subsequent arguments are on their own lines.

## `deftest`

The first form passed to the `(deftest)` macro is the name of the test. It can be a symbol or a string:

```janet
(use judge)

(deftest math
  (test (+ 2 2) 4))

(deftest "advanced math"
  (test (* 2 2) 4))
```

You don't have to use `deftest`, though. You can create anonymous, single-expression tests by using any of the `test` macros at the top level:

```janet
(use judge)

(test (+ 1 2) 3)
```

## Custom testing macros

You can write macros that wrap any of the existing test-macros using `defmacro*`. For example:

```janet
(defmacro* test-loudly [exp & args]
  ~(test (string/ascii-upper ,exp) ,;args))

(test-loudly "hi" "HI")
```

The only difference between `defmacro` and `defmacro*` is that `defmacro*` copies the source map from the macro to its expansion, which Judge needs in order to patch code.

# Running tests

Run all tests in a particular file:

    $ judge tests.janet

Or a directory:

    $ judge tests/

Run a specific named test:

    $ judge --name 'two plus'

Run test on a specific line/column (useful for editor tooling):

    $ judge test.janet:10:2

# Context-dependent tests

Sometimes you might have a bunch of tests that all need some kind of shared context -- a SQL connection, maybe, or an OpenGL graphics context. You could create that context anew at the beginning of every test, but that might be very expensive. There are some cases where it might be appropriate to create the context a single time, and pass it in to every test of that type.

To declare a new context-dependent test type, use the `deftest-type` macro:

```janet
(deftest-type stateful
  :setup (fn [] (create-some-expensive-shared-resource))
  :reset (fn [context] (wipe-clean context))
  :teardown (fn [context] (destroy context)))
```

And to declare custom test types, use `deftest:` instead of `deftest`, like so:

```janet
(deftest: stateful "the test name" [context]
  (do-something-with context))
```

The first time Judge encounters a test declared as a `stateful` test, it will call the `:setup` function. Then it will call the `:reset` function, passing it whatever context `:setup` returned. Then it will run the test, and move on to the next test in its list of tests to run. Any time it needs to run a test declared as a `stateful` test, it will run the `:reset` function again, passing it the same context value. Then, once Judge is done running tests, it will run the `:teardown` function.

Just to recap: if the test-runner is running *N* custom tests, it will run setup once, reset *N* times, and teardown once.

It's important that reset *actually* resets the test state, so that it doesn't matter what order tests run in or what other tests ran before your test. There are few greater sins than writing tests that can't be run independently.

# Hacking

Judge itself is tested using [cram](https://bitheap.org/cram/), so you'll need a working Python distribution.

# Changelog

## v2.8.2 2024-01-04

- fixed a bug where `test`ing a cyclic data structure would cause judge to infinitely loop
- fixed various problems with floating point numbers not round-tripping
- top-level errors now print full stack traces

## v2.8.1 2023-12-27

- fixed a bug where expectations containing structs or tables with tuple keys might not round-trip correctly
- fixed a bug where mutable values inside tuples or structs might not print with the correct results inside a `deftest` clause that mutates those values

## v2.8.0 2023-12-09

- if a `(test)` form spans multiple lines, the suggested correction will always appear on its own line. This allows you to format tests more like a REPL session:
  
  ```janet
  (test
    (+ 1 2))

  # will now produce:
  (test
    (+ 1 2)
    3)

  # instead of:
  (test
    (+ 1 2) 3)
  ```

## v2.7.2 2023-12-03

- accepting corrections now works on Windows
- fixed a bug where `(test mutable-value)` inside `(deftest)` would show the value as it existed at the end of the entire test, rather than the moment of the `(test)` expression

## v2.7.1 2023-11-18

- updated dependencies

## v2.7.0 2023-08-18

- `test-macro` now formats its output better, and allows you to specify custom formatting metadata on your own macro definitions.

## v2.6.1 2023-06-18

- Judge now exits 2 on compilation or top-level errors, so that editor tooling can distinguish this from test failures
- Judge will continue after encountering a top-level error, and `judge --interactive` or `--accept` will still update the source file

## v2.6.0 2023-06-13

- You can now exclude files or specific tests with `--not`
- Importing a file is no longer sufficient to run tests in it
- `(test)` and friends now evaluate to the expression being tested (when running tests)
- Added `(trust)`, for only evaluating an expression once, and caching the result in your source

## v2.5.0 2023-05-18

- Judge now respects the `NO_COLOR` environment variable
- Added `--color` and `--no-color` flags

## v2.4.0 2023-04-23

- Added `defmacro*`, for defining custom assertion types.
- `test` now pretty-prints its output, splitting large data structures across multiple lines and sorting keys of associative structures.

## v2.3.1 2023-04-04

- Fixed a bug where corrections for mutable `@`-prefixed values would be written incorrectly if the expectation was already an `@`-prefixed value
- In `--interactive` mode, the default if no option is supplied is `y` instead of `q`

## v2.3.0 2023-04-03

- Added `--interactive` mode
- Judge now prints the file name before running tests
- Judge now prints the full source of a test on failure
- Added a `--verbose` flag
- Judge no longer prints the names of tests before it runs them unless you pass the `--verbose` flag
- Fixed a bug where `test-macro` failures would insert an extra newline
- Tuples now always render with square brackets (not just top-level tuples)

## v2.2.2 2023-04-02

- `judge --accept` no longer resets file permissions when it overwrites the original source file
- You can now import files by absolute path. However, doing so will cause problems if you mix them with file-relative imports, as absolute and relative paths have different entries in the Janet module cache.

## v2.2.1 2023-03-30

- The Judge test runner now imports files with relative paths instead of absolute paths. This gives better test output, and fixes a bug where a module could be loaded multiple times if a source file used cwd-relative imports.

## v2.2.0 2023-03-29

- Named functions render as `@name` instead of `"<function name>"` in test output
- `test-stdout` now puts the expression result after the output

## v2.1.0 2023-03-28

- Added `test-stdout`
- `test-macro` now pretty-prints the expansion
- Judge diff output now looks nice for multi-line corrections

## v2.0.0 2023-03-27

Judge v2 is a complete rewrite with an incompatible API.

The biggest difference is that Judge now ships with a test runner script instead of defining a `main` function. This makes it possible to write tests inside regular source files, instead of only in a `test/` subdirectory. But it also means that `jpm test` no longer works transparently out of the box -- see above for instructions on how to restore it.

- `expect` is now called `test`, and `expect-error` is now called `test-error`. `test` is now called `deftest`. `deftest` is now called `deftest-type`, and works slightly differently.

    ```janet
    # v1
    (test "basic math"
      (expect (+ 1 1) 2))
    
    # v2
    (deftest "basic math"
      (test (+ 1 1) 2))
    ```

- You no longer need to use `deftest` to declare a test. You can put `(test)` expressions directly at the top level of your source files.

    ```janet
    (use judge)

    (test (+ 1 1) 2)

    (deftest "you can still name tests to group them"
      (test (+ 1 2) 3)
      (test (- 1 2) -1))
    ```

- Custom context-sensitive tests no longer generate a macro. Instead, custom tests are run with the `deftest:` macro.

    ```janet
    # v1
    (deftest custom-test
      :setup (fn [] (get-some-resource)))

    (custom-test "some stateful test" [context]
      (test (:something context) 0))

    # v2
    (deftest-type custom-test
      :setup (fn [] (get-some-resource)))

    (deftest: custom-test "some stateful test" [context]
      (test (:something context) 0))
    ```

- The test runner now prints the actual text of failing expectations, not a serialization of the parsed syntax tree. This means it preserves line-breaks and other formatting.

- Added `test-macro`.

## v1.0.0 2022-08-22

- Added `expect-error`.

## v0.2.0 2022-08-21

- Judge no longer rewrites the entire `(expect)` form, only the bit that has changed. This fixes the bug where `(expect 'foo foo)` would become `(expect (quote foo) foo)`.
- Judge now renders quoted forms with round brackets instead of square brackets. So `(expect ~(1 2))` will become `(expect ~(1 2) (1 2))` instead of `(expect ~(1 2) [1 2])`.

## v0.1.0 2021-09-29

Initial release of Judge. Motivation and design described in some detail [in this blog post](https://ianthehenry.com/posts/janet-game/judging-janet/).
