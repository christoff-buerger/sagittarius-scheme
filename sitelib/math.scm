;; -*- mode: scheme; coding: utf-8; -*-
;; math.scm: mathmatic library.

(library (math)
    (export mod-inverse
	    mod-exp)
    (import (rnrs)
	    (sagittarius))
  (define (mod-inverse u v)
    (let ((u1 1)
	  (u3 u)
	  (v1 0)
	  (v3 v)
	  (bi 1))
      (do ()
	  ((zero? v3) #t)
	(receive (q t3) (div-and-mod u3 v3)
	  (let* ((w (* q v1))
		 (t1 (+ u1 w)))
	    (set! u1 v1)
	    (set! v1 t1)
	    (set! u3 v3)
	    (set! v3 t3)
	    (set! bi (- bi)))))
      (if (negative? bi)
	  (- v u1)
	  u1)))

  ;; compute a ^ b mod n
  (define (mod-exp x n d)
    (do ((y 1) (n n))
	((<= n 0) y)
      (if (odd? n)
	  (set! y (mod (* y x) d)))
      (set! n (bitwise-arithmetic-shift-right n 1))
      (if (positive? n)
	  (set! x (mod (* x x) d))))
    )
  )