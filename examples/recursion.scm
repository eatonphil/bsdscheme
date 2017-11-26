(define exp (base pow)
  (if (= pow 0)
      1
      (* base (exp base (- pow 1)))))

(display (exp 2 64))
(newline)
