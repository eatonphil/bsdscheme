(define-syntax when
  (syntax-rules ()
    ((when test result ...)
     (if test (begin result ...) '()))))

(define (main)
  (when #t
        (display "heyy")
        (newline)
        (newline)))
