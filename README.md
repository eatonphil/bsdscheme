# BSDScheme

This is a Scheme interpreter written in D intended to eventually target Scheme R7RS.

## Installation

### Mac

```
$ brew install ldc
$ make
```

## Example

```
$ cat examples/recursion.scm
(define (exp base pow)
  (if (= pow 0)
      1
      (* base (exp base (- pow 1)))))

(display (exp 2 64))
(newline)
$ ./bin/bsdscheme examples/exp.scm
18446744073709551616
```

## Testing

BSDScheme uses the [btest](https://github.com/briansteffens/btest) test framework.