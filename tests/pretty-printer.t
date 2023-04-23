  $ source $TESTDIR/scaffold

Pretty-printer:

  $ use <<EOF
  > (import judge/fmt)
  > (def long-list ["long strings that will actually" "need to wrap to multiple lines"])
  > (fmt/pretty-print [1 2 3])
  > (fmt/pretty-print [1 [2 3] 4])
  > (fmt/pretty-print [1 [2 3] [[4 5] 6 7] [8 9] [[10 11 12]]])
  > (fmt/pretty-print [1 [2 3] [[4 5] 6 7] [8 9] [[10 11 12] 13]])
  > (fmt/pretty-print long-list)
  > (fmt/pretty-print [1 2 long-list 3 4])
  > (fmt/pretty-print [1 2 (array/slice long-list) 3 4])
  > (fmt/pretty-print [])
  > (fmt/pretty-print [1 '[2] 3])
  > (fmt/pretty-print {:a 1})
  > (fmt/pretty-print {:a long-list})
  > (fmt/pretty-print {long-list 123})
  > (fmt/pretty-print {[1 2] :a [3 4] :b})
  > (fmt/pretty-print @{:a 1 :b 2 :c 3 :d 4 :e 5 :f 6 :g 7 :h 8 :i 9 :j 10})
  > EOF

  $ run script.janet
  [1 2 3]
  [1 [2 3] 4]
  [1 [2 3] [[4 5] 6 7] [8 9] [[10 11 12]]]
  [1
   [2 3]
   [[4 5] 6 7]
   [8 9]
   [[10 11 12] 13]]
  ["long strings that will actually"
   "need to wrap to multiple lines"]
  [1
   2
   ["long strings that will actually"
    "need to wrap to multiple lines"]
   3
   4]
  [1
   2
   @["long strings that will actually"
     "need to wrap to multiple lines"]
   3
   4]
  []
  [1 [2] 3]
  {:a 1}
  {:a ["long strings that will actually"
       "need to wrap to multiple lines"]}
  {["long strings that will actually"
    "need to wrap to multiple lines"]
     123}
  {[1 2] :a [3 4] :b}
  @{:a 1
    :b 2
    :c 3
    :d 4
    :e 5
    :f 6
    :g 7
    :h 8
    :i 9
    :j 10}

Large, nested data structures render across multiple lines:

  $ use <<EOF
  > (use judge)
  > (def state @{:clipboard @["Hello, there"] :coloffset 0 :cx 0 :cy 0 :dirty 0 :erows @[] :filename "" :filetype "" :leftmargin 4 :linenumbers true :modalinput "" :modalmsg "" :rememberx 0 :rowoffset 0 :screencols 100 :screenrows 38 :select-from @{} :select-to @{} :statusmsg "" :statusmsgtime 0 :userconfig @{ :indentwith :spaces :numtype :on :scrollpadding 5 :tabsize 2}})
  > (test state)
  > EOF

  $ judge -a
  ! <dim># script.janet</>
  ! 
  ! <red>(test state)</>
  ! <grn>(test state
  !   @{:clipboard @["Hello, there"]
  !     :coloffset 0
  !     :cx 0
  !     :cy 0
  !     :dirty 0
  !     :erows @[]
  !     :filename ""
  !     :filetype ""
  !     :leftmargin 4
  !     :linenumbers true
  !     :modalinput ""
  !     :modalmsg ""
  !     :rememberx 0
  !     :rowoffset 0
  !     :screencols 100
  !     :screenrows 38
  !     :select-from @{}
  !     :select-to @{}
  !     :statusmsg ""
  !     :statusmsgtime 0
  !     :userconfig @{:indentwith :spaces
  !                   :numtype :on
  !                   :scrollpadding 5
  !                   :tabsize 2}})</>
  ! 
  ! 0 passed 1 failed
  [1]
  $ judge
  ! <dim># script.janet</>
  ! 
  ! 1 passed
