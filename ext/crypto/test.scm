(add-load-path "./crypto")
#!compatible

(import (srfi :64 testing)
	(rnrs)
	(sagittarius)
	(crypto)
	(math random)
	(math prime)
	(math hash)
	(math ec))

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
(define *des3-key* (generate-secret-key DES3 (string->utf8 "24bytekey123456789012345")))
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

;; 1024 bits takes too long. 512 bits can be durable.
(define key-pair (generate-key-pair RSA :size 512 :prng (pseudo-random RC4)))

(test-begin "(run-crypto-test)")
;; basic test
(test-assert "crypto-object?" (crypto-object? des-enc/cbc-cipher))
(test-assert "cipher?" (cipher? des-enc/cbc-cipher))
(test-assert "key?" (key? *des-key*))
(test-assert "prng?" (prng? (pseudo-random RC4)))
(test-assert "prng?" (prng? (secure-random RC4)))
(test-assert "pseudo-random?" (pseudo-random? (pseudo-random RC4)))
(test-assert "secure-random?" (secure-random? (secure-random RC4)))

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
	    ;; to avoid long calculation time...
	    (let ((kp (generate-key-pair RSA :size 256)))
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
	     (guard (e 
		     ((encode-error? e) #t)
		     (else #f))
	       (let ((rsa-encrypt-cipher (cipher RSA public-rsa-key)))
		 (encrypt rsa-encrypt-cipher invalid-rsa-message))))

(test-assert "with padding invalid block"
	     (guard (e 
		     ((decode-error? e) #t)
		     (else #f))
	       (let ((rsa-decrypt-cipher (cipher RSA private-rsa-key)))
		 (decrypt rsa-decrypt-cipher invalid-padding))))

;; hash test
;; hash valid-rsa-message

(test-equal "MD5 hash"
	    #vu8(#xC7 #x2B #x96 #x98 #xFA #x19 #x27 #xE1 #xDD #x12 #xD3 #xCF #x26 #xED #x84 #xB2)
	    (hash MD5 valid-rsa-message))

(test-equal "MD5 OID"
	    "1.2.840.113549.2.5"
	    (hash-oid (hash-algorithm MD5)))

;; mgf-1 test
(define mgf-result-sha1
  (integer->bytevector #x5f8de105b5e96b2e490ddecbd147dd1def7e3b8e0e6a26eb7b956ccb8b3bdc1ca975bc57c3989e8fbad31a224655d800c46954840ff32052cdf0d640562bdfadfa263cfccf3c52b29f2af4a1869959bc77f854cf15bd7a25192985a842dbff8e13efee5b7e7e55bbe4d389647c686a9a9ab3fb889b2d7767d3837eea4e0a2f04))
(define mgf-seed-sha1
  (integer->bytevector #x032e45326fa859a72ec235acff929b15d1372e30b207255f0611b8f785d764374152e0ac009e509e7ba30cd2f1778e113b64e135cf4e2292c75efe5288edfda4))

(test-equal "MGF-1(SHA-1)"
	    mgf-result-sha1
	    (mgf-1 mgf-seed-sha1 (bytevector-length mgf-result-sha1)
		   (hash-algorithm SHA-1)))


;; PKCS#1 EMSA-PSS test

(test-assert "PKCS#1 EMSA-PSS"
	     (let ((encoded (pkcs1-emsa-pss-encode valid-rsa-message 1024)))
	       (pkcs1-emsa-pss-verify valid-rsa-message encoded 1024)))

(test-assert "Verify with EMSA-PSS and SHA-1"
	     (let* ((rsa-sign-cipher (cipher RSA (keypair-private key-pair)))
		    (rsa-verify-cipher (cipher RSA (keypair-public key-pair)))
		    (em (sign rsa-sign-cipher valid-rsa-message)))
	       (verify rsa-verify-cipher valid-rsa-message em)))

(test-assert "Verify with EMSA-PSS and MD5"
	     (let* ((rsa-sign-cipher (cipher RSA (keypair-private key-pair)))
		    (rsa-verify-cipher (cipher RSA (keypair-public key-pair)))
		    (em (sign rsa-sign-cipher valid-rsa-message :hash (hash-algorithm MD5))))
	       (verify rsa-verify-cipher valid-rsa-message em :hash (hash-algorithm MD5))))

(test-assert "Verify with PKCS1-v1.5"
	     (let* ((rsa-sign-cipher (cipher RSA (keypair-private key-pair)))
		    (rsa-verify-cipher (cipher RSA (keypair-public key-pair)))
		    (em (sign rsa-sign-cipher valid-rsa-message :encode pkcs1-emsa-v1.5-encode)))
	       (verify rsa-verify-cipher valid-rsa-message em :verify pkcs1-emsa-v1.5-verify)))

;; Issue 21
(test-assert "SOBER-128 prng"
	     (let ((prng (pseudo-random SOBER-128
					:seed #vu8(1 2 3 4 5 6 7 8))))
	       (pseudo-random? prng)))

(test-error "SOBER-128 prng (no seed)"
	    error?
	    (pseudo-random SOBER-128))

(test-error "SOBER-128 prng (invalid seed size)"
	    error?
	    (pseudo-random SOBER-128 :seed #vu8(1 2 3)))

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

;; EC arithmetic
;; from example calculation
;; https://www.nsa.gov/ia/_files/nist-routines.pdf
;; P-192
(let ((S (make-ec-point (ec-parameter-curve P-192)
			#xD458E7D127AE671B0C330266D246769353A012073E97ACF8
			#x325930500D851F336BDDC050CF7FB11B5673A1645086DF3B))
      (T (make-ec-point (ec-parameter-curve P-192)
			#xF22C4395213E9EBE67DDECDD87FDBD01BE16FB059B9753A4
			#x264424096AF2B3597796DB48F8DFB41FA9CECC97691A9C79)))

  (let ((R (make-ec-point (ec-parameter-curve P-192)
			  #x48E1E4096B9B8E5CA9D0F1F077B8ABF58E843894DE4D0290
			  #x408FA77C797CD7DBFB16AA48A3648D3D63C94117D7B6AA4B)))
    (test-equal "EC add P-192" R (ec-point-add S T)))

  (let ((R (make-ec-point (ec-parameter-curve P-192)
			  #xFC9683CC5ABFB4FE0CC8CC3BC9F61EABC4688F11E9F64A2E
			  #x093e31d00fb78269732b1bd2a73c23cdd31745d0523d816b)))
    (test-equal "EC sub P-192" R (ec-point-sub S T)))
  
  (let ((2R (make-ec-point (ec-parameter-curve P-192)
			   #x30C5BC6B8C7DA25354B373DC14DD8A0EBA42D25A3F6E6962
			   #x0DDE14BC4249A721C407AEDBF011E2DDBBCB2968C9D889CF)))
    (test-equal "EC twice P-192" 2R (ec-point-twice S)))

  (let ((d #xA78A236D60BAEC0C5DD41B33A542463A8255391AF64C74EE)
	(R (make-ec-point (ec-parameter-curve P-192)
			  #x1FAEE4205A4F669D2D0A8F25E3BCEC9A62A6952965BF6D31
			  #x5FF2CDFA508A2581892367087C696F179E7A4D7E8260FB06)))
    (test-equal "EC multiply P-192" R (ec-point-mul S d))
    (let ((e #xC4BE3D53EC3089E71E4DE8CEAB7CCE889BC393CD85B972BC)
	  (r (make-ec-point (ec-parameter-curve P-192)
			    #x019F64EED8FA9B72B7DFEA82C17C9BFA60ECB9E1778B5BDE
			    #x16590C5FCD8655FA4CED33FB800E2A7E3C61F35D83503644)))
      (test-equal "EC multiply P-192 (2)" r 
		  (ec-point-add R (ec-point-mul T e)))))
  )


(test-end)
