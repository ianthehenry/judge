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
