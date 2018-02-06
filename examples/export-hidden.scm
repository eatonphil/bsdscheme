(define-library (helper)
  (import (scheme base))
  (begin
    (define p 123)))

(import (scheme base) (scheme write) (helper))

(define (main)
  (display p))
