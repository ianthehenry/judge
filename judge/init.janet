(import ./runner)

(def- test-types @{})
(def- all-tests @[])
(def- file-contents @{})

(defn- register-test [test]
  (array/push all-tests test))

(defn- register-test-type [id test-type]
  (set (test-types id) test-type))

(defmacro expect [expression & results]
  (def expect-results (dyn :expect-results))
  (def $expect-results (dyn :$expect-results))
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
    @{:macro-form ~(quote ,(dyn :macro-form))
      :actual @[]})
  (def expectation (tuple $expect-results expect-id))
  ~(do
    (array/push (,expectation :actual) ,expression)
    (set (,expectation :expected) (quote ,results))))

(defn- validate-test-name [name]
  (unless (or (symbol? name) (string? name))
    (errorf "test name must be a symbol or a string, got %j" name)))

# this is a function, not a macro, but it returns forms representing
# a test. it's meant to be called from within other macros.
(defn- test-with-args [name test-type args forms]
  (unless (or (symbol? name) (string? name))
    (errorf "test name must be a symbol or a string, got %j" name))
  (def name (string name))
  (def test-type-form (if (nil? test-type) nil ~',test-type))

  (def filename (dyn :current-file))
  (when (not (file-contents filename))
    (def source (with [source-file (file/open filename :rn)]
      (string (file/read source-file :all))))
    (when (nil? source)
      (errorf "could not read file contents %s" filename))
    (set (file-contents filename) source))

  (def expect-results @{})
  (def $expect-results (gensym))
  # If we could just dynamically define macros, we wouldn't have
  # to do this. Instead we use with-dyns to "pass arguments" to
  # the (expect) macro.
  (def expanded-forms
    (with-dyns [:expect-results expect-results
                :$expect-results $expect-results]
      (macex forms)))
  ~(do
    (def ,$expect-results ,expect-results)
    (,register-test
      {:filename (dyn :current-file)
       :pos (quote ,(tuple/sourcemap (dyn :macro-form)))
       :type-id ,test-type-form
       :name ,name
       :body (fn ,args ,;expanded-forms)
       :expect-results ,$expect-results
       })))

(defmacro test [name & forms]
  (test-with-args name nil [] forms))

(defn- bracketed-tuple? [x]
  (and (tuple? x) (= (tuple/type x) :brackets)))

(defmacro deftest [macro-name &keys {:setup setup :reset reset :teardown teardown}]
  (def test-type-id (gensym))
  (def location (tuple/sourcemap (dyn :macro-form)))
  (def filename (dyn :current-file))
  ~(upscope
    (,register-test-type ',test-type-id
      {:setup ,setup
       :reset ,reset
       :teardown ,teardown
       :name ',macro-name
       :location ',location
       :filename ,filename
       })
    (defmacro ,macro-name [name & forms]
      (when (empty? forms)
        (error "cannot create a test with no body"))
      (def [head & tail] forms)
      (def [args-form body-forms]
        (if (,bracketed-tuple? head)
          [head tail]
          ['[$] forms]))
      (,test-with-args name ',test-type-id args-form body-forms))))

(defn main [& args]
  (runner/run-tests all-tests test-types file-contents))
