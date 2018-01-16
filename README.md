# BSDScheme

This is a Scheme interpreter written in D intended to eventually target Scheme R7RS.

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
$ cat examples/recursion.scm
(define (exp base pow)
  (if (= pow 0)
      1
      (* base (exp base (- pow 1)))))

(display (exp 2 64))
(newline)
$ ./bin/bsdi examples/exp.scm
18446744073709551616
```

### Read/eval

```
$ cat examples/read-eval.scm
(display (eval (read "(+ 1 2)")))

(newline)
$ ./bin/bsdi examples/read-eval.scm
3
```

## Features

This isn't so much "features" as in its done unique or well so much
as any of it can be done at all.

* Big numbers
* Strings
* Read / eval
* Line comments

## Testing

BSDScheme uses the [btest](https://github.com/briansteffens/btest) test framework.