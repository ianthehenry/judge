(import cmd)
(import ./util)
(import ./rewriter)
(import ./colorize)
(use ./shared)

(defn find-all-janet-files [path &opt explicit results]
  (default explicit true)
  (default results @[])
  (when (or explicit (not (util/hidden? path)))
    (case (os/stat path :mode)
      :directory
        (when (or explicit (not= (util/basename path) "jpm_tree"))
          (each entry (os/dir path)
            (find-all-janet-files (string path "/" entry) false results)))
      :file
        (when (or explicit (not= (util/basename path) "project.janet"))
          (if (string/has-suffix? ".janet" path) (array/push results path)))
      nil (array/push results [(string/format "could not read %q" path)])))
results)

(defn- stacktrace [err fib]
  (def buf @"")
  (with-dyns [*err* buf]
    (debug/stacktrace fib err ""))
  (string/trim buf))

(defn- expectation-error
  [{:actual actual
    :expected expected
    :form form
    :error err
    :printer printer
    :stabilizer stabilizer
    } get-full-form]
  (cond
    (truthy? err) (let [[err fib] err] [(stacktrace err fib) nil])
    (empty? actual) ["did not reach expectation" nil]
    (not (util/deep-same? actual)) ["inconsistent results" nil]
    (let [stabilized (stabilizer (first actual))]
      (unless (deep= stabilized expected)
        (def pos (tuple/sourcemap form))
        (def [byte-index form-src] (get-full-form))
        (def multiline? (not= nil (string/find "\n" form-src)))
        (def [line col] pos)
        [nil (printer col multiline? ;stabilized)]))))

(defn safely-accept-corrections
  [&named corrected-filename original-filename
          file-permissions file-cache-entry]
  (def {:source source} file-cache-entry)
  (def current-file-contents (slurp original-filename))
  (if (deep= current-file-contents source)
    (do
      (os/chmod corrected-filename file-permissions)
      # On Windows, os/rename will fail if the destination already exists.
      (os/rm original-filename)
      (os/rename corrected-filename original-filename))
    (eprint
      (colorize/fgf :red "%s changed since test runner began; refusing to overwrite"
        original-filename))))

(defn- apply-replacements [file-cache replacements-by-file accept]
  (eachp [file replacements] replacements-by-file
    (def corrected-file (string file ".tested"))
    (if (empty? replacements)
      (util/rm-p corrected-file)
      (do
        (def file-permissions
          (os/perm-string (os/stat file :int-permissions)))
        (def file-cache-entry (in file-cache file))
        (spit corrected-file
          (rewriter/rewrite-forms file-cache-entry replacements))
        (when accept
          (safely-accept-corrections
            :corrected-filename corrected-file
            :original-filename file
            :file-permissions file-permissions
            :file-cache-entry file-cache-entry))
        ))))

# TODO: should render these relative to the current working directory
(defn- format-pos [file [line col]]
  (string/format "%s:%d:%d" file line col))

(defn- name-of [test]
  (if-let [name (test :name)]
    name
    (format-pos (test :file) (test :pos))))

(defn- prefix-lines [prefix str]
  (->
    (seq [line :in (string/split "\n" str)]
      (string prefix line))
    (string/join "\n")))

(defn interactive-verdict []
  (eprinf "\nVerdict? %s " (colorize/dim "[y]naAdqQ?"))
  (def char (let [line (file/read stdin :line)]
    (if line
      (case (length line)
        1 (chr "y")
        2 (in line 0)))))
  (eprint)
  (case char
    (chr "y") :stage
    (chr "n") :skip
    (chr "a") :stage-this-file
    (chr "d") :skip-this-file
    (chr "A") :stage-all-files
    (chr "q") :quit
    nil :quit
    (chr "Q") :abort
    (do
      (eprint "y - patch this test")
      (eprint "n - do not patch this test")
      (eprint "a - patch this and all subsequent tests in this file")
      (eprint "A - patch this and all subsequent tests in all files")
      (eprint "d - don't patch this or any subsequent tests in this file")
      (eprint "q - quit, patching any selected tests")
      (eprint "Q - abort: exit immediately without patching any files")
      (eprint "? - print help")
      (interactive-verdict))))

