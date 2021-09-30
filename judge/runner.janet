(import ./rewriter)
(import ./colorize)
(import ./util)

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
  (each {:filename filename :type-id type-id :name name
         :body body :expect-results expect-results} tests
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

(use spork/argparse)

(defn scan-int [x]
  (let [num (scan-number x)]
    (if (int? num)
      num
      (errorf "cannot parse %s as an integer" x))))

(defn parse-target [str]
  (def components (string/split ":" str))
  (when (not= (length components) 3)
    (errorf "unable to parse %s as filename:line:col" str))

  (let [[filename line col] components
        line (scan-int line)
        col (scan-int col)]
    {:filename filename :pos [line col]}))

(defn pos-in-form? [source form-pos target-pos]
  # TODO: We do this splitting a lot. Like, for each file, we do this
  # (number of tests * number of times this file appears in a target).
  # This is inefficient and could be easily memoized. But also: who cares.
  (def source-lines (string/split "\n" source))

  (def form-start-index (util/pos-to-byte-index source-lines form-pos))
  (def form-length (util/get-form-length source form-start-index))
  (def target-start-index (util/pos-to-byte-index source-lines target-pos))

  (and (>= target-start-index form-start-index)
       (< target-start-index (+ form-start-index form-length))))

(defn matches [file-contents test [predicate-type predicate-arg]]
  (case predicate-type
    :location (and (= (test :filename) (predicate-arg :filename))
                   (pos-in-form? (in file-contents (test :filename))
                                 (test :pos)
                                 (predicate-arg :pos)))
    :name-prefix (string/has-prefix? predicate-arg (test :name))
    :name-exact (= predicate-arg (test :name))))

# TODO: this is just the easiest way to write this. It would be
# much nicer if it would correctly error if a predicate had no effect.
(defn make-test-filter [file-contents includes excludes]
  (def include?
    (if (empty? includes)
      (fn [_] true)
      (fn [test] (some |(matches file-contents test $) includes))))

  (defn exclude? [test] (some |(matches file-contents test $) excludes))

  (fn [test] (and (include? test) (not (exclude? test)))))

(defn parse-positional-selector [x]
  (try
    [:location (parse-target x)]
    ([_] [:name-prefix x])))

(defn safely-accept-corrections [corrected-filename original-filename file-contents]
  (def current-file-contents
    (with [source-file (file/open original-filename :rn)]
      (string (file/read source-file :all))))

  (if (= (file-contents original-filename) current-file-contents)
    (os/rename corrected-filename original-filename)
    (eprint
      (colorize/fgf :yellow "source file %s has changed; refusing to overwrite with .corrected file"
        original-filename))))

(defn run-tests [all-tests test-types file-contents]
  (def args
    (argparse "Runs matching tests. If no tests are added explicitly, all tests are added."
      "name"           {:kind :accumulate :help "add a test by name (prefix match)"}
      "name-exact"     {:kind :accumulate :help "add a test by name (exact match)"}
      "at"             {:kind :accumulate :help "add a test by file:line:col"}
      "not-name"       {:kind :accumulate :help "remove a test by name (prefix match)"}
      "not-name-exact" {:kind :accumulate :help "remove a test by name (exact match)"}
      "not-at"         {:kind :accumulate :help "remove a test by file:line:col"}
      # "interactive"    {:kind :flag :short "i" :help "prompt for replacements"}
      "accept"         {:kind :flag :short "a" :help "overwrite files with .corrected files"}
      :default         {:kind :accumulate :help "list of targets"}))

  (defn get-arg [name default]
    (or (in args name) default))

  (def accept-corrected-files (get-arg "accept" false))

  (def includes
    (array/concat @[]
      (map |(parse-positional-selector $) (get-arg :default []))
      (map |[:name-prefix $] (get-arg "name" []))
      (map |[:name-exact $] (get-arg "name-exact" []))
      (map |[:location (parse-target $)] (get-arg "at" []))))
  (def excludes
    (array/concat @[]
      (map |[:name-prefix $] (get-arg "not-name" []))
      (map |[:name-exact $] (get-arg "not-name-exact" []))
      (map |[:location (parse-target $)] (get-arg "not-at" []))))

  (def should-run-test? (make-test-filter file-contents includes excludes))
  (def tests-to-run (filter should-run-test? all-tests))

  (def replacements-by-file @{})
  (var tests-passed 0)
  (var tests-failed 0)
  (var tests-skipped 0)
  (var resets-errored 0)
  (def test-contexts @{})

  (defn print-context-error [msg test-type]
    (eprint
      (colorize/fgf :red "%s for \"%j\"" msg (test-type :name))
      (colorize/dimf " (%s:%i:%i)"
        (test-type :filename)
        ((test-type :location) 0)
        ((test-type :location) 1))))

  (each { :first-test-of-type? first-test-of-type?
          :last-test-of-type? last-test-of-type?
          :type-fns type-fns
          :type-id type-id
          :filename filename
          :name name
          :body body
          :expect-results expect-results }
        (categorize-tests tests-to-run test-types)

    (when (and first-test-of-type? (type-fns :setup))
      # for some reason lifting the set out of the try causes the stacktrace
      # to omit the runner file, which is nice
      (set (test-contexts type-id)
        (try ((type-fns :setup))
          ([e fib]
            (print-context-error "error initializing context" type-fns)
            (debug/stacktrace fib e)
            nil))))

    (def setup-complete
      (or (nil? type-id)
          (not (nil? (test-contexts type-id)))))

    (var reset-complete true)
    (when (and setup-complete type-id (type-fns :reset))
      (try ((type-fns :reset) (test-contexts type-id))
        ([e fib]
          (set reset-complete false)
          (print-context-error "error resetting context" type-fns)
          (debug/stacktrace fib e))))

    (def skip-test (not (and setup-complete reset-complete)))

    (var test-errored false)
    (unless skip-test
      (eprint "running test: " name)
      (try
        (if type-id
          (body (test-contexts type-id))
          (body))
        ([e fib]
          (set test-errored true)
          (eprint (colorize/fg :red name " raised:"))
          (debug/stacktrace fib e))))

    (when skip-test
      (eprint (colorize/fg :red "unable to run test: " name))
      (++ tests-skipped))

    (when (and setup-complete last-test-of-type? (type-fns :teardown))
      (try ((type-fns :teardown) (test-contexts type-id))
        ([e fib]
          (++ resets-errored)
          # TODO: should say the name of the test type here. This should
          (eprint "unable to tear down test")
          (debug/stacktrace fib e))))

    (unless (replacements-by-file filename)
      (set (replacements-by-file filename) @[]))

    (var any-expectation-failed false)
    (each { :actual actual
            :expected expected
            :macro-form macro-form }
          expect-results

      (def actual (freeze-with-brackets actual))

      (if (empty? actual)
        (do
          (set any-expectation-failed true)
          (eprint (colorize/fg :red "unreachable expect: " name))
          (eprint (colorize/fg :red "- " (prettify macro-form))))
        (when (deep-not= actual expected)
          (set any-expectation-failed true)

          (def replacement-form
            (tuple ;(array/concat @[] (tuple/slice macro-form 0 2) actual)))

          (eprint (colorize/fg :red "- " (prettify macro-form)))
          (eprint (colorize/fg :green "+ " (prettify replacement-form)))

          (array/push (replacements-by-file filename)
            [(tuple/sourcemap macro-form)
             (prettify replacement-form)]))))

    (if (or test-errored any-expectation-failed)
      (++ tests-failed)
      (++ tests-passed)))

  (each [filename replacements] (pairs replacements-by-file)
    (def corrected-filename (string filename ".corrected"))
    (if (empty? replacements)
      (rm-p corrected-filename)
      (do
        (write-file corrected-filename
          (rewriter/rewrite-forms (file-contents filename) replacements))
        (when accept-corrected-files
          (safely-accept-corrections corrected-filename filename file-contents)))))

  (def tests-excluded (- (length all-tests) (length tests-to-run)))

  (eprintf "%i passed %i failed %i excluded %i skipped" tests-passed tests-failed tests-excluded tests-skipped)

  (when (> (+ tests-failed tests-skipped resets-errored) 0)
    (os/exit 1)))
