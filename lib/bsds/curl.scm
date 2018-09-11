(define-library (bsds curl)
  (import (scheme base) (bsds ffi))
  (export easy-init
          easy-setopt
          easy-perform
          easy-cleanup

          +opt-url+
          +opt-writedata+ 
          +opt-writefunction+)

  (begin
    (define curl (dlopen "/usr/lib/libcurl.dylib"))

    (define-foreign easy-init curl "curl_easy_init")
    (define-foreign easy-setopt curl "curl_easy_setopt" "void")
    (define-foreign easy-perform curl "curl_easy_perform" "void")
    (define-foreign easy-cleanup curl "curl_easy_clean" "void")

    (define +opt-url+ 10002)
    (define +opt-writedata+ 10001)
    (define +opt-writefunction+ 20011)))
