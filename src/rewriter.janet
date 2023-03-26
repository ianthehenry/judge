(use ./util)

# replacements is a list of [start-index length new-string]
(defn- string-splice [str replacements]
  (def replacements (sorted-by 0 replacements))

  (do
    (var invalid-to 0)
    (each [start len _] replacements
      (when (> invalid-to start)
        (error "overlapping replacements"))
      (set invalid-to (+ start len))))

  (def components @[])
  (var cursor 0)
  (each [start len replacement] replacements
    (array/push components (string/slice str cursor start))
    (array/push components replacement)
    (set cursor (+ start len)))
  (array/push components (string/slice str cursor))

  (string/join components))

(defn- char-at [x i]
  (string/from-bytes (x i)))

(defn- whitespace? [x]
  (or (= x " ") (= x "\n")))

# returns an array of byte indices for the start of each
# subform, in the coordinate space of the source input
(defn components [source start-index form-length]
  (def innards (slice-len source (+ start-index 1) (- form-length 2)))
  (def innard-lines (string/split "\n" innards))
  (def p (parser/new))
  (parser/consume p innards)
  (parser/eof p)
  (def result @[])
  (while (parser/has-more p)
    (array/push result
      (+ start-index 1
        (pos-to-byte-index innard-lines
          (tuple/sourcemap (parser/produce p true))))))
  result)

# replacements should be a list of [form-pos replacement-str]
(defn rewrite-forms [source replacements]
  (def source-lines (string/split "\n" source))

  (string-splice source (seq [[pos replacement] :in replacements]
    (def start (pos-to-byte-index source-lines pos))
    (def len (get-form-length source start))

    (def components (components source start len))
    (def third-form-end (+ start len -1))
    (def third-form-start
      (case (length components)
        0 (error "cannot patch")
        1 (errorf "cannot patch")
        2 third-form-end
        3 (in components 2)))

    (def third-form-len (- third-form-end third-form-start))

    [third-form-start
     third-form-len
     (if (whitespace? (char-at source (- third-form-start 1)))
      replacement
      (string " " replacement))])))
