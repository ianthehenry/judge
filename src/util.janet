(defn rm-p [file]
  (when (os/stat file)
    # TODO: there's a little bit of a race here... should add rm-p to janet
    (os/rm file)))

(defn slice-len [target start len]
  (slice target start (+ start len)))

(defmacro put-if-unset [t k v]
  (with-syms [$t $k]
    ~(let [,$t ,t ,$k ,k]
      (when (nil? (in ,$t ,$k))
        (put ,$t ,$k ,v)))))

(defn deep-same? [list]
  (case (length list)
    0 true
    1 true
    (do
      (def proto (in list 0))
      (all |(deep= proto $) list))))

(defn get-error [<expr>]
  (with-syms [$errored $err]
    ~(let [[,$err ,$errored]
           (try [,<expr> false]
             ([,$err] [,$err true]))]
      (if ,$errored ,$err (,error "did not error")))))

(defmacro get-or-put [t k v]
  (with-syms [$t $k $v]
    ~(let [,$t ,t ,$k ,k]
      (if-let [,$v (in ,$t ,$k)]
        ,$v
        (let [,$v ,v]
          (put ,$t ,$k ,$v)
          ,$v)))))

(defn peg-replace [pat f str]
  (first (peg/match ~(* (% (any (+ (/ (<- ,pat) ,f) (<- 1)))) -1) str)))

(defn- gensymbly? [sym]
  (and
    (symbol? sym)
    (= (length sym) 7)
    (string/has-prefix? "_0" sym)))

(defn stabilize [node]
  (def hex-cache @{})
  (def gensym-cache @{})
  (def uniquify-hex (fn [str]
    (get-or-put hex-cache str (string/format " 0x%d>" (inc (length hex-cache))))))
  (defn stabilize-hex [node]
    (peg-replace ~(* " 0x" :h+ ">") uniquify-hex (string node)))
  (defn stable-function [name] (symbol "@" name))
  (prewalk (fn [node]
    (cond
      (gensymbly? node) (get-or-put gensym-cache node (symbol "<" (inc (length gensym-cache)) ">"))
      (abstract? node) (stabilize-hex node)
      (cfunction? node)
        # there's no programmatic way to get the
        # name of a cfunction
        (if-let [sym (in make-image-dict node)]
          (stable-function sym)
          (stabilize-hex node))
      (function? node)
        (if-let [name (disasm node :name)]
          (stable-function name)
          (stabilize-hex node))
      node))
    node))

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

(defn hidden? [path]
  (string/has-prefix? "." (basename path)))

(defn last? [i list]
  (= i (- (length list) 1)))

(defmacro catseq [dsl & body]
  (with-syms [$result]
    ~(let [,$result @[]]
      (loop ,dsl
        (,array/concat ,$result (do ,;body)))
      ,$result)))

(defn with-trailing-slash [path]
  (if (string/has-suffix? "/" path) path (string path "/")))

(defn explicit-relative-path [path]
  (if (string/has-prefix? "/" path) path
    (if (string/has-prefix? "./" path) path
      (string "./" path))))

(defn implicit-relative-path [path]
  (if (string/has-prefix? "./" path)
    (string/slice path 2)
    path))

(defmacro lazy [& body]
  (with-syms [$f $forced? $result]
    ~(do
      (def ,$f (fn [] ,;body))
      (var ,$forced? false)
      (var ,$result nil)
      (fn []
        (unless ,$forced?
          (set ,$result (,$f))
          (set ,$forced? true))
        ,$result))))
