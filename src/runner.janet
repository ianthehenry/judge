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

(defn extless [path]
  (def [dir base] (split-path path))
  (def [extless] (string/split "." base))
  (string/join [;dir extless] "/"))

(defn to-abs [path]
  (if (string/has-prefix? "/" path)
    path
    (string (os/cwd) "/" path)))

(defn find-all-janet-files [path &opt results]
  (default results @[])
  (case (os/stat path :mode)
    :directory
      (when (not= (basename path) "jpm_tree")
        (each entry (os/dir path)
          (find-all-janet-files (string path "/" entry) results)))
    :file (if (string/has-suffix? ".janet" path) (array/push results path))
    nil (array/push results [(string/format "could not read %q" path)]))
results)

(defn- serialize [x]
  [(util/freeze-with-brackets x)])

(defn- prettify [value] (string/format "%j" value))
(defn- prettify-many [values] (string/join (map prettify values) " "))

(defn- expectation-error [expectation]
  (def {:actual actual :expected expected :form form :error err} expectation)
  (cond
    (truthy? err) (let [[err fib] err] [err nil])
    (empty? actual) ["did not reach expectation" nil]
    (not (util/deep-same? actual)) ["inconsistent results" nil]
    (empty? expected)
      ["virgin soil"
       [(tuple/sourcemap form)
        (prettify-many (serialize (first actual)))]]
    (deep-not= (serialize (first actual)) expected)
      # todo: duplicated code. do these need to be different?
      ["mismatch"
       [(tuple/sourcemap form)
        (prettify-many (serialize (first actual)))]]))

#(defn safely-accept-corrections [corrected-filename original-filename file-contents]
#  (def current-file-contents
#    (with [source-file (file/open original-filename :rn)]
#      (string (file/read source-file :all))))
#
#  (if (= (file-contents original-filename) current-file-contents)
#    (os/rename corrected-filename original-filename)
#    (eprint
#      (colorize/fgf :yellow "source file %s has changed; refusing to overwrite with .corrected file"
#        original-filename))))

(defn- apply-replacements [file-cache replacements-by-file]
  (eachp [file replacements] replacements-by-file
    (def corrected-file (string file ".tested"))
    (if (empty? replacements)
      (util/rm-p corrected-file)
      (do
        (spit corrected-file
          (rewriter/rewrite-forms (in file-cache file) replacements))
        #(when accept-corrected-files
        #  (safely-accept-corrections corrected-file file file-cache))
        ))))

# TODO: should render these relative to the current working directory
(defn- format-location [file [line col]]
  (string/format "%s:%d:%d" file line col))

(defn- name-of [test]
  (if-let [name (test :name)]
    name
    (format-location (test :file) (test :location))))

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

(defn new [proto & kvs] (table/setproto (table ;kvs) proto))

(cmd/defn main
  [targets (array :file)]

  (def targets
    (if (empty? targets)
      ["."]
      targets))

  # resolve all directories
  (def inflated-targets (mapcat find-all-janet-files targets))
  (loop [target :in inflated-targets :when (tuple? target) :let [[err] target]]
    (eprintf "error: %s" err)
    (os/exit 1))

  (def ctx (new ctx-proto
    :tests @[]
    :passed 0
    :failed 0
    :skipped 0
    :states @{}
    :file-cache @{}
    :replacements @{}))
  (put root-env *global-test-context* ctx)

  # targets should be a list of files or a list of file:line:col.
  (each target inflated-targets
    (def [file line col] (string/split ":" target))
    # TODO: we'll actually get better stack traces if we run these
    # with relative paths, not absolute paths
    (require (string "@" (to-abs (extless file)))))

  # TODO: we should catch this if it errors and fail the test suite
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

  (apply-replacements (ctx :file-cache) (ctx :replacements))

  (eprintf "%i passed %i failed %i skipped %i unreachable"
    (ctx :passed) (ctx :failed) (ctx :skipped) unreachable)

  (if (or (> (+ unreachable (ctx :failed)) 0) teardown-failure)
    (os/exit 1)))
