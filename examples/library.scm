(define-library (test)
  (import (scheme base))
  (export +)
  (begin
    (define (+ a b) (- a b))))

(import (scheme base) (scheme write))

(define (main)
  (import (test))

  (display (+ 7 4))
  (newline))
