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

(show (string-upcase s))

(show (string-downcase s))

(show (substring s 0 5))

(show '(1 2 3))

(show (string->list s))

(string-fill! s #\T)

(show s)

(show (string-length s))

(define s "Hello")

(string-fill! s \#T 2 4)
