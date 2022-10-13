(import (rnrs)
	(text json)
	(text json pointer)
	(util file)
	(util bytevector)
	(asn.1) ;; old...
	(srfi :13)
	(pp)
	(getopt))

(define ((file-prefix? prefix*) path)
  (let-values (((dir file ext) (decompose-path path)))
    (exists (lambda (prefix) (string-prefix? prefix file)) prefix*)))
(define signature-vector?
  (file-prefix? '("dsa" "ecdsa"
		  "rsa_pss" "rsa_sig"
		  "ed448" "eddsa")))
(define algorithm-pointer (json-pointer "/algorithm"))
(define test-groups-pointer (json-pointer "/testGroups"))

(define sha-pointer (json-pointer "/sha"))
(define key-der-pointer (json-pointer "/keyDer"))
(define tests-pointer (json-pointer "/tests"))
(define mgf-pointer (json-pointer "/mgf"))
(define mgf-sha-pointer (json-pointer "/mgfSha"))
(define slen-pointer (json-pointer "/sLen"))
(define type-pointer (json-pointer "/type"))
(define (->signature-test-vector json source)
  (define (test->vector test)
    (list->vector
     (map (lambda (e)
	    (let ((k (car e)))
	      (cond ((string=? k "msg") (hex-string->bytevector (cdr e)))
		    ((string=? k "sig") (hex-string->bytevector (cdr e)))
		    ((string=? k "result")
		     (or (string=? "valid" (cdr e))
			 (string=? "acceptable" (cdr e))))
		    (else (cdr e)))))
	  (vector->list test))))
  (define (mgf json)
    (let ((mgf (mgf-pointer json))
	  (mgf-sha (mgf-sha-pointer json))
	  (slen (slen-pointer json)))
      `(:mgf ,mgf
	:mgf-digest ,mgf-sha
	:salt-length ,slen)))
  (define (p1363? type) (string-contains type "P1363"))
  (define (filename source)
    (let-values (((dir f e) (decompose-path source)))
      f))
  (define ((make-test-runner source algorithm) json)
    (let ((sha (sha-pointer json))
	  (key-der (key-der-pointer json))
	  (tests (tests-pointer json))
	  (type (type-pointer json)))
      
      `(test-signature/testvector ,(filename source)
	:algorithm ,algorithm
	,@(if (json-pointer-not-found? sha)
	      '()
	      `(:digest ,sha))
	:public-key ,(hex-string->bytevector key-der)
	,@(if (string=? algorithm "RSASSA-PSS")
	      (mgf json)
	      '())
	:der-encode ,(not (p1363? type))
	:tests  ',(map test->vector tests))))
  (print "Making testvector from " source)
  (let ((algorithm (algorithm-pointer json))
	(test-groups (test-groups-pointer json)))
    (map (make-test-runner source algorithm) test-groups)))

(define ((write-in base dir) file&json*)
  (define outdir (build-path base dir))
  (unless (file-exists? outdir) (create-directory* outdir))
  (let-values (((d name e) (decompose-path (car file&json*))))
    (let ((file (build-path outdir (string-append name ".scm"))))
      (when (file-exists? file) (delete-file file))
      (call-with-output-file file
	(lambda (out)
	  (for-each (lambda (json) (pp json out)) (cdr file&json*))))
      (build-path* "." dir (string-append name ".scm")))))

(define (write-includer outdir type files)
  (let ((file (build-path outdir (string-append type ".scm"))))
    (when (file-exists? file) (delete-file file))
    (call-with-output-file file
      (lambda (out)
	(for-each (lambda (f) (write `(include ,f) out) (newline out))
		  files)))))

(define ((file->json conv) file)
  (cons file (conv (call-with-input-file file json-read) file)))
(define ((write-test-vectors outdir) in-dir)
  (let ((files (find-files in-dir :recursive #f :pattern "\\.json$")))
    (write-includer outdir "signature"
     (map (write-in outdir (build-path "testvectors" "signature"))
	  (map (file->json ->signature-test-vector)
	       (filter signature-vector? files))))))

(define (usage me)
  (print me "[OPTIONS] dir ...")
  (print "OPTIONS")
  (print " -h, --help")
  (print "  show this message and quit")
  (print " -o $OUTPUT, --output=$OUTPUT")
  (print "  specifying output directory [required]")
  (exit -1))

(define (main args)
  (with-args (cdr args)
      ((verbose (#\v "verbose") #f #f)
       (help?   (#\h "help") #f #f)
       (output  (#\o "output") #t #f)
       . dir)
    (when (or help? (null? dir) (not output)) (usage (car args)))
    (for-each (write-test-vectors output) dir)))
    
