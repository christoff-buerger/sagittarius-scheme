;; -*- scheme -*-

;; testing mutil thread
;; this file will be called from one upper
;; so load path must be like this
(add-load-path "./threads/")
(add-load-path "./time/")
(library (threads test)
    (export run-threads-test)
    (import (srfi :64 testing)
	    (rnrs)
	    (sagittarius threads)
	    (sagittarius time))

  (define (run-threads-test)
    ;; most test cases are from Gauche 
    ;; basic API
    (test-assert "current-thread" (eq? (current-thread) (current-thread)))
    (test-equal "thread?" '(#t #f) (list (thread? (current-thread))
					 (thread? 'foo)))
    (test-assert "make-thread" (thread? (make-thread (lambda () #f))))
    (test-equal "thread-name" 'foo (thread-name (make-thread (lambda () #f) 'foo)))
    (test-equal "thread-specific" "hello"
		(begin
		  (thread-specific-set! (current-thread) "hello")
		  (thread-specific (current-thread))))

    (test-equal "thread-start!" "hello"
		(call-with-string-output-port
		 (lambda (p)
		   (let ((t (thread-start! (make-thread (lambda () (display "hello" p))))))
		     (thread-join! t)))))

    ;; calculate fibonacchi in awful way
    (let ()
      (define (mt-fib n)
	(let ((threads (make-vector n)))
	  (let loop ((i 0))
	    (unless (= i n)
	      (vector-set! threads i
			   (make-thread
			    (case i
			      ((0) (lambda () 1))
			      ((1) (lambda () 1))
			      (else (lambda () (+ (thread-join! (vector-ref threads (- i 1)))
						  (thread-join! (vector-ref threads (- i 2)))))))))
	      (loop (+ i 1))))
	  (let loop ((i 0))
	    (unless (= i n)
	      (thread-start! (vector-ref threads (- n i 1)))
	      (loop (+ i 1))))
	  (thread-join! (vector-ref threads (- n 1)))))
      (test-equal "thread-join!" 1346269 (mt-fib 31)))
    (let ((t1 (make-thread (lambda ()
			     (let loop ()
			       (sys-nanosleep #e5e8)
			       (loop))))))
      (test-equal "thread-state" 'new (thread-state t1))
      (thread-start! t1)
      (test-equal "thread-state" 'runnable (thread-state t1))
      (thread-stop! t1)
      (test-equal "thread-state" 'stopped (thread-state t1))
      (thread-stop! t1) ;; duplicate stop test
      (test-equal "thread-state" 'stopped (thread-state t1))
      (thread-cont! t1)
      (test-equal "thread-state" 'runnable (thread-state t1))
      (thread-terminate! t1)
      (test-equal "thread-state" 'terminated
		  (thread-guard (e 
				 ((terminated-thread-exception? e)
				  (thread-state t1))
				 (else
				  (print e)))
		    (thread-join! t1))))

    ;; thread and error
    (test-assert "uncaught-exception"
		 (let ((t (make-thread (lambda () (assertion-violation 'who "foo")))))
		   (thread-start! t)
		   (with-error-handler
		     (lambda (e)
		       (and (uncaught-exception? e)
			    ((condition-predicate &assertion) (uncaught-exception-reason e))))
		     (lambda () (thread-join! t)))))

    (test-assert "uncaught-exception"
		 (let ((t (make-thread (lambda () (raise 4)))))
		   (thread-start! t)
		   (with-error-handler
		     (lambda (e)
		       (and (uncaught-exception? e)
			    (eqv? (uncaught-exception-reason e) 4)))
		     (lambda () (thread-join! t)))))

    (test-assert "uncaught-exception"
		 (let ((t (make-thread (lambda ()
					 (with-error-handler
					   (lambda (e) e)
					   (lambda () (assertion-violation 'who "foo")))))))
		   (thread-start! t)
		   (with-error-handler
		     (lambda (e) e)
		     (lambda () ((condition-predicate &assertion)
				 (thread-join! t))))))
		 
    (let ((m (make-mutex 'mutex-1)))
      (test-assert 'mutex? (mutex? m))
      (test-equal "mutex name" (mutex-name m) 'mutex-1)
      (mutex-specific-set! m 'specific-data)
      (test-equal "mutex specific" (mutex-specific m) 'specific-data)
      (test-equal "mutex state" (mutex-state m) 'not-abandoned)
      (test-assert "mutex locked" (mutex-lock! m))
      (test-equal "mutex state 2" (mutex-state m) (current-thread))
      (test-assert "mutex unlocked" (mutex-unlock! m))
      )

    (test-equal "lock and unlock - blocking (simple spin-lock)" 
		'((put a) (get a) (put b) (get b) (put c) (get c))
		(let ((log '())
		      (cell #f)
		      (m (make-mutex)))
		  (define (put! msg)
		    (mutex-lock! m)
		    (if cell
			(begin (mutex-unlock! m) (put! msg))
			(begin (set! cell msg)
			       (set! log (cons `(put ,msg) log))
			       (mutex-unlock! m))))
		  (define (get!)
		    (mutex-lock! m)
		    (if cell
			(let ((r cell))
			  (set! cell #f)
			  (set! log (cons `(get ,r) log))
			  (mutex-unlock! m)
			  r)
			(begin (mutex-unlock! m) (get!))))
		  (define (producer)
		    (put! 'a)
		    (put! 'b)
		    (put! 'c))
		  (define (consumer)
		    (get!)
		    (get!)
		    (get!))
		  (let ((tp (thread-start! (make-thread producer 'producer)))
			(tc (thread-start! (make-thread consumer 'consumer))))
		    (thread-join! tp)
		    (thread-join! tc)
		    (reverse log))))

    (test-equal "lock with timeout"
		'(#t #f #f #t #t)
		(let ((m (make-mutex)))
		  (let* ((r0 (mutex-lock! m))
			 (r1 (mutex-lock! m 0))
			 (r2 (mutex-lock! m 0.05))
			 ;; we do not support time object for mutex-lock
			 ;;(r3 (mutex-lock! m (seconds->time (+ (time->seconds (current-time)) 0.05))))
			 ;;(r4 (mutex-lock! m (seconds->time (- (time->seconds (current-time)) 0.05))))
			 (r5 (mutex-unlock! m))
			 (r6 (mutex-lock! m 0)))
		    (mutex-unlock! m)
		    (list r0 r1 r2 #;r3 #;r4 r5 r6))))

    )
)