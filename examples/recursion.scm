(define (exp base pow)
  (if (= pow 0)
      1
      (* base (exp base (- pow 1)))))

(define (main)
  (display (exp 2 62))
  (newline))
