(define (show it)
  (display it)
  (newline)
  (newline))


(define s "Hello world!")

(show s)

(show (string-length s))

(show (string-ref s 1))

(show (string=? s "Hello world!" s))

(show (string=? s "Hello world?"))

(show (string? 1))

(show (string? "foo"))

(string-set! s 0 #\C)

(show s)

(show (string-append s " This is BSDScheme!" " What are you?"))

(define l '(#\a #\b #\c))
(show (list->string l))

(newline)
