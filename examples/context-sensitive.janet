(use judge)

(deftest stateful-test
  :setup (fn [] @{:n 0})
  :reset (fn [context] (set (context :n) 0)))

(stateful-test "initial state" [state]
  (expect (state :n) 0))

(stateful-test "state can be mutated" [state]
  (set (state :n) 1)
  (expect (state :n) 1))

(stateful-test "state is back to normal" [state]
  (expect (state :n) 0))

(deftest erroneous-setup
  :setup (fn [] (error "oh no")))

(erroneous-setup "test that will be skipped"
  (error "unreachable"))

(erroneous-setup "another test that will be skipped"
  (error "unreachable"))

(deftest erroneous-reset
  :setup (fn [] @{:n 0})
  :reset (fn [context] (error "oh dear")))

(erroneous-reset "test that will be skipped for a different reason"
  (error "unreachable"))

(erroneous-reset "and yeah we're still skipping here"
  (error "unreachable"))
