(define-syntax when
  (syntax-rules ()
    ((when test result)
     (if test result '()))))

(when #t (display "heyy\n"))
