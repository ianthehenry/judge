(import ./util)

(defn- type+ [x]
  (if (tuple? x)
    (case (tuple/type x)
      :parens :ptuple
      :brackets :btuple)
    (type x)))

# copied from spork/fmt and modified
(def- sequencey-forms '(fn match with
  with-dyns defn defn- varfn defmacro
  defmacro- defer edefer loop seq tabseq
  generate coro for each eachp eachk case
  cond do if when when-let when-with
  while with-syms with-vars if-let if-not
  if-with let try unless forever upscope
  repeat forv compwhen compif ev/spawn
  ev/do-thread ev/with-deadline label
  prompt))

(def- sequencey-lookup (tabseq [sym :in sequencey-forms] sym true))

(defn- sequencey? [form]
  (truthy? (in sequencey-lookup form)))

# This is pretty basic.
(defn prindent [form indentation &opt newline]
  (prin (string/repeat " " indentation))
  (match (type+ form)
    (:ptuple (sequencey? (first form))) (do
      (prin "(")
      (def indentation (+ 2 indentation))
      (eachp [i el] form
        (prindent el
          (if (= i 0) 0 indentation)
          (not (util/last? i form))))
      (prin ")"))
    (prinf "%q" form))
  (if newline (print)))

# a line is a tuple of [indentation text]
(defn multiline? [lines]
  (> (length lines) 1))

(defn line-length [[indent text]]
  (+ indent (length text)))

(defn indent [lines by]
  (seq [[old text] :in lines]
    [(+ old by) text]))

(defn trailing-indent [lines by]
  [(first lines) ;(indent (drop 1 lines) by)])

(var prettify nil)

(defn surround [lines open close]
  (def last-index (- (length lines) 1))
  (def first-index 0)
  (seq [[i [indentation text]] :pairs lines]
    (var text text)
    (var indentation indentation)
    (if (= i first-index)
      (set text (string open text))
      (+= indentation (length open)))
    (if (= i last-index)
      (set text (string text close)))
    [indentation text]))

(defn should-be-multiline? [pretty-elements open close]
  (if (empty? pretty-elements) (break false))
  (def spaces (- (length pretty-elements) 1))
  (or (some multiline? pretty-elements)
      (> (+ spaces
            (length open)
            (length close)
            (sum (map (comp line-length 0) pretty-elements)))
         40)))

(defn as-single-line [pretty-elements open close]
  [[0 (string open (string/join (map (comp 1 0) pretty-elements) " ") close)]])

(defn prettify-list [node]
  (def [open close] (case (type+ node)
    :ptuple ["[" "]"]
    # This would be nice, but it requires changing the equality check we do
    # to treat `(quote [1])` the same as `[1]`...
    #:btuple ["'[" "]"]
    :btuple ["[" "]"]
    :array ["@[" "]"]
    (error "non-indexed type")))
  (def pretty-elements (map prettify node))
  (if (should-be-multiline? pretty-elements open close)
    (surround (mapcat |$ pretty-elements) open close)
    (as-single-line pretty-elements open close)))

(defn sorted-kvs [ds]
  (util/catseq [k :in (sort (keys ds))]
    [k (in ds k)]))

(defn join-kvs [key-lines value-lines]
  (if (multiline? key-lines)
    [;key-lines ;(indent value-lines 2)]
    (let [[[key-indent key-text]] key-lines
          [[_ first-value-line] & rest] value-lines]
      [[key-indent (string key-text " " first-value-line)]
       ;(indent rest (+ 1 (length key-text)))])))

(defn prettify-pairs [node]
  (def [open close] (case (type node)
    :struct ["{" "}"]
    :table ["@{" "}"]
    (error "non-dictionary type")))
  (def pretty-elements (map prettify (sorted-kvs node)))
  (if (should-be-multiline? pretty-elements open close)
    (-> (util/catseq [[key-lines value-lines] :in (partition 2 pretty-elements)]
      (join-kvs key-lines value-lines))
      (surround open close))
    (as-single-line pretty-elements open close)))

(varfn prettify [element]
  (case (type element)
    :tuple (prettify-list element)
    :array (prettify-list element)
    :table (prettify-pairs element)
    :struct (prettify-pairs element)
    [[0 (string/format "%q" element)]]))

(defn prin-lines [lines]
  (eachp [i [indentation text]] lines
    (if (> i 0) (print))
    (prin (string/repeat " " indentation))
    (prin text)))

(defn pretty-print [element &opt trailing-indentation]
  (default trailing-indentation 0)
  (prin-lines (trailing-indent (prettify element) trailing-indentation))
  (print))

(defn to-string-pretty [element &opt indentation]
  (def lines (prettify element))
  (def [lines buf] (if (multiline? lines) [(indent lines indentation) @"\n"] [lines @""]))
  (with-dyns [*out* buf]
    (prin-lines lines))
  buf)
