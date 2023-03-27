(defn- has-source-map? [x]
  (some |(not= $ -1) (tuple/sourcemap x)))

(defn- tuple-of-type [elems type]
  (case type
    :brackets (tuple/brackets ;elems)
    :parens (tuple ;elems)
    (errorf "illegal tuple type %p" type)))

(defn- tuple-preserve [original mapped]
  (tuple-of-type mapped
    (if (has-source-map? original)
      (tuple/type original)
      :brackets)))

(defn freeze-with-brackets [x]
  (case (type x)
    :array (tuple/brackets ;(map freeze-with-brackets x))
    :tuple (tuple-preserve x (map freeze-with-brackets x))
    :table (if-let [p (table/getproto x)]
             (freeze-with-brackets (merge (table/clone p) x))
             (struct ;(map freeze-with-brackets (kvs x))))
    :struct (struct ;(map freeze-with-brackets (kvs x)))
    :buffer (string x)
    x))

(defn rm-p [file]
  (when (os/stat file)
    # TODO: there's a little bit of a race here... should add rm-p to janet
    (os/rm file)))

(defn slice-len [target start len]
  (slice target start (+ start len)))

(defmacro get-or-put [t k v]
  (with-syms [$t $k $v]
    ~(let [,$t ,t ,$k ,k]
      (if-let [,$v (in ,$t ,$k)]
        ,$v
        (let [,$v ,v]
          (put ,$t ,$k ,$v)
          ,$v)))))

(defn deep-same? [list]
  (case (length list)
    0 true
    1 true
    (do
      (def proto (in list 0))
      (all |(deep= proto $) list))))
