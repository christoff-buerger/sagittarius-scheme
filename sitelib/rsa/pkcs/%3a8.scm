;;; -*- mode:scheme; coding:utf-8; -*-
;;;
;;; rsa/pkcs/%3a8 - PKCS#8
;;;  
;;;   Copyright (c) 2010-2015  Takashi Kato  <ktakashi@ymail.com>
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

(library (rsa pkcs :8)
    (export <private-key-info>
	    private-key-info?
	    make-private-key-info
	    
	    <encrypted-private-key-info>
	    encrypted-private-key-info?
	    make-encrypted-private-key-info
	    encrypted-private-key-info-id
	    encrypted-private-key-info-data

	    <pkcs8-private-key>
	    pkcs8-private-key?
	    private-key-info->private-key
	    (rename (private-key-info->private-key pki->private-key))
	    pkcs8-private-key->private-key

	    PKCS8
	    import-private-key export-private-key
	    generate-private-key
	    )
    (import (rnrs)
	    (sagittarius)
	    (clos user)
	    (asn.1)
	    (crypto)
	    (rsa pkcs :10) ;; for algorithm-identifier
	    )

  #|
      PrivateKeyInfo ::= SEQUENCE {
        version                   Version,
        privateKeyAlgorithm       PrivateKeyAlgorithmIdentifier,
        privateKey                PrivateKey,
        attributes           [0]  IMPLICIT Attributes OPTIONAL }

      Version ::= INTEGER

      PrivateKeyAlgorithmIdentifier ::= AlgorithmIdentifier

      PrivateKey ::= OCTET STRING

      Attributes ::= SET OF Attribute
  |#
  (define-class <private-key-info> (<asn.1-encodable>)
    ((id :init-keyword :id)
     (attributes :init-keyword :attributes)
     (private-key :init-keyword :private-key)))
  (define (private-key-info? o) (is-a? o <private-key-info>))
  (define-generic make-private-key-info)
  (define-method make-private-key-info ((s <asn.1-sequence>))
    (unless (zero? (der-integer->integer (asn.1-sequence-get s 0)))
      (assertion-violation 'make-private-key-info
			   "wrong version for private key info"))
    (let* ((id (make-algorithm-identifier (asn.1-sequence-get s 1)))
	   (ain (open-bytevector-input-port
		 (slot-ref (asn.1-sequence-get s 2) 'string)))
	   (priv-key (read-asn.1-object ain))
	   (attributes (if (> (asn.1-sequence-size s) 3)
			   (make-der-set (asn.1-sequence-get s 3))
			   #f)))
      (make <private-key-info> :id id :attributes attributes 
	    :private-key priv-key)))
  (define-method make-private-key-info ((bv <bytevector>))
    (let ((o (read-asn.1-object (open-bytevector-input-port bv))))
      (make-private-key-info o)))
  (define-method make-private-key-info ((id <algorithm-identifier>)
					(key <private-key>))
    (define (bv->asn.1 bv) (read-asn.1-object (open-bytevector-input-port bv)))
    (make <private-key-info> :id id :attributes #f
	  :private-key (bv->asn.1 (%export-private-key key))))
  
  (define-method make-private-key-info ((key <rsa-private-key>))
    (make-private-key-info 
     (make-algorithm-identifier "1.2.840.113549.1.1.1" (make-der-null))
     key))
  (define-method make-private-key-info ((key <ecdsa-private-key>))
    ;; FIXME inefficient
    (define exported (read-asn.1-object
		      (open-bytevector-input-port
		       ;; specify marker to avoid :around...
		       (export-private-key key))))
    ;; assume it as tag[0]
    (make-private-key-info 
     (make-algorithm-identifier "1.2.840.10045.2.1"
      (slot-ref (asn.1-sequence-get exported 2) 'obj))
     key))


  (define-method asn.1-encodable->asn.1-object ((o <private-key-info>))
    (make-der-sequence
     (make-der-integer 0)
     (slot-ref o 'id)
     (make-der-octet-string (slot-ref o 'private-key))))
  #|
      EncryptedPrivateKeyInfo ::= SEQUENCE {
        encryptionAlgorithm  EncryptionAlgorithmIdentifier,
        encryptedData        EncryptedData }

      EncryptionAlgorithmIdentifier ::= AlgorithmIdentifier

      EncryptedData ::= OCTET STRING
  |#
  (define-class <encrypted-private-key-info> (<asn.1-encodable>)
    ((id   :init-keyword :id :reader encrypted-private-key-info-id)
     (data :init-keyword :data :reader encrypted-private-key-info-data)))
  (define (encrypted-private-key-info? o) 
    (is-a? o <encrypted-private-key-info>))
  (define-method make-encrypted-private-key-info ((s <asn.1-sequence>))
    (make <encrypted-private-key-info>
      :id (make-algorithm-identifier (asn.1-sequence-get s 0))
      :data (asn.1-sequence-get s 1)))
  (define-method make-encrypted-private-key-info ((bv <bytevector>))
    (make-encrypted-private-key-info 
     (read-asn.1-object (open-bytevector-input-port bv))))
  (define-method make-encrypted-private-key-info ((id <algorithm-identifier>)
						  (data <bytevector>))
    (make <encrypted-private-key-info> :id id 
	  :data (make-der-octet-string data)))
  (define-method asn.1-encodable->asn.1-object 
    ((o <encrypted-private-key-info>))
    (make-der-sequence (slot-ref o 'id) (slot-ref o 'data)))
  (define-method write-object ((o <encrypted-private-key-info>) (p <port>))
    (format p "#<encrypted-private-key-info~%~a~%~a>"
	    (slot-ref o 'id)
	    (slot-ref o 'data)))

  ;; PKCS8 private key
  (define-class <pkcs8-private-key> (<private-key>)
    ((private-key-info :init-keyword :private-key-info)))
  (define (pkcs8-private-key? o) (is-a? o <pkcs8-private-key>))
  (define PKCS8 :pkcs8)
  ;; hmm kinda silly without cipher...
  (define-method generate-private-key ((m (eql PKCS8)) (pki <private-key-info>))
    (make <pkcs8-private-key> :private-key-info pki))

  (define-method import-private-key ((m (eql PKCS8)) (in <bytevector>))
    (import-private-key PKCS8 (open-bytevector-input-port in)))
  (define-method import-private-key ((m (eql PKCS8)) (in <port>))
    (import-private-key PKCS8 (read-asn.1-object in)))
  (define-method import-private-key ((m (eql PKCS8)) (in <asn.1-sequence>))
    (make-private-key-info in))

  (define-method export-private-key ((m (eql PKCS8)) (in <private-key-info>))
    (asn.1-encode (asn.1-encodable->asn.1-object in)))
  (define-method export-private-key ((in <private-key-info>))
    (asn.1-encode (asn.1-encodable->asn.1-object in)))

  ;; fxxk!!
  (define-generic %export-private-key)
  (define-method %export-private-key (key)
    (export-private-key key))
  
  (define-method %export-private-key ((key <ecdsa-private-key>))
    (let* ((r (export-private-key key))
	   (s (read-asn.1-object (open-bytevector-input-port r))))
      ;; ok remove tag[0]
      (if (= (asn.1-sequence-size s) 4)
	  (asn.1-encode
	   (make-der-sequence
	    (asn.1-sequence-get s 0)
	    (asn.1-sequence-get s 1)
	    (asn.1-sequence-get s 3)))
	  (asn.1-encode s))))
	    
  ;; for now we only support RSA
  ;; FIXME kinda silly
  (define (pki->rsa-private-key pki)
    (import-private-key RSA (slot-ref pki 'private-key)))
  (define *oid-marker*
    `(("1.2.840.113549.1.1.1" . ,pki->rsa-private-key)
      ("1.2.840.113549.1.1.10" . ,pki->rsa-private-key)
      ("1.2.840.10040.4.1" .
       ,(lambda (pki)
	  (import-private-key DSA (slot-ref pki 'private-key))))
      ("1.2.840.10045.2.1" .
       ,(lambda (pki)
	  ;; awkward way to make it consistant...
	  (import-private-key ECDSA (slot-ref pki 'private-key)
	    (algorithm-identifier-parameters (slot-ref pki 'id)))))))

  (define (private-key-info->private-key pki)
    (let ((oid (algorithm-identifier-id (slot-ref pki 'id))))
      (cond ((assoc oid *oid-marker*) => (lambda (s) ((cdr s) pki)))
	    (else (assertion-violation 'private-key-info->private-key
				       "not supported" oid)))))
  (define (pkcs8-private-key->private-key k)
    (private-key-info->private-key (slot-ref k 'private-key-info)))
)