(def ctx-proto
  @{:on-test-error (fn [self test]
      (def {:error [err fib]} test)
      (eprint)
      (debug/stacktrace fib err ""))

    :on-test-start (fn [self test]
      (when (not= (self :current-file) (test :file))
        (when (self :needs-newline-before-file-header)
          (eprint))
        (eprint (colorize/dim "# " (test :file)))
        (put self :needs-newline-before-file-header false)
        (put self :current-file (test :file)))
      (cond
        (test :ran) (eprint (colorize/fgf :red "%s ran multiple times" (name-of test)))
        (self :verbose) (eprint "running test: " (name-of test))))

    :should-run-test (fn [self test]
      (not (test :ran)))

    :on-test-end (fn [self test]
      (def {:expectations expectations :file file :pos pos} test)
      (var failed (truthy? (test :error)))

      (put test :ran true)

      (def file-cache-entry (in (self :file-cache) file))

      (def [file-offset test-form] (rewriter/get-form file-cache-entry pos))
      (def local-replacements @[])
      (def replacement-candidates @[])
      (each expectation expectations
        (def epos (tuple/sourcemap (expectation :form)))
        (def get-full-form (util/lazy (rewriter/get-form file-cache-entry epos)))
        (when-let [[err replacement] (expectation-error expectation get-full-form)]
          (set failed true)
          (def [byte-index original-form] (get-full-form))
          (array/push local-replacements [
            (- byte-index file-offset)
            (length original-form)
            (if err
              (string
                 (colorize/fg :red (prefix-lines "# " err))
                 "\n"
                 (string/repeat " " (- (in epos 1) 1))
                 (colorize/fg :red original-form))
               (let [corrected-form (rewriter/rewrite-form original-form [1 1] replacement)]
                 (array/push replacement-candidates [epos replacement])
                 (string
                   (colorize/fg :red original-form)
                   "\n"
                   (string/repeat " " (- (in epos 1) 1))
                   (colorize/fg :green corrected-form))))
            ])))

      (if failed
        (++ (self :failed))
        (++ (self :passed)))

      (when failed
        (put self :needs-newline-before-file-header true)
        (eprint)
        (try
          (eprint (rewriter/string-splice test-form local-replacements))
            ([e fib]
              (eprint (colorize/dim "# overlapping replacements"))
              (eprint (colorize/fg :red test-form))))
        (unless (nil? (test :error))
          (:on-test-error self test))
        (unless (empty? replacement-candidates)
          (defn stage [] (array/concat (in (self :replacements) file) replacement-candidates))
          (def verdict (:get-verdict self test))
          (case verdict
            :stage (stage)
            :stage-this-file (do (stage) (put (self :auto-verdict) file :stage))
            :skip-this-file (put (self :auto-verdict) file :skip)
            :stage-all-files (do (stage) (put self :interactive false))
            :skip nil
            :quit (:quit-gracefully self true)
            :abort (os/exit 1)
            (errorf "unknown verdict %q" verdict)))))

    :get-verdict (fn [self test]
      (if (self :interactive)
        (if-let [verdict ((self :auto-verdict) (test :file))]
          verdict
          (interactive-verdict))
        :stage))

    :quit-gracefully (fn [self explicit-quit]
      (def {:states states
            :tests tests
            :file-cache file-cache
            :replacements replacements
            :overwrite overwrite} self)
      (var teardown-failure false)
      (eachp [{:teardown teardown :name name} state] states
        (match state
          [:ok state]
            (try (teardown state)
              ([e fib]
                (set teardown-failure true)
                (eprint (colorize/fgf :red "failed to teardown %s test context" name))
                (debug/stacktrace fib e "")))))

      (var unreachable 0)
      (unless explicit-quit
        (loop [test :in tests :when (not (test :ran))]
          (eprint (colorize/fg :red (name-of test) " did not run"))
          (++ unreachable)))

      (apply-replacements file-cache replacements overwrite)

      (defn eprin-if [n text]
        (if (> n 0)
          (eprinf " %i %s" n text)))
      (eprinf "\n%i passed" (self :passed))
      (eprin-if (self :failed) "failed")
      (eprin-if (self :skipped) "skipped")
      (eprin-if unreachable "unreachable")
      (eprint)

      (os/exit (cond
        (not (empty? (self :files-in-error))) 2
        teardown-failure 1
        (> (+ unreachable (self :failed)) 0) 1
        (= (self :passed) 0) 1
        0)))
    })

