# judge

Judge is a library for writing inline snapshot tests in [Janet](https://github.com/janet-lang/janet).

Judge tests work a little differently than traditional tests. Instead of assertions, you write expressions to observe. Like this:

```janet
(test (+ 1 1))
```

When you run Judge, it will replace the source code with the result of this expression:

```janet
(test (+ 1 1) 2)
```

The Judge test runner gives you a lot flexibility over where you structure your tests. You *can* put all your tests in a `test/` subdirectory, following standard Janet convention, or you can put tests right next to the code that you're testing:

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

```janet
$ judge
running test: sort.janet:14:1
- (test (slow-sort [3 1 4 2]))
+ (test (slow-sort [3 1 4 2]) [1 2 3 4])
0 passed 1 failed 0 skipped 0 unreachable
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

You can also add this to your `project.janet` file:

```janet
(task "test" [] (shell "jpm_tree/bin/judge"))
```

To run Judge with a normal `jpm test` invocation.

## Writing tests

The first form passed to the `(deftest)` macro is the name of the test. It can be a symbol or a string:

```janet
(use judge)

(deftest math
  (test (+ 2 2) 4))

(deftest "advanced math"
  (test (* 2 2) 4))
```

You don't have to use `deftest`, though. You can create anonymous, single-expression tests by using `test` at the top-level:

```janet
(use judge)

(test (+ 1 2) 3)
```

## `test-macro`

`test-macro` is just like `test`ing the result of a `macex1` expression, but it prints with slightly nicer output:

```janet
(test-macro (let [x 1] x) (do (def x 1) x))
```

And `test-macro` will replace `gensym`'d identifiers with stable symbols:

```janet
(test-macro (and x (+ 1 2)) (if (def <1> x) (+ 1 2) <1>))
```

## `test-error`

Requires that the provided expression raises an error:

```janet
(test-error (in [1 2 3] 5) "expected integer key in range [0, 3), got 5")
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

# Changelog

## v2.0.0 2023-??-??

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

- TODO: `test-stdout` and `test-stderr`.

## v1.0.0 2022-08-22

- Added `expect-error`.

## v0.2.0 2022-08-21

- Judge no longer rewrites the entire `(expect)` form, only the bit that has changed. This fixes the bug where `(expect 'foo foo)` would become `(expect (quote foo) foo)`.
- Judge now renders quoted forms with round brackets instead of square brackets. So `(expect ~(1 2))` will become `(expect ~(1 2) (1 2))` instead of `(expect ~(1 2) [1 2])`.

## v0.1.0 2021-09-29

Initial release of Judge. Motivation and design described in some detail [in this blog post](https://ianthehenry.com/posts/janet-game/judging-janet/).
