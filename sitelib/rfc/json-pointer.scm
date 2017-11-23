;;; -*- mode:scheme; coding:utf-8; -*-
;;;
;;; rfc/json-pointer - JSON Pointer
;;;  
;;;   Copyright (c) 2017  Takashi Kato  <ktakashi@ymail.com>
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

;; reference:
;; RFC 6901: https://tools.ietf.org/html/rfc6901
(library (rfc json-pointer)
    (export json-pointer json-pointer-not-found?
	    parse-json-pointer)
    (import (rnrs)
	    (peg)
	    (text json)
	    (sagittarius generators)
	    (srfi :14)
	    (srfi :127))

(define json-pointer-token
  (char-set-difference char-set:full (char-set #\/ #\~)))

;; more for testing...
(define (parse-json-pointer p)
  (define ->token list->string)
  (define unescaped
    ($do (c ($satisfy (lambda (c) (char-set-contains? json-pointer-token c))))
	 ($return c)))
  (define escaped
    ($do (($satisfy (lambda (c) (eqv? #\~ c))))
	 (c ($satisfy (lambda (c) (or (eqv? #\0 c) (eqv? #\1 c)))))
	 ($return (case c ((#\0) #\~) ((#\1) #\/)))))
  (define reference-token
    ($do (chars ($many ($or unescaped escaped)))
	 ($return (->token chars))))
  (define root
    ($do (jp ($many ($seq ($satisfy (lambda (c) (eqv? c #\/)))
			  reference-token)))
	 ($return jp)))
  (let-values (((s v nl) (root (generator->lseq (string->generator p)))))
    (if (parse-success? s)
	v
	(error 'json-pointer "Failed to parse JSON pointer"))))

(define-record-type not-found)
(define +json-pointer-not-found+ (make-not-found))
(define (json-pointer-not-found? v) (eq? +json-pointer-not-found+ v))

(define (json-pointer p . maybe-parent)
  (define tokens (parse-json-pointer p))
  (define (find-vector-map json p)
    (define len (vector-length json))
    (do ((i 0 (+ i 1)))
	((or (= i len) (equal? (car (vector-ref json i)) p))
	 (if (= i len)
	     +json-pointer-not-found+
	     (cdr (vector-ref json i))))))
  (define (find-list-array json p)
    (do ((i 0 (+ i 1)) (j json (cdr json)))
	((or (= i p) (null? j))
	 (if (null? j)
	     +json-pointer-not-found+
	     (car json)))))
  (define parent (if (null? maybe-parent) values (car maybe-parent)))
  ;; TODO leading 0 shouldn't be there for array-index
  ;;      e.g. 0001 is not an index
  (define (->array-index p) (string->number p))
  (fold-left (lambda (pointer p)
	         (case (*json-map-type*)
		   ((vector)
		    (lambda (json)
		      (let ((json (pointer json)))
			(cond ((vector? json) (find-vector-map json p))
			      ((and (pair? json) (->array-index p)) =>
			       (lambda (n) (find-list-array json n)))
			      (else +json-pointer-not-found+)))))
		   ((alist)
		    (lambda (json)
		      (let ((json (pointer json)))
			(cond ((and (pair? json) (assoc p json)) => cdr)
			      ((and (vector? json) (->array-index p)) =>
			       (lambda (n)
				 (if (< (vector-length json) n)
				     (vector-ref json n)
				     +json-pointer-not-found+)))
			      (else +json-pointer-not-found+)))))))
	     (lambda (json) (parent json)) tokens))

)
