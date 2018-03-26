(define-syntax when
  (syntax-rules ()
    ((when test result)
     (if test result '()))))

(define (main)
  (when #t (display "heyy\n")))
