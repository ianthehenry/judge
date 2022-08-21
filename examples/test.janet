(use judge)

(test "math"
  (expect (+ 2 2) 4))

(test "math2"
  (expect (+ 2 2) 3))

(test "math3"
  (expect (+ 2 2) 4)
  (expect (+ 2 2) 5)
  (expect (+ 3 3) 5))

(test "sorted-by"
  (expect (sorted-by 0 [[10 10] [1 1]]) [[1 1] [10 10]]))

(test exceptions
  (error "hello"))

(test unreachable
  (when false
    (expect 1 2)))

(test "unreachable due to exception"
  (error "hello")
  (expect 1 1))

(deftest printy-test
  :setup (fn [] (print "setting up") 1)
  :reset (fn [context] (printf "resetting, context = %j" context))
  :teardown (fn [context] (printf "tearing down, context = %j" context)))

(printy-test my-test
  (print "actually running"))
