(import ./runner)

(def- $top-secret-result-symbol (symbol (string "EXPECT_MUST_OCCUR_WITHIN_TEST_BODY" (gensym))))

(def- test-types @{})
(def- all-tests @[])
(def- file-contents @{})

(defn- register-test [test]
  (array/push all-tests test))

(defn- register-test-type [id test-type]
  (set (test-types id) test-type))

(defn- get-or-set [table key get-default]
  (if-let [value (table key)]
    value
    (set (table key) (get-default))))

(defmacro expect [expression & results]
  (let [expect-id (gensym)
        $expectation (gensym)]
    ~(let [,$expectation
            (,get-or-set
              ,$top-secret-result-symbol
              ',expect-id
              |@{:macro-form ',(dyn :macro-form)
                 :expected ',results
                 :actual @[]})]
          (array/push (,$expectation :actual) ,expression))))

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

  ~(let [,$top-secret-result-symbol @{}]
    (,register-test
      {:filename (dyn :current-file)
       :pos ',(tuple/sourcemap (dyn :macro-form))
       :type-id ,test-type-form
       :name ,name
       :body (fn ,args ,;forms)
       :expect-results ,$top-secret-result-symbol
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
