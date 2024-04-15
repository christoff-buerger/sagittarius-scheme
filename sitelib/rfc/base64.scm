;;; -*- mode:scheme; coding:utf-8 -*-
;;;
;;; base64.scm - Base64 encoding/decoding routine
;;;  
;;;   Copyright (c) 2010-2024  Takashi Kato  <ktakashi@ymail.com>
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

;; ref: https://tools.ietf.org/html/rfc4648
#!nounbound
(library (rfc base64)
    (export base64-encode base64-encode-string
	    base64-decode base64-decode-string
	    
	    base64url-encode base64url-encode-string
	    base64url-decode base64url-decode-string
	    
	    open-base64-encode-output-port
	    open-base64-encode-input-port
	    open-base64url-encode-output-port
	    open-base64url-encode-input-port

	    open-base64-decode-output-port
	    open-base64-decode-input-port
	    open-base64url-decode-output-port
	    open-base64url-decode-input-port

	    ;; For custom encoder/decoder
	    (rename (*decode-table* *base64-decode-table*)
		    (*encode-table* *base64-encode-table*)
		    (*decode-url-table* *base64-decode-url-table*)
		    (*encode-url-table* *base64-encode-url-table*))
	    make-base64-decoder make-base64-encoder
	    )
    (import (rnrs)
	    (rfc base-n)
	    (sagittarius))

  (define *encode-table*
    (vector-map char->integer
       ;;0   1   2   3   4   5   6   7   8   9   10  11  12  13  14  15
     #(#\A #\B #\C #\D #\E #\F #\G #\H #\I #\J #\K #\L #\M #\N #\O #\P
       ;;16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31
       #\Q #\R #\S #\T #\U #\V #\W #\X #\Y #\Z #\a #\b #\c #\d #\e #\f
       ;;32  33  34  35  36  37  38  39  40  41  42  43  44  45  46  47
       #\g #\h #\i #\j #\k #\l #\m #\n #\o #\p #\q #\r #\s #\t #\u #\v
       ;;48  49  50  51  52  53  54  55  56  57  58  59  60  61  62  63
       #\w #\x #\y #\z #\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9 #\+ #\/
       ;;pad 
       #\= )))

  (define *decode-table*
    (base-n-encode-table->decode-table *encode-table*))

  ;; base64url
  (define *encode-url-table*
    (vector-map char->integer		
     #(;;0   1   2   3   4   5   6   7   8   9   10  11  12  13  14  15
       #\A #\B #\C #\D #\E #\F #\G #\H #\I #\J #\K #\L #\M #\N #\O #\P
       ;;16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31
       #\Q #\R #\S #\T #\U #\V #\W #\X #\Y #\Z #\a #\b #\c #\d #\e #\f
       ;;32  33  34  35  36  37  38  39  40  41  42  43  44  45  46  47
       #\g #\h #\i #\j #\k #\l #\m #\n #\o #\p #\q #\r #\s #\t #\u #\v
       ;;48  49  50  51  52  53  54  55  56  57  58  59  60  61  62  63
       #\w #\x #\y #\z #\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9 #\- #\_
       ;;pad 
       #\= )))

  (define *decode-url-table*
    (base-n-encode-table->decode-table *encode-url-table*))
  

  (define utf8-transcoder (make-transcoder (utf-8-codec) 'none))
  (define-syntax define-decode-string
    (syntax-rules ()
      ((_ name decoder)
       (define (name string :key (transcoder utf8-transcoder))
	 (or (string? string)
	     (assertion-violation 'name
				  (format "string required, but got ~s" string)
				  string))
	 (let ((bv (decoder (string->utf8 string))))
	   (if transcoder
	       (bytevector->string bv transcoder)
	       bv))))))
  (define-decode-string base64-decode-string base64-decode)
  (define-decode-string base64url-decode-string base64url-decode)

  (define-syntax define-decode
    (syntax-rules ()
      ((_ name table)
       (define (name in)
	 (if (bytevector? in)
	     (name (open-bytevector-input-port in))
	     (call-with-bytevector-output-port
	      (lambda (out)
		(base64-decode-impl in out table))))))))
  (define-decode base64-decode *decode-table*)
  (define-decode base64url-decode *decode-url-table*)

  (define (base64-decode-impl in out decode-table)
    (define (put b) (put-u8 out b))
    (define (get) (get-u8 in))
    (define decoder (make-base64-decoder :decode-table decode-table))
    (do () ((decoder get put))))
  
  ;; decode port
  (define (%base64-decode put buffer buffer-size)
    (define lshift bitwise-arithmetic-shift-left)
    (define rshift bitwise-arithmetic-shift-right)
    (define (check b) (>= b 0))
    (define (decode put b0 b1 b2 b3)
	(when (and (check b0) (check b1))
	  (put (bitwise-and (bitwise-ior (lshift b0 2) (rshift b1 4)) #xFF))
	  (when (check b2)
	    (put (bitwise-and (bitwise-ior (lshift b1 4) (rshift b2 2)) #xFF))
	    (when (check b3)
	      (put (bitwise-and (bitwise-ior (lshift b2 6)  b3) #xFF))))))
    (case buffer-size
      ;; we at least need 2 bytes ;)
      ((2) (decode put
		   (bytevector-u8-ref buffer 0)
		   (bytevector-u8-ref buffer 1)
		   -1 -1))
      ((3) (decode put
		   (bytevector-u8-ref buffer 0)
		   (bytevector-u8-ref buffer 1)
		   (bytevector-u8-ref buffer 2)
		   -1))
      ((4) (decode put
		   (bytevector-u8-ref buffer 0)
		   (bytevector-u8-ref buffer 1)
		   (bytevector-u8-ref buffer 2)
		   (bytevector-u8-ref buffer 3)))))
  (define make-base64-decoder (make-make-base-n-decoder %base64-decode 64))

  (define-syntax define-encode-string
    (syntax-rules ()
      ((_ name encoder lw pad)
       (define (name string :key (transcoder utf8-transcoder)
				 (line-width lw)
				 (padding? pad))
	 (or (string? string)
	     (assertion-violation 'name
				  (format "string required, but got ~s" string)
				  string))
	 (utf8->string
	  (encoder (string->bytevector string transcoder)
		   :line-width line-width :padding? padding?))))))
  (define-encode-string base64-encode-string base64-encode 76 #t)
  (define-encode-string base64url-encode-string base64url-encode #f #f)

  (define-syntax define-encode
    (syntax-rules ()
      ((_ name table lw pad)
       (define (name in :key (line-width lw) (padding? pad))
	 (if (bytevector? in)
	     (name (open-bytevector-input-port in) 
		   :line-width line-width :padding? padding?)
	     (let-values (((out e) (open-bytevector-output-port)))
	       (base64-encode-impl in out line-width padding? table)
	       (e)))))))
  (define-encode base64-encode *encode-table* 76 #t)
  (define-encode base64url-encode *encode-url-table* #f #f)
  
  (define (base64-encode-impl inp out line-width padding? encode-table)
    (define (put v) (put-u8 out (or v #x0a)))
    (define (get) (get-u8 inp))
    (define encoder
      (make-base64-encoder :encode-table encode-table
			   :line-width line-width
			   :padding? padding?))
    (do () ((encoder get put))))

  (define (%base64-encode put buffer buffer-size padding?)
    (define lshift bitwise-arithmetic-shift-left)
    (define rshift bitwise-arithmetic-shift-right)
    (define ior bitwise-ior)
    (define (encode b0 b1 b2)
      (when (>= b0 0)
	(put (rshift (bitwise-and #xFC b0) 2))
	(let ((b (lshift (bitwise-and #x03 b0) 4)))
	  (cond ((negative? b1) (put b) (when padding? (put 64) (put 64)))
		(else
		 (put (ior b (rshift (bitwise-and #xF0 b1) 4)))
		 (let ((b (lshift (bitwise-and #x0F b1) 2)))
		   (cond ((negative? b2) (put b) (when padding? (put 64)))
			 (else
			  (put (ior b (rshift (bitwise-and #xC0 b2) 6)))
			  (put (bitwise-and #x3F b2))))))))))
    (case buffer-size
      ((1) (encode (bytevector-u8-ref buffer 0)
		   -1
		   -1))
      ((2) (encode (bytevector-u8-ref buffer 0)
		   (bytevector-u8-ref buffer 1)
		   -1))
      ((3) (encode (bytevector-u8-ref buffer 0)
		   (bytevector-u8-ref buffer 1)
		   (bytevector-u8-ref buffer 2)))))
  (define make-base64-encoder (make-make-base-n-encoder %base64-encode 64))
  
  (define (open-base64-encode-output-port sink
					  :key (owner? #f) (line-width #f)
					       (padding? #t))
    (open-base64-encode-output-port/encode-table sink *encode-table*
      :owner? owner? :line-width line-width :padding? padding?))
  (define (open-base64url-encode-output-port sink
					     :key (owner? #f) (line-width #f)
					          (padding? #f))
    (open-base64-encode-output-port/encode-table sink *encode-url-table*
      :owner? owner? :line-width line-width :padding? padding?))

  (define open-base64-encode-output-port/encode-table
    (let ((v (make-base-n-encode-output-port-opener %base64-encode 64)))
      (lambda (sink encode-table . opts)
	(apply v sink :encode-table encode-table opts))))
  
  (define (open-base64-encode-input-port source
					 :key (owner? #f) (line-width #f)
					      (padding? #t))
    (open-base64-encode-input-port/encode-table source *encode-table*
     :owner? owner? :line-width line-width :padding? padding?))
  (define (open-base64url-encode-input-port source
					 :key (owner? #f) (line-width #f)
					      (padding? #f))
    (open-base64-encode-input-port/encode-table source *encode-url-table*
     :owner? owner? :line-width line-width :padding? padding?))
  (define open-base64-encode-input-port/encode-table
    (let ((v (make-base-n-encode-input-port-opener %base64-encode 64)))
      (lambda (source encode-table . opts)
	(apply v source :encode-table encode-table opts))))
      
  (define (open-base64-decode-input-port source :key (owner? #f))
    (open-base64-decode-input-port/decode-table source *decode-table*
						:owner? owner?))
  (define (open-base64url-decode-input-port source :key (owner? #f))
    (open-base64-decode-input-port/decode-table source *decode-url-table*
						:owner? owner?))

  (define open-base64-decode-input-port/decode-table
    (let ((v (make-base-n-decode-input-port-opener %base64-decode 64)))
      (lambda (source decode-table . opts)
	(apply v source :decode-table decode-table opts))))
  

  (define (open-base64-decode-output-port sink :key (owner? #f))
    (open-base64-decode-output-port/decode-table sink *decode-table*
						 :owner? owner?))
  (define (open-base64url-decode-output-port sink :key (owner? #f))
    (open-base64-decode-output-port/decode-table sink *decode-url-table*
						 :owner? owner?))

  (define open-base64-decode-output-port/decode-table
    (let ((v (make-base-n-decode-output-port-opener %base64-decode 64)))
      (lambda (sink decode-table . opts)
	(apply v sink :decode-table decode-table opts))))
)
