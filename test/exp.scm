(define exp (base pow)
  (if (= pow 0)
      1
      (* base (exp base (- pow 1)))))

(exp 9 10)
