(define (show it)
  (display it)
  (newline)
  (newline))

(define v #(1 2 3))

(show v)

(show (vector-length v))

(show (vector-ref v 1))

(vector-set! v 1 5)

(show v)
