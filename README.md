# BSDScheme

This is a Scheme interpreter written in D intended to eventual target Scheme R7RS.

## Installation

### Mac

```
$ brew install ldc
$ ldc bsdscheme.d
```

## Example

```
$ cat test/exp.scm
(define exp (base pow)
  (if (= pow 0)
      1
      (* base (exp base (- pow 1)))))

(display (exp 3 3))
(newline)
$ ./bsdscheme test/exp.scm
27
```