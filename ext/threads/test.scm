;; -*- scheme -*-

;; testing mutil thread
(library (threads test)
    (export run-threads-test)
    (import (srfi :64 testing)
	    (rnrs)
	    (sagittarius threads))

  (define (run-threads-test)
    (test-begin "base64-test")
    (let ((t (make-thread (lambda () 'thread-1)
			  'thread-1)))
      (test-assert 'thread? (thread? t))
      (test-equal "thread name" (thread-name t) 'thread-1)
      (test-equal "thread state new" (thread-state t) 'new)
      (let ((t (thread-start! t)))
	(test-assert "thread-start" (thread? t))
	(thread-join! t) ;; just in case
	(test-equal "thread state terminated" (thread-state t) 'terminated)))
    (test-end))
)