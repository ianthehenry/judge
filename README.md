# judge

A library for writing self-modifying tests -- also known as snapshot tests or expect tests -- in the [Janet language](https://github.com/janet-lang/janet).

Write your tests:

```clojure
# test.janet

(use judge)

(test "basic math"
  (expect (+ 2 2) 3))
```

Run your tests:

```
$ janet test.janet
running test: basic math
expect failed
- (expect (+ 2 2) 3)
+ (expect (+ 2 2) 4)
```

And look! It fixed your tests:

```clojure
# test.janet.corrected

(use judge)

(test "basic math"
  (expect (+ 2 2) 4))
```

You can then diff the `.corrected` file with your original source and interactively merge them using whatever tools you are comfortable with.

## Usage

### Writing tests

The first form passed to the `(test)` macro is the name of the test. It can be a symbol or a string:

```clojure
(use judge)

(test math
  (expect (+ 2 2) 4))

(test "advanced math"
  (expect (* 2 2) 4))
```

The `(expect)` macro can only appear inside the `(test)` macro (or any custom test macro -- see "Context-dependent tests" below).

If you call `(expect)` multiple times within a test invocation, every result will be checked in order:

```clojure
(use judge)

(defn capitalize [str]
  (string
    (string/ascii-upper (string/slice str 0 1)) 
    (string/slice str 1)))

(test "test capitalization"
  (each name ["eleanor" "chidi" "tahani" "jason"]
    (expect (capitalize name) "Eleanor" "Chidi" "Tahani" "Jason")))
```

This imperative style might, sometimes, be more convenient than the more functional equivalent:

```clojure
(test "test capitalization"
  (expect (map capitalize ["eleanor" "chidi" "tahani" "jason"])
    ["Eleanor" "Chidi" "Tahani" "Jason"]))
```

There is currently no macro that lets you call `(expect)` multiple times and assert that you get the same result every time, but I realize writing this documentation that that might be useful.

### Running tests

Run all tests:

    janet test.janet

Run a specific test:

    janet test.janet --name 'two plus'

Run test on a specific line/column (useful for editor tooling):

    janet test.janet --at test.janet:10:2

You can also pass positional arguments, and those will be treated either as test names or locations depending on whether or not they can be parsed as `file:line:col`.

You can also exclude certain tests:

    janet test.janet --not-name 'two plus two is four'

### A note about `main`

When you `(use judge)`, you will bring a `main` function into scope that actually runs the tests. If you'd rather do something more complicated -- for example, import tests from multiple different files and run them at the same time -- just invoke the `judge/main` function directly, or define your own `main` to point to it.

```clojure
(import judge)

(use /tests/simple-tests)
(use /tests/advanced-tests)

(def main judge/main)
```

This isn't necessary if you're writing simple tests and putting them all in the `test/` subdirectory -- `jpm test` will run all of them. But it has one big advantage: `jpm test` stops running tests after the first failing test file. By importing multiple files into a single test runner, you can run all your tests and see all the failures at once. It can also be much faster, if you're writing...

### Context-dependent tests

Sometimes you might have a bunch of tests that all need some kind of shared context -- a SQL connection, maybe, or an OpenGL graphics context. You could create that context anew at the beginning of every test, but that might be very expensive. There are some cases where it might be appropriate to create the context a single time, and pass it in to every test of that type.

To declare a new test type, use the `deftest` macro:

```clojure
(deftest custom-test
  :setup (fn [] (create-some-expensive-shared-resource))
  :reset (fn [context] (wipe-clean context))
  :teardown (fn [context] (destroy context)))
```

This will declare a macro called `custom-test`, which you can then use like the regular `test` macro:

```clojure
(custom-test "some kind of test" [context]
  (do-something-with context))
```

The first time the test-runner encounters a test declared with the `custom-test` macro, it will first call the `:setup` function. Then it will call the `:reset` function, passing it whatever context `:setup` returned. Then it will run the test, and move on to the next test in its list of tests to run. Any time it needs to run a test declared with the `custom-test` macro, it will run the `:reset` function again, passing it the same context value. Then, after the final `custom-test` has completed, it will run the `:teardown` function.

The binding form after the test name is optional. If you omit it, the context returned from `:setup` will be named `$` by default.

```clojure
(custom-test "some kind of test"
  (do-something-with $))
```

Just to recap: if the test-runner is running *N* custom tests, it will run setup once, reset *N* times, and teardown once.

It's important that reset *actually* resets the test state, so that it doesn't matter what order tests run in or what other tests ran before your test. There are few greater sins than writing tests that can't be run independently.

## Shortcomings

The macros themselves work pretty well, but the actual "test runner" bit is pretty basic and needs some work. For example:

- test output isn't very pretty
- there's no interactive mode to select particular corrections

Another shortcoming is that the source code modifier is very primitive. It doesn't preserve formatting *within* an `(expect)` form. So, for example, if you write something like this:

```clojure
(expect
    (+ 2
      2) 
 3)
```

That will be replaced with the one-line expression:

```clojure
(expect (+ 2 2) 4)
```

This wouldn't be very hard to fix, so if it matters to you, I'll fix it.

There's also no stdout redirect/output embedding, which is a pretty useful thing that I'll probably add as a first-class helper at some point.

## Caveats

There's a potential race with file contents that may cause errors patching files, because Judge will read and cache the file during compilation -- necessarily after Janet has already read the file. If the file has changed in between the time that Janet began compiling the test and the time that Judge reads the source file, you will probably get patch errors. This... is very unlikely, but it's worth mentioning.
