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

(defn stabilize [node]
  (var i 1)
  (def hex-cache @{})
  (def uniquify (fn [str]
    (get-or-put hex-cache str
      (let [x (string/format " 0x%d>" i)] (++ i) x))))
  (defn recur [node]
    (cond
      (or (function? node) (cfunction? node) (abstract? node))
        (peg-replace ~(* " 0x" :h+ ">") uniquify (string node))
      (walk recur node)))
  (recur node))

(defn bracketify [node]
  (if (tuple? node)
    (tuple/brackets ;(walk stabilize node))
    (walk bracketify node)))
