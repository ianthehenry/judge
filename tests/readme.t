  $ source $TESTDIR/scaffold

  $ use <<EOF
  > (use judge)
  > 
  > (defn slow-sort [list]
  >   (case (length list)
  >     0 list
  >     1 list
  >     2 (let [[x y] list] [(min x y) (max x y)])
  >     (do
  >       (def pivot (in list (math/floor (/ (length list) 2))))
  >       (def bigs (filter |(> $ pivot) list))
  >       (def smalls (filter |(< $ pivot) list))
  >       [;(slow-sort smalls) pivot ;(slow-sort bigs)])))
  > 
  > (test (slow-sort [3 1 4 2]))
  > EOF

  $ judge
  ! running test: ./script.janet:14:1
  ! <red>- (test (slow-sort [3 1 4 2]))</>
  ! <grn>+ (test (slow-sort [3 1 4 2]) [1 2 3 4])</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]
