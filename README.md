# BSDScheme

[![CircleCI](https://circleci.com/gh/eatonphil/bsdscheme.svg?style=svg)](https://circleci.com/gh/eatonphil/bsdscheme)

This is a Scheme implementation written in D intended to eventually
support Scheme R7RS. There is an interpreter backend which is more
mature and there is a compiler backend that targets D.

## Installation

### Mac

```
$ brew install ldc
$ make
```

### FreeBSD

```
$ doas pkg install ldc
$ make
```

## Examples

### Recursion

```
$ cat examples/recursion-tco.scm
(define (exp base pow accum)
  (if (= pow 0)
      accum
      (exp base (- pow 1) (* accum base))))

(define (main)
  (display (exp 2 100 1))
  (newline))
$ ./bin/bsdi examples/exp.scm
1267650600228229401496703205376
```

### Read/eval

```
$ cat examples/read-eval.scm
(display (eval (read "(+ 1 2)")))

(newline)
$ ./bin/bsdi examples/read-eval.scm
3
```

### REPL

```
$ ./bin/bsdi
BSDScheme v0.0.0
> (define (show it) (display it) (newline))
> (show '(1 2 3))
(1 2 3)
> (show (vector-ref #(1 2 3) 1))
2
```

### Compiler (and Macros)

```
$ cat examples/my-let.scm
(define-syntax my-let*
  (syntax-rules ()
    ((_ ((p v)) b ...)
     (let ((p v)) b ...))
    ((_ ((p1 v1) (p2 v2) ...) b ...)
     (let ((p1 v1))
       (my-let* ((p2 v2) ...)
		b ...)))))

(define (main)
  (my-let* ((a 1)
            (b (+ a 2)))
           (display (+ a b))
           (newline)))
$ ./bin/bsdc examples/my-let.scm
$ ./a
4
```

## Current state

* Supported:
  * Literals: strings, characters, boolean, vectors, lists, pairs
  * Read / eval / include
  * Comments
  * Command-line REPL
  * `if`, `let`, `define`, `begin` tail calls optimized (interpreter only)
  * R7RS Libraries (interpreter only)
  * Basic define-syntax/syntax-rules support (not hygienic)
* Missing (but planned, R7RS is the obvious goal):
  * Labelled let
  * D FFI
  * Threading support

## Testing

BSDScheme uses the [btest](https://github.com/briansteffens/btest) test framework.
