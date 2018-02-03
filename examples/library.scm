(define-library (test)
  (export +)
  (begin
    (define (+ a b) (- a b))))

(define (main)
  (import (test))

  (display (+ 7 4))
  (newline))
