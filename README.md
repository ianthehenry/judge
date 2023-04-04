# judge

Judge is a library for writing inline snapshot tests in [Janet](https://github.com/janet-lang/janet). You can install it with `jpm`:

```janet
# project.janet
(declare-project
  :dependencies [
    {:url "https://github.com/ianthehenry/judge.git"
     :tag "v2.3.0"}
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
  [-i], [--interactive]      : select which replacements to include
  [--not-name-exact NAME]... : skip tests whose name is exactly this prefix
  [--name-exact NAME]...     : only run tests with this exact name
  [--not-name PREFIX]...     : skip tests whose name starts with this prefix
  [--name PREFIX]...         : only run tests whose name starts with the given
                               prefix
  [-v], [--verbose]          : verbose output
```

You can also add this to your `project.janet` file:

```janet
(task "test" [] (shell "jpm_tree/bin/judge"))
```

To run Judge with a normal `jpm test` invocation.

## Writing tests

## `test`

```janet
(test (+ 1 2) 3)
```

## `test-error`

Requires that the provided expression raises an error:

```janet
(test-error (in [1 2 3] 5) "expected integer key in range [0, 3), got 5")
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

(test-stdout (add 1 2) 3 `
  adding 1 and 2
`)
```

Due to ambiguity in the Janet parser for multi-line strings, a trailing newline will always be added to the output if it does not exist.

## `test-macro`

`test-macro` is just like `test`ing the result of a `macex1` expression, but it prints with slightly nicer output:

```janet
(test-macro (let [x 1] x)
  (do
    (def x 1)
    x))
```

And `test-macro` will replace `gensym`'d identifiers with stable symbols:

```janet
(test-macro (and x (+ 1 2))
  (if (def <1> x) (+ 1 2) <1>))
```

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

## Running tests

Run all tests in a particular file:

    $ judge tests.janet

Or a directory:

    $ judge tests/

Run a specific named test:

    $ judge --name 'two plus'

Run test on a specific line/column (useful for editor tooling):

    $ judge test.janet:10:2

## Context-dependent tests

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

