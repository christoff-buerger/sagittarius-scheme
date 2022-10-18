#!read-macro=sagittarius/bv-string
(import (srfi :64 testing)
	(rnrs)
	(sagittarius)
	(crypto)
	(math random)
	(math prime)
	(math hash)
	(math ec)
	(rfc base64)
	(util bytevector)
	(clos user))

;; plain value for all test cases
(define *plain-value* (string->utf8 "I want to encrypt this text with the key!"))

;; DES test variables
;; DES-key must be 8 byte.
(define *des-key* (generate-secret-key DES (string->utf8 "8bytekey")))
;; mode ECB
(define *des/ecb-encrypted-value* #vu8(84 85 42 221 141 106 0 232 14 121 91
					  247 72 234 116 240 172 64 21 37 132 95
					  218 33 115 60 198 159 177 7 190 132 192
					  41 72 56 147 35 16 19 57 251 193 32 172
					  60 149 88 ))
;; we only support NoPadding for now.
;; DES/ECB/PKCS5Padding
(define des/ecb-cipher (cipher DES *des-key*))
;; mode CBC
(define *des/cbc-encrypted-value* #vu8(84 85 42 221 141 106 0 232 27 30 182
					  118 4 145 76 6 188 159 250 21 101 77
					  164 108 21 17 88 238 91 182 222 224 167
					  190 146 224 245 191 197 96 180 131 240
					  188 245 131 173 214 ))
;; DES/CBC/PKCS5Padding
(define des-dec/cbc-cipher (cipher DES *des-key*
				   :mode MODE_CBC
				   :iv (make-bytevector 8 0)))
(define des-enc/cbc-cipher (cipher DES *des-key*
				   :mode MODE_CBC
				   :iv (make-bytevector 8 0)))
;; Triple DES test variables
;; we need 24 bytes for key
(define des3-key-raw (string->utf8 "24bytekey123456789012345"))
(define *des3-key* (generate-secret-key DES3 des3-key-raw))
(define des3/ecb-cipher (cipher DES3 *des3-key*))
(define *des3/ecb-encrypted-value* #vu8(206 108 187 150 233 197 246 31 249 102
					    106 26 0 109 134 172 189 147 206 65
					    130 22 96 65 19 127 169 159 56 4 89
					    237 101 140 28 239 201 52 238 48 225
					    116 191 153 151 81 167 192 ))
;; mode CBC
(define des3-enc/cbc-cipher (cipher DES3 *des3-key*
				:mode MODE_CBC
				:iv (make-bytevector 8 0)))
(define des3-dec/cbc-cipher (cipher DES3 *des3-key*
				    :mode MODE_CBC
				    :iv (make-bytevector 8 0)))
(define *des3/cbc-encrypted-value* #vu8(206 108 187 150 233 197 246 31 137 218
					    183 8 206 147 188 108 248 23 19 187
					    239 219 114 237 233 214 34 79 76 209
					    191 75 26 223 140 38 166 255 236 146
					    140 167 157 42 240 38 203 30 ))

(define *pseudo-primes*
  '(341 561 645 1105 1387 1729 1905 2047 2465 2701 
	2821 3277 4033 4369 4371 4681 5461 6601 7957 8321 
	8481 8911))


