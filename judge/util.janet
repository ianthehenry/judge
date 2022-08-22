# 1-indexed -> 0-indexed
(defn- normalize-pos [[line col]]
  [(- line 1) (- col 1)])

(defn- delimited? [x]
  (case (type x)
    :array true
    :tuple true
    :table true
    :struct true
    :string true
    :buffer true
    false))

(defn pos-to-byte-index [lines pos]
  (var bytes 0)
  (def [target-line target-col] (normalize-pos pos))
  (for i 0 target-line (+= bytes (length (in lines i))))
  # add target-line to account for the newlines.
  # not really sure how \r\n newlines would work.
  (+ bytes target-line target-col))

(defn get-form-length [source start-index]
  (def p (parser/new))

  (var form-length 0)

  (while (not (parser/has-more p))
    (when (= (parser/status p) :error)
      (error "parse error while trying to find the end of a form"))
    (when (> (+ start-index form-length) (length source))
      (error "reached end-of-string before finding the end of the form"))
    (parser/byte p (in source (+ start-index form-length)))
    (++ form-length))

  # we found a value, which means that either
  # we parsed a closing delimiter, or a character
  # that cannot be part of an atom. So we will have
  # advanced something like this:
  # "(hello)"
  # "hello "
  # "hello)"
  (if (delimited? (parser/produce p))
    form-length
    (- form-length 1)))
