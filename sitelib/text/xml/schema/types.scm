;;; -*- mode:scheme; coding:utf-8; -*-
;;;
;;; text/xml/schema/types.scm - XML Schema Datatypes
;;;
;;;   Copyright (c) 2020  Takashi Kato  <ktakashi@ymail.com>
;;;
;;;   Redistribution and use in source and binary forms, with or without
;;;   modification, are permitted provided that the following conditions
;;;   are met:
;;;
;;;   1. Redistributions of source code must retain the above copyright
;;;      notice, this list of conditions and the following disclaimer.
;;;
;;;   2. Redistributions in binary form must reproduce the above copyright
;;;      notice, this list of conditions and the following disclaimer in the
;;;      documentation and/or other materials provided with the distribution.
;;;
;;;   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;;;   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;;;   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
;;;   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
;;;   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;;;   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
;;;   TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
;;;   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
;;;   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;;;   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;;;   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;;;

;; ref:
;;  W3C XML Schema Definition Language (XSD) 1.1 Part 2: Datatypes
;;  https://www.w3.org/TR/xmlschema11-2/

#!nounbound
(library (text xml schema types)
    (export xs:any-type xs:any-type?
	    xs:any-simple-type xs:any-simple-type?
	    xs:any-atomic-type xs:any-atomic-type?

	    xs:duration xs:duration? (rename make-xs:duration xs:make-duration)
	    xs:duration-months xs:duration-seconds

	    xs:day-time-duration xs:day-time-duration?
	    (rename make-xs:day-time-duration xs:make-day-time-duration)

	    xs:year-month-duration xs:year-month-duration?
	    (rename make-xs:year-month-duration xs:make-year-month-duration)
	    
	    xs:qname xs:qname? (rename make-xs:qname xs:make-qname)
	    xs:qname-namespace-uri xs:qname-local-part xs:qname-prefix
	    xs:qname->node-name xs:qname->expanded-qname

	    )
    (import (rnrs)
	    (srfi :115 regexp))

;; 3 Built-in Datatypes and Their Definitions
;; for now, I implement what we need
;; we don't consider lexical space here
(define-record-type xs:any-type)

(define-record-type xs:any-simple-type
  (parent xs:any-type))

(define-record-type (xs:any-atomic-type dummy %any-atomic-type?)
  (parent xs:any-simple-type))

(define (xs:any-atomic-type? o)
  (or (%any-atomic-type? o)
      (string? o)  ;; anyURI base64Binary string
      (integer? o) ;; decimal and its hierarchies
      (real? o)	   ;; float double
      (boolean? o) ;; boolean
      ;; TODO date and dateTime (maybe srfi 19?)
      ))


(define +duration-regex+
  (regexp
   '(: (? #\-) "P"
       (or (: (or (: ($ (+ (/ "09"))) "Y"      ;; 1
		     (? ($ (+ (/ "09"))) "M")  ;; 2
		     (? ($ (+ (/ "09"))) "D")) ;; 3
		  (: ($ (+ (/ "09"))) "M"      ;; 4
		     (? ($ (+ (/ "09"))) "D")) ;; 5
		  (: ($ (+ (/ "09"))) "D"))    ;; 6
	      (? "T"
		 (or (: ($ (+ (/ "09"))) "H"		  ;; 7 
			(? ($ (+ (/ "09"))) "M")	  ;; 8
			(? ($ (+ (/ "09")))		  ;; 9
			   (? "." ($ (+ (/ "09")))) "S")) ;; 10
		     (: ($ (+ (/ "09"))) "M"		  ;; 11
			(? ($ (+ (/ "09")))		  ;; 12
			   (? "." ($ (+ (/ "09")))) "S")) ;; 13
		     (: ($ (+ (/ "09")))		  ;; 14
			(? "." ($ (+ (/ "09")))) "S"))))  ;; 15

	   (: "T" (or (: ($ (+ (/ "09"))) "H"		     ;; 16
			 (? ($ (+ (/ "09"))) "M")	     ;; 17
			 (? ($ (+ (/ "09")))		     ;; 18
			    (? "." ($ (+ (/ "09")))) "S"))   ;; 19
		      (: ($ (+ (/ "09"))) "M"		     ;; 20
			 (? ($ (+ (/ "09")))		     ;; 21
			    (? "." ($ (+ (/ "09")))) "S"))   ;; 22
		      (: ($ (+ (/ "09")))		     ;; 23
			 (? "." ($ (+ (/ "09")))) "S"))))))) ;; 24
