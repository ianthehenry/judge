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

(defn- skip-whitespace [str i]
  (var i i)
  (while (and (< i (length str)) (whitespace? (char-at str i)))
    (++ i))
  i)

# replacements should be a list of [form-pos replacement-str]
(defn rewrite-forms [source replacements]
  (def source-lines (string/split "\n" source))

  (->> replacements
    (map (fn [[enclosing-form-pos replacement]]
      (def enclosing-form-start (pos-to-byte-index source-lines enclosing-form-pos))
      (def enclosing-form-length (get-form-length source enclosing-form-start))

      (def first-form-start (+ enclosing-form-start 1))
      (def first-form-length (get-form-length source first-form-start))

      (def second-form-start (+ first-form-start first-form-length))
      (def second-form-length (get-form-length source second-form-start))

      (def third-form-start (skip-whitespace source (+ second-form-start second-form-length)))

      (def offset (- third-form-start enclosing-form-start))
      (assert (and (> offset 0)
                   (< offset enclosing-form-length)))

      [third-form-start (- enclosing-form-length offset 1) replacement]))
    (map (fn [[start len str]]
      (if (whitespace? (char-at source (- start 1)))
        [start len str]
        [start len (string " " str)])))
    (string-splice source)))
