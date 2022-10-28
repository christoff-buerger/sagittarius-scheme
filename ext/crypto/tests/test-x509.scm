(import (rnrs)
	(sagittarius crypto pkix certificate)
	(sagittarius crypto pkix extensions)
	(sagittarius crypto keys)
	(sagittarius crypto signatures)
	(sagittarius crypto asn1)
	(rfc base64)
	(srfi :19)
	(srfi :64))

(test-begin "X.509 certificate")

(define cert
  (base64-decode-string
   (string-append
    "MIICcDCCAhWgAwIBAgIUOJ0BDDovxF2W3+0Kndg1cl9q5NQwCgYIKoZIzj0EAwIw"
    "gYwxCzAJBgNVBAYTAk5MMRUwEwYDVQQIDAxadWlkLUhvbGxhbmQxDzANBgNVBAcM"
    "BkxlaWRlbjEbMBkGA1UECgwSU2FnaXR0YXJpdXMgU2NoZW1lMRUwEwYDVQQDDAxU"
    "YWthc2hpIEthdG8xITAfBgkqhkiG9w0BCQEWEmt0YWthc2hpQHltYWlsLmNvbTAe"
    "Fw0yMjEwMjQxODM2MjhaFw0zMjEwMjExODM2MjhaMIGMMQswCQYDVQQGEwJOTDEV"
    "MBMGA1UECAwMWnVpZC1Ib2xsYW5kMQ8wDQYDVQQHDAZMZWlkZW4xGzAZBgNVBAoM"
    "ElNhZ2l0dGFyaXVzIFNjaGVtZTEVMBMGA1UEAwwMVGFrYXNoaSBLYXRvMSEwHwYJ"
    "KoZIhvcNAQkBFhJrdGFrYXNoaUB5bWFpbC5jb20wWTATBgcqhkjOPQIBBggqhkjO"
    "PQMBBwNCAAQdBG9xFor8DDnduyf9S1oJvX7Z7fZnZlbyen0/vXD/CghqKJRrgins"
    "yUb4D2cp0N/gvKX5b1Lkmw5dLCD02bJXo1MwUTAdBgNVHQ4EFgQUgm9i/kQ+u/KT"
    "zBcddqH9Gy8tT48wHwYDVR0jBBgwFoAUgm9i/kQ+u/KTzBcddqH9Gy8tT48wDwYD"
    "VR0TAQH/BAUwAwEB/zAKBggqhkjOPQQDAgNJADBGAiEAr3vM7SgzcSdsJ25chY5G"
    "DdYbGazEK4PU6oJRGj2RXCACIQDbm8/zohffUKa2zYJ77NUVEN4+oZquRW/ZMg1i"
    "UeWU6g==")
   :transcoder #f))

(define alt-names
  (x509-general-names
   ;; I want my own domain for this :D
   (dns-name->general-name "*.example.com")
   (rfc822-name->general-name "ktakashi@ymail.com")
   (ip-address->general-name #vu8(127 0 0 1))
   (directory-name->general-name "O=bla")
   (registered-id->general-name "1.2.3.4")))

(test-assert (x509-general-name? (dns-name->general-name "*.example.com")))
(test-assert (x509-general-name? (rfc822-name->general-name "ktakashi@ymail.com")))
(test-assert (x509-general-name? (ip-address->general-name #vu8(127 0 0 1))))
(test-assert (x509-general-name? (directory-name->general-name "O=bla")))
(test-assert (x509-general-name? (registered-id->general-name "1.2.3.4")))

(test-assert (x509-general-names? alt-names))
(test-assert (x509-authority-key-identifier?
	      (make-x509-authority-key-identifier :key-identifier #vu8(1))))
(test-error
 (make-x509-authority-key-identifier :authority-cert-serial-number 0))

(define (test-certificate-builder algorithm)
  (define one-year (make-time time-duration 0 (* 3600 24 365)))
  (define one-second (make-time time-duration 0 1))
  (define now (current-time))
  (define key-scheme (oid->key-operation algorithm))
  (define issuer-dn (x509-name '(C "NL")
			       '(ST "Zuid-Holland")
			       '(L "Leiden")
			       '(OU "Sagittarius Scheme")
			       '(CN "Takashi Kato")))
  (define subject-dn (x509-name '(C "NL")
			       '(ST "Zuid-Holland")
			       '(OU "Sagittarius Scheme")
			       '(CN "Takashi Kato")
			       '(E "ktakashi@ymail.com")))
  (let ((template (x509-certificate-template-builder
		    (issuer-dn issuer-dn)
		    (subject-dn subject-dn)
		    (serial-number 1000)
		    (not-before (time-utc->date now))
		    (not-after (time-utc->date (add-duration now one-year)))
		    (extensions
		     (x509-extensions
		      (make-x509-subject-alternative-name-extension alt-names)
		      (make-x509-issuer-alternative-name-extension alt-names)
		      (make-x509-authority-key-identifier-extension
		       (make-x509-authority-key-identifier
			:key-identifier #vu8(1 2 3 4 5)))))))
	(signing-key-pair (generate-key-pair key-scheme))
	(failing-key-pair (generate-key-pair key-scheme)))
    (test-assert (x509-certificate-template? template))
    (let ((cert (sign-x509-certificate-template
		 template algorithm signing-key-pair)))
      (test-assert (x509-certificate? cert))
      (test-assert algorithm (validate-x509-certificate cert
		    (x509-certificate-validity-validator)
		    (x509-certificate-signature-validator 
		     (key-pair-public signing-key-pair))))
      (test-error "Validity before"
		  ((x509-certificate-validity-validator 
		    (time-utc->date (subtract-duration now one-second)))
		   cert))
      (let ((expired-date (time-utc->date
			   (add-duration (add-duration now one-year)
					 one-second))))
	(test-assert (x509-certificate-expired? cert expired-date))
	(test-error "Validity after"
		    ((x509-certificate-validity-validator expired-date) cert)))
      (test-error "Signature verificateion"
		  ((x509-certificate-signature-validator
		    (key-pair-public failing-key-pair)) cert))
      cert)))

(let ((x509-cert
       (read-x509-certificate (open-bytevector-input-port cert))))
  (test-assert (x509-certificate? x509-cert))
  (test-equal 3 (x509-certificate-version x509-cert))
  (test-assert (x509-name? (x509-certificate-issuer-dn x509-cert)))
  (test-assert (x509-name? (x509-certificate-subject-dn x509-cert)))
  (let ((validity (x509-certificate-validity x509-cert)))
    (test-assert (x509-validity? validity))
    (test-assert (date? (x509-validity-not-before validity)))
    (test-assert (date? (x509-validity-not-after validity))))
  (test-assert (public-key? (x509-certificate-public-key x509-cert)))
  (let-values (((out e) (open-bytevector-output-port)))
    (let ((bport (open-base64-encode-output-port out)))
      (write-x509-certificate x509-cert bport)
      (close-output-port bport)
      (test-equal (base64-encode cert :line-width #f) (e))))
  (let* ((cert (test-certificate-builder *signature-algorithm:ecdsa-sha256*))
	 (extensions (x509-certificate-extensions cert)))

    (define (test-extension extensions oid critical value)
      (let ((x (find-x509-extension (x509-extension-by-id oid) extensions)))
	(test-assert (x509-extension? x))
	(test-assert (der-object-identifier->oid-string oid)
		     (x509-extension-id x))
	(test-equal critical (x509-extension-critical? x))
	(test-equal oid value (x509-extension-value x))))
    (define (ensure-raw-asn1-object o)
      (bytevector->asn1-object (asn1-encodable->bytevector o)))
    (test-extension extensions *extension:subject-alt-name* #f
		    (ensure-raw-asn1-object
		     (x509-general-names->general-names alt-names)))
    (test-extension extensions *extension:issuer-alt-name* #f
		    (ensure-raw-asn1-object
		     (x509-general-names->general-names alt-names)))
    (test-extension extensions *extension:authority-key-identifier* #f
		    (ensure-raw-asn1-object
		     (x509-authority-key-identifier->authority-key-identifier
		      (make-x509-authority-key-identifier
		       :key-identifier #vu8(1 2 3 4 5))))))
    
  (for-each test-certificate-builder
	    (list *signature-algorithm:rsa-pkcs-v1.5-sha1*
		  *signature-algorithm:rsa-pkcs-v1.5-sha256*
		  *signature-algorithm:rsa-pkcs-v1.5-sha384*
		  *signature-algorithm:rsa-pkcs-v1.5-sha512*
		  *signature-algorithm:rsa-pkcs-v1.5-sha224*
		  *signature-algorithm:rsa-pkcs-v1.5-sha512/224*
		  *signature-algorithm:rsa-pkcs-v1.5-sha512/256*
		  *signature-algorithm:rsa-pkcs-v1.5-sha3-224*
		  *signature-algorithm:rsa-pkcs-v1.5-sha3-256*
		  *signature-algorithm:rsa-pkcs-v1.5-sha3-384*
		  *signature-algorithm:rsa-pkcs-v1.5-sha3-512*
		  *signature-algorithm:dsa-sha224*
		  *signature-algorithm:dsa-sha256*
		  ;; Key size doesn't fit...
		  ;; Not sure why these are defined even as max size of DSA
		  ;; key is 2048...
		  ;; *signature-algorithm:dsa-sha384*
		  ;; *signature-algorithm:dsa-sha512*
		  *signature-algorithm:ecdsa-sha1*
		  *signature-algorithm:ecdsa-sha224*
		  *signature-algorithm:ecdsa-sha256*
		  *signature-algorithm:ecdsa-sha384*
		  *signature-algorithm:ecdsa-sha512*
		  *signature-algorithm:ecdsa-sha3-224*
		  *signature-algorithm:ecdsa-sha3-256*
		  *signature-algorithm:ecdsa-sha3-384*
		  *signature-algorithm:ecdsa-sha3-512*
		  *signature-algorithm:ed25519*
		  *signature-algorithm:ed448*)))

(test-end)
