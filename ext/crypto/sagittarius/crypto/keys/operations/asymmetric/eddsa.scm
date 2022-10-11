;;; -*- mode:scheme; coding:utf-8; -*-
;;;
;;; sagittarius/crypto/keys/operations/asymmetric/eddsa.scm - EdDSA key op
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
(library (sagittarius crypto keys operations asymmetric eddsa)
    (export generate-key-pair
	    generate-public-key
	    generate-private-key
	    import-public-key
	    import-private-key
	    export-public-key
	    export-private-key

	    *key:eddsa*	    
	    *key:ed25519*
	    *key:ed448*

	    
	    eddsa-key?
	    eddsa-key-parameter

	    eddsa-public-key? <eddsa-public-key>
	    eddsa-public-key-data

	    eddsa-private-key? <eddsa-private-key>
	    eddsa-private-key-random
	    eddsa-private-key-public-key

	    ed25519-key?
	    ed25519-public-key?
	    ed25519-private-key?

	    ed448-key?
	    ed448-public-key?
	    ed448-private-key?

	    eddsa-clamp!
	    )
    (import (rnrs)
	    (core misc)
	    (clos user)
	    (srfi :117 list-queues)
	    (sagittarius)
	    (sagittarius mop immutable)
	    (sagittarius crypto asn1)
	    (sagittarius crypto keys types)
	    (sagittarius crypto keys operations asymmetric apis)
	    (sagittarius crypto digests)
	    (sagittarius crypto random)
	    (sagittarius crypto math ed)
	    (sagittarius crypto math prime))

(define *key:eddsa*   :eddsa)
(define *key:ed25519* :ed25519)
(define *key:ed448*   :ed448)

(define-class <eddsa-key> (<immutable>)
  ((parameter :init-keyword :parameter :reader eddsa-key-parameter)))
(define (eddsa-key? o) (is-a? o <eddsa-key>))

(define-class <eddsa-public-key> (<public-key> <eddsa-key>)
  ((data :init-keyword :data :reader eddsa-public-key-data)))
(define (eddsa-public-key? o) (is-a? o <eddsa-public-key>))

(define-class <eddsa-private-key> (<private-key> <eddsa-key>)
  ((random :init-keyword :random :reader eddsa-private-key-random)
   (public-key :init-keyword :public-key :reader eddsa-private-key-public-key)))
(define (eddsa-private-key? o) (is-a? o <eddsa-private-key>))

(define (ed25519-key? key)
  (and (eddsa-key? key)
       (eq? 'ed25519 (eddsa-parameter-name (eddsa-key-parameter key)))))
(define (ed448-key? key)
  (and (eddsa-key? key)
       (eq? 'ed448 (eddsa-parameter-name (eddsa-key-parameter key)))))
(define (ed25519-public-key? key)
  (and (eddsa-public-key? key) (ed25519-key? key)))
(define (ed25519-private-key? key)
  (and (eddsa-private-key? key) (ed25519-key? key)))
(define (ed448-public-key? key)
  (and (eddsa-public-key? key) (ed448-key? key)))
(define (ed448-private-key? key)
  (and (eddsa-private-key? key) (ed448-key? key)))


(define (generate-ed25519-key-pair prng)
  (let* ((random (random-generator-read-random-bytes prng 32))
	 (private-key (generate-ed25519-private-key random)))
    (make-key-pair private-key
		  (eddsa-private-key-public-key private-key))))

(define (generate-ed25519-public-key data)
  (make <eddsa-public-key> :data data :parameter ed25519-parameter))

(define (generate-ed25519-private-key random)
    #|
5.1.5.  Key Generation

   The private key is 32 octets (256 bits, corresponding to b) of
   cryptographically secure random data.  See [RFC4086] for a discussion
   about randomness.

   The 32-byte public key is generated by the following steps.

   1.  Hash the 32-byte private key using SHA-512, storing the digest in
       a 64-octet large buffer, denoted h.  Only the lower 32 bytes are
       used for generating the public key.

   2.  Prune the buffer: The lowest three bits of the first octet are
       cleared, the highest bit of the last octet is cleared, and the
       second highest bit of the last octet is set.

   3.  Interpret the buffer as the little-endian integer, forming a
       secret scalar s.  Perform a fixed-base scalar multiplication
       [s]B.

   4.  The public key A is the encoding of the point [s]B.  First,
       encode the y-coordinate (in the range 0 <= y < p) as a little-
       endian string of 32 octets.  The most significant bit of the
       final octet is always zero.  To form the encoding of the point
       [s]B, copy the least significant bit of the x coordinate to the
       most significant bit of the final octet.  The result is the
       public key.
  |#
  (define (generate-public-key random)
    (let ((h (digest-message (make-message-digest *digest:sha-512*) random))
	  (l (make-bytevector 32)))
      ;; 1
      (bytevector-copy! h 0 l 0 32)
      ;; 2
      (eddsa-clamp! l 3 254 256)
      ;; 3
      (let* ((s (bytevector->integer/endian l (endianness little)))
	     (sB (ed-point-mul ed25519-parameter
			       (eddsa-parameter-B ed25519-parameter)
			       s)))
	;; 4
	(ed-point-encode-base ed25519-parameter sB
			      (eddsa-parameter-b ed25519-parameter)))))
  (unless (= (bytevector-length random) 32)
    (assertion-violation 'generate-ed25519-private-key "Invalid key size"))
  (let ((pub (generate-ed25519-public-key (generate-public-key random))))
    (make <eddsa-private-key> :parameter ed25519-parameter
	  :random random :public-key pub)))

(define-method generate-public-key ((m (eql *key:ed25519*))
				    (data <bytevector>) . ignore)
  (generate-ed25519-public-key data))
(define-method generate-private-key ((m (eql *key:ed25519*))
				     (random <bytevector>) . ignore)
  (generate-ed25519-private-key random))
(define-method generate-key-pair ((m (eql *key:ed25519*))
				  :key (prng (secure-random-generator *prng:chacha20*))
				  :allow-other-keys)
  (generate-ed25519-key-pair prng))

(define (generate-ed448-key-pair prng)
  (let* ((random (random-generator-read-random-bytes prng 57))
	 (private-key (generate-ed448-private-key random)))
    (make-key-pair private-key
		   (eddsa-private-key-public-key private-key))))
(define (generate-ed448-public-key data)
  (make <eddsa-public-key> :data data :parameter ed448-parameter))
(define (generate-ed448-private-key random)
  #|
5.2.5.  Key Generation

   The private key is 57 octets (456 bits, corresponding to b) of
   cryptographically secure random data.  See [RFC4086] for a discussion
   about randomness.

   The 57-byte public key is generated by the following steps:

   1.  Hash the 57-byte private key using SHAKE256(x, 114), storing the
       digest in a 114-octet large buffer, denoted h.  Only the lower 57
       bytes are used for generating the public key.

   2.  Prune the buffer: The two least significant bits of the first
       octet are cleared, all eight bits the last octet are cleared, and
       the highest bit of the second to last octet is set.

   3.  Interpret the buffer as the little-endian integer, forming a
       secret scalar s.  Perform a known-base-point scalar
       multiplication [s]B.

   4.  The public key A is the encoding of the point [s]B.  First encode
       the y-coordinate (in the range 0 <= y < p) as a little-endian
       string of 57 octets.  The most significant bit of the final octet
       is always zero.  To form the encoding of the point [s]B, copy the
       least significant bit of the x coordinate to the most significant
       bit of the final octet.  The result is the public key.
  |#
  (define (generate-public-key random)
    (let ((h (digest-message (make-message-digest *digest:shake-256*)
			     random 114))
	  (l (make-bytevector 57)))
      ;; 1
      (bytevector-copy! h 0 l 0 57)
      ;; 2
      (eddsa-clamp! l 2 447 456)
      ;; 3
      (let* ((s (bytevector->integer/endian l (endianness little)))
	     (sB (ed-point-mul ed448-parameter
			       (eddsa-parameter-B ed448-parameter)
			       s)))
	;; 4
	(ed-point-encode-base ed448-parameter sB
			      (eddsa-parameter-b ed448-parameter)))))
  (unless (= (bytevector-length random) 57)
    (assertion-violation 'generate-ed448-private-key "Invalid key size"))
  (let ((pub (generate-ed448-public-key (generate-public-key random))))
    (make <eddsa-private-key> :parameter ed448-parameter
	  :random random :public-key pub)))

(define-method generate-public-key ((m (eql *key:ed448*))
				    (data <bytevector>) . ignore)
  (generate-ed448-public-key data))
(define-method generate-private-key ((m (eql *key:ed448*))
				     (random <bytevector>) . ignore)
  (generate-ed448-private-key random))
(define-method generate-key-pair ((m (eql *key:ed448*))
				  :key (prng (secure-random-generator *prng:chacha20*))
				  :allow-other-keys)
  (generate-ed448-key-pair prng))

(define *ed25519-key-oid* "1.3.101.112")
(define-method oid->key-operation ((oid (equal *ed25519-key-oid*)))
  *key:ed25519*)
(define *ed448-key-oid* "1.3.101.113")
(define-method oid->key-operation ((oid (equal *ed448-key-oid*)))
  *key:ed448*)

(define-method export-public-key ((key <eddsa-public-key>) . opts)
  (apply export-public-key *key:eddsa* key opts))
(define-method export-public-key ((m (eql *key:ed25519*))
				  (key <eddsa-public-key>) . opts)
  (apply export-public-key *key:eddsa* key opts))
(define-method export-public-key ((m (eql *key:ed448*))
				  (key <eddsa-public-key>) . opts)
  (apply export-public-key *key:eddsa* key opts))

(define-method export-public-key ((m (eql *key:eddsa*))
				  (key <eddsa-public-key>)
				  :optional (format (public-key-format raw)))
  (define (eddsa-key->oid key)
    (cond ((ed25519-key? key) *ed25519-key-oid*)
	  ((ed448-key? key)   *ed448-key-oid*)
	  (else (assertion-violation 'export-public-key
				     "Unknown EdDSA key type"))))
  (case format
    ((raw) (eddsa-public-key-data key))
    ((subject-public-key-info)
     (asn1-encodable->bytevector
      (der-sequence
       (der-sequence
	(oid-string->der-object-identifier (eddsa-key->oid key)))
       (bytevector->der-bit-string (eddsa-public-key-data key)))))
    (else (assertion-violation 'export-public-key
			       "Unknown public key format" format))))

(define-method import-public-key ((m (eql *key:ed25519*))
				  (in <port>) . opts)
  (apply import-public-key m (get-bytevector-all in) opts))
(define-method import-public-key ((m (eql *key:ed25519*))
				  (bv <bytevector>)
				  :optional (format (public-key-format raw)))
  (if (eq? format 'raw)
      (generate-ed25519-public-key bv)
      (import-public-key *key:eddsa* bv format)))

(define-method import-public-key ((m (eql *key:ed448*))
				  (in <port>) . opts)
  (apply import-public-key m (get-bytevector-all in) opts))
(define-method import-public-key ((m (eql *key:ed448*))
				  (bv <bytevector>)
				  :optional (format (public-key-format raw)))
  (if (eq? format 'raw)
      (generate-ed448-public-key bv)
      (import-public-key *key:eddsa* bv format)))

(define-method import-public-key ((m (eql *key:eddsa*))
				  (in <bytevector>) . opts)
  (apply import-public-key m (open-bytevector-input-port in) opts))
(define-method import-public-key ((m (eql *key:eddsa*))
				  (in <port>) . opts)
  (apply import-public-key m (read-asn1-object in) opts))
(define-method import-public-key ((m (eql *key:eddsa*))
				  (in <der-sequence>)
				  :optional (format (public-key-format subject-public-key-info)))
  (unless (eq? format 'subject-public-key-info)
    (assertion-violation 'import-public-key
			 "Bare EdDSA can't be imported with raw format"))
  (let*-values (((aid key) (deconstruct-asn1-collection in))
		((oid . rest) (deconstruct-asn1-collection aid)))
    (let ((op (oid->key-operation (der-object-identifier->oid-string oid))))
      ;; ironically, specifying key type, e.g. *key:ed25519*, for SPKI
      ;; format is slower than just specifying *key:eddsa*...
      ;; life sucks, huh?
      (import-public-key op (der-bit-string->bytevector key)))))

(define-method export-private-key ((key <eddsa-private-key>) . opts)
  (apply export-private-key *key:eddsa* key opts))
(define-method export-private-key ((m (eql *key:ed25519*))
				   (key <eddsa-private-key>) . opts)
  (apply export-private-key *key:eddsa* key opts))
(define-method export-private-key ((m (eql *key:ed448*))
				   (key <eddsa-private-key>) . opts)
  (apply export-private-key *key:eddsa* key opts))
(define-method export-private-key ((m (eql *key:eddsa*))
				   (key <eddsa-private-key>) . ignore)
  (eddsa-private-key-random key))

(define-method import-private-key ((m (eql *key:ed25519*))
				   (in <port>) . opts)
  (apply import-private-key m (get-bytevector-all in) opts))
(define-method import-private-key ((m (eql *key:ed25519*))
				   (in <bytevector>) . ignore)
  (generate-ed25519-private-key in))
(define-method import-private-key ((m (eql *key:ed448*))
				   (in <port>) . opts)
  (apply import-private-key m (get-bytevector-all in) opts))
(define-method import-private-key ((m (eql *key:ed448*))
				   (in <bytevector>) . ignore)
  (generate-ed448-private-key in))

(define (eddsa-clamp! a c n b)
  (do ((i 0 (+ i 1)))
      ((= i c))
    (bytevector-u8-set! a (div i 8)
     (bitwise-and (bytevector-u8-ref a (div i 8))
		  (bitwise-not (bitwise-arithmetic-shift-left 1 (mod i 8))))))
  (bytevector-u8-set! a (div n 8)
   (bitwise-ior (bytevector-u8-ref a (div n 8))
		(bitwise-arithmetic-shift-left 1 (mod n 8))))
  (do ((i (+ n 1) (+ i 1)))
      ((= i b) a)
    (bytevector-u8-set! a (div i 8)
     (bitwise-and (bytevector-u8-ref a (div i 8))
		  (bitwise-not (bitwise-arithmetic-shift-left 1 (mod i 8)))))))
)
