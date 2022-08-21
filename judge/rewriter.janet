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

# replacements should be a list of [form-pos replacement-str]
(defn rewrite-forms [source replacements]
  (def source-lines (string/split "\n" source))

  (->> replacements
    (map (fn [[form-pos replacement]]
      (def form-start (pos-to-byte-index source-lines form-pos))
      (def form-length (get-form-length source form-start))
      [form-start form-length replacement]))
    (string-splice source)))
