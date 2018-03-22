(define (main)
  (define a 1)
  (display ((lambda (b) (+ a b)) 12)))
