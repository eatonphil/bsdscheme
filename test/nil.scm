(define list (cons 2 (cons 1 '())))

(define display-with-newline (to-display)
  (display to-display)
  (newline))

(display-with-newline list)
(display-with-newline (car list))
