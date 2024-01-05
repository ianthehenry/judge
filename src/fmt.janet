(import ./util)

(defn- type+ [x]
  (if (tuple? x)
    (case (tuple/type x)
      :parens :ptuple
      :brackets :btuple)
    (type x)))

# copied from spork/fmt and modified
(def- builtin-fmt '{
  coro 1 defer 1 edefer 1 do 1 upscope 1 forever 1
  ev/spawn 1 ev/do-thread 1
  fn 2 match 2 with 2 with-dyns 2 defn 2 defn- 2 varfn 2 defmacro 2
  defmacro- 2 loop 2 seq 2 tabseq 2 castseq 2 generate 2
  each 2 eachp 2 eachk 2 case 2 cond 2 if 2 when 2 when-let 2 when-with 2
  while 2 with-syms 2 with-vars 2 if-let 2 if-not 2
  if-with 2 let 2 try 2 unless 2 repeat 2 compwhen 2 compif 2
  ev/with-deadline 2
  label 2 prompt 2
  for 4 forv 4 })

(defn- on-first-line [form]
  (def car (first form))
  (when (= car 'as-macro)
    (when-let [cadr (get form 1)]
      (when (symbol? cadr)
        (def macro-name (if (string/has-prefix? "@" cadr) (symbol (string/slice cadr 1)) cadr))
        (break (+ 1 (on-first-line [macro-name ;(drop 2 form)]))))))
  (when-let [on-first-line (in builtin-fmt car)]
    (break on-first-line))
  (if-let [binding (in (curenv) car)]
    (cond
      (binding :fmt/block) 1
      (binding :fmt/control) 2
      (length form))
    (length form)))

(defn prindent [form indentation &opt newline]
  (prin (string/repeat " " indentation))
  (match (type+ form)
    :ptuple (do
      (def on-first-line (on-first-line form))
      (prin "(")
      (for i 0 on-first-line
        (prinf "%s%q" (if (= i 0) "" " ") (form i)))
      (when (< on-first-line (length form))
        (print))
      (for i on-first-line (length form)
        (def el (form i))
        (prindent el (+ indentation 2) (not (util/last? i form))))
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

# If the simpler representation round-trips,
# don't use the potentially longer .17g expansion,
# even if it is a more precise decimal expansion of
# the actual floating point number
(defn float-to-string-round-trippable [num]
  (def simple-candidate (string num))
  (if (= (scan-number simple-candidate) num)
    simple-candidate
    (cond
      (= num math/inf) "9e999"
      (= num (- math/inf)) "-9e999"
      # LDBL_DIG - 1 (for the leading zero) = 17
      (string/format "%.17g" num))))

(varfn prettify [element]
  (case (type element)
    :tuple (prettify-list element)
    :array (prettify-list element)
    :table (prettify-pairs element)
    :struct (prettify-pairs element)
    :number [[0 (float-to-string-round-trippable element)]]
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
