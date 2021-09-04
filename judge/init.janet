(import ./rewriter)

(def- test-types @{})
(def- all-tests @[])
(def- file-contents @{})

# This is my way to make a *basically private* function. I want
# to be able to call this function from macro expansions here,
# but I want it to be otherwise completely private.
(def- register-test-sym (gensym))
(eval ~(defn ,register-test-sym [filename test-type name f expect-results]
  (array/push all-tests [filename test-type name f expect-results])))

(def- register-test-type-sym (gensym))
(eval ~(defn ,register-test-type-sym [id test-type]
  (set (test-types id) test-type)))

(defmacro expect [expression & results]
  (def expect-results (dyn :expect-results))
  (def expect-results-sym (dyn :expect-results-sym))
  (unless expect-results
    (error "expect must occur within a test definition"))
  (def expect-id (length expect-results))
  # - After all the expects have been expanded for a given test,
  #   (test) is going to expand to include the value of this table.
  #   But obviously we aren't embedding a *value*, we're embedding a
  #   *form* that looks like this value. So it's important that we quote
  #   the :macro-form, so that it doesn't try to expand it *again* during
  #   the recursive expansion phase.
  #
  # - We could get rid of the initial :actual and check every time we run
  #   expect, but... whatever.
  (set (expect-results expect-id)
    @{ :macro-form ~(quote ,(dyn :macro-form))
       :actual @[] })
  (def expectation (tuple expect-results-sym expect-id))
  ~(do
    (array/push (,expectation :actual) ,expression)
    (set (,expectation :expected) (quote ,results))))

(defn- get-symbol-prefix [sym]
  (def components (string/split "/" sym))
  (if (= (length components) 1)
    nil
    (in components 0)))

(defn- prefix-symbol [sym prefix]
  (if prefix
    (symbol prefix "/" sym)
    sym))

# Is there some official way to do this? This seems like it would
# be necessary in basically any nontrivial macro.
(defn- prefix-macro [macro-sym]
  (def symbol-prefix (get-symbol-prefix (in (dyn :macro-form) 0)))
  (prefix-symbol macro-sym symbol-prefix))

(def- validate-test-name-sym (gensym))
(eval ~(defn ,validate-test-name-sym [name]
  (unless (or (symbol? name) (string? name))
    (errorf "test name must be a symbol or a string, got %j" name))))

(def- test-with-args-sym (gensym))
(eval ~(defmacro ,test-with-args-sym [name args forms]
  (def filename (dyn :current-file))
  (when (not (file-contents filename))
    (def source-file (file/open filename :rn))
    (def source
      (defer (file/close source-file)
        (file/read source-file :all)))
    (when (nil? source)
      (errorf "could not read file contents %s" filename))
    (set (file-contents filename) source))

  (def name (string name))

  (def expect-results @{})
  (def expect-results-sym (gensym))
  # If we could just dynamically define macros, we wouldn't have
  # to do this. Instead we use with-dyns to "pass arguments" to
  # the (expect) macro.
  (def expanded-forms
    (with-dyns [:expect-results expect-results
                :expect-results-sym expect-results-sym]
      (macex forms)))
  ~(do
    (def ,expect-results-sym ,expect-results)
    (,(prefix-macro register-test-sym)
      (dyn :current-file)
      (dyn :test-type)
      ,name
      (fn ,args ,;expanded-forms)
      ,expect-results-sym))))

(defmacro test [name & forms]
  ((eval (prefix-macro validate-test-name-sym)) name)
  ~(,(prefix-macro test-with-args-sym) ,name [] ,forms))

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

(defn- rm-p [filename]
  (when (os/stat filename)
    # TODO: there's a little bit of a race here... should add rm-p to janet
    (os/rm filename)))

(defn- write-file [filename contents]
  (def file (file/open filename :wn))
  (defer (file/close file)
    (file/write file contents)))

(defmacro deftest [macro-name &keys { :setup setup :reset reset :teardown teardown }]
  (def test-type-id (gensym))
  (def test-with-args-sym (prefix-macro test-with-args-sym))
  (def register-test-type-sym (prefix-macro register-test-type-sym))
  (def validate-test-name-sym (prefix-macro validate-test-name-sym))
  ~(upscope
    (,register-test-type-sym (quote ,test-type-id) { :setup ,setup :reset ,reset :teardown ,teardown })
    (defmacro ,macro-name [name & forms]
      (def dynamic-bindings '[:test-type (quote ,test-type-id)])
      (def test-with-args-sym (quote ,test-with-args-sym))
      
      (,validate-test-name-sym name)
      (when (empty? forms)
        (error "cannot create a test with no body"))

      (def first-form (in forms 0))
      (def args-form
        (if (and (tuple? first-form) (= (tuple/type first-form) :brackets))
          first-form
          '[$]))
      
      ~(with-dyns ,dynamic-bindings
        (,test-with-args-sym ,name ,args-form ,forms)))))

(defn- categorize-tests [tests]
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

# TODO: break this up into smaller chunks; this is a mess
(defn main [args]
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
        (categorize-tests all-tests)

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
          (eprintf "unreachable expect")
          (eprintf "- %j" macro-form))
        (when (deep-not= actual expected)
          (set test-failed true)

          (def replacement-form 
            (tuple ;(array/concat @[] (tuple/slice macro-form 0 2) actual)))

          (eprintf "expect failed")
          (eprintf "- %j" macro-form)
          (eprintf "+ %j" replacement-form)

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
