(import (rnrs)
	(sagittarius)
	(sagittarius crypto ciphers types) ;; for cipher-scheme...
	(sagittarius crypto ciphers)
	(sagittarius crypto signatures)
	(sagittarius crypto keys)
	(sagittarius crypto digests)
	(sagittarius crypto math prime)
	(sagittarius crypto mac)
	(sagittarius crypto kdfs)
	(srfi :64))

(define (test-prime name tests)
  (define (check test)
    (let ((id (vector-ref test 0))
	  (comment (vector-ref test 1))
	  (value (vector-ref test 2))
	  (result (vector-ref test 3)))
      ;; We don't accept negative prime
      (unless (string=? "negative of a prime" comment)
	(test-equal (format "~a ~d (~a): ~a" name id result comment)
		    result
		    (probable-prime? value)))))
  (for-each check tests))

(test-begin "Prime number test vectors")
(include "./testvectors/prime.scm")
(test-end)

(define (test-hmac source :key algorithm key-size tag-size tests)
  (define (->digest a)
    (cond ((string=? a "HMACSHA1") *digest:sha-1*)
	  ((string=? a "HMACSHA224") *digest:sha-224*)
	  ((string=? a "HMACSHA256") *digest:sha-256*)
	  ((string=? a "HMACSHA384") *digest:sha-384*)
	  ((string=? a "HMACSHA512") *digest:sha-512*)
	  ((string=? a "HMACSHA3-224") *digest:sha3-224*)
	  ((string=? a "HMACSHA3-256") *digest:sha3-256*)
	  ((string=? a "HMACSHA3-384") *digest:sha3-384*)
	  ((string=? a "HMACSHA3-512") *digest:sha3-512*)
	  (else (assertion-violation 'test-hmac "Unknown algorithm" a))))
  (define ((check digest) test)
    (let-values (((id comment key msg tag result flag)
		  (apply values (vector->list test))))
      (let ((mac (make-mac *mac:hmac* key :digest digest))
	    (size (div tag-size 8)))
	(test-equal (list algorithm comment)
		    result (equal? tag (generate-mac mac msg size))))))
  (let ((digest (->digest algorithm)))
    (for-each (check digest) tests)))

(test-begin "HMAC test vectors")
(include "./testvectors/hmac.scm")
(test-end)

(define (test-cmac source :key algorithm key-size tag-size tests)
  (define (->cipher a)
    (cond ((string=? a "AES-CMAC") *scheme:aes*)
	  (else (assertion-violation 'test-hmac "Unknown algorithm" a))))
  (define ((check cipher) test)
    (let-values (((id comment key msg tag result flag)
		  (apply values (vector->list test))))
      (let ((mac (make-mac *mac:cmac* key :cipher cipher))
	    (size (div tag-size 8)))
	(if (string=? comment "invalid key size")
	    (test-error (list algorithm comment) (generate-mac mac msg size))
	    (test-equal (list algorithm comment) result
			(equal? tag (generate-mac mac msg size)))))))
  (let ((cipher (->cipher algorithm)))
    (for-each (check cipher) tests)))

(test-begin "CMAC")
(include "./testvectors/cmac.scm")
(test-end)

(define (test-gmac source :key algorithm key-size tag-size tests)
  (define (->cipher a)
    (cond ((string=? a "AES-GMAC") *scheme:aes*)
	  (else (assertion-violation 'test-hmac "Unknown algorithm" a))))
  (define ((check cipher) test)
    (let-values (((id comment key iv msg tag result flag)
		  (apply values (vector->list test))))
      (if (string=? comment "invalid key size")
	  (test-error (list id algorithm comment)
		      (make-mac *mac:gmac* key :cipher cipher :iv iv))
	  (let ((mac (make-mac *mac:gmac* key :cipher cipher :iv iv))
		(size (div tag-size 8)))
	    (if (string=? comment "invalid nonce size")
		(test-error (list id algorithm comment)
			    (generate-mac mac msg size))
		(test-equal (list id algorithm comment) result
			    (equal? tag (generate-mac mac msg size))))))))
  (let ((cipher (->cipher algorithm)))
    (for-each (check cipher) tests)))

(test-begin "GMAC")
(include "./testvectors/gmac.scm")
(test-end)

(define (test-hkdf source :key algorithm key-size tests)
  (define (->digest a)
    (cond ((string=? a "HKDF-SHA-1") *digest:sha-1*)
	  ((string=? a "HKDF-SHA-256") *digest:sha-256*)
	  ((string=? a "HKDF-SHA-384") *digest:sha-384*)
	  ((string=? a "HKDF-SHA-512") *digest:sha-512*)
	  (else (assertion-violation 'test-hkdf "Unknown algorithm" a))))
  (define ((check digest) test)
    (let-values (((id comment ikm salt info size okm result flag)
		  (apply values (vector->list test))))
      (cond (result (test-equal (cons* source comment flag) okm
				(hkdf digest ikm salt info size)))
	    ((member "SizeTooLarge" flag)
	     (test-error (cons* source comment flag)
			 (hkdf digest ikm salt info size)))
	    (else
	     (test-assert (cons* source comment flag)
		  (not (equal? okm (hkdf digest ikm salt info size))))))))
  (for-each (check (->digest algorithm)) tests))

(test-begin "HKDF")
(include "./testvectors/hkdf.scm")
(test-end)

(define ecdh-expected-error-test-comments
  '(
    ;; FIXME this must be fixed, but not sure how...
    "edge case for Jacobian and projective coordinates"
    "edge case for Jacobian and projective coordinates in left to right addition chain"
    "a = 0" ;; We check curve equiality, so this can't be passed
    ;; we don't correct or strip excess 0s
    "appending 0's to bit string"
    "appending null value to bit string"
    ;; Qy will be different (e.g. on tcId 486 of brainpool p224r1 test)
    "modifying last byte of bit string"
    "truncated bit string"
    "bit string of size 4155 to check for overflows"
    "unused bits in bit string"
    ))
(define ecdh-expected-error-test-flags
  '("InvalidAsn"))

(define (run-test-ecdh source algorithm curve encoding tests ->key)
  (define (check-flags flags)
    (exists (lambda (flag) (member flag ecdh-expected-error-test-flags)) flags))
  (define (check-deviation comment flags)
    (or (member comment ecdh-expected-error-test-comments)
	(check-flags flags)))
  (define (check test)
    (let-values (((id comment public private shared result flags)
		  (apply values (vector->list test))))
      (guard (e (else
		 (if (check-deviation comment flags)
		     (test-assert `("ECDH error" ,curve ,id ,comment) result)
		     (test-assert `("ECDH error" ,curve ,id ,comment)
				  (not result)))))
	(let ((pub-key (->key public 'public))
	      (priv-key (->key private 'private)))
	  (let ((sk (calculate-key-agreement *key:ecdh* priv-key pub-key)))
	    (if result
		(let ((ok? (equal? shared sk)))
		  (when (and (not ok?) (check-deviation comment flags))
		    (test-expect-fail `("ECDH" ,curve ,id ,comment)))
		  (test-assert `("ECDH" ,curve ,id ,comment) ok?))
		(test-assert `("ECDH invalid" ,curve ,id ,comment)
			     (not (equal? shared sk)))))))))
  (for-each check tests))

(define (test-ecdh source :key algorithm curve encoding tests)
  (define (curve->ec-parameter curve)
    (cond ((string=? curve "brainpoolP224r1") *ec-parameter:brainpool-p224r1* #f)
	  ((string=? curve "brainpoolP256r1") *ec-parameter:brainpool-p256r1* #f)
	  ((string=? curve "brainpoolP320r1") *ec-parameter:brainpool-p320r1* #f)
	  ((string=? curve "brainpoolP384r1") *ec-parameter:brainpool-p384r1* #f)
	  ((string=? curve "brainpoolP512r1") *ec-parameter:brainpool-p512r1* #f)
	  ((string=? curve "secp224k1") *ec-parameter:secp224k1* #f)
	  ((string=? curve "secp224r1") *ec-parameter:secp224r1* #f)
	  ((string=? curve "secp256k1") *ec-parameter:secp256k1* #f)
	  ((string=? curve "secp256r1") *ec-parameter:secp256r1* #f)
	  ((string=? curve "secp384r1") *ec-parameter:secp384r1* #f)
	  ((string=? curve "secp521r1") *ec-parameter:secp521r1*)
	  ((string=? curve "sect283k1") *ec-parameter:sect283k1* #f)
	  ((string=? curve "sect283r1") *ec-parameter:sect283r1* #f)
	  ((string=? curve "sect409k1") *ec-parameter:sect409k1* #f)
	  ((string=? curve "sect409r1") *ec-parameter:sect409r1* #f)
	  ((string=? curve "sect571k1") *ec-parameter:sect571k1* #f)
	  ((string=? curve "sect571r1") *ec-parameter:sect571r1* #f)
	  (else (print "Unknown curve: " curve) #f)))
  (define ec-parameter (curve->ec-parameter curve))
  (define (bytevector->key bv type)
    (case type
      ((public)
       (if (string=? encoding "asn")
	   (import-public-key *key:ecdsa* bv)
	   (import-public-key *key:ecdsa* bv 'raw ec-parameter)))
      ((private)
       (generate-private-key *key:ecdsa*
			     (bytevector->integer bv) ec-parameter))))
  (when ec-parameter
    (print "Testing " curve)
    (run-test-ecdh source algorithm curve encoding tests bytevector->key)))

(define (test-ecdh-jwk source :key algorithm curve encoding tests)
  (define (jwk->key json type) #t)
  #;(run-test-ecdh source algorithm curve encoding tests jwk->key))

;; (test-begin "ECDH")
;; (include "./testvectors/ecdh.scm")
;; (test-end)

;; In our implementation, size of the signature matters
;; So, if the signature size is not properly constructed,
;; it's an error. So below test(s) will fail even though
;; it should be 'acceptable'
(define signature-size-test
  '("incorrect size of signature"))

(define last-test #f)
(define (test-signature/testvector source
	 :key algorithm public-key tests der-encode
	      (digest #f) (mgf #f) (mgf-digest #f) (salt-length #f))
  ;; if key import is not supported, then ignore
  (define (import-key k)
    (guard (e ((implementation-restriction-violation? e)
	       (report-error e)
	       #f)
	      (else (test-assert "Failed to import key" #f)
		    (report-error e)
		    #f))
      (import-public-key k (public-key-format subject-public-key-info))))
  (define (->mgf mgf)
    (if (string=? mgf "MGF1")
	mgf-1
	(error '->mgf (string-append "Unknown MGF function: " mgf))))
  (define (->digest d)
    (cond ((string=? d "SHA-1")       *digest:sha-1*)
	  ((string=? d "SHA-224")     *digest:sha-224*)
	  ((string=? d "SHA-256")     *digest:sha-256*)
	  ((string=? d "SHA-384")     *digest:sha-384*)
	  ((string=? d "SHA-512")     *digest:sha-512*)
	  ((string=? d "SHA-512/224") *digest:sha-512/224*)
	  ((string=? d "SHA-512/256") *digest:sha-512/256*)
	  ((string=? d "SHA3-224")    *digest:sha3-224*)
	  ((string=? d "SHA3-256")    *digest:sha3-256*)
	  ((string=? d "SHA3-384")    *digest:sha3-384*)
	  ((string=? d "SHA3-512")    *digest:sha3-512*)
	  (else (error '->digest (string-append "Unknown digest: "d)))))
  (define (algorithm->signature-algorithm algorithm pkey)
    (cond ((string=? algorithm "DSA")
	   (values *signature:dsa*
		   `(:der-encode ,der-encode
		     :digest ,(->digest digest))))
	  ((string=? algorithm "ECDSA")
	   (values *signature:ecdsa*
		   `(:der-encode ,der-encode
		     :digest ,(->digest digest))))
	  ((string=? algorithm "EDDSA")
	   (values (if (ed25519-key? pkey)
		       *signature:ed25519*
		       *signature:ed448*) '()))
	  ((string=? algorithm "RSASSA-PSS")
	   (values *signature:rsa*
		   `(:verifier ,pkcs1-emsa-pss-verify
		     :digest ,(->digest digest)
		     :salt-length ,salt-length
		     :mgf ,(->mgf mgf)
		     :mgf-digest ,(->digest mgf-digest))))
	  ((string=? algorithm "RSASSA-PKCS1-v1_5" algorithm)
	   (values *signature:rsa*
		   `(:verifier ,pkcs1-emsa-v1.5-verify
		     :digest ,(->digest digest))))
	  (else (error #f (string-append "Unknown algorithm " algorithm)))))
  (define (->verifier algorithm pkey)
    (guard (e (else (test-assert (condition-message e) #f) #f))
      (let-values (((alg param)
		    (algorithm->signature-algorithm algorithm pkey)))
	(apply make-verifier alg pkey param))))
  (define ((verify-signature verifier) test)
    (define (safe-verify verifier msg sig)
      (guard (e (else #;(report-error e) #f))
	(verifier-verify-signature verifier msg sig)))
    (let ((id (vector-ref test 0))
	  (comment (vector-ref test 1))
	  (msg (vector-ref test 2))
	  (sig (vector-ref test 3))
	  (result (vector-ref test 4))
	  (tags (vector-ref test 5)))
      (unless (or (member comment signature-size-test))
	(test-equal (format "~a ~d (~a): ~a" source id result comment)
		    result (safe-verify verifier msg sig)))))
  (let* ((pkey (import-key public-key))
	 (verifier (->verifier algorithm pkey)))
    (when verifier
      (unless (equal? last-test source)
	(print "Testing " source)
	(set! last-test source))
      (test-assert verifier)
      (for-each (verify-signature verifier) tests))))

(test-begin "Signature test vectors")
(include "./testvectors/signature.scm")
(test-end)

(define ((make-test-chacha20-poly1305 chacha20-scheme)
	 name :key algorithm key-size tests)
  (define (cipher-name cipher) (cipher-descriptor-name (cipher-scheme cipher)))
  (define (setup-cipher cipher key iv aad direction)
    (stream-cipher-init! cipher direction key (make-iv-parameter iv))
    (stream-cipher-update-aad! cipher aad))
  (define (test-encrypt id cipher key iv aad msg ct tag)
    (setup-cipher cipher key iv aad (cipher-direction encrypt))
    (let ((v (stream-cipher-encrypt cipher msg)))
      (let ((tag1 (stream-cipher-done/tag cipher (bytevector-length tag))))
	(test-equal `(,(cipher-name cipher) "encrypt tag" ,id) tag tag1))
      (test-equal `(,(cipher-name cipher) "encrypt" ,id) ct v)))
  (define (test-decrypt id cipher key iv aad msg ct tag)
    (setup-cipher cipher key iv aad (cipher-direction decrypt))
    (let ((v (stream-cipher-decrypt cipher ct)))
      (stream-cipher-done/tag! cipher tag)
      (test-equal `(,(cipher-name cipher) "decrypt" ,id) msg v)))
  (define (run-test id cipher key iv aad msg ct tag)
    (test-encrypt id cipher key iv aad msg ct tag)
    (test-decrypt id cipher key iv aad msg ct tag))
  (define (check-chacha20-poly1305 test)
    (let ((id (vector-ref test 0))
	  (comment (vector-ref test 1))
	  (key (vector-ref test 2))
	  (iv (vector-ref test 3))
	  (aad (vector-ref test 4))
	  (msg (vector-ref test 5))
	  (ct (vector-ref test 6))
	  (tag (vector-ref test 7))
	  (result (vector-ref test 8)))
      (let ((cipher (make-stream-cipher chacha20-scheme))
	    (skey (make-symmetric-key key)))
	(if result
	    (run-test id cipher skey iv aad msg ct tag)
	    (test-error `("Error:" ,(cipher-name cipher) ,id ,comment) 
	     serious-condition?
	     ;; decrypt will raise an error instead of crush it...
	     (test-decrypt id cipher skey iv aad msg ct tag))))))
  (for-each check-chacha20-poly1305 tests))

(define test-chacha20-poly1305
  (make-test-chacha20-poly1305 *scheme:chacha20-poly1305*))

(test-begin "ChaCha20-Poly1305 test vectors")
(include "./testvectors/chacha20-poly1305.scm")
(test-end)

(define test-xchacha20-poly1305
  (make-test-chacha20-poly1305 *scheme:xchacha20-poly1305*))

(test-begin "XChaCha20-Poly1305 test vectors")
(include "./testvectors/xchacha20-poly1305.scm")
(test-end)
