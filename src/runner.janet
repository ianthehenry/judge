(import cmd)
(import ./util)
(import ./rewriter)
(import ./colorize)
(use ./shared)

(defn but-last [t]
  (tuple/slice t 0 (- (length t) 1)))
(defn basename [path]
  (last (string/split "/" path)))
(defn dirname [path]
  (string/join (but-last (string/split "/" path)) "/"))
(defn split-path [path]
  [(but-last (string/split "/" path))
   (basename path)])

(defn chop-ext [path]
  (def [dir base] (split-path path))
  (def components (string/split "." base))
  (def leading (tuple/slice components 0 (- (length components) 1)))
  (string/join [;dir (string/join leading ".")] "/"))

(defn to-abs [path]
  (if (string/has-prefix? "/" path)
    path
    (string (os/cwd) "/" path)))

(defn- hidden? [path]
  (string/has-prefix? "." (basename path)))

(defn find-all-janet-files [path &opt explicit results]
  (default explicit true)
  (default results @[])
  (when (or explicit (not (hidden? path)))
    (case (os/stat path :mode)
      :directory
        (when (or explicit (not= (basename path) "jpm_tree"))
          (each entry (os/dir path)
            (find-all-janet-files (string path "/" entry) false results)))
      :file (if (string/has-suffix? ".janet" path) (array/push results path))
      nil (array/push results [(string/format "could not read %q" path)])))
results)

(defn- expectation-error
  [{:actual actual
    :expected expected
    :form form
    :error err
    :printer printer}]
  (cond
    (truthy? err) (let [[err fib] err] [err nil])
    (empty? actual) ["did not reach expectation" nil]
    (not (util/deep-same? actual)) ["inconsistent results" nil]
    (let [actual (first actual)]
      (unless (deep= [actual] expected)
        [nil [(tuple/sourcemap form) (printer actual)]]))))

(defn safely-accept-corrections [corrected-filename original-filename {:source source}]
  (def current-file-contents (slurp original-filename))
  (if (deep= current-file-contents source)
    (os/rename corrected-filename original-filename)
    (eprint
      (colorize/fgf :yellow "%s changed since test runner began; refusing to overwrite"
        original-filename))))

(defn- apply-replacements [file-cache replacements-by-file accept]
  (eachp [file replacements] replacements-by-file
    (def corrected-file (string file ".tested"))
    (if (empty? replacements)
      (util/rm-p corrected-file)
      (do
        (def file-cache-entry (in file-cache file))
        (spit corrected-file
          (rewriter/rewrite-forms file-cache-entry replacements))
        (when accept
          (safely-accept-corrections corrected-file file file-cache-entry))
        ))))

# TODO: should render these relative to the current working directory
(defn- format-pos [file [line col]]
  (string/format "%s:%d:%d" file line col))

(defn- name-of [test]
  (if-let [name (test :name)]
    name
    (format-pos (test :file) (test :pos))))

(def ctx-proto
  @{:on-test-error (fn [self err fib]
      (eprint (colorize/fg :red "test raised:"))
      (debug/stacktrace fib err ""))

    :on-test-start (fn [self test]
      (put test :ran true)
      (eprint "running test: " (name-of test)))

    :on-test-end (fn [self test]
      (def {:expectations expectations :file file} test)

      (var failed false)
      (match test
        {:error [err fib]} (do
          (:on-test-error self err fib)
          (set failed true)))

      (each expectation expectations
        (case (:report-expectation self test expectation)
          :error (set failed true)))

      (if failed
        (++ (self :failed))
        (++ (self :passed))))

    :add-replacement (fn [self test replacement]
      (array/push (in (self :replacements) (test :file))
        replacement))

    :report-expectation (fn [self test expectation]
      (when-let [[err replacement] (expectation-error expectation)]
        (def current-form (rewriter/get-form (in (self :file-cache) (test :file))
          (tuple/sourcemap (expectation :form))))
        (unless replacement
          (eprint (colorize/fg :red err)))
        # TODO: this should actually work with multi-line forms
        (eprint (colorize/fg :red "- " current-form))
        (when replacement
          (def new-form
            (rewriter/rewrite-form current-form [1 1] (in replacement 1)))
          (eprint (colorize/fg :green "+ " new-form))
          (:add-replacement self test replacement))
        (break :error))
      :ok)
    })

