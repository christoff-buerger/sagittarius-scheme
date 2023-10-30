;;; -*- mode:scheme; coding:utf-8; -*-
;;;
;;; text/json/schema/validators/array.scm - JSON schema array validators
;;;
;;;   Copyright (c) 2023  Takashi Kato  <ktakashi@ymail.com>
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

#!nounbound
(library (text json schema validators array)
    (export json-schema:items
	    json-schema:prefix-items
	    json-schema:additional-items
	    json-schema:unevaluated-items
	    json-schema:contains

	    json-schema:draft-7-items)
    (import (rnrs)
	    (srfi :1 lists)
	    (text json schema validators api))

(define (schema->core-validator schema context schema-path)
  (schema-validator->core-validator
   (schema-context->schema-validator (make-schema-context schema context)
				     schema-path)))

(define (json-schema:items value context schema-path)
  (lambda (e ctx) #t))

(define (json-schema:prefix-items value context schema-path)
  (lambda (e ctx) #t))

(define (json-schema:additional-items value context schema-path)
  (unless (json-schema? value)
    (assertion-violation 'json-schema:additiona-items
			 "JSON Schema is required" value))
  (let ((validator (schema->core-validator value context
		    (build-schema-path schema-path "additionalItems"))))
    ;; TODO check additional item
    (lambda (e ctx) #t)))

(define (json-schema:unevaluated-items value context schema-path)
  (lambda (e ctx) #t))

(define (json-schema:contains value context schema-path)
  (unless (json-schema? value)
    (assertion-violation 'json-schema:contains "JSON Schema is required" value))
  (let* ((path (build-schema-path schema-path "contains"))
	 (validator (schema->core-validator value context path)))
    (lambda (e ctx)
      (or (not (list? e))
	  (exists (lambda (v) (validator v ctx)) e)))))

;; Draft 7 and 2019-09
(define (json-schema:draft-7-items value context schema-path)
  (define path (build-schema-path schema-path "items"))
  (cond ((json-schema? value)
	 (let ((validator (schema->core-validator value context path)))
	   (lambda (e ctx)
	     (or (not (list? e))
		 (for-all (lambda (v) (validator v ctx)) e)))))
	((and (list? value) (for-all json-schema? value))
	 (let ((validators
		(map (lambda (schema)
		       (schema->core-validator schema context path)) value)))
	   (lambda (e ctx)
	     (or (not (list? e))
		 (every (lambda (validator v) (validator v ctx))
			validators e)))))
	(else (assertion-violation 'json-schema:items
		"Either JSON Schema or list of JSON Schema is required" value))))

)
