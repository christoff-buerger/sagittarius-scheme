;;; -*- mode:scheme;coding:utf-8 -*-
;;;
;;; net/http.scm - HTTP utilities
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
(library (net http)
    (export http-get async-http-get async-http-get/client
	    http-post async-http-post async-http-post/client
	    http-put async-http-put async-http-put/client
	    http-head async-http-head async-http-head/client
	    http-delete async-http-delete async-http-delete/client
	    http-patch async-http-patch async-http-patch/client
	    http-options async-http-options async-http-options/client

	    async-http-request async-http-request/client
	    request-context-builder request-context?

	    http:request-basic-auth http:request-bearer-auth

	    http:response?
	    http:response-status http:response-headers
	    http:response-cookies http:response-body
	    http:headers? http:make-headers
	    http:headers-names http:headers-ref* http:headers-ref
	    http:headers->alist
	    
	    request-payload request-payload?

	    octet-stream-request-payload octet-stream-request-payload?
	    (rename (make-octet-stream-request-payload octet-stream-payload))

	    json-request-payload json-request-payload?
	    (rename (make-json-request-payload json-payload))

	    x-www-form-urlencoded-request-payload
	    x-www-form-urlencoded-request-payload?
	    (rename (make-x-www-form-urlencoded-request-payload
		     x-www-form-urlencoded-payload)))
    (import (rnrs)
	    (net http-client)
	    (record builder)
	    (rfc uri)
	    (srfi :13 strings)
	    (text json)
	    (util concurrent)
	    (util duration))

(define pooled-connection-manager
  (make-http-pooling-connection-manager
   (http-pooling-connection-config-builder
    ;; timeouts are basically random number, mostly taken from some other
    ;; libraries or whatever values 
    (dns-timeout (duration:of-seconds 30))	  ;; 30s
    (read-timeout (duration:of-seconds 120))	  ;; 120s
    (connection-timeout (duration:of-seconds 60)) ;; 60s
    (max-connection-per-route 100))))

(define *default-http-client*
  (http:client-builder
   (follow-redirects (http:redirect always))
   (connection-manager pooled-connection-manager)))

(define-record-type request-payload
  (fields content-type content converter))

(define-record-type octet-stream-request-payload
  (parent request-payload)
  (protocol (lambda (p)
	      (lambda (bv)
		((p "application/octet-stream" bv values))))))

(define-record-type json-request-payload
  (parent request-payload)
  (protocol (lambda (p)
	      (define (json->string json)
		(let-values (((out e) (open-string-output-port)))
		  (json-write/normalized json out)
		  (e)))
	      (define (json->bytevector json) (string->utf8 (json->string json)))
	      (lambda (json)
		((p "application/json" json json->bytevector))))))

(define-record-type x-www-form-urlencoded-request-payload
  (parent request-payload)
  (protocol (lambda (p)
	      (define (->urlencoded kv)
		(string-append (uri-encode-string (car kv))
			       "="
			       (uri-encode-string (cdr kv))))
	      (define (encode-values kv*)
		(string->utf8 (string-join (map ->urlencoded kv*) "&")))
	      (lambda (kv)
		((p "application/x-www-form-urlencoded" kv encode-values))))))

(define (->request-body body)
  (values (request-payload-content-type body)
	  ((request-payload-converter body) (request-payload-content body))))

(define-record-type request-context
  (fields uri
	  method
	  payload
	  authenticator
	  headers
	  cookies
	  timeout
	  callback))

(define-syntax request-context-builder
  (make-record-builder request-context
   ((headers '())
    (cookies '()))))

(define (request-context->http-request context)
  (define payload (request-context-payload context))
  (let-values (((content-type body)
		(if payload (->request-body payload) (values #f #f))))
    (http:request-builder
     (uri (request-context-uri context))
     (method (request-context-method context))
     (uri (request-context-uri context))
     (content-type content-type)
     (auth (request-context-authenticator context))
     (headers (request-context-headers context))
     (cookies (request-context-cookies context))
     (body body)
     (timeout (request-context-timeout context)))))

(define (async-http-request/client http-client request-context)
  (define request (request-context->http-request request-context))
  (define callback (or (request-context-callback request-context) values))
  (future-map callback (http:client-send-async http-client request)))

(define (async-http-request context)
  (async-http-request/client *default-http-client* context))

(define nobody-http-request/client
  (case-lambda
   ((http-client (method symbol?) (uri string?) (callback (or procedure? #f)))
    (let ((context (request-context-builder
		    (uri uri)
		    (method method)
		    (callback callback))))
      (async-http-request/client http-client context)))
   ((http-client method (context request-context?))
    (let ((new-context (request-context-builder (from context) (method method))))
      (async-http-request/client http-client new-context)))))

(define bodied-http-request/client
  (case-lambda
   ((http-client (method symbol?)
		 (uri string?)
		 (payload (or bytevector? request-payload? #f))
		 (callback (or procedure? #f)))
    (let ((context (request-context-builder
		    (uri uri)
		    (method method)
		    (payload (if (bytevector? payload)
				 (make-octet-stream-request-payload payload)
				 payload))
		    (callback callback))))
      (async-http-request/client http-client context)))
   ((http-client method (context request-context?))
    (let ((new-context (request-context-builder (from context) (method method))))
      (async-http-request/client http-client new-context)))))

(define-syntax define-nobody
  (lambda (x)
    (define (->names k m)
      (define mm (string-downcase (symbol->string (syntax->datum m))))
      (datum->syntax k (map string->symbol
			    (list
			     (string-append "http-" mm)
			     (string-append "async-http-" mm)
			     (string-append "async-http-" mm "/client")))))
    (syntax-case x ()
      ((k method)
       (with-syntax (((sync async async/client) (->names #'k #'method)))
	 #'(begin
	     (define (async/client http-client . rest)
	       (apply nobody-http-request/client http-client 'method rest))
	     (define (async . opts)
	       (apply async/client *default-http-client* opts))
	     (define sync
	       (case-lambda
		((context)
		 (future-get (if (request-context? context)
				 (async context)
				 (async context values))))
		((uri callback)
		 (future-get (async uri callback)))))))))))
		  
(define-nobody GET)
(define-nobody HEAD)
(define-nobody OPTIONS)

(define-syntax define-bodied
  (lambda (x)
    (define (->names k m)
      (define mm (string-downcase (symbol->string (syntax->datum m))))
      (datum->syntax k (map string->symbol
			    (list
			     (string-append "http-" mm)
			     (string-append "async-http-" mm)
			     (string-append "async-http-" mm "/client")))))
    (syntax-case x ()
      ((k method)
       (with-syntax (((sync async async/client) (->names #'k #'method)))
	 #'(begin
	     (define (async/client http-client . rest)
	       (apply bodied-http-request/client http-client 'method rest))
	     (define (async . opts)
	       (apply async/client *default-http-client* opts))
	     (define sync
	       (case-lambda
		((context)
		 (future-get (if (request-context? context)
				 (async context)
				 ;; nobody
				 (async context #f values))))
		((uri body) (future-get (async uri body values)))
		((uri body callback)
		 (future-get (async uri body callback)))))))))))

(define-bodied POST)
(define-bodied PUT)
(define-bodied PATCH)
(define-bodied DELETE)
)
