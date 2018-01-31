(define (b arg)
  (stacktrace)
  (display arg)
  (newline))

(define (a arg)
  (b (+ arg 1)))

(define (main)
  (a 1)
  (a (a 2)))
