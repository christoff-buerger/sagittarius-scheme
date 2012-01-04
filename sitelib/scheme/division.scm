;; -*- mode:scheme; coding: utf-8; -*-
#!compatible
(library (scheme division)
    (export ceiling-quotient ceiling-remainder ceiling/ 
	    centered-quotient centered-remainder centered/
	    euclidean-quotient euclidean-remainder euclidean/
	    floor-quotient floor-remainder floor/
	    round-quotient round-remainder round/
	    truncate-quotient truncate-remainder truncate/)
    (import (rnrs) (rnrs r5rs))
  ;; From chibi-scheme

  ;; The builtin quotient and remainder implement truncation - the
  ;; fractional part is always discarded.

  (define truncate-quotient quotient)
  (define truncate-remainder remainder)
  (define (truncate/ n m)
    (values (truncate-quotient n m) (truncate-remainder n m)))

  ;; Floor, ceiling and round just compose their corresponding function
  ;; with division to determine the quotient, and compute the remainder
  ;; from that.

  (define (floor-quotient n m)
    (inexact->exact (floor (/ n m))))
  (define (floor-remainder n m)
    (- n (* m (floor-quotient n m))))
  (define (floor/ n m)
    (values (floor-quotient n m) (floor-remainder n m)))

  (define (ceiling-quotient n m)
    (inexact->exact (ceiling (/ n m))))
  (define (ceiling-remainder n m)
    (- n (* m (ceiling-quotient n m))))
  (define (ceiling/ n m)
    (values (ceiling-quotient n m) (ceiling-remainder n m)))

  (define (round-quotient n m)
    (inexact->exact (round (/ n m))))
  (define (round-remainder n m)
    (- n (* m (round-quotient n m))))
  (define (round/ n m)
    (values (round-quotient n m) (round-remainder n m)))

  ;; Euclidean is defined as floor if the divisor is negative, and
  ;; ceiling otherwise.

  (define (euclidean-quotient n m)
    (if (> m 0) (floor-quotient n m) (ceiling-quotient n m)))
  (define (euclidean-remainder n m)
    (- n (* m (euclidean-quotient n m))))
  (define (euclidean/ n m)
    (values (euclidean-quotient n m) (euclidean-remainder n m)))

  ;; Centered places the remainder in the half-open interval
  ;; [-m/2, m/2).

  (define (centered-remainder n m)
    (let ((r (euclidean-remainder n m))
	  (m/2 (abs (/ m 2))))
      (cond ((< r (- m/2)) (+ r (abs m)))
	    ((>= r m/2) (- r (abs m)))
	    (else r))))
  (define (centered-quotient n m)
    (quotient (- n (centered-remainder n m)) m))
  (define (centered/ n m)
    (values (centered-quotient n m) (centered-remainder n m)))

)