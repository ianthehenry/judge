# 1-indexed -> 0-indexed
(defn- normalize-pos [[line col]]
  [(- line 1) (- col 1)])

(defn- pos-to-byte-index [lines pos]
  (var bytes 0)
  (def [target-line target-col] (normalize-pos pos))
  (for i 0 target-line (+= bytes (length (in lines i))))
  # add target-line to account for the newlines.
  # not really sure how \r\n newlines would work.
  (+ bytes target-line target-col))

(defn- get-form-length [source start-index]
  (def p (parser/new))

  (var form-length 0)

  (while (not (parser/has-more p))
    (when (= (parser/status p) :error)
      (error "parse error while trying to find the end of a form"))
    (when (> (+ start-index form-length) (length source))
      (error "reached end-of-string before finding the end of the form"))
    (parser/byte p (in source (+ start-index form-length)))
    (++ form-length))
  form-length)

# replacements is a list of [start-index length new-string]
(defn- string-splice [str replacements]
  (def replacements (sorted-by 0 replacements))

  (do
    (var invalid-to 0)
    (each [start len _] replacements
      (when (> invalid-to start)
        (error "overlapping replacements" ))
      (set invalid-to (+ start len))))

  (def components @[])
  (var cursor 0)
  (each [start len replacement] replacements
    (array/push components (string/slice str cursor start))
    (array/push components replacement)
    (set cursor (+ start len)))
  (array/push components (string/slice str cursor))

  (string/join components))

# replacements should be a list of [form-pos replacement-str]
(defn rewrite-forms [source replacements]
  (def source-lines (string/split "\n" source))

  (->> replacements
    (map (fn [[form-pos replacement]]
      (def form-start (pos-to-byte-index source-lines form-pos))
      (def form-length (get-form-length source form-start))
      [form-start form-length replacement]))
    (string-splice source)))
