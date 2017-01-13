;;; -*- mode: scheme; coding: utf-8 -*-
;;;
;;; ec.scm - Elliptic curve
;;; 

;; this library provides 3 things
;;  - curve parameters
;;  - constructors (ec point and curve)
;;  - and arithmetic procedure for ec points
;;
;; there are 2 curves used, one is Fp and other one is F2m.
;; Fp is 
;;   y^2 = x^3 + ax + b (mod p)
;; F2m is
;;   y^2 + xy = x^3 + ax^2 + b (mod p)
#!core
(library (math ec)
    (export make-ec-point
	    ec-point-add
	    ec-point-twice
	    ec-point-negate
	    ec-point-sub
	    ec-point-mul
	    ;; NIST parameters
	    NIST-P-192 (rename (NIST-P-192 secp192r1))
	    NIST-P-224 (rename (NIST-P-224 secp224r1))

	    ;; SEC 2 parameters
	    sect113r1
	    sect163k1
	    
	    ec-parameter?
	    ec-parameter-curve

	    ;; for testing
	    make-elliptic-curve
	    make-ec-field-fp
	    make-ec-field-f2m
	    ec-infinity-point
	    )
    (import (core)
	    (core base)
	    (core errors)
	    (core syntax)
	    (core inline)
	    (core record)
	    (sagittarius))

  ;; modular arithmetic
  ;; these are needed on for Fp
  ;; a + b (mod p)
  (define (mod-add a b p) (mod (+ a b) p))
  ;; a - b (mod p)
  (define (mod-sub a b p) (mod (- a b) p))
  ;; a * b (mod p)
  ;;(define (mod-mul a b p) (mod (* a b) p))
  (define (mod-mul a b p) (* (mod a p) (mod b p)))
  ;; a / b (mod p)
  (define (mod-div a b p) (mod (* a (mod-inverse b p)) p))
  ;; a^2 (mod p)
  (define (mod-square a p) (mod-expt a 2 p))
  ;; -a (mod p)
  (define (mod-negate a p) (mod (- a) p))
  ;; mod-inverse is defined in (sagittarius)
  ;; mod-expt is defined in (sagittarius)


  ;; to make constant foldable, we use vectors to represent
  ;; data structure
  ;;;
  ;; EC Curve
  ;; curve is a vector which contains type and parameters
  ;; for the curve.

  ;; make my life easier
  (define-syntax define-vector-type
    (lambda (x)
      (define (order-args args fs)
	(map (lambda (a) 
	       (cond ((memp (lambda (f) (bound-identifier=? a f)) fs) => car)
		     (else
		      (syntax-violation 'define-vector-type "unknown tag" a))))
	     args))
      (define (generate-accessor k acc)
	;; starting from 1 because 0 is type tag
	(let loop ((r '()) (i 1) (acc acc))
	  (syntax-case acc ()
	    ((name rest ...)
	     (with-syntax ((n (datum->syntax k i)))
	       (loop (cons #'(define (name o) (vector-ref o n)) r)
		     (+ i 1)
		     #'(rest ...))))
	    (() r))))
      (syntax-case x ()
	((k type (ctr args ...) pred
	    (field accessor) ...)
	 (and (identifier? #'pred) (identifier? #'type) (identifier? #'ctr))
	 (with-syntax (((ordered-args ...)
			(order-args #'(args ...) #'(field ...)))
		       ((acc ...) (generate-accessor #'k #'(accessor ...))))
	 #'(begin
	     (define (ctr args ...) (vector 'type ordered-args ...))
	     (define (pred o) 
	       (and (vector? o)
		    (= (vector-length o) (+ (length #'(field ...)) 1))
		    (eq? (vector-ref o 0) 'type)))
	     acc ...))))))

  ;;; Finite field
  ;; Fp
  (define-vector-type ec-field-fp (make-ec-field-fp p) ec-field-fp?
    (p ec-field-fp-p))

  ;; F2m
  ;; TODO check valid reduction polynominal
  ;;      It must be either trinominal (X^m + X^k + 1 with m > k >= 1) or
  ;;      pentanominal (X^m X^k3 + X^k2 + X^k1 + 1 with m > k3 > k2 > k1 >= 1)
  (define-vector-type ec-field-f2m (make-ec-field-f2m m k1 k2 k3) ec-field-f2m?
    (m  ec-field-f2m-m)
    (k1 ec-field-f2m-k1)
    (k2 ec-field-f2m-k2)
    (k3 ec-field-f2m-k3))

  ;; F2m field operations
  (define (f2m-ppb? f)
    (not (or (zero? (ec-field-f2m-k2 f)) (zero? (ec-field-f2m-k3 f)))))
  (define (f2m-zero? field x) (zero? x))
  (define (f2m-add field x y)
    (if (zero? y)
	x
	(bitwise-xor x y)))
  
  (define (f2m-mul field x y)
    (define ax x)
    (define bx y)
    (define cz (if (bitwise-bit-set? ax 0) bx 0))
    (define m  (ec-field-f2m-m field))
    (define k1 (ec-field-f2m-k1 field))
    (define k2 (ec-field-f2m-k2 field))
    (define k3 (ec-field-f2m-k3 field))
    (define (mult-z-mod a)
      (define az (bitwise-arithmetic-shift-left a 1))
      (if (bitwise-bit-set? az m)
	  (let* ((bl (bitwise-length az))
		 (bm (- (- (bitwise-arithmetic-shift-left 1 bl) 1)
			(bitwise-arithmetic-shift-left 1 m)))
		 (cm 1)
		 (k1m (bitwise-arithmetic-shift-left 1 k1))
		 (r (bitwise-and az bm)))
	    (if (f2m-ppb? field)
		(let ((k2m (bitwise-arithmetic-shift-left 1 k2))
		      (k3m (bitwise-arithmetic-shift-left 1 k3)))
		  (bitwise-xor r cm k1m k2m k3m))
		(bitwise-xor r cm k1m)))
	  az))
    (do ((i 1 (+ i 1)) (bx (mult-z-mod bx) (mult-z-mod bx))
	 (cz cz (if (bitwise-bit-set? ax i)
		    (bitwise-xor cz bx)
		    cz)))
	((= i m) cz)))
  
  (define (f2m-div field x y) (f2m-mul field x (f2m-inverse field y)))
  (define (f2m-square field x) (f2m-mul field x x))
  (define (f2m-inverse field x)
    (define m  (ec-field-f2m-m field))
    (define k1 (ec-field-f2m-k1 field))
    (define k2 (ec-field-f2m-k2 field))
    (define k3 (ec-field-f2m-k3 field))
    (define uz x)
    (define vz
      (let ((ppb? (f2m-ppb? field)))
	(bitwise-ior (bitwise-arithmetic-shift-left 1 m)
		     1
		     (bitwise-arithmetic-shift-left 1 k1)
		     (if ppb? (bitwise-arithmetic-shift-left 1 k2) 0)
		     (if ppb? (bitwise-arithmetic-shift-left 1 k3) 0))))
    (when (<= uz 0)
      (assertion-violation 'f2m-inverse "x is zero or negative" x))
    (let loop ((uz uz) (vz vz) (g1z 1) (g2z 0))
      (if (= uz 0)
	  g2z
	  (let ((j (- (bitwise-length uz) (bitwise-length vz))))
	    (let-values (((uz vz g1z g2z j)
			  (if (< j 0)
			      (values vz uz g2z g1z (- j))
			      (values uz vz g1z g2z j))))
	      (loop (bitwise-xor uz (bitwise-arithmetic-shift-left vz j))
		    vz
		    (bitwise-xor g1z (bitwise-arithmetic-shift-left g2z j))
		    g2z))))))
    
  (define-vector-type ec-curve (make-elliptic-curve field a b) elliptic-curve?
    (field elliptic-curve-field)
    (a     elliptic-curve-a)
    (b     elliptic-curve-b))
  

  (define-record-type predicate-generic
    (fields name table)
    (protocol (lambda (p)
		(lambda (n)
		  (p n (make-eq-hashtable))))))
  (define-syntax define-predicate-generic
    (syntax-rules ()
      ((_ name)
       (begin
	 (define dummy (make-predicate-generic 'name))
	 (define-syntax name
	   (lambda (x)
	     (syntax-case x ()
	       ((_ self args (... ...))
		#'(let* ((table (predicate-generic-table dummy))
			 (target self)
			 (eof (cons #f #f))
			 (itr (%hashtable-iter table)))
		    (let loop ()
		      (let-values (((k v) (itr eof)))
			(when (eq? k eof)
			  (assertion-violation 'name
			   "predicate for given argument is not registered"
			   self))
			(if (k target)
			    (v target args (... ...))
			    (loop))))))
	       (n (identifier? #'n) #'dummy))))))))
  (define-syntax define-predicate-method
    (syntax-rules ()
      ((_ name pred (self args ...) body ...)
       (define dummy
	 (let ((table (predicate-generic-table name))
	       (method (lambda (self args ...) body ...)))
	   (when (hashtable-contains? table pred)
	     (assertion-violation 'name
				  "specified predicate is already registered"
				  pred))
	   (hashtable-set! table pred method))))))

  (define (ec-curve=? a b) (equal? a b))

  ;; EC point
  (define-vector-type ec-point (make-ec-point x y) ec-point?
    (x     ec-point-x)
    (y     ec-point-y))

  ;; keep it immutable...
  (define ec-infinity-point '#(ec-point #f #f))

  ;; we don't check x and y, these can be #f for infinite point
  (define (ec-point-infinity? p)
    (or (not (ec-point-x p))
	(not (ec-point-y p))))
  
  (define (ec-point=? a b) (equal? a b))

  ;; Twice
  (define-predicate-generic field-ec-point-twice)
  (define-predicate-method field-ec-point-twice ec-field-fp? (field curve x)
    (if (zero? (ec-point-y x))
	ec-infinity-point
	(let* ((xx (ec-point-x x))
	       (xy (ec-point-y x))
	       (p (ec-field-fp-p field))
	       ;; gamma = ((xx^2)*3 + curve.a)/(xy*2)
	       (gamma (mod-div (mod-add (mod-mul (mod-square xx p) 3 p)
					(elliptic-curve-a curve)
					p)
			       (mod-mul xy 2 p) p))
	       ;; x3 = gamma^2 - x*2
	       (x3 (mod-sub (mod-square gamma p) (mod-mul xx 2 p) p))
	       ;; y3 = gamma*(xx - x3) - xy
	       (y3 (mod-sub (mod-mul gamma (mod-sub xx x3 p) p) xy p)))
	  (make-ec-point x3 y3))))
	
  (define-predicate-method field-ec-point-twice ec-field-f2m? (field curve x)
    (if (f2m-zero? field x)
	ec-infinity-point
	(let* ((xx (ec-point-x x))
	       (xy (ec-point-y x))
	       (l1 (f2m-add field (f2m-div field xy xx) xx))
	       (x3 (f2m-add field (f2m-add field (f2m-square field l1) l1)
			    (elliptic-curve-a curve)))
	       (y3 (f2m-add field (f2m-add field (f2m-square field xx)
					   (f2m-mul field l1 x3))
			    x3)))
	  (make-ec-point x3 y3))))
  
  (define (ec-point-twice curve x)
    (if (ec-point-infinity? x)
	x
	(field-ec-point-twice (elliptic-curve-field curve) curve x)))

  ;; Add
  (define-predicate-generic field-ec-point-add)
  (define-predicate-method field-ec-point-add ec-field-fp? (field curve x y)
    (if (equal? (ec-point-x x) (ec-point-x y))
	(if (equal? (ec-point-y x) (ec-point-y y))
	    (ec-point-twice x)
	    ec-infinity-point)
	(let* ((xx (ec-point-x x))
	       (xy (ec-point-y x))
	       (yx (ec-point-x y))
	       (yy (ec-point-y y))
	       (p (ec-field-fp-p field))
	       ;; gamma = (yy - xy)/(yx-xx)
	       (gamma (mod-div (mod-sub yy xy p) (mod-sub yx xx p) p))
	       ;; x3 = gamma^2 - xx - yx
	       (x3 (mod-sub (mod-sub (mod-square gamma p) xx p) yx p))
	       ;; y3 = gamma*(xx - x3) - xy
	       (y3 (mod-sub (mod-mul gamma (mod-sub xx x3 p) p) xy p)))
	  (make-ec-point x3 y3))))

  (define-predicate-method field-ec-point-add ec-field-f2m? (field curve x y)
    (let* ((xx (ec-point-x x))
	   (xy (ec-point-y x))
	   (yx (ec-point-x y))
	   (yy (ec-point-y y))
	   (dx (f2m-add field xx yx))
	   (dy (f2m-add field xy yy)))
      (if (f2m-zero? field dx)
	  (if (f2m-zero? field dy)
	      (ec-point-twice curve x)
	      ec-infinity-point)
	  (let* ((L (f2m-div field dy dx))
		 (x3 (f2m-add field
		      (f2m-add field
		       (f2m-add field
			(f2m-square field L) L)
		       dx)
		      (elliptic-curve-a curve)))
		 (y3 (f2m-add field
		      (f2m-add field
		       (f2m-mul field L 
			(f2m-add field xx x3))
		       x3)
		      xy)))
	    (make-ec-point x3 y3)))))
  
  (define (ec-point-add curve x y)
    (cond ((ec-point-infinity? x) y)
	  ((ec-point-infinity? y) x)
	  (else
	   (field-ec-point-add (elliptic-curve-field curve) curve x y))))

  ;; Negate
  (define-predicate-generic field-ec-point-negate)
  (define-predicate-method field-ec-point-negate ec-field-fp? (field x)
    (make-ec-point (ec-point-x x)
		   (mod-negate (ec-point-y x) (ec-field-fp-p field))))
  (define-predicate-method field-ec-point-negate ec-field-f2m? (field x)
    (let ((xx (ec-point-x x)))
      (make-ec-point xx (f2m-add field xx (ec-point-y x)))))
  
  (define (ec-point-negate curve x)
    (field-ec-point-negate (elliptic-curve-field curve) x))

  (define (ec-point-sub curve x y)
    (if (ec-point-infinity? y)
	x
	;; add -y
	(ec-point-add curve x (ec-point-negate curve y))))
  
  ;; http://en.wikipedia.org/wiki/Non-adjacent_form
  ;; this is probably super slow but for now...
  (define (ec-point-mul curve p k)
    (unless (integer? k) (error 'ec-point-mul "integer required for k" k))
    (let ((h (* k 3))
	  (neg (ec-point-negate curve p)))
      (let loop ((R p) (i (- (bitwise-length h) 2)))
	(if (zero? i)
	    R
	    (let ((R (ec-point-twice curve R))
		  (hbit? (bitwise-bit-set? h i)))
	      (if (eqv? hbit? (bitwise-bit-set? k i))
		  (loop R (- i 1))
		  (loop (ec-point-add curve R (if hbit? p neg)) (- i 1))))))))
  
  ;;;;
  ;;; Parameters
  ;; Parameter contains followings
  ;;  - curve
  ;;  - base point x y (as ec-point)
  ;;  - Order q of the point G (and of the elliptic curve group E)
  ;;  - h = (l - 1) / 160 where l is bit length of prime p
  ;;  - seed

  (define (ec-parameter? o) 
    (and (vector? o) (= (vector-length o) 6) 
	 (eq? (vector-ref o 0) 'ec-parameter)))
  (define (ec-parameter-curve o) (vector-ref o 1))

  ;;; Parameters
  ;; from
  ;;   https://www.nsa.gov/ia/_files/nist-routines.pdf (gone)
  ;;   http://csrc.nist.gov/groups/ST/toolkit/documents/dss/NISTReCur.pdf (*)
  ;;   http://koclab.cs.ucsb.edu/teaching/cren/docs/w02/nist-routines.pdf
  ;;   http://www.secg.org/sec2-v2.pdf
  ;; 
  ;; (*) is not used
  ;;; Fp
  ;; #(tag #(curve fp a b) #(E x y) n h S) = #(#(#(p) a b)) #(G G) n h S)
  (define-constant NIST-P-192
    `#(ec-parameter
       ,(make-elliptic-curve 
	 (make-ec-field-fp #xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFFFF)
	 #xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFFFC
	 #x64210519E59C80E70FA7E9AB72243049FEB8DEECC146B9B1) 
       ,(make-ec-point #x188DA80EB03090F67CBF20EB43A18800F4FF0AFD82FF1012
		       #x07192B95FFC8DA78631011ED6B24CDD573F977A11E794811)
       #xFFFFFFFFFFFFFFFFFFFFFFFF99DEF836146BC9B1B4D22831
       1
       ;;3045AE6FC8422F64ED579528D38120EAE12196D5
       #vu8(#x30 #x45 #xAE #x6F #xC8 #x42 #x2F #x64 #xED #x57
	    #x95 #x28 #xD3 #x81 #x20 #xEA #xE1 #x21 #x96 #xD5)))

  (define-constant NIST-P-224
    `#(ec-parameter
       ,(make-elliptic-curve 
	 (make-ec-field-fp
	  #xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF000000000000000000000001)
	 #xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFE
	 #xB4050A850C04B3ABF54132565044B0B7D7BFD8BA270B39432355FFB4)
       ,(make-ec-point
	 #xB70E0CBD6BB4BF7F321390B94A03C1D356C21122343280D6115C1D21
	 #xBD376388B5F723FB4C22DFE6CD4375A05A07476444D5819985007E34)
       #xFFFFFFFFFFFFFFFFFFFFFFFFFFFF16A2E0B8F03E13DD29455C5C2A3D
       1
       ;; BD71344799D5C7FCDC45B59FA3B9AB8F6A948BC5
       #vu8(#xBD #x71 #x34 #x47 #x99 #xD5 #xC7 #xFC #xDC #x45
	    #xB5 #x9F #xA3 #xB9 #xAB #x8F #x6A #x94 #x8B #xC5)))


  ;;; F2m
  ;; #(tag #(curve #(m k1 k2 k3) a b) #(E x y) n h S)
  ;; f(x) = x^113 + x^9 + 1
  (define-constant sect113r1
    `(ec-parameter
      ,(make-elliptic-curve (make-ec-field-f2m 163 9 0 0)
			    #x003088250CA6E7C7FE649CE85820F7
			    #x00E8BEE4D3E2260744188BE0E9C723)
      ,(make-ec-point #x009D73616F35F4AB1407D73562C10F
		      #x00A52830277958EE84D1315ED31886)
      #x0100000000000000D9CCEC8A39E56F
      2
      #vu8(#x10 #xE7 #x23 #xAB #x14 #xD6 #x96 #xE6 #x76 #x87
	   #x56 #x15 #x17 #x56 #xFE #xBF #x8F #xCB #x49 #xA9)))
  
  ;; f(x) = x^163 + x^7 + x^6 + x^3 + 1
  (define-constant sect163k1
    `(ec-parameter
      ,(make-elliptic-curve (make-ec-field-f2m 163 3 6 7) 1 1)
      ,(make-ec-point #x02FE13C0537BBC11ACAA07D793DE4E6D5E5C94EEE8
		      #x0289070FB05D38FF58321F2E800536D538CCDAA3D9)
      #x04000000000000000000020108A2E0CC0D99F8A5EF
      2
      #vu8(#x85 #xE2 #x5B #xFE #x5C #x86 #x22 #x6C #xDB #x12
	   #x01 #x6F #x75 #x53 #xF9 #xD0 #xE6 #x93 #xA2 #x68)))
)