(defn matches [ctx test [predicate-type & predicate-args]]
  (case predicate-type
    :pos (let [[file pos] predicate-args]
      (and (= (test :file) file)
           (rewriter/pos-in-form?
             (in (ctx :file-cache) (test :file))
             (test :pos)
             pos)))
    :name-prefix (string/has-prefix? (first predicate-args) (test :name))
    :name-exact (= (first predicate-args) (test :name))))

(def- some_ some)
(defn- some [list pred]
  (truthy? (some_ pred list)))

(defn- with-trailing-slash [path]
  (if (string/has-suffix? "/" path) path (string path "/")))

(defn include-file? [file files-or-dirs]
  (some files-or-dirs (fn [file-or-dir]
    (or (= file file-or-dir)
       (string/has-prefix? (with-trailing-slash file-or-dir) file)) files-or-dirs)))

# It might would be nice to error if a predicate had no effect.
(defn make-test-predicate [files includes excludes] (fn [ctx test]
  (if (include-file? (test :file) files)
    (let [include? (if (empty? includes)
                     true
                     (some includes |(matches ctx test $)))
          exclude? (some excludes |(matches ctx test $))]
      (and include? (not exclude?)))
    :ignore)))

(defn new [proto & kvs] (table/setproto (table ;kvs) proto))

(def arg/prefix ["PREFIX" :string])
(def arg/name ["NAME" :string])
(def arg/target
  (cmd/peg "FILE[:LINE:COL]"
    ~{:main (* (+ (/ :specific ,|[:just ;$&]) (/ :general ,|[:all $])) -1)
      :specific (* (<- (to ":")) ":" (number (to ":")) ":" (number (to -1)))
      :general (<- (to -1))}))

(cmd/defn main
  `Test runner for Judge.

   If no targets are given on the command line, Judge will look for tests in the current working directory.

   Targets can be file names, directory names, or FILE:LINE:COL to run a test at a
   specific location (which is mostly useful for editor tooling).`
  [targets (array arg/target)
   [name-prefix-selectors        --name] (array arg/prefix) "only run tests whose name starts with the given prefix"
   [name-exact-selectors   --name-exact] (array arg/name)   "only run tests with this exact name"
   [name-prefix-filters      --not-name] (array arg/prefix) "skip tests whose name starts with this prefix"
   [name-exact-filters --not-name-exact] (array arg/name)   "skip tests whose name is exactly this prefix"
   [--accept -a] (flag) "overwrite source files with .tested files"]

  (def targets
    (if (empty? targets)
      [[:all "."]]
      targets))

  # resolve all directories
  (def file-targets (map 1 targets))
  (def found-files (mapcat find-all-janet-files file-targets))
  (loop [f :in found-files :when (tuple? f) :let [[err] f]]
    (eprintf "error: %s" err)
    (os/exit 1))

  # TODO: we'll actually get better stack traces if we run these
  # with relative paths, not absolute paths. But I can't figure
  # out how to dynamically require files with relative paths.
  (def found-files (map to-abs found-files))

  (def pos-selectors (seq [[mode file line col] :in targets :when (= mode :just)]
    [:pos (to-abs file) [line col]]))

  (def includes
    (array/concat
      pos-selectors
      (map |[:name-prefix $] name-prefix-selectors)
      (map |[:name-exact $] name-exact-selectors)))
  (def excludes
    (array/concat
      (map |[:name-prefix $] name-prefix-filters)
      (map |[:name-prefix $] name-exact-filters)))

  (def ctx (new ctx-proto
    :tests @[]
    :passed 0
    :failed 0
    :skipped 0
    :test-predicate (make-test-predicate found-files includes excludes)
    :states @{}
    :file-cache @{}
    :replacements @{}))
  (put root-env *global-test-context* ctx)

  (each file found-files
    (require (string "@" (chop-ext file))))

  (var teardown-failure false)
  (eachp [{:teardown teardown :name name} state] (ctx :states)
    (match state
      [:ok state]
        (try (teardown state)
          ([e fib]
            (set teardown-failure true)
            (eprint (colorize/fgf :red "failed to teardown %s test context" name))
            (debug/stacktrace fib e "")))))

  (var unreachable 0)
  (loop [test :in (ctx :tests) :when (not (test :ran))]
    (eprint (colorize/fg :red (name-of test) " did not run"))
    (++ unreachable))

  (apply-replacements (ctx :file-cache) (ctx :replacements) accept)

  (eprintf "%i passed %i failed %i skipped %i unreachable"
    (ctx :passed) (ctx :failed) (ctx :skipped) unreachable)

  (if (or (> (+ unreachable (ctx :failed)) 0)
          teardown-failure
          (= (ctx :passed) 0))
    (os/exit 1)))
