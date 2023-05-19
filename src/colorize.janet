(def *no-color* (gensym))

(def- colors
  {:black 0
   :red 1
   :green 2
   :yellow 3
   :blue 4
   :magenta 5
   :cyan 6
   :white 7})

(def- foreground 30)
(def- background 40)

(defn- encode [color offset]
  (def color-code (in colors color))
  (assert color-code "color not found")
  (+ color-code offset))

(defn- colorize? [] (not (dyn *no-color*)))

(defn fg [color & strs]
  (if (colorize?)
    (string "\e[" (encode color foreground) "m" ;strs "\e[0m")
    (string ;strs)))

(defn fgf [color & strs]
  (fg color (string/format ;strs)))

(defn dim [& strs]
  (if (colorize?)
    (string "\e[2m" ;strs "\e[0m")
    (string ;strs)))

(defn dimf [& strs]
  (dim (string/format ;strs)))

(defn bg [color & strs]
  (if (colorize?)
    (string "\e[" (encode color background) "m" ;strs "\e[0m")
    (string ;strs)))

(defn bgf [color & strs]
  (bg color (string/format ;strs)))
