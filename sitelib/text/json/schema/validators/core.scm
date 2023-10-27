;;; -*- mode:scheme; coding:utf-8; -*-
;;;
;;; text/json/schema/validators/core.scm - JSON schema core
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
(library (text json schema validators core)
    (export json-schema:$id json-schema:$schema
	    json-schema:$vocabularies
	    json-schema:draft-7-$id)
    (import (rnrs)
	    (rfc uri)
	    (srfi :13 strings)
	    (text json pointer)
	    (text json schema version)
	    (text json schema validators api))

(define (($id-handler allow-anchor?) value context schema-path)
  (define in-id (schema-context-in-id context))
  ;; split id and anchor
  (let-values (((id anchor) (uri->id&fragment value)))
    (when (and anchor (not allow-anchor?))
      (assertion-violation 'json-schema:$id
			   "$id mustn't contain fragment" value))
    ;; #foo case, allowed on Draft 7
    (when id
      (schema-context:set-id! context (or (and in-id (uri-merge in-id id)) id)))
    (when anchor (schema-context:add-anchor! context anchor)))
  ;; we don't need validator for this
  #f)


(define json-schema:$id ($id-handler #f))
  
(define json-schema:draft-7-$id ($id-handler #t))

(define $schema-pointer (json-pointer "/$schema"))
(define (json-schema:$schema value context schema-path)
  (cond ((json-schema->version value) =>
	 (lambda (version)
	   (schema-context-version-set! context version)))
	(else
	 (assertion-violation 'json-schema:$schema "Unknown schema" value)))
  #f)


(define (json-schema:$vocabularies value context schema-path)
  (lambda (e ctx) #t))

)