(defn file-selector-matches? [selector file]
  (def selector (util/explicit-relative-path selector))
  (def file (util/explicit-relative-path file))
  (or (= file selector)
    (string/has-prefix? (util/with-trailing-slash selector) file)))

(defn matches [ctx test [predicate-type & predicate-args]]
  (case predicate-type
    :file (let [[file-selector] predicate-args]
      (file-selector-matches? file-selector (test :file)))
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

(defn include-file? [file files-or-dirs]
  (some files-or-dirs |(file-selector-matches? $ file)))

# It might be nice to error if a predicate had no effect.
(defn make-test-predicate [files includes excludes] (fn [ctx test]
  (def file (test :file))
  (cond
    (in (ctx :files-in-error) file) :ignore
    (include-file? file files)
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
   [exclude-targets               --not] (array arg/target) "skip all tests in this target"
   [--untrusting -u] (flag) "re-evaluate all trust expressions"
   [--accept -a] (flag) "overwrite all source files with .tested files"
   [--interactive -i] (flag) "select which replacements to include"
   no-color (last {--color false --no-color true}) "default is --color unless the NO_COLOR environment variable is set"
   [--verbose -v] (flag) "verbose output"]

  (default no-color (truthy? (os/getenv "NO_COLOR" false)))

  (when (and accept interactive)
    (eprint "only one of --accept or --interactive allowed")
    (os/exit 1))

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

  # (dyn :filename) doesn't use an explicit ./, so we strip
  # it off here so that file names are comparable
  (def found-files (map util/implicit-relative-path found-files))

  (def file-excluders (seq [[mode file] :in exclude-targets :when (= mode :all)]
    [:file file]))

  (def pos-selectors (seq [[mode file line col] :in targets :when (= mode :just)]
    [:pos file [line col]]))
  (def pos-excluders (seq [[mode file line col] :in exclude-targets :when (= mode :just)]
    [:pos file [line col]]))

  (def includes
    (array/concat
      pos-selectors
      (map |[:name-prefix $] name-prefix-selectors)
      (map |[:name-exact $] name-exact-selectors)))
  (def excludes
    (array/concat
      file-excluders
      pos-excluders
      (map |[:name-prefix $] name-prefix-filters)
      (map |[:name-prefix $] name-exact-filters)))

  (def ctx (new ctx-proto
    :overwrite (or accept interactive)
    :interactive interactive
    :auto-verdict @{}
    :current-file nil
    :trusting (not untrusting)
    :needs-newline-before-file-header false
    :verbose verbose
    :tests @[]
    :passed 0
    :failed 0
    :skipped 0
    :files-in-error @{}
    :test-predicate (make-test-predicate found-files includes excludes)
    :states @{}
    :file-cache @{}
    :replacements @{}))
  (put root-env *global-test-context* ctx)
  (put root-env colorize/*no-color* no-color)

  (defn not-excluded? [file]
    (not (some file-excluders (fn [[_ selector]]
      (file-selector-matches? selector file)))))

  # If we've already seen this file, we don't want to evaluate it again.
  # Usually requiring the file would be a no-op, because it would be cached
  # in the module cache already. But if it raised a top-level error, it won't
  # be cached. This only works if the file that raised a top-level error hit
  # a test before it raised -- otherwise we have no way of knowing that the
  # file was evaluated -- but since really all we care about is not
  # double-executing tests, this works fine.
  (loop [file :in found-files :when (not-excluded? file)
        :when (not (in (ctx :file-cache) file))]
    (def prefix (if (string/has-prefix? "/" file) "@" "/"))
    (try
      (require (string prefix (util/chop-ext file)))
      ([e fib]
        (put (ctx :files-in-error) file true)
        (debug/stacktrace fib e ""))))

  (:quit-gracefully ctx false))
