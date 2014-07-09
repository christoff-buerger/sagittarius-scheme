#|
creates:
  char-set-range.inc
|#
(import (rnrs) (sagittarius) (match))

(define (shrink-range-list lst)
  (if (null? lst)
      '()
      (let loop ((lst lst) (ans '()))
	(match lst
	  (((e1 . e2)) (reverse! (cons (cons e1 e2) ans)))
	  (((e1 . e2) (e3 . e4) more ...)
	   (if (= e2 (- e3 1))
	       (loop (cons (cons e1 e4) more) ans)
	       (loop (cdr lst) (cons (cons e1 e2) ans))))))))

(define +general-category-1+ 
  (call-with-input-file "./ucd/general-category-1.datum" read))
(define +general-category-2+ 
  (call-with-input-file "./ucd/general-category-2.datum" read))

(define lower? (lambda (p) (eq? (cdr p) 'Ll)))
(define upper? (lambda (p) (eq? (cdr p) 'Lu)))
(define title? (lambda (p) (eq? (cdr p) 'Lt)))
(define alpha? (lambda (p) (memq (cdr p) '(Lu Ll Lt Lm Lo Nl))))
(define numeric? (lambda (p) (eq? (cdr p) 'Nd)))
;; is this correct???
(define punct? (lambda (p) (memq (cdr p) '(Ps Pe Pi Pf Pd Pc Po))))
(define symbl? (lambda (p) (memq (cdr p) '(Sm Sc Sk So))))
(define space? (lambda (p) (memq (cdr p) '(Zs Zl Zp))))
(define cntrl? (lambda (p) (memq (cdr p) '(Cc Cf Co Cs Cn))))

(define (emit-range name pred :optional (other #f))
  (let ((base (map (lambda (p) (cons (car p) (car p)))
		   (append (filter pred +general-category-1+)
			   (filter pred +general-category-2+))))
	(other (if other
		   (call-with-input-file (build-path "ucd" other) read)
		   '())))
    (let ((result (shrink-range-list
		   (list-sort (lambda (a b) (< (car a) (car b)))
			      (append base other)))))
      (print "static struct {")
      (print "  int32_t start;")
      (print "  int32_t end;")
      (format #t "} s_~a[~a] = {~%" name (length result))
      (for-each (lambda (p)
		  (format #t "  {~aL, ~aL},~%" (car p) (cdr p)))
		result)
      (print "};"))))


(define (main args)
  (when (file-exists? "charset.inc") (delete-file "charset.inc"))
  (with-output-to-file "charset.inc"
    (lambda ()
      (print "/* charset.inc                                   -*- mode:c; coding:utf-8 -*- */")
      (print "/* ******** This file is automatically generated. DO NOT EDIT!! ************* */")
      (emit-range "lower_set" lower? "other-lowercase.datum")
      (emit-range "upper_set" upper? "other-uppercase.datum")
      (emit-range "title_set" title?)
      (emit-range "alpha_set" alpha? "other-alphabetic.datum")
      (emit-range "numeric_set" numeric?)
      (emit-range "punct_set" punct?)
      (emit-range "symbl_set" symbl?)
      (emit-range "space_set" space?)
      (emit-range "cntrl_set" cntrl?))))
