(use ./shared)
(import ./util)
(import ./fmt)

(def- *current-test* (gensym))

(defn- smuggle [expr] ~(,|expr))
(defn- ignore [&] nil)

(defn- make-test [ctx <name>]
  (def pos (tuple/sourcemap (dyn *macro-form*)))
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

(defn- actual-expectation [test expr expected stabilizer printer]
  (def expectation
    @{:expected expected
      :form (dyn *macro-form*)
      :stabilizer stabilizer
      :printer printer
      :actual @[]})
  (array/push (test :expectations) expectation)
  ~(try (,array/push (,(smuggle expectation) :actual) ,expr)
    ([e fib] (,put ,(smuggle expectation) :error [e fib]))))

(defn- test* [<expr> <expected> stabilizer printer]
  (if-let [test (dyn *current-test*)]
    (actual-expectation test <expr> <expected> stabilizer printer)
    (declare-test nil nil nil [(dyn *macro-form*)])))

(defn- normal-stabilize [node] [(util/stabilize node)])

(defn- normal-printer [col form]
  (fmt/to-string-pretty form (+ col 1)))

(defn- macro-printer [col form]
  (def buf @"\n")
  (with-dyns [*out* buf]
    (fmt/prindent form (+ col 1)))
  buf)

(defn- gensymbly? [sym]
  (and
    (symbol? sym)
    (= (length sym) 7)
    (string/has-prefix? "_0" sym)))

(defn- macro-stabilize [form]
  (var i 1)
  (def syms @{})

  (defn recur [node]
    (if (gensymbly? node)
      (util/get-or-put syms node (do
        (let [sym (symbol "<" i ">")]
          (++ i)
          sym)))
      (walk recur node)))
  [(recur (util/stabilize form))])

(def- backticks (peg/compile ~(any (+ (<- (some "`")) 1))))

(defn- indent [str col]
  (def col (- col 1))
  (def lines (string/split "\n" str))
  (def indent (string/repeat " " (+ col 2)))
  (def indented (seq [[i line] :pairs lines]
    (if (and (util/last? i lines) (empty? line))
      (string (string/repeat " " col) line)
      (string indent line))))
  (string/join indented "\n"))

(defn- backtick-quote [str col]
  (def most-backticks
    (reduce |(max $0 (length $1)) 0 (peg/match backticks str)))
  (def delimiter (string/repeat "`" (+ 1 most-backticks)))
  (string
    delimiter
    "\n"
    str
    (if (= col 1) "\n")
    delimiter))

(defn- stdout-printer [col output &opt form]
  (def output (backtick-quote output col))
  (if (nil? form)
    output
    (string/format "%s %s" output (normal-printer col form))))

(defn- ensure-trailing-newline [str]
  (if (string/has-suffix? "\n" str)
    str
    (string str "\n")))

(defn- remove-trailing-newline [str]
  (if (string/has-suffix? "\n" str)
    (string/slice str 0 (- (length str) 1))
    str))

(defn- stdout-stabilize [col]
  (fn [[output result]]
    (def indented (indent (ensure-trailing-newline output) col))
    # work around a horrible quirk of the janet parser
    (def normalized
      (if (= col 1)
        (remove-trailing-newline indented)
        indented))
    (if result
      [normalized (util/stabilize result)]
      [normalized])))

(defmacro test-error [<expr> & <expected>]
  (test* (util/get-error <expr>) <expected> normal-stabilize normal-printer))

(defmacro test-macro [<expr> & <expected>]
  (test* ~(,macex1 ',<expr>) <expected> macro-stabilize macro-printer))

(defmacro test-stdout [<expr> & <expected>]
  (def [line col] (tuple/sourcemap (dyn *macro-form*)))
  (def <expr> (with-syms [$buf]
    ~(let [,$buf @""]
      (with-dyns [',*out* ,$buf]
        [,$buf ,<expr>]))))
  (test* <expr> <expected> (stdout-stabilize col) stdout-printer))

(defmacro test [<expr> & <expected>]
  (test* <expr> <expected> normal-stabilize normal-printer))

(defn- with-map [src dest]
  (tuple/setmap dest ;(tuple/sourcemap src)))

(defmacro defmacro* [name binding-form & body]
  ~(defmacro ,name ,binding-form
    (,with-map (,dyn *macro-form*)
      (do ,;body))))