(define +duration-ymd-matches+
  '((1  2  3)
    (4  5 #f)
    (6 #f #f)))
(define +duration-hms-matches+
  '(( 7  8  9 10)
    (11 12 13 #f)
    (14 15 #f #f)
    (16 17 18 19)
    (20 21 22 #f)
    (23 24 #f #f)))

(define (parse-duration duration rx ymd hms)
  (define (submatch m n rest)
    (cond ((regexp-match-submatch m n) => (lambda (s) (cons* m s rest)))
	  (else #f)))
  
  (define (return r&n*)
    (let ((m (car r&n*))
	  (r (cadr r&n*))
	  (n* (cddr r&n*)))
      (apply values r
	     (map (lambda (n) (and n (regexp-match-submatch m n))) n*))))
  
  (define (parse m matchers)
    (define sample (car matchers))
    (or (exists (lambda (p)
		  (cond ((submatch m (car p) (cdr p)) => return)
			(else #f))) matchers)
	(apply values (map (lambda (_) #f) sample))))
    
  (cond ((regexp-matches +duration-regex+ duration) =>
	 (lambda (m)
	   (let-values (((y mo d) (parse m ymd))
			((t mi s f) (parse m hms)))		     
	     (define neg? (char=? (string-ref duration 0) #\-))
	     (define (neg n) (if neg? (- n) n))
	     (values (neg (+ (or (and y (* 12 (string->number y))) 0)
			     (or (and mo (string->number mo)) 0)))
		     (neg (+ (or (and d (* 24 60 60 (string->number d))) 0)
			     (or (and t (* 60 60 (string->number d))) 0)
			     (or (and mi (* 60 (string->number mi))) 0)
			     (or (and s (string->number s)) 0)
			     ;; fraction?
			     (or (and f (div (string->number f) 1000)) 0)))))))
	(else (assertion-violation 'parse-duration "Invalid duration"
				   duration))))

(define-record-type xs:duration
  (parent xs:any-atomic-type)
  (fields months seconds)
  (protocol (lambda (p)
	      (define (ctr m s)
		(when (or (and (negative? m) (positive? s))
			  (and (positive? m) (negative? s)))
		  (assertion-violation 'xs:make-duration
				       "Invalid months and seconds" m s))
		((p) m s))
	      (case-lambda
	       ((s)
		(let-values (((m s) (parse-duration s +duration-regex+
						    +duration-ymd-matches+
						    +duration-hms-matches+)))
		  (ctr m s)))
	       ((m s) (ctr m s))))))
(define-record-type xs:day-time-duration
  (parent xs:duration)
  (protocol (lambda (p) (lambda (s) ((p 0 s))))))
(define-record-type xs:year-month-duration
  (parent xs:duration)
  (protocol (lambda (p) (lambda (m) ((p m 0))))))


(define-record-type xs:qname
  (parent xs:any-atomic-type)
  ;; QName is defined rather weirdly on the specification
  ;; we take these fields from common sense
  (fields namespace-uri
	  local-part
	  prefix
	  ;; cache
	  >node-name
	  >expanded-qname)
  (protocol (lambda (p)
	      (define (make namespace-uri local-part prefix)
		((p) namespace-uri local-part prefix
		     (if (zero? (string-length prefix))
			 local-part
			 (string-append prefix ":" local-part))
		     (list prefix namespace-uri local-part)))
	      (case-lambda
	       ((namespace-uri local-part)
		(make namespace-uri local-part ""))
	       ((namespace-uri local-part prefix)
		(make namespace-uri local-part prefix))))))

)