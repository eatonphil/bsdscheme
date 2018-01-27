cases:
  - name: basic
    status: 0
    stdout: abc

templates:
- test.scm: |

    (display (list->string '(#\a #\b #\c)))
