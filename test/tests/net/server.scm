(import (rnrs)
	(net server)
	(sagittarius socket)
	(srfi :18)
	(srfi :64))

(test-begin "Simple server framework")

(let ()
  (define (handler socket)
    (let ((bv (socket-recv socket 255)))
      (socket-send socket bv)))
  (define server (make-simple-server "5000" handler))
  (define server-thread (make-thread (lambda () (start-server! server))))
  ;; wait until it's started
  (thread-start! server-thread)
  (thread-sleep! 0.1)
  (let ((sock (make-client-socket "localhost" "5000")))
    (socket-send sock (string->utf8 "hello"))
    (test-equal "echo back" (string->utf8 "hello") (socket-recv sock 255))
    (socket-close sock))
  (test-assert "stop server" (stop-server! server))
  (test-assert "finish simple server" (thread-join! server-thread))
)

;; multi threading server
(let ()
  (define config (make-server-config :shutdown-port "8888"
				     :exception-handler (lambda (e s) (print e))
				     :max-thread 5))
  (define (handler socket)
    (let ((bv (socket-recv socket 255)))
      (socket-send socket bv)))
  (define server (make-simple-server "5000" handler config))
  (define server-thread (make-thread (lambda () (start-server! server))))
  (thread-start! server-thread)
  (thread-sleep! 0.1)
  (let ((t* (map (lambda (_)
		 (make-thread
		  (lambda ()
		    (define sock (make-client-socket "localhost" "5000"))
		    (thread-sleep! 0.2)
		    (socket-send sock (string->utf8 "hello"))
		    (let ((r (utf8->string (socket-recv sock 255))))
		      (socket-close sock)
		      r))))
		 ;; more than max thread
		 '(1 2 3 4 5 6 7 8 9 10))))
    (test-equal "multi threaded server"
		'("hello" "hello" "hello" "hello" "hello"
		  "hello" "hello" "hello" "hello" "hello")
		(map thread-join! (map thread-start! t*))))
  ;; stop server by accessing shutdown port
  (make-client-socket "localhost" "8888")
  (thread-sleep! 0.2)
  (test-assert "server-stopped?" (server-stopped? server))
)

(test-end)