;; 256 bits
(define public-rsa-key
  (generate-public-key RSA
		       #xeb054bbba72bbc6493bc097ac370c0fc54717494b2e7d9370a9c6c02b76aeaa9
		       #x10001))
(define private-rsa-key 
  (generate-private-key RSA
			#xeb054bbba72bbc6493bc097ac370c0fc54717494b2e7d9370a9c6c02b76aeaa9
			#x6b05da5af5e180c4fc51a0af7ad899c86ee18e03284d2e392ab8f667debfef41))
(define private-crt-rsa-key
  (generate-private-key RSA 
			#xeb054bbba72bbc6493bc097ac370c0fc54717494b2e7d9370a9c6c02b76aeaa9
			#x6b05da5af5e180c4fc51a0af7ad899c86ee18e03284d2e392ab8f667debfef41
			;; CRT other information will be calculated.
			:public-exponent #x10001
			:p #xfbe6477962d4061751f70afa70ea90bd
			:q #xeed8adc508800e7f570b8cbd05120e5d))

;; with padding, it must be data < key-length/8 - 11
(define valid-rsa-message (string->utf8 "test message"))
;; with 256 bits key 22 bytes message is invalid
(define invalid-rsa-message (string->utf8 "1234567890123456789012"))
;; use PKCS#1 v1.5 EMSA to validate
(define encrypted-rsa-message-with-padding
  #vu8(108 25 42 122 6 232 191 202 194 60 111 176 144 142 117 184 35 36 117 225 106 182 31 55 98 101 225 64 242 177 64 167))
(define encrypted-rsa-message-without-padding
  #vu8(14 84 14 78 188 35 123 21 38 39 170 179 53 29 36 140 76 176 113 238 68 6 105 28 134 217 169 1 155 212 50 193))

(define invalid-padding
  ;; #xFE is invalid
  #vu8(1 255 255 255 255 255 255 255 255 255 255 #xFE 255 255 255 255 255 255 0 116 101 115 116 32 109 101 115 115 97 103 101))

(define key-pair (generate-key-pair RSA :size 1024 :prng (pseudo-random RC4)))

(test-begin "(run-crypto-test)")
;; basic test
(test-assert "crypto-object?" (crypto-object? des-enc/cbc-cipher))
(test-assert "cipher?" (cipher? des-enc/cbc-cipher))
(test-assert "key?" (key? *des-key*))

(define (test-prng prng)
  (test-assert "prng?" (prng? (pseudo-random prng)))
  (test-assert "prng?" (prng? (secure-random prng)))
  (test-assert "pseudo-random?" (pseudo-random? (pseudo-random prng)))
  (test-assert "secure-random?" (secure-random? (secure-random prng))))
(for-each test-prng (list Yarrow Fortuna RC4 SOBER-128 System ChaCha20))

(test-equal 8 (bytevector-length (read-sys-random 64)))
(test-equal 8 (bytevector-length (read-sys-random 63)))
(let ((bv (make-bytevector 8)))
  (test-assert (eq? bv (read-sys-random! bv)))
  (bytevector-u8-set! bv 0 0)
  (test-assert (eq? bv (read-sys-random! bv 1)))
  (test-equal 0 (bytevector-u8-ref bv 0))
  (bytevector-u8-set! bv 7 0)
  (test-assert (eq? bv (read-sys-random! bv 1 6)))
  (test-equal 0 (bytevector-u8-ref bv 7)))

(test-assert "cipher-iv" (bytevector? (cipher-iv des-enc/cbc-cipher)))
(test-equal "cipher-iv (set!)"
	    (cipher-iv des-enc/cbc-cipher)
	    (let ((iv (cipher-iv des-enc/cbc-cipher)))
	     (cipher-iv des-enc/cbc-cipher iv)
	     (cipher-iv des-enc/cbc-cipher)))


;; key suggest

;;(test-equal "DES key size" 8 (cipher-keysize DES 8))
(test-equal "DES key size" 8 (cipher-keysize des/ecb-cipher 8))
;;(test-equal "DES3 key size" 24 (cipher-keysize DES3 24))
(test-equal "DES3 key size" 24 (cipher-keysize des3/ecb-cipher 24))

;; block size
(test-equal "DES block size" 8 (cipher-blocksize des/ecb-cipher))
(test-equal "DES3 block size" 8 (cipher-blocksize des3/ecb-cipher))

;; new interface
(test-equal "DES block size" 8 (cipher-blocksize DES))
(test-equal "DES3 block size" 8 (cipher-blocksize DESede))

;; encryption

(test-equal "DES/ECB encrypt"
	    *des/ecb-encrypted-value*
	    (encrypt des/ecb-cipher *plain-value*))
(test-equal "DES/CBC encrypt"
	    *des/cbc-encrypted-value*
	    (encrypt des-enc/cbc-cipher *plain-value*))
(test-equal "DES3/ECB encrypt"
	    *des3/ecb-encrypted-value*
	    (encrypt des3/ecb-cipher *plain-value*))
(test-equal "DES3/CBC encrypt"
	    *des3/cbc-encrypted-value*
	    (encrypt des3-enc/cbc-cipher *plain-value*))
;; decryption

(test-equal "DES/ECB decrypt"
	    *plain-value*
	    (decrypt des/ecb-cipher *des/ecb-encrypted-value*))
(test-equal "DES/CBC decrypt"
	    *plain-value*
	    (decrypt des-dec/cbc-cipher *des/cbc-encrypted-value*))
(test-equal "DES3/ECB decrypt"
	    *plain-value*
	    (decrypt des3/ecb-cipher *des3/ecb-encrypted-value*))
(test-equal "DES3/CBC decrypt"
	    *plain-value*
	    (decrypt des3-dec/cbc-cipher *des3/cbc-encrypted-value*))

;; prime?

(test-assert "is-prime?"
	     (not (exists is-prime? *pseudo-primes*)))
;; RSA

(test-assert "generated private key?" (private-key? private-rsa-key))
(test-assert "generated public key?" (public-key? public-rsa-key))
(test-equal "public/private keys"
	    '(#t #t)
	    (list (key? private-rsa-key) (key? public-rsa-key)))

(test-equal "generate key pair"
	    '(#t #t)
	    (let ((kp (generate-key-pair RSA)))
	      (list (private-key? (keypair-private kp))
		    (public-key? (keypair-public kp)))))

;; with padding
(test-equal "encrypt/decript with padding"
	    `(,encrypted-rsa-message-with-padding ,valid-rsa-message ,valid-rsa-message)
	    (let ((rsa-encrypt-cipher (cipher RSA public-rsa-key :block-type PKCS-1-EMSA))
		  (rsa-decrypt-cipher (cipher RSA private-rsa-key :block-type PKCS-1-EMSA))
		  (rsa-decrypt-crt-cipher (cipher RSA private-crt-rsa-key :block-type PKCS-1-EMSA)))
	      (list (encrypt rsa-encrypt-cipher valid-rsa-message)
		    (decrypt rsa-decrypt-cipher encrypted-rsa-message-with-padding)
		    (decrypt rsa-decrypt-crt-cipher encrypted-rsa-message-with-padding))))

;; without padding
(test-equal "encrypt/decript without padding"
	    `(,encrypted-rsa-message-without-padding ,valid-rsa-message ,valid-rsa-message)
	    (let ((rsa-encrypt-cipher (cipher RSA public-rsa-key :padding #f))
		  (rsa-decrypt-cipher (cipher RSA private-rsa-key :padding #f))
		  (rsa-decrypt-crt-cipher (cipher RSA private-crt-rsa-key :padding #f)))
	      (list (encrypt rsa-encrypt-cipher valid-rsa-message)
		    (decrypt rsa-decrypt-cipher encrypted-rsa-message-without-padding)
		    (decrypt rsa-decrypt-crt-cipher encrypted-rsa-message-without-padding))))

(test-assert "encrypt/decript without padding more than 21 bytes"
	     (let ((rsa-encrypt-cipher (cipher RSA public-rsa-key :padding #f))
		   (rsa-decrypt-cipher (cipher RSA private-rsa-key :padding #f))
		   (rsa-decrypt-crt-cipher (cipher RSA private-crt-rsa-key :padding #f)))
	       (let* ((ct (encrypt rsa-encrypt-cipher invalid-rsa-message))
		      (pt (decrypt rsa-decrypt-cipher ct))
		      (pt-crt (decrypt rsa-decrypt-crt-cipher ct)))
		 (and (equal? pt invalid-rsa-message)
		      (equal? pt-crt invalid-rsa-message)))))

(test-assert "with padding too long RSA block"
	     (guard (e (else #t))
	       (let ((rsa-encrypt-cipher (cipher RSA public-rsa-key)))
		 (encrypt rsa-encrypt-cipher invalid-rsa-message))))

(test-assert "with padding invalid block"
	     (guard (e (else #t))
	       (let ((rsa-decrypt-cipher (cipher RSA private-rsa-key)))
		 (decrypt rsa-decrypt-cipher invalid-padding))))

;; hash test
;; hash valid-rsa-message

(test-equal "MD5 hash"
	    #vu8(#xC7 #x2B #x96 #x98 #xFA #x19 #x27 #xE1 #xDD #x12 #xD3 #xCF #x26 #xED #x84 #xB2)
	    (hash MD5 valid-rsa-message))

;; new interface
(let ((msg (string->utf8 "hello world"))
      (md (hash-algorithm MD5))
      (out (make-bytevector (hash-size MD5)))
      (out2 (make-bytevector (+ (hash-size MD5) 2) 0)))
  (test-equal "optional start end for hash-process!"
	      (hash md msg)
	      (begin
		(hash-init! md)
		(hash-process! md msg 0 5)
		(hash-process! md msg 5)
		(hash-done! md out)))
  (test-equal "optional start end for hash-done! (1)"
	      (bytevector-append #vu8(0) (hash md msg) #vu8(0))
	      (begin
		(hash-init! md)
		(hash-process! md msg)
		(hash-done! md out2 1)))
  (test-error "optional start end for hash-done! (2)"
	      condition?
	      (begin
		(hash-init! md)
		(hash-process! md msg)
		(hash-done! md out 0 1)))
)

(test-equal "MD5 OID"
	    "1.2.840.113549.2.5"
	    (hash-oid (hash-algorithm MD5)))

;; SHA-512/224 and SHA-512/256
(let ((msg #vu8())
      (md (hash-algorithm SHA-512/224)))
  (test-equal "SHA-512/224"
	      (integer->bytevector #x6ed0dd02806fa89e25de060c19d3ac86cabb87d6a0ddd05c333b84f4)
	      (hash md msg)))
(let ((msg #vu8())
      (md (hash-algorithm SHA-512/256)))
  (test-equal "SHA-512/256"
	      (integer->bytevector #xc672b8d1ef56ed28ab87c3622c5114069bdd3ad7b8f9737498d0c01ecef0967a)
	      (hash md msg)))

;; SHA3
(let ((algorithmes (list SHA-3-224 SHA-3-256 SHA-3-384 SHA-3-512)))
  (define abcs
    (map hex-string->bytevector
	 '("e642824c3f8cf24ad09234ee7d3c766fc9a3a5168d0c94ad73b46fdf"
	   "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532"
	   "ec01498288516fc926459f58e2c6ad8df9b473cb0fc08c2596da7cf0e49be4b298d88cea927ac7f539f1edf228376d25"
	   "b751850b1a57168a5693cd924b6b096e08f621827444f70d884f5d0240d2712e10e116e9192af3c91a7ec57647e3934057340b4cf408d5a56592f8274eec53f0")))
  (define empties
    (map hex-string->bytevector
	 '("6b4e03423667dbb73b6e15454f0eb1abd4597f9a1b078e3f5b5a6bc7"
	   "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a"
	   "0c63a75b845e4f7d01107d852e4c2485c51a50aaaa94fc61995e71bbee983a2ac3713831264adb47fb6bd1e058d5f004"
	   "a69f73cca23a9ac5c8b567dc185a756e97c982164fe25859e0d1dcc1475c80a615b2123af1f5f94c11e3e9402c3ac558f500199d95b6d3e301758586281dcd26")))
  (define (test-sha3 algo in out) (test-equal out (hash algo in)))
  (for-each (lambda (algo out) (test-sha3 algo #*"abc" out)) algorithmes abcs)
  (for-each (lambda (algo out) (test-sha3 algo #*"" out)) algorithmes empties))

;; SHAKE128
(let ()
  (define (convert v)
    (list (car v) (integer->bytevector (cadr v))))
  (define digests-shake-128
    (map convert
	 '((#vu8() #x7f9c2ba4e88f827d616045507605853e)
	   (#vu8(#x0e) #xfa996dafaa208d72287c23bc4ed4bfd5)
	   (#vu8(#xd9 #xe8) #xc7211512340734235bb8d3c4651495aa)
	   (#vu8(#x1b #x3b #x6e) #xd7335497e4cd3666885edbb0824d7a75))))
  (define digests-shake-256
    (map convert
	 '((#vu8()
	    #x46b9dd2b0ba88d13233b3feb743eeb243fcd52ea62b81b82b50c27646ed5762f)
	   (#vu8(#x0f)
	    #xaabb07488ff9edd05d6a603b7791b60a16d45093608f1badc0c9cc9a9154f215)
	   (#vu8(#x0d #xc1)
	    #x8e2df9d379bb034aee064e965f960ebb418a9bb535025fb96427f678cf207877)
 	   (#vu8(#x21 #xed #xa6)
	    #xf7d02b4512be5ddcc25d148c71664dfd34e16abea26d6e7287f45e08ed6fcd87)
	   )))
  (define (test algo size test-data)
    (let ((v (hash algo (car test-data) :size size)))
      (test-equal (cadr test-data) v)))
  (for-each (lambda (td) (test SHAKE128 16 td)) digests-shake-128)
  (for-each (lambda (td) (test SHAKE256 32 td)) digests-shake-256)
  )
  

;; BLAKE2s
(let ((algos (list BLAKE2s-256 BLAKE2s-224 BLAKE2s-160 BLAKE2s-128
		   BLAKE2b-512 BLAKE2b-384 BLAKE2b-256 BLAKE2b-160)))
  (define empties
    '(#vu8( #x69 #x21 #x7a #x30 #x79 #x90 #x80 #x94
            #xe1 #x11 #x21 #xd0 #x42 #x35 #x4a #x7c
	    #x1f #x55 #xb6 #x48 #x2c #xa1 #xa5 #x1e
	    #x1b #x25 #x0d #xfd #x1e #xd0 #xee #xf9 )
      #vu8( #x1f #xa1 #x29 #x1e #x65 #x24 #x8b #x37
            #xb3 #x43 #x34 #x75 #xb2 #xa0 #xdd #x63
	    #xd5 #x4a #x11 #xec #xc4 #xe3 #xe0 #x34
	    #xe7 #xbc #x1e #xf4 )
      #vu8( #x35 #x4c #x9c #x33 #xf7 #x35 #x96 #x24
            #x18 #xbd #xac #xb9 #x47 #x98 #x73 #x42
	    #x9c #x34 #x91 #x6f)
      #vu8( #x64 #x55 #x0d #x6f #xfe #x2c #x0a #x01
	    #xa1 #x4a #xba #x1e #xad #xe0 #x20 #x0c )
      #vu8( #x78 #x6a #x02 #xf7 #x42 #x01 #x59 #x03
            #xc6 #xc6 #xfd #x85 #x25 #x52 #xd2 #x72
            #x91 #x2f #x47 #x40 #xe1 #x58 #x47 #x61
            #x8a #x86 #xe2 #x17 #xf7 #x1f #x54 #x19
            #xd2 #x5e #x10 #x31 #xaf #xee #x58 #x53
            #x13 #x89 #x64 #x44 #x93 #x4e #xb0 #x4b
            #x90 #x3a #x68 #x5b #x14 #x48 #xb7 #x55
            #xd5 #x6f #x70 #x1a #xfe #x9b #xe2 #xce )
      #vu8( #xb3 #x28 #x11 #x42 #x33 #x77 #xf5 #x2d
            #x78 #x62 #x28 #x6e #xe1 #xa7 #x2e #xe5
            #x40 #x52 #x43 #x80 #xfd #xa1 #x72 #x4a
            #x6f #x25 #xd7 #x97 #x8c #x6f #xd3 #x24
            #x4a #x6c #xaf #x04 #x98 #x81 #x26 #x73
            #xc5 #xe0 #x5e #xf5 #x83 #x82 #x51 #x00 )
      #vu8( #x0e #x57 #x51 #xc0 #x26 #xe5 #x43 #xb2
            #xe8 #xab #x2e #xb0 #x60 #x99 #xda #xa1
            #xd1 #xe5 #xdf #x47 #x77 #x8f #x77 #x87
            #xfa #xab #x45 #xcd #xf1 #x2f #xe3 #xa8 )
      #vu8( #x33 #x45 #x52 #x4a #xbf #x6b #xbe #x18
            #x09 #x44 #x92 #x24 #xb5 #x97 #x2c #x41
            #x79 #x0b #x6c #xf2 )))
  (define abcs
    '(#vu8( #x50 #x8c #x5e #x8c #x32 #x7c #x14 #xe2
            #xe1 #xa7 #x2b #xa3 #x4e #xeb #x45 #x2f
	    #x37 #x45 #x8b #x20 #x9e #xd6 #x3a #x29
	    #x4d #x99 #x9b #x4c #x86 #x67 #x59 #x82 )
      #vu8( #x0b #x03 #x3f #xc2 #x26 #xdf #x7a #xbd
	    #xe2 #x9f #x67 #xa0 #x5d #x3d #xc6 #x2c
	    #xf2 #x71 #xef #x3d #xfe #xa4 #xd3 #x87
	    #x40 #x7f #xbd #x55 )
      #vu8( #x5a #xe3 #xb9 #x9b #xe2 #x9b #x01 #x83
            #x4c #x3b #x50 #x85 #x21 #xed #xe6 #x04
	    #x38 #xf8 #xde #x17 )
      #vu8( #xaa #x49 #x38 #x11 #x9b #x1d #xc7 #xb8
	    #x7c #xba #xd0 #xff #xd2 #x00 #xd0 #xae )
      #vu8( #xba #x80 #xa5 #x3f #x98 #x1c #x4d #x0d
            #x6a #x27 #x97 #xb6 #x9f #x12 #xf6 #xe9
            #x4c #x21 #x2f #x14 #x68 #x5a #xc4 #xb7
            #x4b #x12 #xbb #x6f #xdb #xff #xa2 #xd1
            #x7d #x87 #xc5 #x39 #x2a #xab #x79 #x2d
            #xc2 #x52 #xd5 #xde #x45 #x33 #xcc #x95
            #x18 #xd3 #x8a #xa8 #xdb #xf1 #x92 #x5a
            #xb9 #x23 #x86 #xed #xd4 #x00 #x99 #x23 )
      #vu8( #x6f #x56 #xa8 #x2c #x8e #x7e #xf5 #x26
            #xdf #xe1 #x82 #xeb #x52 #x12 #xf7 #xdb
            #x9d #xf1 #x31 #x7e #x57 #x81 #x5d #xbd
            #xa4 #x60 #x83 #xfc #x30 #xf5 #x4e #xe6
            #xc6 #x6b #xa8 #x3b #xe6 #x4b #x30 #x2d
            #x7c #xba #x6c #xe1 #x5b #xb5 #x56 #xf4 )
      #vu8( #xbd #xdd #x81 #x3c #x63 #x42 #x39 #x72
            #x31 #x71 #xef #x3f #xee #x98 #x57 #x9b
            #x94 #x96 #x4e #x3b #xb1 #xcb #x3e #x42
            #x72 #x62 #xc8 #xc0 #x68 #xd5 #x23 #x19 )
      #vu8( #x38 #x42 #x64 #xf6 #x76 #xf3 #x95 #x36
            #x84 #x05 #x23 #xf2 #x84 #x92 #x1c #xdc
            #x68 #xb6 #x84 #x6b )))
  (define (test-blake2 algo in out) (test-equal out (hash algo in)))
  (for-each (lambda (algo out) (test-blake2 algo #*"abc" out)) algos abcs)
  (for-each (lambda (algo out) (test-blake2 algo #*"" out)) algos empties))

(test-equal (hash SHA-256 #vu8())
	    (hash (oid->hash-algorithm "2.16.840.1.101.3.4.2.1") #vu8()))

;; These are internal tests, covered by test vector tests
;; mgf-1 test
;; (define mgf-result-sha1
;;   (integer->bytevector #x5f8de105b5e96b2e490ddecbd147dd1def7e3b8e0e6a26eb7b956ccb8b3bdc1ca975bc57c3989e8fbad31a224655d800c46954840ff32052cdf0d640562bdfadfa263cfccf3c52b29f2af4a1869959bc77f854cf15bd7a25192985a842dbff8e13efee5b7e7e55bbe4d389647c686a9a9ab3fb889b2d7767d3837eea4e0a2f04))
;; (define mgf-seed-sha1
;;   (integer->bytevector #x032e45326fa859a72ec235acff929b15d1372e30b207255f0611b8f785d764374152e0ac009e509e7ba30cd2f1778e113b64e135cf4e2292c75efe5288edfda4))

;; (test-equal "MGF-1(SHA-1)"
;; 	    mgf-result-sha1
;; 	    (mgf-1 mgf-seed-sha1 (bytevector-length mgf-result-sha1) SHA-1))


;; ;; PKCS#1 EMSA-PSS test
;; (test-assert "PKCS#1 EMSA-PSS"
;; 	     (let ((encoded (pkcs1-emsa-pss-encode valid-rsa-message 1024)))
;; 	       (pkcs1-emsa-pss-verify valid-rsa-message encoded 1024)))

(test-assert "Verify with EMSA-PSS and SHA-1"
	     (let* ((rsa-sign-cipher (cipher RSA (keypair-private key-pair)))
		    (rsa-verify-cipher (cipher RSA (keypair-public key-pair)))
		    (em (cipher-signature rsa-sign-cipher valid-rsa-message)))
	       (verify rsa-verify-cipher valid-rsa-message em)))

(test-assert "Verify with EMSA-PSS and MD5"
	     (let* ((rsa-sign-cipher (cipher RSA (keypair-private key-pair)))
		    (rsa-verify-cipher (cipher RSA (keypair-public key-pair)))
		    (em (sign rsa-sign-cipher valid-rsa-message 
			      :hash (hash-algorithm MD5))))
	       (verify rsa-verify-cipher valid-rsa-message em 
		       :hash (hash-algorithm MD5))))

(test-assert "Verify with PKCS1-v1.5"
	     (let* ((rsa-sign-cipher (cipher RSA (keypair-private key-pair)))
		    (rsa-verify-cipher (cipher RSA (keypair-public key-pair)))
		    (em (sign rsa-sign-cipher valid-rsa-message
			      :encode pkcs1-emsa-v1.5-encode)))
	       (verify rsa-verify-cipher valid-rsa-message em
		       :verify pkcs1-emsa-v1.5-verify)))

;; Issue 21
(test-assert "SOBER-128 prng"
	     (let ((prng (pseudo-random SOBER-128
					:seed #vu8(1 2 3 4 5 6 7 8))))
	       (pseudo-random? prng)))

;; this will never happen since we follow the upsteam of libtomcrypt
;; (test-error "SOBER-128 prng (no seed)"
;; 	    error?
;; 	    (pseudo-random SOBER-128))
;; 
;; (test-error "SOBER-128 prng (invalid seed size)"
;; 	    error?
;; 	    (pseudo-random SOBER-128 :seed #vu8(1 2 3)))

;; blowfish
;; test vector from http://www.schneier.com/code/vectors.txt
(define (blowfish-test key plaintext)
  (let* ((skey (generate-secret-key Blowfish (integer->bytevector key 8)))
	 (blowfish-cipher (cipher Blowfish skey :padder #f)))
    (let* ((text (integer->bytevector plaintext 8))
	   (enc (encrypt blowfish-cipher text)))
      (and (equal? text (decrypt blowfish-cipher enc))
	   (bytevector-u64-ref enc 0 (endianness big))))))

(test-equal "blowfish (1)" #x4EF997456198DD78 (blowfish-test #x0000000000000000 #x0000000000000000))
(test-equal "blowfish (1)" #x51866FD5B85ECB8A (blowfish-test #xFFFFFFFFFFFFFFFF #xFFFFFFFFFFFFFFFF))
(test-equal "blowfish (1)" #x7D856F9A613063F2 (blowfish-test #x3000000000000000 #x1000000000000001))
(test-equal "blowfish (1)" #x2466DD878B963C9D (blowfish-test #x1111111111111111 #x1111111111111111))
(test-equal "blowfish (1)" #x61F9C3802281B096 (blowfish-test #x0123456789ABCDEF #x1111111111111111))
(test-equal "blowfish (1)" #x7D0CC630AFDA1EC7 (blowfish-test #x1111111111111111 #x0123456789ABCDEF))
(test-equal "blowfish (1)" #x4EF997456198DD78 (blowfish-test #x0000000000000000 #x0000000000000000))
(test-equal "blowfish (1)" #x0ACEAB0FC6A0A28D (blowfish-test #xFEDCBA9876543210 #x0123456789ABCDEF))
(test-equal "blowfish (1)" #x59C68245EB05282B (blowfish-test #x7CA110454A1A6E57 #x01A1D6D039776742))
(test-equal "blowfish (1)" #xB1B8CC0B250F09A0 (blowfish-test #x0131D9619DC1376E #x5CD54CA83DEF57DA))
(test-equal "blowfish (1)" #x1730E5778BEA1DA4 (blowfish-test #x07A1133E4A0B2686 #x0248D43806F67172))
(test-equal "blowfish (1)" #xA25E7856CF2651EB (blowfish-test #x3849674C2602319E #x51454B582DDF440A))
(test-equal "blowfish (1)" #x353882B109CE8F1A (blowfish-test #x04B915BA43FEB5B6 #x42FD443059577FA2))
(test-equal "blowfish (1)" #x48F4D0884C379918 (blowfish-test #x0113B970FD34F2CE #x059B5E0851CF143A))
(test-equal "blowfish (1)" #x432193B78951FC98 (blowfish-test #x0170F175468FB5E6 #x0756D8E0774761D2))
(test-equal "blowfish (1)" #x13F04154D69D1AE5 (blowfish-test #x43297FAD38E373FE #x762514B829BF486A))
(test-equal "blowfish (1)" #x2EEDDA93FFD39C79 (blowfish-test #x07A7137045DA2A16 #x3BDD119049372802))
(test-equal "blowfish (1)" #xD887E0393C2DA6E3 (blowfish-test #x04689104C2FD3B2F #x26955F6835AF609A))
(test-equal "blowfish (1)" #x5F99D04F5B163969 (blowfish-test #x37D06BB516CB7546 #x164D5E404F275232))
(test-equal "blowfish (1)" #x4A057A3B24D3977B (blowfish-test #x1F08260D1AC2465E #x6B056E18759F5CCA))
(test-equal "blowfish (1)" #x452031C1E4FADA8E (blowfish-test #x584023641ABA6176 #x004BD6EF09176062))
(test-equal "blowfish (1)" #x7555AE39F59B87BD (blowfish-test #x025816164629B007 #x480D39006EE762F2))
(test-equal "blowfish (1)" #x53C55F9CB49FC019 (blowfish-test #x49793EBC79B3258F #x437540C8698F3CFA))
(test-equal "blowfish (1)" #x7A8E7BFA937E89A3 (blowfish-test #x4FB05E1515AB73A7 #x072D43A077075292))
(test-equal "blowfish (1)" #xCF9C5D7A4986ADB5 (blowfish-test #x49E95D6D4CA229BF #x02FE55778117F12A))
(test-equal "blowfish (1)" #xD1ABB290658BC778 (blowfish-test #x018310DC409B26D6 #x1D9D5C5018F728C2))
(test-equal "blowfish (1)" #x55CB3774D13EF201 (blowfish-test #x1C587F1C13924FEF #x305532286D6F295A))
(test-equal "blowfish (1)" #xFA34EC4847B268B2 (blowfish-test #x0101010101010101 #x0123456789ABCDEF))
(test-equal "blowfish (1)" #xA790795108EA3CAE (blowfish-test #x1F1F1F1F0E0E0E0E #x0123456789ABCDEF))
(test-equal "blowfish (1)" #xC39E072D9FAC631D (blowfish-test #xE0FEE0FEF1FEF1FE #x0123456789ABCDEF))
(test-equal "blowfish (1)" #x014933E0CDAFF6E4 (blowfish-test #x0000000000000000 #xFFFFFFFFFFFFFFFF))
(test-equal "blowfish (1)" #xF21E9A77B71C49BC (blowfish-test #xFFFFFFFFFFFFFFFF #x0000000000000000))
(test-equal "blowfish (1)" #x245946885754369A (blowfish-test #x0123456789ABCDEF #x0000000000000000))
(test-equal "blowfish (1)" #x6B5C5A9C5D9E0A5A (blowfish-test #xFEDCBA9876543210 #xFFFFFFFFFFFFFFFF))

;; key components stuff
(let ((key (integer->bytevector
	    #x708986F7C8FEBFD064A15B25B62C6DC710F8AD3264BA7329)))
  (let-values (((comp1 comp2 comp3) (split-key key))
	       ((buf) (make-bytevector (bytevector-length key))))
    (test-equal "combine3(1)" key (combine-key-components comp1 comp2 comp3))
    (test-equal "combine3(1)" key 
		(combine-key-components! buf comp1 comp2 comp3)))
  (let-values (((comp1 comp2) (split-key key 2))
	       ((buf) (make-bytevector (bytevector-length key))))
    (test-equal "combine2(1)" key (combine-key-components comp1 comp2))
    (test-equal "combine2(1)" key 
		(combine-key-components! buf comp1 comp2))))

(let ((key (generate-secret-key DES3 (integer->bytevector #x975158F83E3164388A6DC252B03EF2D6643E151FF2A1CDB3))))
  (test-equal "KCV" #vu8(#x5B #x3A #x44) (key-check-value DES3 key))
  ;; I don't think we need whole length of the value but in case
  (test-equal "KCV" (integer->bytevector #x5B3A44A4D78ADE13)
	      (key-check-value DES3 key 8))
  (test-error "KCV (size 2)" values (key-check-value DES3 key 2))
  (test-error "KCV (size 2)" values (key-check-value DES3 key 9)))

;; import and export keys
(let ((epub (export-public-key RSA (keypair-public key-pair)))
      (epri (export-private-key RSA (keypair-private key-pair))))
  (test-equal "import public key" (keypair-public key-pair)
	      (import-public-key RSA epub))

  (test-equal "import private key" (keypair-private key-pair)
	      (import-private-key RSA epri)))

(let ((pv
#u8( 
 #x30 #x82 #x02 #x5c #x02 #x01 #x00 #x02 #x81 #x81 #x00 #x9f #xe9 #x80 #x09 #x39
 #x20 #x58 #x3e #xf7 #xb5 #x8e #x96 #x03 #xce #xaf #xb0 #xfb #xef #x18 #x56 #x80
 #x13 #x23 #xf6 #x02 #x8b #xf4 #x4a #x65 #xa4 #x24 #xfa #x5d #x99 #x7e #x85 #x10
 #x83 #x4a #xab #x62 #xb7 #xe4 #xcd #xea #x0e #x6b #xfa #x9d #xe5 #x52 #xe3 #x4d
 #x3b #xc7 #x12 #x0c #x17 #x9e #x50 #xd7 #x31 #xfa #x3e #xbd #x28 #x31 #xa2 #xc5
 #x31 #x0c #xe6 #x57 #x31 #x30 #x6a #x24 #x63 #x95 #x8a #xfe #x4a #xd9 #x00 #x6f
 #x93 #xc0 #x35 #xc2 #x2e #x24 #xf2 #xdb #xa8 #xff #xb3 #x96 #xc9 #xad #xbd #x1e
 #xf7 #x1f #x6a #xf5 #x24 #xdd #x85 #xda #x57 #x66 #x05 #x7b #xc5 #x7a #xb2 #xc6
 #x99 #x8c #xd7 #x15 #x5a #x60 #xdd #x8e #xa3 #x64 #x5f #x02 #x03 #x01 #x00 #x01
 #x02 #x81 #x80 #x2e #xb7 #x7e #x8a #x33 #x40 #x39 #xc7 #x9b #x82 #x54 #xf7 #x8a
 #x81 #x35 #x5e #x95 #x1b #x52 #x96 #xe2 #xaf #xb4 #xcf #xc8 #x0a #xaf #x01 #x95
 #x14 #x11 #x21 #x7b #x7a #xbe #x35 #x8d #x8f #x6d #x9f #x08 #x26 #x05 #x18 #x0b
 #x0a #xcf #x8c #xd5 #xd8 #x0b #x11 #x10 #x9d #x28 #x19 #x23 #xa3 #x3a #xc3 #x0f
 #x3b #x30 #x89 #xf1 #x50 #x9a #xae #x8f #xae #x66 #x2b #x06 #x41 #x45 #xa8 #x2a
 #x0b #x27 #x07 #xa9 #x49 #x87 #x56 #x9c #xad #x60 #x6d #x9f #xdd #xe3 #x7a #xd1
 #xda #xc5 #xf3 #x48 #x66 #x67 #x82 #xc7 #x31 #xd0 #x2c #x4e #xec #xa6 #x7b #xc5
 #x49 #x30 #x10 #xd1 #x9d #xdf #xe9 #x4a #x5d #x5e #xc9 #xeb #xfb #xe0 #xcc #x9e
 #x17 #x9e #x41 #x02 #x41 #x00 #xd3 #x3f #xac #xd6 #x29 #x3e #xd8 #x0d #xc9 #x24
 #x59 #xed #x38 #x85 #xb8 #x47 #xc8 #x1b #x8d #x39 #x6d #x3a #xf0 #xd8 #x14 #x52
 #xfa #x19 #x74 #x17 #xb0 #x7a #xb4 #x7b #xe0 #xc2 #x71 #xea #x7c #xf6 #xf1 #x3a
 #x7e #x0d #xe3 #x6f #x73 #x41 #x2f #x7a #x24 #x31 #xb0 #x49 #xdb #x57 #xcb #xbe
 #x35 #x19 #x17 #xe7 #x2d #x31 #x02 #x41 #x00 #xc1 #xc9 #xc4 #x00 #x60 #x67 #xe6
 #x42 #x5d #xe9 #x2a #x54 #xd0 #x02 #xc0 #xf5 #x71 #x29 #x52 #xfe #xed #x1d #x30
 #x06 #x41 #x88 #x02 #x45 #xb7 #xd3 #x4f #x9f #x61 #x84 #xea #xba #x23 #x6d #x80
 #x8a #xf8 #xce #x08 #xd1 #xbd #x73 #xa1 #x3b #x10 #x1d #xa4 #x70 #xf5 #x46 #xb8
 #x2a #x58 #x52 #x1c #xbb #x5c #x12 #x06 #x8f #x02 #x40 #x2b #x99 #x5a #xbc #xa0
 #xaa #x9d #xc0 #xca #xa0 #xbc #x06 #x9f #xc1 #xc9 #x74 #xd7 #x32 #x08 #x85 #xaf
 #xab #x98 #x85 #xa0 #x3c #x37 #xee #x04 #xed #xd6 #xb8 #x9c #x83 #x6c #xb1 #xf4
 #xfc #xe6 #x69 #xb9 #x03 #xcf #x7c #x62 #x52 #x60 #x41 #x35 #xe1 #x49 #x93 #x0f
 #xc5 #x4e #x85 #xe2 #x41 #x11 #x88 #x6a #x4c #x86 #x21 #x02 #x40 #x24 #x87 #xa6
 #x3c #xf3 #xef #x62 #x06 #x6c #xb1 #x81 #x5b #x4f #x82 #xd5 #x60 #xef #x1d #xfd
 #x19 #x35 #x15 #x65 #x72 #x28 #x74 #x3d #x09 #x6b #x67 #x98 #x00 #xd1 #x5f #x3e
 #xe8 #x2b #xb9 #x7e #x9b #xb3 #xdf #x12 #xe6 #x86 #xb1 #xff #x58 #xa4 #xe7 #x11
 #x92 #x81 #x89 #xfd #x39 #x6e #x40 #xbc #x4d #xcd #x43 #x50 #x9d #x02 #x41 #x00
 #x89 #xb0 #xaf #xfc #x98 #x15 #xe9 #xc8 #xc7 #x71 #xd0 #xe9 #x45 #xff #x7c #x2b
 #x7a #xaa #x91 #x83 #xbf #x45 #x5f #x38 #xbc #x91 #xeb #x83 #x0d #x79 #xe8 #x31
 #xa3 #xb0 #xe1 #x37 #x11 #xdb #x16 #x42 #x06 #xce #x4e #x25 #x2a #x13 #x0a #x70
 #x72 #x83 #xad #xac #x19 #x6d #xd2 #x6d #x4b #xd8 #x9e #xda #x07 #x92 #xc1 #x54
 )))
  (test-equal pv (export-private-key (import-private-key RSA pv))))


;; EC arithmetic
;; EC point test (from bouncycastle ECPointTest.java) start

;; Copyright (c) 2000-2016 The Legion of the Bouncy Castle Inc.
;; (http://www.bouncycastle.org)
;; Permission is hereby granted, free of charge, to any person
;; obtaining a copy of this software and associated documentation
;; files (the "Software"), to deal in the Software without
;; restriction, including without limitation the rights to use, copy,
;; modify, merge, publish,;; distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software
;; is furnished to do so, subject to the following conditions:
;;
;; The above copyright notice and this permission notice shall be
;; included in all copies or substantial portions of the Software.
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
;; NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
;; BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
;; ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
;; CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

;; The original code was written in Java. Translated into Scheme by
;; Takashi Kato
(let ((prng (secure-random RC4)))
  (define-record-type fp
    (fields q a b n h curve point-source p)
    (protocol (lambda (p)
		(lambda ()
		  (let* ((ps #(5 22 16 27 13 6 14 6))
			 (len (div (vector-length ps) 2))
			 (field (make-ec-field-fp 29)))
		    (do ((i 0 (+ i 1)) (p* (make-vector len)))
			((>= i len)
			 (p 29 4 20 38 1
			    (make-elliptic-curve field 4 20) ps p*))
		      (vector-set! p* i
		       (make-ec-point (vector-ref ps (* i 2))
				      (vector-ref ps (+ (* i 2) 1))))))))))

  (define-record-type f2m
    (fields m k1 a-tbp b-tbp n h curve point-source p)
    (protocol (lambda (p)
		(lambda ()
		  (let* ((ps #(#b0010 #b1111 #b1100 #b1100
			       #b0001 #b0001 #b1011 #b0010))
			 (len (div (vector-length ps) 2))
			 (field (make-ec-field-f2m 4 1 0 0)))
		    (do ((i 0 (+ i 1)) (p* (make-vector len)))
			((>= i len)
			 (p 4 1 #b1000 #b1101 23 1
			    (make-elliptic-curve field #b1000 #b1101) ps p*))
		      (vector-set! p* i
		       (make-ec-point (vector-ref ps (* i 2))
				      (vector-ref ps (+ (* i 2) 1))))))))))

  (define (assert-points-equals msg a b)
    (test-equal msg a b)
    (test-equal msg b a))
  (define (test-add)
    (define (impl-test-add curve p)
      (assert-points-equals "p0 plus p1 does not equal p2" (vector-ref p 2)
			    (ec-point-add curve (vector-ref p 0)
					  (vector-ref p 1)))
      (assert-points-equals "p1 plus p0 does not equal p2" (vector-ref p 2)
			    (ec-point-add curve (vector-ref p 1)
					  (vector-ref p 0)))
      (do ((len (vector-length p)) (i 0 (+ i 1)))
	  ((= i len))
	(assert-points-equals "Adding infinity field"
			      (vector-ref p i)
			      (ec-point-add curve (vector-ref p i)
					    ec-infinity-point))
	(assert-points-equals "Adding to infinity field"
			      (vector-ref p i)
			      (ec-point-add curve ec-infinity-point
					    (vector-ref p i)))))
    (define fp (make-fp))
    (define f2m (make-f2m))
    (impl-test-add (fp-curve fp) (fp-p fp))
    (impl-test-add (f2m-curve f2m) (f2m-p f2m)))

  (define (test-twice)
    (define (impl-test-twice curve p)
      (assert-points-equals "Twice incorrect" (vector-ref p 3)
			    (ec-point-twice curve (vector-ref p 0)))
      (assert-points-equals "Add same point incorrect" (vector-ref p 3)
			    (ec-point-add curve (vector-ref p 0)
					  (vector-ref p 0))))
    (define fp (make-fp))
    (define f2m (make-f2m))
    (impl-test-twice (fp-curve fp) (fp-p fp))
    (impl-test-twice (f2m-curve f2m) (f2m-p f2m)))

  (define (test-all-points)
    (define (impl-test-all-points curve p)
      (let loop ((i 1) (adder ec-infinity-point))
	(let ((adder (ec-point-add curve adder p))
	      (multiplier (ec-point-mul curve p i)))
	  (assert-points-equals
	   (format "Results of add and mul are inconsistent ~a" i)
	   adder multiplier)
	  (unless (ec-point-infinity? adder) (loop (+ i 1) adder)))))
    (define fp (make-fp))
    (define f2m (make-f2m))
    (vector-for-each (lambda (p) (impl-test-all-points (fp-curve fp) p))
		     (fp-p fp))
    (vector-for-each (lambda (p) (impl-test-all-points (f2m-curve f2m) p))
		     (f2m-p f2m)))
  
  (test-add)
  (test-twice)
  (test-all-points)
  )

;; from bouncycastle end

;; from the example calculation of the followings
;;   https://www.nsa.gov/ia/_files/nist-routines.pdf (N/A)
;;   http://koclab.cs.ucsb.edu/teaching/cren/docs/w02/nist-routines.pdf

;; P-192
(test-assert (ec-parameter? NIST-P-192))
(define-syntax test-ec
  (syntax-rules ()
    ((_ curve? S? T? Radd? Rsub? 2R? d? Rmul? e? Raddmull?)
     (let ((S S?)
	   (T T?)
	   (curve (ec-parameter-curve curve?)))
       (test-equal (format "EC add ~a" 'curve?) Radd? (ec-point-add curve S T))
       (test-equal (format "EC sub ~a" 'curve?) Rsub? (ec-point-sub curve S T))
       (test-equal (format "EC twice ~a" 'curve?) 2R? (ec-point-twice curve S))
       (test-equal (format "EC multiply ~a" 'curve?) Rmul?
		   (ec-point-mul curve S d?))
       (test-equal (format "EC multiply ~a (2)" 'curve?) Raddmull? 
		   (ec-point-add curve Rmul? (ec-point-mul curve T e?)))))))

(test-ec NIST-P-192
	 (make-ec-point #xD458E7D127AE671B0C330266D246769353A012073E97ACF8
			#x325930500D851F336BDDC050CF7FB11B5673A1645086DF3B)
	 (make-ec-point #xF22C4395213E9EBE67DDECDD87FDBD01BE16FB059B9753A4
			#x264424096AF2B3597796DB48F8DFB41FA9CECC97691A9C79)
	 (make-ec-point #x48E1E4096B9B8E5CA9D0F1F077B8ABF58E843894DE4D0290
			#x408FA77C797CD7DBFB16AA48A3648D3D63C94117D7B6AA4B)
	 (make-ec-point #xFC9683CC5ABFB4FE0CC8CC3BC9F61EABC4688F11E9F64A2E
			#x093e31d00fb78269732b1bd2a73c23cdd31745d0523d816b)
	 (make-ec-point #x30C5BC6B8C7DA25354B373DC14DD8A0EBA42D25A3F6E6962
			#x0DDE14BC4249A721C407AEDBF011E2DDBBCB2968C9D889CF)
	 #xA78A236D60BAEC0C5DD41B33A542463A8255391AF64C74EE
	 (make-ec-point #x1FAEE4205A4F669D2D0A8F25E3BCEC9A62A6952965BF6D31
			#x5FF2CDFA508A2581892367087C696F179E7A4D7E8260FB06)
	 #xC4BE3D53EC3089E71E4DE8CEAB7CCE889BC393CD85B972BC
	 (make-ec-point #x019F64EED8FA9B72B7DFEA82C17C9BFA60ECB9E1778B5BDE
			#x16590C5FCD8655FA4CED33FB800E2A7E3C61F35D83503644))

;; P-224
(test-assert (ec-parameter? NIST-P-224))
(test-ec NIST-P-224
	 (make-ec-point
	  #x6eca814ba59a930843dc814edd6c97da95518df3c6fdf16e9a10bb5b
	  #xef4b497f0963bc8b6aec0ca0f259b89cd80994147e05dc6b64d7bf22)
	 (make-ec-point
	  #xb72b25aea5cb03fb88d7e842002969648e6ef23c5d39ac903826bd6d
	  #xc42a8a4d34984f0b71b5b4091af7dceb33ea729c1a2dc8b434f10c34)
	 (make-ec-point
	  #x236f26d9e84c2f7d776b107bd478ee0a6d2bcfcaa2162afae8d2fd15
	  #xe53cc0a7904ce6c3746f6a97471297a0b7d5cdf8d536ae25bb0fda70)
	 (make-ec-point
	  #xdb4112bcc8f34d4f0b36047bca1054f3615413852a7931335210b332
	  #x90c6e8304da4813878c1540b2396f411facf787a520a0ffb55a8d961)
	 (make-ec-point
	  #xa9c96f2117dee0f27ca56850ebb46efad8ee26852f165e29cb5cdfc7
	  #xadf18c84cf77ced4d76d4930417d9579207840bf49bfbf5837dfdd7d)
	 #xa78ccc30eaca0fcc8e36b2dd6fbb03df06d37f52711e6363aaf1d73b
	 (make-ec-point
	  #x96a7625e92a8d72bff1113abdb95777e736a14c6fdaacc392702bca4
	  #x0f8e5702942a3c5e13cd2fd5801915258b43dfadc70d15dbada3ed10)
	 #x54d549ffc08c96592519d73e71e8e0703fc8177fa88aa77a6ed35736
	 (make-ec-point
	  #xdbfe2958c7b2cda1302a67ea3ffd94c918c5b350ab838d52e288c83e
	  #x2f521b83ac3b0549ff4895abcc7f0c5a861aacb87acbc5b8147bb18b))

(test-assert (ec-parameter? NIST-P-256))
(test-ec NIST-P-256
	 (make-ec-point
	  #xde2444bebc8d36e682edd27e0f271508617519b3221a8fa0b77cab3989da97c9
	  #xc093ae7ff36e5380fc01a5aad1e66659702de80f53cec576b6350b243042a256)
	 (make-ec-point
	  #x55a8b00f8da1d44e62f6b3b25316212e39540dc861c89575bb8cf92e35e0986b
	  #x5421c3209c2d6c704835d82ac4c3dd90f61a8a52598b9e7ab656e9d8c8b24316)
	 (make-ec-point
	  #x72b13dd4354b6b81745195e98cc5ba6970349191ac476bd4553cf35a545a067e
	  #x8d585cbb2e1327d75241a8a122d7620dc33b13315aa5c9d46d013011744ac264)
	 (make-ec-point
	  #xc09ce680b251bb1d2aad1dbf6129deab837419f8f1c73ea13e7dc64ad6be6021
	  #x1a815bf700bd88336b2f9bad4edab1723414a022fdf6c3f4ce30675fb1975ef3)
	 (make-ec-point
	  #x7669e6901606ee3ba1a8eef1e0024c33df6c22f3b17481b82a860ffcdb6127b0
	  #xfa878162187a54f6c39f6ee0072f33de389ef3eecd03023de10ca2c1db61d0c7)
	 #xc51e4753afdec1e6b6c6a5b992f43f8dd0c7a8933072708b6522468b2ffb06fd
	 (make-ec-point
	  #x51d08d5f2d4278882946d88d83c97d11e62becc3cfc18bedacc89ba34eeca03f
	  #x75ee68eb8bf626aa5b673ab51f6e744e06f8fcf8a6c0cf3035beca956a7b41d5)
	 #xd37f628ece72a462f0145cbefe3f0b355ee8332d37acdd83a358016aea029db7
	 (make-ec-point
	  #xd867b4679221009234939221b8046245efcf58413daacbeff857b8588341f6b8
	  #xf2504055c03cede12d22720dad69c745106b6607ec7e50dd35d54bd80f615275))

(define (test-ec-point-encode&decode curve x y)
  (let* ((ep (make-ec-point x y))
	 (size (div (+ (ec-field-size (elliptic-curve-field curve)) 7) 8))
	 (bv (bytevector-append #vu8(#x04)
				(integer->bytevector x size)
				(integer->bytevector y size))))
    (test-equal "EC point decode" ep (decode-ec-point curve bv))
    (test-equal "EC point encode" bv (encode-ec-point curve ep))))

(test-ec-point-encode&decode
 (make-elliptic-curve (make-ec-field-f2m 1 0 0 0) 0 0)
 1 2)

(test-ec-point-encode&decode (ec-parameter-curve NIST-P-192)
			     #x64210519E59C80E70FA7E9AB72243049FEB8DEECC146B9B1
			     #x188DA80EB03090F67CBF20EB43A18800F4FF0AFD82FF1012)


;; call #98 restoring value properly
(let ()
  (define keypair (generate-key-pair RSA))
  
  (define msg #vu8(0 0 0 1))
  ;; Bouncy Castle compatible behaviour...
  (let ((enc-ci (cipher RSA (keypair-public keypair) :padding #f))
	(dec-ci (cipher RSA (keypair-private keypair) :padding #f)))
    (let ((r (decrypt dec-ci (encrypt enc-ci msg))))
      (test-equal "restoring (fail)" #vu8(1) r)))

  (let ((enc-ci (cipher RSA (keypair-public keypair)))
	(dec-ci (cipher RSA (keypair-private keypair))))
    (let ((r (decrypt dec-ci (encrypt enc-ci msg))))
      (test-equal "restoring (success)" msg r))))


;; OAEP padding
(let ()
  ;; the cipher text is generated by Bouncy Castle
  (define cipher-text (integer->bytevector #x9990ee109c208410c4d59ae4fdb933c84ca34d0e418aa7b2d5abe4b8f120377db722547c331b40d42d7eefdbc3c37cf7ed9b887093acf656eaf6a92ae30a3094))
  (define public-rsa-key
    (generate-public-key RSA
			 #xc53c6270dca84de0b0683d1e1089a18694ea0b52b1ceeac83e2c9b29a964e66ae97268f1267364b336ce300f271a5161c98203152009fa4143e46c45fee4a90b
			 #x10001))
  (define private-rsa-key 
    (generate-private-key RSA
			  #xc53c6270dca84de0b0683d1e1089a18694ea0b52b1ceeac83e2c9b29a964e66ae97268f1267364b336ce300f271a5161c98203152009fa4143e46c45fee4a90b
			  #x5edc4bfc3c2436507a87a7dd6dd6c3f91665fa4c2b78793315b41e6c4b2c5c24f6b002f9ac814b8720b6c450236b1cb4f6122add9ea1cc16ca42f527684a2b1))
  (let ((enc-ci (cipher RSA public-rsa-key :padding (rsa-oaep-padding SHA-1)))
	(dec-ci (cipher RSA private-rsa-key :padding (rsa-oaep-padding SHA-1))))
    
    (test-equal "OAEP padding decrypt" valid-rsa-message
		(decrypt dec-ci cipher-text))
    
    ;; encryption generates different cipher text each time
    ;; so we can't compare it directly. encrypt -> decrypt should
    ;; return the plain text.
    (test-equal "OAEP padding encrypt&decrypt" valid-rsa-message
		(decrypt dec-ci (encrypt enc-ci valid-rsa-message)))))

;; input size check
(let ()
  (let ((enc-ci (cipher RSA public-rsa-key :padding (rsa-oaep-padding SHA-1)))
	(dec-ci (cipher RSA private-rsa-key :padding (rsa-oaep-padding SHA-1))))
    
    (test-error "OAEP padding decrypt (input error)" condition?
		(decrypt dec-ci cipher-text))
    
    (test-error "OAEP padding encrypt&decrypt (input error)" condition?
		(encrypt enc-ci valid-rsa-message))))

;; call #130
(let ()
  (define priv
    (generate-private-key RSA 
     #xb14314da2ddd1f811734cc8bf868c34ff94519f463da28769889674fb88c1756602fc21d1c2961b4745b8e1c82bdc1748e554dd6d1bc25c63023d25cff0692c09d74c88882bd9afecf3887d050ca4dd2e59ee94b5085e262ac66dc864100cc6879449fa2b4ff9aebe4776c6e663e567c9db71e89686c7c5662fb31bcfc333755
     #x693ca61891ba0186263cd66312eb3f692f57f2fcc07b38229094a29d15b735f3b5cf24b31b9105cc9877f27ac2b3dd32517e1b6439c835b4dfc7a4904967a19f736d1b5d13c10d3de61fc17c736e71cb1145a8312942d914cc66c80d974af7602928193082dc77326bfdf8ab282469eae26e8e445b6892435813fed417d033d1
     :public-exponent #x10001
     :p #xc82733b2c4a6811bd8ff7fd77cbe889d7dfd83aeed6d86666dcb84ccb7a5a9f717b967c93190baf46e0fcf765d8fcfdd73f2d372bcfa8333feab1a151bef0ca7
     :q #xe2b8c8da2b7b726dcbc95688056d3ef96e5cfc4ac38d68981e86fed84129235eaa42970a264fd4f24f36c2fddf0c7826b37b62f0b51915aa059f8e1d5ee8afa3))
  (define pub
    (generate-public-key RSA
     #xb14314da2ddd1f811734cc8bf868c34ff94519f463da28769889674fb88c1756602fc21d1c2961b4745b8e1c82bdc1748e554dd6d1bc25c63023d25cff0692c09d74c88882bd9afecf3887d050ca4dd2e59ee94b5085e262ac66dc864100cc6879449fa2b4ff9aebe4776c6e663e567c9db71e89686c7c5662fb31bcfc333755
     #x10001))
  (define msg #vu8(0 0 0 1))
  ;; don't use secure random to reproduce this issue
  (define prng (pseudo-random RC4))

  ;; the issue is that fixing up byte was also 0 thus de-padding
  ;; procedure mis calculate the position.
  ;; this happend with above key (probaby doesn't matter) with
  ;; encryption after 27 times
  (do ((i 0 (+ i 1)))
      ((= i 28))
    (when (= i 27)
      (let ((enc-ci (cipher RSA priv :prng prng))
	    (dec-ci (cipher RSA pub :prng prng)))
	(test-equal "restoring (success)" 
		    msg (decrypt dec-ci (encrypt enc-ci msg)))))))


;; we have now updateAAD, tag and tagsize slot so test it
(define-class <dummy-spi> (<cipher-spi>)
  ((aad-value :reader dummy-aad)
   (tag-value :reader dummy-tag)))
(define-method initialize ((spi <dummy-spi>) initargs)
  (call-next-method)
  (slot-set! spi 'update-aad (lambda (data) 
			       (slot-set! spi 'aad-value data)
			       'ok))
  (slot-set! spi 'encrypt (lambda (pt key)
			    (slot-set! spi 'tag-value #vu8(1 2 3 4))))
  (slot-set! spi 'tag (lambda (dst) 
			(bytevector-copy! (dummy-tag spi) 0
					  dst 0
					  4)))
  (slot-set! spi 'tagsize 4))
(let* ((spi (make <dummy-spi>))
       (cipher (make-cipher spi #f)))
  ;; it's not documented but returning value is the result of
  ;; underlying procedure of update-aad
  (test-equal "dummy update AAD" 'ok (cipher-update-aad! cipher #vu8(1 2 3 4)))
  (test-equal "dummy AAD" #vu8(1 2 3 4) (dummy-aad spi))
  (cipher-encrypt cipher #vu8(5 6 7 8))
  (test-equal "dummy tag" #vu8(1 2 3 4) (cipher-tag cipher)))

;; mode
(test-assert "composite-parameter" 
	     (mode-parameter? (make-composite-parameter
			       (make-mode-name-parameter MODE_ECB))))
(test-error "composite-parameter (error)" (make-composite-parameter #f))

(test-assert "iv-parameter? (1)"
	     (iv-parameter?  (make-iv-parameter #vu8())))

(test-assert "iv-parameter? (2)"
	     (iv-parameter? (make-composite-parameter 
			     (make-iv-parameter #vu8()))))

(test-equal "parameter-iv (2)" #vu8()
	    (parameter-iv (make-composite-parameter 
			    (make-iv-parameter #vu8()))))


;; GCM
(test-assert "MODE_GCM" MODE_GCM)
(test-equal "GCM tag size" 16
	    (cipher-max-tag-size
	     (cipher AES
		     ;; we can use DESede key for AES
		     (generate-secret-key AES des3-key-raw)
		     :iv #vu8(1 2 3 4 5 6 7 8) :mode MODE_GCM :padder #f)))

(define (test-gcm-decryption count key iv ct aad tag pt :key (invalid-tag #f))
  (let* ((skey (generate-secret-key AES key))
	 (parameter (make-composite-parameter
		     (make-mode-name-parameter MODE_GCM)
		     (make-iv-parameter iv)
		     (make-padding-parameter no-padder)))
	 (cipher (make-cipher AES skey :mode-parameter parameter))
	 (enc-cipher (make-cipher AES skey :mode-parameter parameter)))
    (cipher-update-aad! cipher aad)
    (if invalid-tag
	(test-error "Invalid GCM tag to decrypt"
		    (cipher-decrypt/tag cipher ct tag))
	(let-values (((decrypted this-tag) (cipher-decrypt/tag cipher ct tag)))
	  (test-equal (format "GCM decryption (~a)" count) pt decrypted)
	  (test-equal (format "GCM decryption tag length (~a)" count)
		      (bytevector-length tag) (bytevector-length this-tag))
	  (test-equal (format "GCM decryption tag (~a)" count)
		      tag this-tag)
	  (cipher-update-aad! enc-cipher aad)
	  (let-values (((encrypted this-tag)
			(cipher-encrypt/tag enc-cipher pt 
					    :tag-size (bytevector-length tag))))
	    (test-equal (format "GCM encrypted value (~a)" count) ct encrypted)
	    (test-equal (format "GCM encrypted tag (~a)" count) tag this-tag)))
	)))

;; from gcmDecrypt128.rsp
#|
Count = 0
Key = cf063a34d4a9a76c2c86787d3f96db71
IV = 113b9785971864c83b01c787
CT = 
AAD = 
Tag = 72ac8493e3a5228b5d130a69d2510e42
PT = 
|#
(test-gcm-decryption 0 
		     (integer->bytevector #xcf063a34d4a9a76c2c86787d3f96db71)
		     (integer->bytevector #x113b9785971864c83b01c787)
		     #vu8()
		     #vu8()
		     (integer->bytevector #x72ac8493e3a5228b5d130a69d2510e42)
		     #vu8())
#|
Count = 1
Key = a49a5e26a2f8cb63d05546c2a62f5343
IV = 907763b19b9b4ab6bd4f0281
CT = 
AAD = 
Tag = a2be08210d8c470a8df6e8fbd79ec5cf
FAIL
|#
(test-gcm-decryption 1
		     (integer->bytevector #xa49a5e26a2f8cb63d05546c2a62f5343)
		     (integer->bytevector #x907763b19b9b4ab6bd4f0281)
		     #vu8()
		     #vu8()
		     (integer->bytevector #xa2be08210d8c470a8df6e8fbd79ec5cf)
		     #vu8()
		     :invalid-tag #t)
#|
Count = 2
Key = 2ad0bf5aeb47a0c1a98da3dfdab4fded
IV = 25f1b6091ee7040fea4ba854
CT = 
AAD = 
Tag = d7963d240317653e01cf5abe5d0966ae
PT = 
|#
(test-gcm-decryption 2
		     (integer->bytevector #x2ad0bf5aeb47a0c1a98da3dfdab4fded)
		     (integer->bytevector #x25f1b6091ee7040fea4ba854)
		     #vu8()
		     #vu8()
		     (integer->bytevector #xd7963d240317653e01cf5abe5d0966ae)
		     #vu8())
;; we don't do all test vectors...
;; keylen = 128
;; ivlen  = 1024
#|
Count = 1
Key = ea254e519268b0e3297dd96d98b5948a
IV = 0e14a468989d3965c48adf7f52b68ac4fecd1ba7f5cd1748d63f0cd34ffe8c6d3fc89630f3d08967c983f4c22db51debf7c7d0d6ff3a5827d46b39087b075dc65e2c692fbaab995b8ab0d8f210f1092c0d36abec0f2e62361a617abd8ad77b650669b015c358903e224dbd9ef113652c0257f30cd5254e310a0d00df145e8dfa
CT = 35337fd8497aefbfad20fff19a02ee11
AAD = 
Tag = decdcfc10f998a5a1a7be1344b81
PT = 42fc4fc1da542a45a7c96461179c315a
|#
(test-gcm-decryption 3
		     (integer->bytevector #xea254e519268b0e3297dd96d98b5948a)
		     (integer->bytevector #x0e14a468989d3965c48adf7f52b68ac4fecd1ba7f5cd1748d63f0cd34ffe8c6d3fc89630f3d08967c983f4c22db51debf7c7d0d6ff3a5827d46b39087b075dc65e2c692fbaab995b8ab0d8f210f1092c0d36abec0f2e62361a617abd8ad77b650669b015c358903e224dbd9ef113652c0257f30cd5254e310a0d00df145e8dfa)
		     (integer->bytevector #x35337fd8497aefbfad20fff19a02ee11)
		     #vu8()
		     (integer->bytevector #xdecdcfc10f998a5a1a7be1344b81)
		     (integer->bytevector #x42fc4fc1da542a45a7c96461179c315a))

#|
Count = 2
Key = 09eabe1718525df9b6b268bf4526bc3c
IV = 9798d99269034276321c6a7dc1fb57d8fb0b1fb4b4bb61f5471a834c6fcba82d84646541ee61ca96f8441aed005d783a1551eb5f6d50253f353dfedd3c9925d69b66b9c9792b5d6b4aa1c132a606ca24c45f9a9066add1522b457edff8ca711f40f8bcb6b0de9b2c9887e70b7c92ef12e18be35acd9685abfdb762664878868d
CT = da051dd1f5c25188a7fa327438daf328
AAD = 
Tag = dac0b5a3b94584462d0fd2d17395
PT = b36bfd4e8b182eae3e930de978be4be3
|#
(test-gcm-decryption 6
		     (integer->bytevector #x09eabe1718525df9b6b268bf4526bc3c)
		     (integer->bytevector #x9798d99269034276321c6a7dc1fb57d8fb0b1fb4b4bb61f5471a834c6fcba82d84646541ee61ca96f8441aed005d783a1551eb5f6d50253f353dfedd3c9925d69b66b9c9792b5d6b4aa1c132a606ca24c45f9a9066add1522b457edff8ca711f40f8bcb6b0de9b2c9887e70b7c92ef12e18be35acd9685abfdb762664878868d)
		     (integer->bytevector #xda051dd1f5c25188a7fa327438daf328)
		     #vu8()
		     (integer->bytevector #xdac0b5a3b94584462d0fd2d17395)
		     (integer->bytevector #xb36bfd4e8b182eae3e930de978be4be3))
;; with AAD
#|
Count = 4
Key = 12fe7dc72949c5175db64c0bf92944c7
IV = 8a9ebcb4ea47249a87dc2751aaa0114ba44441be49815cc05a2d42925f356e1e34ae5b30092d3cd1af79153872c6ad8e64f1d2241037fe18758ea696fa52e33ceabf4f4f6f4a77f32c4c3fd36fdd692d597978684feb0fc66d19d00906c6c6835fe6c4b8d4573c0eece4f1de85e0f5ae105485f6b2db4c821980a28d41f2f155
CT = dd192ba4d1d9967fb9d8fd559307b1de
AAD = a62d96ac6b4acdae784e4748cfe837fc
Tag = 4528b211ba29af8f06d4d1388fbc549a
PT = 498255c2c186a7792dfd1a613c0b434d
|#
(test-gcm-decryption 4
		     (integer->bytevector #x12fe7dc72949c5175db64c0bf92944c7)
		     (integer->bytevector #x8a9ebcb4ea47249a87dc2751aaa0114ba44441be49815cc05a2d42925f356e1e34ae5b30092d3cd1af79153872c6ad8e64f1d2241037fe18758ea696fa52e33ceabf4f4f6f4a77f32c4c3fd36fdd692d597978684feb0fc66d19d00906c6c6835fe6c4b8d4573c0eece4f1de85e0f5ae105485f6b2db4c821980a28d41f2f155)
		     (integer->bytevector #xdd192ba4d1d9967fb9d8fd559307b1de)
		     (integer->bytevector #xa62d96ac6b4acdae784e4748cfe837fc)
		     (integer->bytevector #x4528b211ba29af8f06d4d1388fbc549a)
		     (integer->bytevector #x498255c2c186a7792dfd1a613c0b434d))

#|
[Keylen = 128]
[IVlen = 1024]
[PTlen = 0]
[AADlen = 0]
[Taglen = 128]
Count = 2
Key = 6e3a3b7b1cc98c1fa4754a7d63547427
IV = 0c87956a3ed77f63a98a97b7e6fb58bf6a4426977c3a0a6409b79e1c536229e229bb69eb376563b168c1823dc2e3d9988a0f843b4d9b872f9119bbc00e3146605c4b1ca715b9e272e59298905ad1abd3b0981969028f94441223ff927419c17156d0110f165539a883ece07d6a81d00d5aa52fa443e97ee05e79a7183de46176
CT = 
AAD = 
Tag = 8dcd0426704986f4fe7257288466f2b5
PT = 
|#
(test-gcm-decryption 5
		     (integer->bytevector #x6e3a3b7b1cc98c1fa4754a7d63547427)
		     (integer->bytevector #x0c87956a3ed77f63a98a97b7e6fb58bf6a4426977c3a0a6409b79e1c536229e229bb69eb376563b168c1823dc2e3d9988a0f843b4d9b872f9119bbc00e3146605c4b1ca715b9e272e59298905ad1abd3b0981969028f94441223ff927419c17156d0110f165539a883ece07d6a81d00d5aa52fa443e97ee05e79a7183de46176)
		     #vu8()
		     #vu8()
		     (integer->bytevector #x8dcd0426704986f4fe7257288466f2b5)
		     #vu8())

#|
Count = 0
Key = e98b72a9881a84ca6b76e0f43e68647a
IV = 8b23299fde174053f3d652ba
CT = 5a3c1cf1985dbb8bed818036fdd5ab42
AAD = 
Tag = 23c7ab0f952b7091cd324835043b5eb5
PT = 28286a321293253c3e0aa2704a278032
|#
(test-gcm-decryption 7
		     (integer->bytevector #xe98b72a9881a84ca6b76e0f43e68647a)
		     (integer->bytevector #x8b23299fde174053f3d652ba)
		     (integer->bytevector #x5a3c1cf1985dbb8bed818036fdd5ab42)
		     #vu8()
		     (integer->bytevector #x23c7ab0f952b7091cd324835043b5eb5)
		     (integer->bytevector #x28286a321293253c3e0aa2704a278032))

(define (test-gcm-encryption count key iv pt aad ct tag)
  (let* ((skey (generate-secret-key AES key))
	 (cipher (make-cipher AES skey
			      :mode-parameter (make-composite-parameter
					       (make-mode-name-parameter
						MODE_GCM)
					       (make-iv-parameter iv)
					       (make-padding-parameter no-padder)))))
    (cipher-update-aad! cipher aad)
    (let-values (((encrypted this-tag)
		  (cipher-encrypt/tag cipher pt 
				      :tag-size (bytevector-length tag))))
      (test-equal (format "GCM encryption (~a)" count) ct encrypted)
      (test-equal (format "GCM encryption tag length (~a)" count)
		  (bytevector-length tag) (bytevector-length this-tag))
      (let ((bv (make-bytevector (bytevector-length tag))))
	(test-equal (format "GCM encryption cipher-tag! (~a)" count)
		    (bytevector-length tag) (cipher-tag! cipher bv)))
      (test-equal (format "GCM encryption tag (~a)" count) tag this-tag))))
#|
Count = 0
Key = 11754cd72aec309bf52f7687212e8957
IV = 3c819d9a9bed087615030b65
PT = 
AAD = 
CT = 
Tag = 250327c674aaf477aef2675748cf6971
|#
(test-gcm-encryption 0 
		     (integer->bytevector #x11754cd72aec309bf52f7687212e8957)
		     (integer->bytevector #x3c819d9a9bed087615030b65)
		     #vu8()
		     #vu8()
		     #vu8()
		     (integer->bytevector #x250327c674aaf477aef2675748cf6971))
#|
Count = 1
Key = ca47248ac0b6f8372a97ac43508308ed
IV = ffd2b598feabc9019262d2be
PT = 
AAD = 
CT = 
Tag = 60d20404af527d248d893ae495707d1a
|#
(test-gcm-encryption 1
		     (integer->bytevector #xca47248ac0b6f8372a97ac43508308ed)
		     (integer->bytevector #xffd2b598feabc9019262d2be)
		     #vu8()
		     #vu8()
		     #vu8()
		     (integer->bytevector #x60d20404af527d248d893ae495707d1a))
#|
Count = 3
Key = d19cfcba59b9a338c46c2408e3a0412b
IV = ac
PT = 41258dfc23f799affb2720f63316394021a6d183e9f37b9973ef79df92896fea0a288e97d6b63740597097fff27891a3069400
AAD = c3dedc50a6a11924d095ad22644a09b6047630b46e2a3627ed1d418edeaaaeb08603f1e21d11919d7a3d57ef5134be9f
CT = 3072def0c3fb47ff4fc124ab30e76f5903e235b2612148aae67181ef62a736ee6fc147cc703f76dee557eba84349f1c5b158be
Tag = 267a3ba3670ff076
|#
(test-gcm-encryption 3
		     (integer->bytevector #xd19cfcba59b9a338c46c2408e3a0412b)
		     (integer->bytevector #xac)
		     (integer->bytevector #x41258dfc23f799affb2720f63316394021a6d183e9f37b9973ef79df92896fea0a288e97d6b63740597097fff27891a3069400)
		     (integer->bytevector #xc3dedc50a6a11924d095ad22644a09b6047630b46e2a3627ed1d418edeaaaeb08603f1e21d11919d7a3d57ef5134be9f)
		     (integer->bytevector #x3072def0c3fb47ff4fc124ab30e76f5903e235b2612148aae67181ef62a736ee6fc147cc703f76dee557eba84349f1c5b158be)
		     (integer->bytevector #x267a3ba3670ff076))

;; RFC3686
(define (test-rfc3686 i vec)
  (let ((key (vector-ref vec 0))
	(iv (vector-ref vec 1))
	(nonce (vector-ref vec 2))
	(plain (vector-ref vec 3))
	(cipher (vector-ref vec 4)))
    (define param (make-composite-parameter
		   (make-mode-name-parameter MODE_CTR)
		   (make-rfc3686-parameter iv nonce)))
    (define ec (make-cipher AES (generate-secret-key AES key)
			    :mode-parameter param))
    (define dc (make-cipher AES (generate-secret-key AES key)
			    :mode-parameter param))
    (test-equal (format "AES-CTR enc (~a)" i) cipher (cipher-encrypt ec plain))
    (test-equal (format "AES-CTR dec (~a)" i) plain (cipher-decrypt dc cipher))))

(define test-rfc3686-vector
  '(;; key iv nonce plain cipher
    #(#vu8(#xAE #x68 #x52 #xF8 #x12 #x10 #x67 #xCC #x4B #xF7 #xA5 #x76 #x55 #x77 #xF3 #x9E)
      #vu8(#x00 #x00 #x00 #x00 #x00 #x00 #x00 #x00)
      #vu8(#x00 #x00 #x00 #x30)
      #vu8(#x53 #x69 #x6E #x67 #x6C #x65 #x20 #x62 #x6C #x6F #x63 #x6B #x20 #x6D #x73 #x67)
      #vu8(#xE4 #x09 #x5D #x4F #xB7 #xA7 #xB3 #x79 #x2D #x61 #x75 #xA3 #x26 #x13 #x11 #xB8))
    #(#vu8(#x7E #x24 #x06 #x78 #x17 #xFA #xE0 #xD7 #x43 #xD6 #xCE #x1F #x32 #x53 #x91 #x63)
      #vu8(#xC0 #x54 #x3B #x59 #xDA #x48 #xD9 #x0B)
      #vu8(#x00 #x6C #xB6 #xDB)
      #vu8(#x00 #x01 #x02 #x03 #x04 #x05 #x06 #x07 #x08 #x09 #x0A #x0B #x0C #x0D #x0E #x0F
           #x10 #x11 #x12 #x13 #x14 #x15 #x16 #x17 #x18 #x19 #x1A #x1B #x1C #x1D #x1E #x1F)
      #vu8(#x51 #x04 #xA1 #x06 #x16 #x8A #x72 #xD9 #x79 #x0D #x41 #xEE #x8E #xDA #xD3 #x88
           #xEB #x2E #x1E #xFC #x46 #xDA #x57 #xC8 #xFC #xE6 #x30 #xDF #x91 #x41 #xBE #x28))
    #(#vu8(#x76 #x91 #xBE #x03 #x5E #x50 #x20 #xA8 #xAC #x6E #x61 #x85 #x29 #xF9 #xA0 #xDC)
      #vu8(#x27 #x77 #x7F #x3F #x4A #x17 #x86 #xF0)
      #vu8(#x00 #xE0 #x01 #x7B)
      #vu8(#x00 #x01 #x02 #x03 #x04 #x05 #x06 #x07 #x08 #x09 #x0A #x0B #x0C #x0D #x0E #x0F
           #x10 #x11 #x12 #x13 #x14 #x15 #x16 #x17 #x18 #x19 #x1A #x1B #x1C #x1D #x1E #x1F
	   #x20 #x21 #x22 #x23)
      #vu8(#xC1 #xCF #x48 #xA8 #x9F #x2F #xFD #xD9 #xCF #x46 #x52 #xE9 #xEF #xDB #x72 #xD7
           #x45 #x40 #xA4 #x2B #xDE #x6D #x78 #x36 #xD5 #x9A #x5C #xEA #xAE #xF3 #x10 #x53
	   #x25 #xB2 #x07 #x2F))
    #(#vu8(#x16 #xAF #x5B #x14 #x5F #xC9 #xF5 #x79 #xC1 #x75 #xF9 #x3E #x3B #xFB #x0E #xED
           #x86 #x3D #x06 #xCC #xFD #xB7 #x85 #x15)
      #vu8(#x36 #x73 #x3C #x14 #x7D #x6D #x93 #xCB)
      #vu8(#x00 #x00 #x00 #x48)
      #vu8(#x53 #x69 #x6E #x67 #x6C #x65 #x20 #x62 #x6C #x6F #x63 #x6B #x20 #x6D #x73 #x67)
      #vu8(#x4B #x55 #x38 #x4F #xE2 #x59 #xC9 #xC8 #x4E #x79 #x35 #xA0 #x03 #xCB #xE9 #x28))
    #(#vu8(#x7C #x5C #xB2 #x40 #x1B #x3D #xC3 #x3C #x19 #xE7 #x34 #x08 #x19 #xE0 #xF6 #x9C
           #x67 #x8C #x3D #xB8 #xE6 #xF6 #xA9 #x1A)
      #vu8(#x02 #x0C #x6E #xAD #xC2 #xCB #x50 #x0D)
      #vu8(#x00 #x96 #xB0 #x3B)
      #vu8(#x00 #x01 #x02 #x03 #x04 #x05 #x06 #x07 #x08 #x09 #x0A #x0B #x0C #x0D #x0E #x0F
           #x10 #x11 #x12 #x13 #x14 #x15 #x16 #x17 #x18 #x19 #x1A #x1B #x1C #x1D #x1E #x1F)
      #vu8(#x45 #x32 #x43 #xFC #x60 #x9B #x23 #x32 #x7E #xDF #xAA #xFA #x71 #x31 #xCD #x9F
	   #x84 #x90 #x70 #x1C #x5A #xD4 #xA7 #x9C #xFC #x1F #xE0 #xFF #x42 #xF4 #xFB #x00))
    #(#vu8(#x02 #xBF #x39 #x1E #xE8 #xEC #xB1 #x59 #xB9 #x59 #x61 #x7B #x09 #x65 #x27 #x9B
	   #xF5 #x9B #x60 #xA7 #x86 #xD3 #xE0 #xFE)
      #vu8(#x5C #xBD #x60 #x27 #x8D #xCC #x09 #x12)
      #vu8(#x00 #x07 #xBD #xFD)
      #vu8(#x00 #x01 #x02 #x03 #x04 #x05 #x06 #x07 #x08 #x09 #x0A #x0B #x0C #x0D #x0E #x0F
	   #x10 #x11 #x12 #x13 #x14 #x15 #x16 #x17 #x18 #x19 #x1A #x1B #x1C #x1D #x1E #x1F
	   #x20 #x21 #x22 #x23)
      #vu8(#x96 #x89 #x3F #xC5 #x5E #x5C #x72 #x2F #x54 #x0B #x7D #xD1 #xDD #xF7 #xE7 #x58
	   #xD2 #x88 #xBC #x95 #xC6 #x91 #x65 #x88 #x45 #x36 #xC8 #x11 #x66 #x2F #x21 #x88
	   #xAB #xEE #x09 #x35))
    #(#vu8(#x77 #x6B #xEF #xF2 #x85 #x1D #xB0 #x6F #x4C #x8A #x05 #x42 #xC8 #x69 #x6F #x6C
	   #x6A #x81 #xAF #x1E #xEC #x96 #xB4 #xD3 #x7F #xC1 #xD6 #x89 #xE6 #xC1 #xC1 #x04)
      #vu8(#xDB #x56 #x72 #xC9 #x7A #xA8 #xF0 #xB2)
      #vu8(#x00 #x00 #x00 #x60)
      #vu8(#x53 #x69 #x6E #x67 #x6C #x65 #x20 #x62 #x6C #x6F #x63 #x6B #x20 #x6D #x73 #x67)
      #vu8(#x14 #x5A #xD0 #x1D #xBF #x82 #x4E #xC7 #x56 #x08 #x63 #xDC #x71 #xE3 #xE0 #xC0))
    #(#vu8(#xF6 #xD6 #x6D #x6B #xD5 #x2D #x59 #xBB #x07 #x96 #x36 #x58 #x79 #xEF #xF8 #x86
	   #xC6 #x6D #xD5 #x1A #x5B #x6A #x99 #x74 #x4B #x50 #x59 #x0C #x87 #xA2 #x38 #x84)
      #vu8(#xC1 #x58 #x5E #xF1 #x5A #x43 #xD8 #x75)
      #vu8(#x00 #xFA #xAC #x24)
      #vu8(#x00 #x01 #x02 #x03 #x04 #x05 #x06 #x07 #x08 #x09 #x0A #x0B #x0C #x0D #x0E #x0F
           #x10 #x11 #x12 #x13 #x14 #x15 #x16 #x17 #x18 #x19 #x1A #x1B #x1C #x1D #x1E #x1F)
      #vu8(#xF0 #x5E #x23 #x1B #x38 #x94 #x61 #x2C #x49 #xEE #x00 #x0B #x80 #x4E #xB2 #xA9
	   #xB8 #x30 #x6B #x50 #x8F #x83 #x9D #x6A #x55 #x30 #x83 #x1D #x93 #x44 #xAF #x1C))
  #(#vu8(#xFF #x7A #x61 #x7C #xE6 #x91 #x48 #xE4 #xF1 #x72 #x6E #x2F #x43 #x58 #x1D #xE2
	 #xAA #x62 #xD9 #xF8 #x05 #x53 #x2E #xDF #xF1 #xEE #xD6 #x87 #xFB #x54 #x15 #x3D)
    #vu8(#x51 #xA5 #x1D #x70 #xA1 #xC1 #x11 #x48)
    #vu8(#x00 #x1C #xC5 #xB7)
    #vu8(#x00 #x01 #x02 #x03 #x04 #x05 #x06 #x07 #x08 #x09 #x0A #x0B #x0C #x0D #x0E #x0F
         #x10 #x11 #x12 #x13 #x14 #x15 #x16 #x17 #x18 #x19 #x1A #x1B #x1C #x1D #x1E #x1F
	 #x20 #x21 #x22 #x23)
    #vu8(#xEB #x6C #x52 #x82 #x1D #x0B #xBB #xF7 #xCE #x75 #x94 #x46 #x2A #xCA #x4F #xAA
         #xB4 #x07 #xDF #x86 #x65 #x69 #xFD #x07 #xF4 #x8C #xC0 #xB5 #x83 #xD6 #x07 #x1F
	 #x1E #xC0 #xE6 #xB8))
  ))

(let loop ((i 1) (v test-rfc3686-vector))
  (unless (null? v)
    (test-rfc3686 i (car v))
    (loop (+ i 1) (cdr v))))

;; ECDSA tests
;; import private key
(let ()
  (define b64 "MIIBaAIBAQQgspVz8SYOcEa7W3/CmRmiwsrAXC9fQczupivKOnoLKZiggfowgfcC
AQEwLAYHKoZIzj0BAQIhAP////8AAAABAAAAAAAAAAAAAAAA////////////////
MFsEIP////8AAAABAAAAAAAAAAAAAAAA///////////////8BCBaxjXYqjqT57Pr
vVV2mIa8ZR0GsMxTsPY7zjw+J9JgSwMVAMSdNgiG5wSTamZ44ROdJreBn36QBEEE
axfR8uEsQkf4vOblY6RA8ncDfYEt6zOg9KE5RdiYwpZP40Li/hp/m47n60p8D54W
K84zV2sxXs7LtkBoN79R9QIhAP////8AAAAA//////////+85vqtpxeehPO5ysL8
YyVRAgEBoUQDQgAEHE1h+2lRvy3BRBxBJWHYciA+k7XOqTlRrnREu6EUqP2f7Q64
PmkKfA8SLO+yiHr2N0Q31/9xF1Twi6yWfjZyUw==")
  (define bv (base64-decode-string b64 :transcoder #f))
    
  (test-assert "Import ECDSA" (private-key? (import-private-key ECDSA bv)))
  (test-equal "Export ECDSA" bv
	      (export-private-key ECDSA (import-private-key ECDSA bv))))

;; import public key
(let ()
  (define b64 "MIIBSzCCAQMGByqGSM49AgEwgfcCAQEwLAYHKoZIzj0BAQIhAP////8AAAABAAAA
AAAAAAAAAAAA////////////////MFsEIP////8AAAABAAAAAAAAAAAAAAAA////
///////////8BCBaxjXYqjqT57PrvVV2mIa8ZR0GsMxTsPY7zjw+J9JgSwMVAMSd
NgiG5wSTamZ44ROdJreBn36QBEEEaxfR8uEsQkf4vOblY6RA8ncDfYEt6zOg9KE5
RdiYwpZP40Li/hp/m47n60p8D54WK84zV2sxXs7LtkBoN79R9QIhAP////8AAAAA
//////////+85vqtpxeehPO5ysL8YyVRAgEBA0IABBxNYftpUb8twUQcQSVh2HIg
PpO1zqk5Ua50RLuhFKj9n+0OuD5pCnwPEizvsoh69jdEN9f/cRdU8Iusln42clM=")

  (define bv (base64-decode-string b64 :transcoder #f))
  (test-assert "Import ECDSA pub" (public-key? (import-public-key ECDSA bv)))
  (test-equal "Export ECDSA pub" bv
	      (export-public-key ECDSA (import-public-key ECDSA bv))))

;; TODO named curve...

;; simple test
(let ()
  (define keypair (generate-key-pair ECDSA :ec-parameter NIST-P-521))
  (define msg "this message requires digital signature")
  (define ec-signer (make-cipher ECDSA (keypair-private keypair)))
  (define signature (cipher-signature ec-signer (string->utf8 msg)))
  (define ec-verifier (make-cipher ECDSA (keypair-public keypair)))

  (test-assert "ECDSA sign&verify"
	       (cipher-verify ec-verifier (string->utf8 msg) signature)))

;; Curve25519 (ECDSA, experimental support)
(let ()
  ;;(define keypair (generate-key-pair ECDSA :ec-parameter curve25519))
  (define private-key
    (generate-private-key ECDSA
     #x7db02f79be391155563a1d505606c90a7bbf1e572d3f0b675750d90955aab1c
     curve25519))
  (define public-key
    (generate-public-key ECDSA
     #x71b71c091f5bf57e4025712f8544f0135b6e4a75a37afc7e6440a50792619d9e
     #x45a799c07c0d4c38f0e6f73c7eb91b8f212f1b33b7ef4a8dd90a56baf75ff88e
     curve25519))
  (define msg "this message requires digital signature")
  ;; #x3044022004670fbb5c5e62ac270ba3915b9260d527045b172ea0e1fbf05c9caeb33943e902200ea21f512349ac489f234f445724ee4045be4b76b2efb91e260c8e4c0f30f4d2
  (define bc-signature
    #vu8(48 68 2 32 4 103 15 187 92 94 98 172 39 11 163 145 91 146 96 213 39 4 91 23 46 160 225 251 240 92 156 174 179 57 67 233 2 32 14 162 31 81 35 73 172 72 159 35 79 68 87 36 238 64 69 190 75 118 178 239 185 30 38 12 142 76 15 48 244 210))
  (define ec-signer (make-cipher ECDSA private-key))
  (define signature (cipher-signature ec-signer (string->utf8 msg)
				      :hash SHA-256))
  (define ec-verifier (make-cipher ECDSA public-key))

  (test-assert "ECDSA (curve25519) sign&verify (BC)"
	       (cipher-verify ec-verifier (string->utf8 msg) bc-signature
			      :hash SHA-256))
  (test-assert "ECDSA (curve25519) sign&verify"
	       (cipher-verify ec-verifier (string->utf8 msg) signature
			      :hash SHA-256)))

;; no hash
(define-syntax define-no-hash
  (syntax-rules ()
    ((_ name marker size)
     (begin
       (define-class <no-hash> (<user-hash-algorithm>)
	 ((buffer :init-form (make-bytevector size))))
       (define-method initialize ((o <no-hash>) initargs)
	 (call-next-method)
	 (slot-set! o 'init values)
	 (slot-set! o 'process
		    (lambda (h bv . ignore)
		      (bytevector-copy! bv 0 (slot-ref h 'buffer) 0 size)))
	 (slot-set! o 'done
		    (lambda (h out . ignore)
		      (bytevector-copy! (slot-ref h 'buffer) 0 out 0 size)))
	 (slot-set! o 'block-size 16)
	 (slot-set! o 'hash-size size)
	 (slot-set! o 'oid #f)
	 (slot-set! o 'state #f))
       (define name marker)
       (define dummy (register-hash name <no-hash>))))))

(define-no-hash no-20 :no-20 20) ;; sha1
(define-no-hash no-28 :no-38 28) ;; sha224
(define-no-hash no-32 :no-32 32) ;; sha256
(define-no-hash no-48 :no-48 48) ;; sha384
(define-no-hash no-64 :no-64 64) ;; sha512

(define (%test-ecdsa name param hash msg d Qx Qy k R S)
  (define priv (generate-private-key ECDSA d param))
  (define pub (generate-public-key ECDSA Qx Qy param))
  (define cipher (make-cipher ECDSA priv))
  (define algo (hash-algorithm hash))
  (define size (ceiling (/ (bitwise-length (ec-parameter-n param)) 8)))
  ;; do only SHA-1 (the unsecure one) for test time
  (when (eq? hash :no-20)
    (let ((signature (bytevector-append (uinteger->bytevector R size)
					(uinteger->bytevector S size)))
	  (message (uinteger->bytevector msg (hash-size algo))))
      (test-equal (format "~a (~a) sign" name hash)
		  signature
		  (cipher-signature cipher
				    message
				    :hash algo
				    :k-generator (lambda (n d) k)
				    :der-encode #f))
      (let ((verifier (make-cipher ECDSA pub)))
	(test-assert (format "~a (~a) verify" name hash)
		     (cipher-verify verifier message signature
				    :hash algo
				    :der-encode #f))))))

(include "test-eddsa.scm")
(include "test-ecdsa.scm")
(include "test-ecdhc.scm")

;; key wrap
(let* ((aes-key (generate-secret-key AES
		 #vu8(#x00 #x01 #x02 #x03 #x04 #x05 #x06 #x07 
		      #x08 #x09 #x0A #x0B #x0C #x0D #x0E #x0F)))
       (aes-wrap (make-aes-key-wrap aes-key))
       (aes-unwrap (make-aes-key-unwrap aes-key))
       (invalid-aes-unwrap
	(make-aes-key-unwrap aes-key :iv #vu8(1 2 3 4 5 6 7 8))))
  (test-equal #vu8(#x1F #xA6 #x8B #x0A #x81 #x12 #xB4 #x47
		   #xAE #xF3 #x4B #xD8 #xFB #x5A #x7B #x82
		   #x9D #x3E #x86 #x23 #x71 #xD2 #xCF #xE5)
	      (aes-wrap #vu8(#x00 #x11 #x22 #x33 #x44 #x55 #x66 #x77
			     #x88 #x99 #xAA #xBB #xCC #xDD #xEE #xFF)))
  (test-equal #vu8(#x00 #x11 #x22 #x33 #x44 #x55 #x66 #x77
		   #x88 #x99 #xAA #xBB #xCC #xDD #xEE #xFF)
	      (aes-unwrap #vu8(#x1F #xA6 #x8B #x0A #x81 #x12 #xB4 #x47
			       #xAE #xF3 #x4B #xD8 #xFB #x5A #x7B #x82
			       #x9D #x3E #x86 #x23 #x71 #xD2 #xCF #xE5)))
  (test-error integrity-error?
	      (invalid-aes-unwrap #vu8(#x1F #xA6 #x8B #x0A #x81 #x12 #xB4 #x47
				       #xAE #xF3 #x4B #xD8 #xFB #x5A #x7B #x82
				       #x9D #x3E #x86 #x23 #x71 #xD2 #xCF #xE5))))

(define (test-agreement expect proc k u)
  (test-equal (number->string expect 16)
	      (integer->bytevector expect)
	      (proc (integer->bytevector k) (integer->bytevector u))))

(define (test-x25519 expect k u)
  (test-agreement expect x25519-calculate-agreement k u))

(define (test-x448 expect k u)
  (test-agreement expect x448-calculate-agreement k u))

(test-x25519 #xc3da55379de9c6908e94ea4df28d084f32eccf03491c71f754b4075577a28552
	     #xa546e36bf0527c9d3b16154b82465edd62144c0ac1fc5a18506a2244ba449ac4
	     #xe6db6867583030db3594c1a424b15f7c726624ec26b3353b10a903a6d0ab1c4c)

(test-x25519 #x95cbde9476e8907d7aade45cb4b873f88b595a68799fa152e6f8f7647aac7957
	     #x4b66e9d4d1b4673c5ad22691957d6af5c11b6421e0ea01d42ca4169e7918ba0d
	     #xe5210f12786811d3f4b7959d0538ae2c31dbe7106fc03c3efc4cd549c715a493)

(test-x448 #xce3e4ff95a60dc6697da1db1d85e6afbdf79b50a2412d7546d5f239fe14fbaadeb445fc66a01b0779d98223961111e21766282f73dd96b6f
	   #x3d262fddf9ec8e88495266fea19a34d28882acef045104d0d1aae121700a779c984c24f8cdd78fbff44943eba368f54b29259a4f1c600ad3
	   #x06fce640fa3487bfda5f6cf2d5263f8aad88334cbd07437f020f08f9814dc031ddbdc38c19c6da2583fa5429db94ada18aa7a7fb4ef8a086)

(test-x448 #x884a02576239ff7a2f2f63b2db6a9ff37047ac13568e1e30fe63c4a7ad1b3ee3a5700df34321d62077e63633c575c1c954514e99da7c179d
	   #x203d494428b8399352665ddca42f9de8fef600908e0d461cb021f8c538345dd77c3e4806e25f46d3315c44e0a5b4371282dd2c8d5be3095f
	   #x0fbcc2f993cd56d3305b0b7d9e55d4c1a8fb5dbb52f8e9a1e9b6201b165d015894e56c4d3570bee52fe205e28a78b91cdfbde71ce8d157db)

(define (test-key-generation type priv-a pub-a priv-b pub-b k)
  (let ((A (generate-private-key type (integer->bytevector priv-a)))
	(B (generate-private-key type (integer->bytevector priv-b)))
	(K (integer->bytevector k)))
    (test-equal (integer->bytevector pub-a)
		(rfc7748-public-key-data (rfc7748-private-key-public-key A)))
    (test-equal (integer->bytevector pub-b)
		(rfc7748-public-key-data (rfc7748-private-key-public-key B)))
    (let ((agreement (if (x25519-private-key? A)
			 x25519-calculate-agreement
			 x448-calculate-agreement)))
      (test-equal "A priv, B pub"
		  K (agreement (rfc7748-private-key-random A)
			       (rfc7748-public-key-data
				(rfc7748-private-key-public-key B))))
      (test-equal "B priv, A pub"
		  K (agreement (rfc7748-private-key-random B)
			       (rfc7748-public-key-data
				(rfc7748-private-key-public-key A)))))
    (test-equal "A priv, B pub" K
		(calculate-key-agreement ECDH
					 A (rfc7748-private-key-public-key B)))
    (test-equal "B priv, A pub" K
		(calculate-key-agreement ECDH
					 B (rfc7748-private-key-public-key A)))
    ))

(test-key-generation
 X25519
 #x77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a
 #x8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a
 #x5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb
 #xde9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f
 #x4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742)

(test-key-generation
 X448
 #x9a8f4925d1519f5775cf46b04b5800d4ee9ee8bae8bc5565d498c28dd9c9baf574a9419744897391006382a6f127ab1d9ac2d8c0a598726b
 #x9b08f7cc31b7e3e67d22d5aea121074a273bd2b83de09c63faa73d2c22c5d9bbc836647241d953d40c5b12da88120d53177f80e532c41fa0
 #x1c306a7ac2a0e2e0990b294470cba339e6453772b075811d8fad0d1d6927c120bb5ee8972b0d3e21374c9c921b09d1b0366f10b65173992d
 #x3eb7a829b0cd20f5bcfc0b599b6feccf6da4627107bdb0d4f345b43027d8b972fc3e34fb4232a13ca706dcb57aec3dae07bdc1c67bf33609
 #x07fff4181ac6cc95ec1c16a94a0f74d12da232ce40a77552281d282bb60c0b56fd2464c335543936521c24403085d59a449a5037514a879d)


(test-end)
