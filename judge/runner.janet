(import ./rewriter)
(import ./colorize)

(defn- prettify [value] (string/format "%j" value))

(defn- rm-p [filename]
  (when (os/stat filename)
    # TODO: there's a little bit of a race here... should add rm-p to janet
    (os/rm filename)))

(defn- write-file [filename contents]
  (def file (file/open filename :wn))
  (defer (file/close file)
    (file/write file contents)))

(defn- categorize-tests [tests test-types]
  (var last-seen-tests-by-type @{})
  (var results @[])
  (each [filename type-id name body expect-results] tests
    (def test
      @{ :first-test-of-type? false
         :last-test-of-type? false
         :type-id type-id
         :type-fns (in test-types type-id)
         :filename filename
         :name name
         :body body
         :expect-results expect-results
      })

    (when type-id
      (set (test :first-test-of-type?) (nil? (in last-seen-tests-by-type type-id)))
      (set (last-seen-tests-by-type type-id) test))
    (array/push results test))

  (each [type-id test] (pairs last-seen-tests-by-type)
    (set (test :last-test-of-type?) true))

  results)

(defn- freeze-with-brackets [x]
  (case (type x)
    :array (tuple/brackets ;(map freeze-with-brackets x))
    :tuple (tuple/brackets ;(map freeze-with-brackets x))
    :table (if-let [p (table/getproto x)]
             (freeze-with-brackets (merge (table/clone p) x))
             (struct ;(map freeze-with-brackets (kvs x))))
    :struct (struct ;(map freeze-with-brackets (kvs x)))
    :buffer (string x)
    x))

# so i want to make different types of runners... one that
# just prints things (with or without colors)

(defn run-tests [tests test-types file-contents]
  (def replacements-by-file @{})

  (var any-test-failed false)

  (def test-contexts @{})

  (each { :first-test-of-type? first-test-of-type?
          :last-test-of-type? last-test-of-type?
          :type-fns type-fns
          :type-id type-id
          :filename filename
          :name name
          :body body 
          :expect-results expect-results }
        (categorize-tests tests test-types)

    (var test-failed false)

    # TODO: should say the name of the test type here.
    # Also, this shouldn't fail the test. This should skip
    # the test... somehow.
    (when (and first-test-of-type? (type-fns :setup))
      (set (test-contexts type-id)
        (try ((type-fns :setup))
          ([e fib]
            (set test-failed true)
            (eprint "error initializing context")
            (debug/stacktrace fib e)
            nil))))

    # TODO: should say the name of the test type here. This should
    # also skip the test.
    (when (and type-id (type-fns :reset))
      (try ((type-fns :reset) (test-contexts type-id))
        ([e fib]
          (set test-failed true)
          (eprint "error resetting context")
          (debug/stacktrace fib e))))

    (eprint "running test: " name)

    (try (if type-id (body (test-contexts type-id)) (body))
      ([e fib]
        (set test-failed true)
        (eprint "test failed")
        (debug/stacktrace fib e)))

    # TODO: should say the name of the test type here. This should
    # also skip the test.
    (when (and last-test-of-type? (type-fns :teardown))
      (try ((type-fns :teardown) (test-contexts type-id))
        ([e fib]
          (set test-failed true)
          (eprint "unable to tear down test")
          (debug/stacktrace fib e))))

    (unless (replacements-by-file filename)
      (set (replacements-by-file filename) @[]))

    (each { :actual actual
            :expected expected
            :macro-form macro-form }
          expect-results

      (def actual (freeze-with-brackets actual))

      (if (empty? actual)
        (do
          (set test-failed true)
          (eprint "unreachable expect")
          (eprint (colorize/fg :red "- " (prettify macro-form))))
        (when (deep-not= actual expected)
          (set test-failed true)

          (def replacement-form 
            (tuple ;(array/concat @[] (tuple/slice macro-form 0 2) actual)))

          (eprint "expect failed")
          (eprint (colorize/fg :red "- " (prettify macro-form)))
          (eprint (colorize/fg :green "+ " (prettify replacement-form)))

          (array/push (replacements-by-file filename)
            [(tuple/sourcemap macro-form) 
             (string/format "%j" replacement-form)]))))

    (when test-failed (set any-test-failed true)))

  (each [file replacements] (pairs replacements-by-file)
    (def corrected-filename (string file ".corrected"))
    (if (empty? replacements)
      (rm-p corrected-filename)
      (do
        (set any-test-failed true)
        (write-file corrected-filename
          (rewriter/rewrite-forms (file-contents file) replacements)))))

  (when any-test-failed
    (os/exit 1)))
