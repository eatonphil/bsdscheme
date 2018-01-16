; Credit to https://github.com/ddz
; Someday bsdscheme will run this

(define map2
  (lambda (f ls1 ls2)
    (if (null? ls1)
        '()
        (cons (f (car ls1) (car ls2)) (map2 f (cdr ls1) (cdr ls2))))))

(define add1
  (lambda (x)
    (+ x 1)))

(define sub1
  (lambda (x)
    (- x 1)))

(define alt
  (lambda (ls)
    (let ((alt-row 1) (alt-col 1))
      (set! alt-row
            (lambda (j k ls)
              (if (null? ls)
                  '()
                  (cons (* j (* k (car ls)))
                        (alt-row j (* -1 k) (cdr ls))))))
      (set! alt-col
            (lambda (l m ls)
              (if (null? ls)
                  '()
                  (cons (alt-row l m (car ls))
                        (alt-col (* -1 l) m (cdr ls))))))
      (if (pair? (car ls))
          (alt-col 1 1 ls)
          (alt-row 1 1 ls)))))

(define sublist
  (lambda (ls n m)
    (let ((tail 1) (head 1)) 
      (set! tail
            (lambda (ls n)
              (if (= n 0)
                  ls
                  (tail (cdr ls) (sub1 n)))))
      (set! head
            (lambda (ls m)
              (if (= m 0)
                  '()
                  (cons (car ls) (head (cdr ls) (sub1 m))))))
      (head (tail ls n) (- m n)))))

(define kill-row
  (lambda (A r)
    (append (sublist A 0 r)
            (sublist A (add1 r) (length A)))))

(define kill-col
  (lambda (A c)
    (map (lambda (x) (kill-row x c)) A)))

(define iota
  (lambda (n)
    (let ((loop 1))
      (set! loop 
            (lambda (m acc)
              (if (= m 0)
                  acc
                  (loop (sub1 m) (cons m acc)))))
      (loop n '()))))

(define determinant
  (lambda (A)
    (let ((n (length A)))
      (if (= n 1)
          (car (car A))
          (let ((B (kill-row A 0)))
            (let ((minors (map (lambda (x) (kill-col B (sub1 x))) (iota n))))
              (let ((cofactors (map determinant minors)))
                (apply + (map2 * (alt (list-ref A 0)) cofactors)))))))))

(define A '((1  2  3  4  5) 
            (6 -5  4 -3  2) 
            (1  3  6  2  4) 
            (3  4  5 -1 -3) 
            (1  0 -1  0 -1)))

(define B '((1  2  3  4  5  6) 
            (6 -5  4 -3  2 -4) 
            (1  3  6  2  4  2)
            (3  4  5 -1 -3  0) 
            (1  0 -1  0 -1 -1)
            (5  4  1 -2  4 -2)))

(define C '((1  2  3  4  5  6  7) 
            (6 -5  4 -3  2 -4  2) 
            (1  3  6  2  4  2 -1)
            (3  4  5 -1 -3  0 -2) 
            (1  0 -1  0 -1 -1 -3)
            (5  4  1 -2  4 -2 -4)
            (7  6  5  4  3  2  1)))

(determinant A)
(determinant B)
(determinant C)
