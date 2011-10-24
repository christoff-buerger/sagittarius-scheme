;; -*- scheme -*-
(import (srfi :64)
	(tests sagittarius)
	(tests r6rs+ vector)
	(tests r6rs+ string)
	(tests r6rs+ lists)
	(tests srfi :13)
	(tests srfi :14)
	(tests srfi :41)
	(tests srfi :42)
	(tests rfc base64)
	(tests rfc quoted-printable)
	(tests rfc mime)
	;; text
	(tests text sxml ssax)
	(tests text sxml sxpath)
	(tests text sxml serializer)
	(tests text sxml htmlprag))
;; srfi-64 default implementation does not report detail error.
;; so creates own test-runner
(define (test-on-test-end-detail runner)
  (define (%test-write-result1 pair port)
    (display "  " port)
    (display (car pair) port)
    (display ": " port)
    (write (cdr pair) port)
    (newline port))
  (let ((log  (test-runner-aux-value runner))
	(kind (test-result-ref runner 'result-kind)))
    (when (memq kind '(xpass fail))
      (let* ((results (test-result-alist runner))
	     (source-file (assq 'source-file results))
	     (source-line (assq 'source-line results))
	     (test-name (assq 'test-name results)))
	(when (or source-file source-line)
	  (if source-file (display (cdr source-file)))
	  (display ":")
	  (if source-line (display (cdr source-line)))
	  (display ":"))
	(display (if (eq? kind 'xpass) "XPASS" "FAIL"))
	(when test-name
	  (display " ")(display (cdr test-name)))
	(newline))
      (let ((expected (test-result-ref runner 'expected-value))
	    (actual   (test-result-ref runner 'actual-value)))
	(display #\tab)(display "expected value: ")(write expected)(newline)
	(display #\tab)(display "  actual value: ")(write actual)(newline)))
    (when (output-port? log)
      (display "Test end:" log)
      (newline log)
      (let loop ((list (test-result-alist runner)))
	(if (pair? list)
	    (let ((pair (car list)))
	      ;; Write out properties not written out by on-test-begin.
	      (if (not (memq (car pair)
			     '(test-name source-file source-line source-form)))
		  (%test-write-result1 pair log))
	      (loop (cdr list))))))))

(define (test-runner-detail)
  (let ((runner (test-runner-simple)))
      (test-runner-on-test-end! runner test-on-test-end-detail)
      runner))

(test-runner-factory test-runner-detail)

(test-begin "sagittarius functionality tests start")
(run-sagittarius-tests)
(run-r6rs+-vector-tests)
(run-r6rs+-string-tests)
(run-r6rs+-lists-tests)
(run-srfi-13-tests)
(run-srfi-14-tests)
(run-srfi-41-tests)
(run-srfi-42-tests)
(run-rfc-base64-tests)
(run-rfc-quoted-printable-tests)
(run-rfc-mime-test)
(run-ssax-test)
(run-sxpath-test)
(run-serializer-test)
(run-htmlprag-test)
(test-end)