(define (exp base pow accum)
  (if (= pow 0)
      accum
      (begin (stacktrace) (exp base (- pow 1) (* accum base)))))

(define (main)
  (display (exp 2 100 1))
  (newline))
