(define-syntax when
  (syntax-rules ()
    ((when test result ...)
     (if test (begin result ...) '()))))

(when #t
      (display "heyy")
      (newline)
      (newline))
