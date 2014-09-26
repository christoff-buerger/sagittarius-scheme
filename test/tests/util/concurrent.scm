(import (rnrs)
	(util concurrent)
	(srfi :18)
	(srfi :64))

(test-begin "Concurrent utilities")

(let ((executor (make-executor 1)))
  (test-assert "executor?" (executor? executor))
  (test-equal "max pool size" 1 (executor-max-pool-size executor))
  (test-equal "pool size" 0 (executor-pool-size executor))
  (test-equal "state" 'running (executor-state executor)))

(let ((future (make-future (lambda () 1))))
  (test-assert "future?" (future? future))
  (test-assert "future-done?" (not (future-done? future)))
  (test-assert "future-cancelled?" (not (future-cancelled? future)))
  (test-error "future-get" condition? (future-get future))
  (test-error "future-cancel" condition? (future-cancel future))
  )

(let ((e (make-executor 1))
      (f1 (future 1))
      (f2 (future (thread-sleep! 10)))
      (f3 (future (thread-sleep! 10))))
  (test-assert "execute" (executor? (execute-future! e f1)))
  (test-equal "future-get(1)" 1 (future-get f1))
  (test-assert "future-done? (1)" (future-done? f1))
  (test-assert "future-cancelled? (1)" (not (future-cancelled? f1)))
  (test-assert "execute(2)" (executor? (execute-future! e f2)))
  (test-assert "available?" (not (executor-available? e)))
  (test-error "exeucte(3)" rejected-execution-error? (execute-future! e f3))
  (test-equal "pool size" 1 (executor-pool-size e))
  (test-assert "future-cancel" (future-cancel f2))
  (test-assert "future-cancelled? (2)" (future-cancelled? f2))
  (test-equal "pool size" 0 (executor-pool-size e))
  )

;; shutdown
(let ((e (make-executor 3))
      (f1 (future (thread-sleep! 10)))
      (f2 (future (thread-sleep! 10)))
      (f3 (future (thread-sleep! 10))))
  (test-assert "execute(1)" (executor? (execute-future! e f1)))
  (test-assert "execute(2)" (executor? (execute-future! e f2)))
  (test-assert "exeucte(3)" (executor? (execute-future! e f3)))
  (test-equal "pool size" 3 (executor-pool-size e))
  (test-assert "shutodown" (shutdown-executor! e))
  (test-equal "pool size" 0 (executor-pool-size e))
  (test-assert "future-cancelled? (1)" (future-cancelled? f1))
  (test-assert "future-cancelled? (2)" (future-cancelled? f2))
  (test-assert "future-cancelled? (3)" (future-cancelled? f3))
  )

(let ((e (make-executor 1 terminate-oldest-handler))
      (f1 (future (thread-sleep! 10)))
      (f2 (future (thread-sleep! 10)))
      (f3 (future (thread-sleep! 10))))
  (test-assert "execute(1)" (executor? (execute-future! e f1)))
  (test-assert "execute(2)" (executor? (execute-future! e f2)))
  (test-assert "future-cancelled? (1)" (future-cancelled? f1))
  (test-assert "exeucte(3)" (executor? (execute-future! e f3)))
  (test-assert "future-cancelled? (2)" (future-cancelled? f2))
  (test-equal "pool size" 1 (executor-pool-size e))
  (test-assert "shutodown" (shutdown-executor! e))
  (test-equal "pool size" 0 (executor-pool-size e))
  (test-assert "future-cancelled? (3)" (future-cancelled? f3))
  )

;; concurrent executor 
(let* ((e (make-executor 1))
       (t1 (make-thread (lambda ()
			  (let ((f (future (thread-sleep! 5))))
			    (execute-future! e f)))))
       (t2 (make-thread (lambda ()
			  (let ((f (future (thread-sleep! 5))))
			    (execute-future! e f))))))
  ;; hope we get there
  (map thread-start! (list t1 t2))
  (thread-sleep! 0.1)
  (test-equal "pool size" 1 (executor-pool-size e))
  (test-error "failed to add" uncaught-exception?
	      ;; one of them must be failed
	      (begin (thread-join! t1) (thread-join! t2)))
  )

(test-end)
