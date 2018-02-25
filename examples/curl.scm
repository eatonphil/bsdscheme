(import (scheme base) (bsds curl) (bsds ffi))

(define-callback (read-body ((string buffer) offset length (string data)))
  (string-append! data (substring buffer offset length)))

(define (main)
  (let ((curl (easy-init))
        (body ""))
    (easy-setopt +opt-url+ "http://httpbin.org/ip")
    (easy-setopt +opt-writefunction+ read-body)
    (easy-setopt +opt-writedata+ &body)
    (easy-perform curl)))
