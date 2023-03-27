# judge

Judge is a library for writing inline snapshot tests in [Janet](https://github.com/janet-lang/janet).

Judge lets you write your tests in any file. You can put them in `test/` subdirectory, following standard Janet convention, or you can put tests right next to the code that you're testing:

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

```
TODO

$ jpm_tree/bin/judge sort.janet
test failed
- (test (slow-sort [3 1 4 2]))
+ (test (slow-sort [3 1 4 2]) [1 2 3 4])
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

```
(deftest "sorting tests"
  (test (slow-sort [3 1 2 4]) [1 2 3 4])
  (test (slow-sort [1 1 1 1]) [1 1 1 1]))
```

When you aren't using the `judge` test runner, the `test` and `deftest` macros are no-ops. So these tests will not execute during normal evaluation: tests won't slow down your program, and you can freely distribute modules with Judge tests as libraries without worrying about.

# Usage

Judge distributes a runner executable called `judge`. When you install Judge using `jpm deps -l`, the runner script will live at `jpm_tree/bin/judge`. You can invoke it directly as `jpm_tree/bin/judge`, or you can add the local bin directory to your `PATH`:

    export PATH="./jpm_tree/bin:$PATH"

So that you can just run it as `judge`.

You can also add this to your `project.janet` file:

```janet
(task "test" []
  ($ jpm_tree/bin/judge))
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

To declare a new test type, use the `deftest-type` macro:

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

## Shortcomings

The macros themselves work pretty well, but the actual "test runner" bit is pretty basic and needs some work. For example:

- test output isn't very pretty
- there's no interactive mode to select particular corrections

There's also no stdout redirect/output embedding, which is a pretty useful thing that I'll probably add as a first-class helper at some point.

## Caveats

There's a potential race with file contents that may cause errors patching files, because Judge will read and cache the file during compilation -- necessarily after Janet has already read the file. If the file has changed in between the time that Janet began compiling the test and the time that Judge reads the source file, you will probably get patch errors. This... is very unlikely, but it's worth mentioning.

# TODO

- [ ] judge should not recurse into hidden directories
- [ ] judge should distinguish between explicitly specified files and discovered files -- shouldn't error if you discover a readonly file
