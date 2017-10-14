(display (let ((f (lambda (a b) (+ a b))))
           (f ((lambda (a) (+ a 1)) 20) 3)))

(newline)
