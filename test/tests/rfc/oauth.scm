#!read-macro=sagittarius/bv-string
(import (rnrs)
	(rfc oauth)
	(rfc http-connections)
	(util bytevector)
	(rsa pkcs :8)
	(rfc base64)
	(rfc x.509)
	(srfi :64))

(test-begin "OAuth 1.0")

(test-group "HMAC-SHA1 Signature"
  ;; from https://dev.twitter.com/oauth/overview/creating-signatures
  (define consumer-secret #*"kAcSOqF21Fu85e7zjz7ZN2U4ZRhfV3WpwPAoE3Z7kBw")
  (define token-secret #*"LswwdoUaIvS8ltyTt5jkRh4J50vUPVVHtR2YPi5kE")
  (define base-string
    "POST&https%3A%2F%2Fapi.twitter.com%2F1%2Fstatuses%2Fupdate.json&include_entities%3Dtrue%26oauth_consumer_key%3Dxvz1evFS4wEEPTGEFPHBog%26oauth_nonce%3DkYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg%26oauth_signature_method%3DHMAC-SHA1%26oauth_timestamp%3D1318622958%26oauth_token%3D370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb%26oauth_version%3D1.0%26status%3DHello%2520Ladies%2520%252B%2520Gentlemen%252C%2520a%2520signed%2520OAuth%2520request%2521")
  (let ((signer (make-oauth-hmac-sha1-signer consumer-secret token-secret)))
    (test-assert (oauth-signer? signer))
    (oauth-signer-process! signer (string->utf8 base-string))
    (test-equal "tnnArxj06cWHq44gCs1OSKk/jLY=" (oauth-signer-done! signer))
    (oauth-signer-process! signer (string->utf8 base-string))
    (test-equal "tnnArxj06cWHq44gCs1OSKk/jLY=" (oauth-signer-done! signer))
    
    (let ((in (open-bytevector-input-port (string->utf8 base-string))))
      (let loop ()
	(let ((bv (get-bytevector-n in 64)))
	  (unless (eof-object? bv) (oauth-signer-process! signer bv) (loop))))
      (test-equal "tnnArxj06cWHq44gCs1OSKk/jLY=" (oauth-signer-done! signer)))

    (let ((verifier (make-oauth-hmac-sha1-verifier consumer-secret token-secret)))
      (test-assert (oauth-verifier? verifier))
      (test-assert (oauth-verifier-verify verifier (string->utf8 base-string)
			     "tnnArxj06cWHq44gCs1OSKk/jLY=")))))

(test-group "RSA-SHA1 Signature"
  ;; from http://wiki.oauth.net/w/page/12238556/TestCases
  (define private-key-info
    (make-private-key-info (base64-decode-string
    "MIICdgIBADANBgkqhkiG9w0BAQEFAASCAmAwggJcAgEAAoGBALRiMLAh9iimur8V
     A7qVvdqxevEuUkW4K+2KdMXmnQbG9Aa7k7eBjK1S+0LYmVjPKlJGNXHDGuy5Fw/d
     7rjVJ0BLB+ubPK8iA/Tw3hLQgXMRRGRXXCn8ikfuQfjUS1uZSatdLB81mydBETlJ
     hI6GH4twrbDJCR2Bwy/XWXgqgGRzAgMBAAECgYBYWVtleUzavkbrPjy0T5FMou8H
     X9u2AC2ry8vD/l7cqedtwMPp9k7TubgNFo+NGvKsl2ynyprOZR1xjQ7WgrgVB+mm
     uScOM/5HVceFuGRDhYTCObE+y1kxRloNYXnx3ei1zbeYLPCHdhxRYW7T0qcynNmw
     rn05/KO2RLjgQNalsQJBANeA3Q4Nugqy4QBUCEC09SqylT2K9FrrItqL2QKc9v0Z
     zO2uwllCbg0dwpVuYPYXYvikNHHg+aCWF+VXsb9rpPsCQQDWR9TT4ORdzoj+Nccn
     qkMsDmzt0EfNaAOwHOmVJ2RVBspPcxt5iN4HI7HNeG6U5YsFBb+/GZbgfBT3kpNG
     WPTpAkBI+gFhjfJvRw38n3g/+UeAkwMI2TJQS4n8+hid0uus3/zOjDySH3XHCUno
     cn1xOJAyZODBo47E+67R4jV1/gzbAkEAklJaspRPXP877NssM5nAZMU0/O/NGCZ+
     3jPgDUno6WbJn5cqm8MqWhW1xGkImgRk+fkDBquiq4gPiT898jusgQJAd5Zrr6Q8
     AO/0isr/3aa6O6NLQxISLKcPDk2NOccAfS/xOtfOz4sJYM3+Bs4Io9+dZGSDCA54
     Lw03eHTNQghS0A=="
    :transcoder #f)))
  (define x509-certificate
    (make-x509-certificate
     (base64-decode-string
      "MIIBpjCCAQ+gAwIBAgIBATANBgkqhkiG9w0BAQUFADAZMRcwFQYDVQQDDA5UZXN0
       IFByaW5jaXBhbDAeFw03MDAxMDEwODAwMDBaFw0zODEyMzEwODAwMDBaMBkxFzAV
       BgNVBAMMDlRlc3QgUHJpbmNpcGFsMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKB
       gQC0YjCwIfYoprq/FQO6lb3asXrxLlJFuCvtinTF5p0GxvQGu5O3gYytUvtC2JlY
       zypSRjVxwxrsuRcP3e641SdASwfrmzyvIgP08N4S0IFzEURkV1wp/IpH7kH41Etb
       mUmrXSwfNZsnQRE5SYSOhh+LcK2wyQkdgcMv11l4KoBkcwIDAQABMA0GCSqGSIb3
       DQEBBQUAA4GBAGZLPEuJ5SiJ2ryq+CmEGOXfvlTtEL2nuGtr9PewxkgnOjZpUy+d
       4TvuXJbNQc8f4AMWL/tO9w0Fk80rWKp9ea8/df4qMq5qlFWlx6yOLQxumNOmECKb
       WpkUQDIDJEoFUzKMVuJf4KO/FJ345+BNLGgbJ6WujreoM1X/gYfdnJ/J"
      :transcoder #f)))
  (define private-key (pki->private-key private-key-info))
  (define public-key (x509-certificate-get-public-key x509-certificate))
  (define base-string
    "GET&http%3A%2F%2Fphotos.example.net%2Fphotos&file%3Dvacaction.jpg%26oauth_consumer_key%3Ddpf43f3p2l4k3l03%26oauth_nonce%3D13917289812797014437%26oauth_signature_method%3DRSA-SHA1%26oauth_timestamp%3D1196666512%26oauth_version%3D1.0%26size%3Doriginal")
  (define signature "jvTp/wX1TYtByB1m+Pbyo0lnCOLIsyGCH7wke8AUs3BpnwZJtAuEJkvQL2/9n4s5wUmUl4aCI4BwpraNx4RtEXMe5qg5T1LVTGliMRpKasKsW//e+RinhejgCuzoH26dyF8iY2ZZ/5D1ilgeijhV/vBka5twt399mXwaYdCwFYE=")
  (let ((signer (make-oauth-rsa-sha1-signer private-key)))
    (test-assert (oauth-signer? signer))
    (oauth-signer-process! signer (string->utf8 base-string))
    (test-equal signature (oauth-signer-done! signer))
    (oauth-signer-process! signer (string->utf8 base-string))
    (test-equal signature (oauth-signer-done! signer))
    
    (let ((in (open-bytevector-input-port (string->utf8 base-string))))
      (let loop ()
	(let ((bv (get-bytevector-n in 64)))
	  (unless (eof-object? bv) (oauth-signer-process! signer bv) (loop))))
      (test-equal signature (oauth-signer-done! signer)))
    
    (let ((verifier (make-oauth-rsa-sha1-verifier public-key)))
      (test-assert (oauth-verifier? verifier))
      (test-assert (oauth-verifier-verify
		    verifier (string->utf8 base-string) signature)))))

(test-equal "http://example.com/r%20v/X"
	    (oauth-construct-base-string-uri
	     (make-http1-connection "EXAMPLE.COM:80" #f)
	     "/r%20v/X?id=123"))
(test-equal "https://www.example.net:8080/"
	    (oauth-construct-base-string-uri
	     (make-http1-connection "www.example.net:8080" #t)
	     "/?q=1"))
(test-equal #*"%3D%253D" (oauth-encode-string "=%3D"))
(test-equal #*"a" (oauth-encode-string "a"))
(test-equal #*"c%40" (oauth-encode-string "c@"))
(test-equal #*"r%20b" (oauth-encode-string "r b"))
(test-equal '((           #*"a2"           .       #*"r%20b"      )
              (           #*"a3"           .       #*"2%20q"      )
              (           #*"a3"           .         #*"a"        )
              (           #*"b5"           .     #*"%3D%253D"     )
              (          #*"c%40"          .         #*""         )
              (           #*"c2"           .         #*""         )
              (   #*"oauth_consumer_key"   . #*"9djdj82h48djs9d2" )
              (       #*"oauth_nonce"      .     #*"7d8f3e4a"     )
              ( #*"oauth_signature_method" .     #*"HMAC-SHA1"    )
              (     #*"oauth_timestamp"    .     #*"137131201"    )
              (       #*"oauth_token"      . #*"kkk9d7dh3k39sjv7" ))
	    (oauth-normalize-parameters
	     '((           "b5"                  "=%3D"       )
               (           "a3"                    "a"        )
               (           "c@"                    ""         )
               (           "a2"                   "r b"       )
               (   "oauth_consumer_key"    "9djdj82h48djs9d2" )
               (       "oauth_token"       "kkk9d7dh3k39sjv7" )
               ( "oauth_signature_method"      "HMAC-SHA1"    )
               (     "oauth_timestamp"         "137131201"    )
               (       "oauth_nonce"           "7d8f3e4a"     )
               (           "c2"                    ""         )
               (           "a3"                   "2 q"       ))))

;; data from
;; https://dev.twitter.com/oauth/overview/creating-signatures
(let ((conn
       (make-oauth-connection
	(make-http1-connection "api.twitter.com" #t)
	"xvz1evFS4wEEPTGEFPHBog"
	(make-oauth-hmac-sha1-signer
	 #*"kAcSOqF21Fu85e7zjz7ZN2U4ZRhfV3WpwPAoE3Z7kBw"
	 #*"LswwdoUaIvS8ltyTt5jkRh4J50vUPVVHtR2YPi5kE"))))
  (let-values (((signature alist)
		(oauth-compute-signature&authorization-parameter conn 'POST
		 "/1/statuses/update.json"
		 :include_entities "true"
		 ;; hand modified post data...
		 :status "Hello%20Ladies%20%2B%20Gentlemen%2C%20a%20signed%20OAuth%20request%21"
		 :timestamp 1318622958
		 :nonce "kYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg"
		 :oauth_token "370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb")))
    (test-equal "tnnArxj06cWHq44gCs1OSKk/jLY=" signature))

  (test-equal "OAuth oauth_consumer_key=\"xvz1evFS4wEEPTGEFPHBog\",oauth_signature_method=\"HMAC-SHA1\",oauth_timestamp=\"1318622958\",oauth_nonce=\"kYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg\",oauth_version=\"1.0\",oauth_token=\"370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb\",oauth_signature=\"tnnArxj06cWHq44gCs1OSKk%2FjLY%3D\""
	      (oauth-authorization-header conn 'POST
	       "/1/statuses/update.json"
	       :include_entities "true"
	       :status "Hello%20Ladies%20%2B%20Gentlemen%2C%20a%20signed%20OAuth%20request%21"
	       :timestamp 1318622958
	       :nonce "kYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg"
	       :oauth_token "370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb"))
  (test-equal "oauth_consumer_key=xvz1evFS4wEEPTGEFPHBog&oauth_signature_method=HMAC-SHA1&oauth_timestamp=1318622958&oauth_nonce=kYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg&oauth_version=1.0&oauth_token=370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb&oauth_signature=tnnArxj06cWHq44gCs1OSKk%2FjLY%3D"
	      (oauth-authorization-parameter conn 'POST
	       "/1/statuses/update.json"
	       :include_entities "true"
	       :status "Hello%20Ladies%20%2B%20Gentlemen%2C%20a%20signed%20OAuth%20request%21"
	       :timestamp 1318622958
	       :nonce "kYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg"
	       :oauth_token "370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb")))

(let ((conn (make-oauth-connection
	     (make-http1-connection "api.twitter.com" #t)
	     "xvz1evFS4wEEPTGEFPHBog"
	     (make-oauth-hmac-sha1-signer
	      #*"kAcSOqF21Fu85e7zjz7ZN2U4ZRhfV3WpwPAoE3Z7kBw"
	      #*"LswwdoUaIvS8ltyTt5jkRh4J50vUPVVHtR2YPi5kE"))))
  ;; http1 connection does nothing, so no packet sending to Twitter ;)
  (test-assert (oauth-connection? (open-oauth-connection! conn)))
  (test-assert (oauth-connection? (close-oauth-connection! conn)))
  (test-assert (http-connection? (oauth-connection-http-connection conn))))

(test-end)
