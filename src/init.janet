(use ./shared)

(def- *current-test* (gensym))

(defn- smuggle [expr] ~(,|expr))
(defn- ignore [&] nil)

(defn- make-test [ctx <name>]
  (def location (tuple/sourcemap (dyn :macro-form)))
  (def file (dyn :current-file))
  (def {:file-cache file-cache} ctx)
  (unless (in file-cache file)
    (put file-cache file (slurp file)))
  @{:name (if <name> (string <name>))
    :expectations @[]
    :file file
    :ran false
    :location location})

(defn- should-run [ctx test]
  # TODO
  true)

(defn- get-state [ctx test-type]
  (def states (ctx :states))
  (def state
    (or (in states test-type)
      (try [:ok ((test-type :setup))]
        ([e fib] [:error e fib]))))
  (def state
    (match state
      [:ok state]
        (try (do ((test-type :reset) state) [:ok state])
          ([e fib] [:error e fib]))
      [:error e fib _] [:error e fib]
      state))
  (put states test-type state)
  state)

(defn- wrap-test-body [test ctx <test-type> <args> <body>]
  (def <run-test>
    (if <test-type>
      (with-syms [$state]
        ~(match (,get-state ,(smuggle ctx) ,<test-type>)
          [:ok ,$state] ((fn ,<args> ,;<body>) ,$state)
          [:error e fib] (propagate (string "failed to initialize context: " e) fib)))
      ~(do ,;<body>)))
  ~(try (do ,<run-test> (,put ,(smuggle test) :ran true))
     ([e fib] (,put ,(smuggle test) :error [e fib]))))

(defn- declare-test [<name> <test-type> <args> body]
  (when-let [ctx (dyn *global-test-context*)]
    (def test (make-test ctx <name>))
    (if (should-run ctx test)
      (do
        (array/push (ctx :tests) test)
        (wrap-test-body test ctx <test-type> <args>
          (with-dyns [*current-test* test]
            (macex body))))
      (ignore (++ (ctx :skipped))))))

(defmacro deftest [<name> & <body>]
  (declare-test <name> nil nil <body>))

(defmacro deftest: [<type> <name> <args> & body]
  (declare-test <name> <type> <args> body))

# TODO: should be a no-op if not testing
(defmacro deftest-type [name &named setup reset teardown]
  (default setup ~(fn []))
  (default reset ~(fn [_]))
  (default teardown ~(fn [_]))
  ~(def ,name
    @{:setup ,setup
      :reset ,reset
      :teardown ,teardown}))

(defn- actual-expectation [test expr expected]
  (def expectation
    @{:expected expected
      :form (dyn *macro-form*)
      :actual @[]})
  (array/push (test :expectations) expectation)
  ~(try (,array/push (,(smuggle expectation) :actual) ,expr)
    ([e fib] (,put ,(smuggle expectation) :error [e fib]))))

(defmacro test [<expr> & <expected>]
  (if-let [test (dyn *current-test*)]
    (actual-expectation test <expr> <expected>)
    (declare-test nil nil nil [(dyn *macro-form*)])))

(defn- get-error [<expr>]
  (with-syms [$errored $err]
    ~(let [[,$err ,$errored]
           (try [,<expr> false]
             ([,$err] [,$err true]))]
      (if ,$errored ,$err (,error "did not error")))))

(defmacro test-error [<expr> & <expected>]
  (tuple/setmap ~(as-macro ,test ,(get-error <expr>) ,;<expected>)
    ;(tuple/sourcemap (dyn *macro-form*))))

(defmacro test-macro [<expr> & <expected>]
  (tuple/setmap ~(as-macro ,test (,macex1 ',<expr>) ,;<expected>)
    ;(tuple/sourcemap (dyn *macro-form*))))
