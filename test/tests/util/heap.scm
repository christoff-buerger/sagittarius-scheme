(import (rnrs)
	(util heap)
	(srfi :64))

(test-begin "Heap")

(test-assert "pred?" (heap? (make-heap compare)))
(test-assert "pred?" (not (heap? 'foo)))
(test-assert "pred?" (not (heap? "foo")))

(let ((h (make-heap compare)))
  (test-assert "size" (zero? (heap-size h)))
  (test-assert "empty?" (heap-empty? h))
  (test-error "empty extract" error? (heap-extract-min! h))
  (test-assert "set! (1)" (heap-entry? (heap-set! h "key0" "value0")))
  (test-equal "ref" "value0" (heap-ref h "key0"))
  (test-equal "ref" #f (heap-ref h "key1"))
  (test-equal "ref (fallback)" 'fallback (heap-ref h "key1" 'fallback))

  (test-assert "set! (2)" (heap-entry? (heap-set! h "key1" "value0")))
  (test-assert "set! (3)" (heap-entry? (heap-set! h "key2" "value0")))

  ;; search
  (test-assert "search (default)" (heap-entry? (heap-search h "key2")))
  (test-equal "search (finish)" "key2" (heap-search h "key2" heap-entry-key))
  (let ((e (heap-set! h "key3" "value0")))
    (test-equal "delete! (entry)" "key3" (heap-entry-key (heap-delete! h e))))
  ;; key0, key1, key2 is there
  (test-assert "extract-min" (heap-entry? (heap-extract-min! h)))
  (test-equal "extract-min (1)" "key1" (heap-entry-key (heap-extract-min! h)))

  ;; only key2
  ;; update
  (test-equal "update!" "updated!" 
	      (heap-update! h "key2" (lambda (v) "updated!") "foo"))
  (test-equal "ref (updated)" "updated!" (heap-ref h "key2"))

  ;; key2 -> key0
  ;; decrease key
  (test-error "decrease-key!" error? (heap-decrease-key! h "key2" "key3"))
  (test-assert "decrease-key!" (heap-decrease-key! h "key2" "key0"))
  (test-equal "decreased" "updated!" (heap-ref h "key0"))
  (test-equal "decreased(2)" #f (heap-ref h "key2"))

  ;; duplicated key
  (test-assert "set!" (heap-set! h "key2" "value2"))
  (test-assert "decrease-key!" (heap-decrease-key! h "key2" "key0"))
  (test-equal "decreased" "value2" (heap-ref h "key0"))
  ;; mix up
  (heap-set! h "k0" "v0")
  (heap-set! h "k1" "v1")
  (test-assert "extract" (heap-delete! h "key0"))
  (test-equal "size" 3 (heap-size h))
  ;; it's undefined so don't depend on this
  (test-assert "decreased" (member (heap-ref h "key0") '("updated!" "value2")))
  )

;;  merge is brokwn for now...
#;
(let ((h1 (alist->heap compare '(("k0" . "v0") ("k2" . "v2") ("k4" . "v4"))))
      (h2 (alist->heap compare '(("k1" . "v1") ("k3" . "v3") ("k5" . "v5")))))

  (define (extract-ref h) (heap-entry-key (heap-extract-min! h)))
  (define (check-merge h expects)
    (let loop ((e expects) (i 0))
      (if (heap-empty? h)
	  (test-equal "count" i (length expects))
	  (begin
	    (test-equal (format "merge ~a" (car e)) (car e) (extract-ref h))
	    (loop (cdr e) (+ i 1))))))

  (test-assert "merge" (heap? (heap-merge compare h1 h2)))
  (test-assert "merge!" (heap? (heap-merge! (make-heap compare) h1 h2)))
  (let ((h3 (heap-merge compare h1 h2)))
    (check-merge h3 '("k0" "k1" "k2" "k3" "k4" "k5")))
  (let ((h3 (heap-merge! (make-heap compare) h1 h2)))
    (check-merge h3 '("k0" "k1" "k2" "k3" "k4" "k5")))
  
)

(test-end)