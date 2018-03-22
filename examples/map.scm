(define (pp a)
  (+ a 1))

(define (main)
  (display (for-each pp (list 1 2 3)))
  (newline))
