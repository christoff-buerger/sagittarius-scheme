;;; -*- mode:scheme; coding:utf-8; -*-
;;;
;;; sagittarius/crypto/pkcs/keys.scm - PKCS#8 key operation
;;;
;;;   Copyright (c) 2022  Takashi Kato  <ktakashi@ymail.com>
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
(library (sagittarius crypto pkcs keys)
    (export import-private-key export-private-key
	    one-asymmetric-key->private-key
	    private-key->one-asymmetric-key

	    pkcs-encrypted-private-key-info? <pkcs-encrypted-private-key-info>
	    pkcs-encrypted-private-key-info-encryption-algorithm
	    pkcs-encrypted-private-key-info-encrypted-data
	    read-pkcs-encrypted-private-key-info
	    bytevector->pkcs-encrypted-private-key-info
	    write-pkcs-encrypted-private-key-info
	    pkcs-encrypted-private-key-info->bytevector
	    )
    (import (rnrs)
	    (clos user)
	    (sagittarius crypto asn1)
	    (sagittarius crypto asn1 modules)
	    (sagittarius crypto pkcs modules akp)
	    (sagittarius crypto pkix algorithms)
	    (sagittarius crypto keys)
	    (sagittarius combinators))

(define-method import-private-key ((key <one-asymmetric-key>))
  (one-asymmetric-key->private-key key))
(define-method export-private-key ((key <one-asymmetric-key>))
  (asn1-encodable->bytevector key))

(define (one-asymmetric-key->private-key (oakp one-asymmetric-key?))
  (import-private-key (asn1-encodable->asn1-object oakp)
		      (private-key-format private-key-info)))

(define (private-key->one-asymmetric-key (private-key private-key?))
  (let ((bv (export-private-key private-key
				(private-key-format private-key-info))))
    (bytevector->asn1-encodable <one-asymmetric-key> bv)))

(define (make-slot-ref getter conv) (lambda (o) (conv (getter o))))
(define-class <pkcs-encrypted-private-key-info> (<asn1-encodable-container>)
  ((encryption-algorithm :allocation :virtual :cached #t
    :slot-ref (make-slot-ref
	       (.$ encrypted-private-key-info-encryption-algorithm
		   asn1-encodable-container-c)
	       algorithm-identifier->x509-algorithm-identifier)
    :reader pkcs-encrypted-private-key-info-encryption-algorithm)
   (encrypted-date :allocation :virtual :cached #t
    :slot-ref (make-slot-ref
	       (.$ encrypted-private-key-info-encrypted-data
		   asn1-encodable-container-c)
	       der-octet-string->bytevector)
    :reader pkcs-encrypted-private-key-info-encrypted-data)))
(define (pkcs-encrypted-private-key-info? o)
  (is-a? o <pkcs-encrypted-private-key-info>))

(define (bytevector->pkcs-encrypted-private-key-info bv)
  (read-pkcs-encrypted-private-key-info (open-bytevector-input-port bv)))
(define (read-pkcs-encrypted-private-key-info in)
  (encrypted-private-key-info->pkcs-encrypted-private-key-info
   (asn1-object->asn1-encodable <encrypted-private-key-info>
				(read-asn1-object in))))
(define (encrypted-private-key-info->pkcs-encrypted-private-key-info epki)
  (make <pkcs-encrypted-private-key-info> :c epki))

(define (pkcs-encrypted-private-key-info->encrypted-private-key-info epki)
  (asn1-encodable-container-c epki))
(define (write-pkcs-encrypted-private-key-info epki
	 :optional (out (current-output-port)))
  (put-bytevector out (pkcs-encrypted-private-key-info->bytevector epki)))
(define (pkcs-encrypted-private-key-info->bytevector epki)
  (asn1-encodable->bytevector epki))
)
