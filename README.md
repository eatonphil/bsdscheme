# BSDScheme

This is a Scheme implementation written in D intended to eventually
target Scheme R7RS. There is an interpreter backend which is more
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

### Compiler

```
$ cat examples/compile-basic.scm
(define (plus a b)
  (+ a b))

(define (main)
  (display (plus 1 2)))
$ ./bin/bsdc examples/compile-basic.scm
$ ./a
3
```

## Current state

* Supported:
  * Literals: strings, characters, boolean, vectors, lists, pairs
  * Read / eval / include
  * Comments
  * Command-line REPL
  * `if`, `let`, `define`, `begin` tail calls optimized
* Missing (but planned, R7RS is the obvious goal):
  * Macros
  * Labelled let
  * Modules
  * D FFI
  * Threading support

## Testing

BSDScheme uses the [btest](https://github.com/briansteffens/btest) test framework.