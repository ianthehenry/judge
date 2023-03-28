(use ./shared)
(import ./util)

(def- *current-test* (gensym))

(defn- smuggle [expr] ~(,|expr))
(defn- ignore [&] nil)

(defn- make-test [ctx <name>]
  (def pos (tuple/sourcemap (dyn :macro-form)))
  (def file (dyn :current-file))
  # we create this now because the presence of an empty
  # list is significant -- it will cause us to delete the
  # .tested file after we're done
  (util/put-if-unset (ctx :replacements) file @[])
  (def {:file-cache file-cache} ctx)
  (unless (in file-cache file)
    (def source (slurp file))
    (def lines (string/split "\n" source))
    (put file-cache file {:source source :lines lines}))
  @{:name (if <name> (string <name>))
    :expectations @[]
    :file file
    :ran false
    :pos pos})

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
  ~(do
      (:on-test-start ,(smuggle ctx) ,(smuggle test))
      (try ,<run-test>
         ([e fib] (,put ,(smuggle test) :error [e fib])))
      (:on-test-end ,(smuggle ctx) ,(smuggle test))))

(defn- declare-test [<name> <test-type> <args> body]
  (when-let [ctx (dyn *global-test-context*)]
    (def test (make-test ctx <name>))
    (case (:test-predicate ctx test)
      :ignore nil
      true (do
        (array/push (ctx :tests) test)
        (wrap-test-body test ctx <test-type> <args>
          (with-dyns [*current-test* test]
            (macex body))))
      false (ignore (++ (ctx :skipped))))))

(defmacro deftest [<name> & <body>]
  (declare-test <name> nil nil <body>))

(defmacro deftest: [<type> <name> <args> & body]
  (declare-test <name> <type> <args> body))

(defmacro deftest-type [name &named setup reset teardown]
  (when (dyn *global-test-context*)
    (default setup ~(fn []))
    (default reset ~(fn [_]))
    (default teardown ~(fn [_]))
    ~(def ,name
      @{:name ',name
        :setup ,setup
        :reset ,reset
        :teardown ,teardown})))

(defn- actual-expectation [test expr expected printer]
  (def expectation
    @{:expected expected
      :form (dyn *macro-form*)
      :printer printer
      :actual @[]})
  (array/push (test :expectations) expectation)
  ~(try (,array/push (,(smuggle expectation) :actual) ,expr)
    ([e fib] (,put ,(smuggle expectation) :error [e fib]))))

(defn- test* [<expr> <expected> printer]
  (if-let [test (dyn *current-test*)]
    (actual-expectation test <expr> <expected> printer)
    (declare-test nil nil nil [(dyn *macro-form*)])))

(defn- normal-printer [x]
  (string/format "%j" (util/freeze-with-brackets x)))

(defn- macro-printer [x]
  (string/format "%q" x))

(defmacro test-error [<expr> & <expected>]
  (test* (util/get-error <expr>) <expected> normal-printer))

(defmacro test-macro [<expr> & <expected>]
  (test* ~(,macex1 ',<expr>) <expected> macro-printer))

(defmacro test [<expr> & <expected>]
  (test* <expr> <expected> normal-printer))
