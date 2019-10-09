(import (rnrs)
	(text xml xpath parser)
	(sagittarius generators)
	(peg)
	(srfi :127)
	(srfi :64))

(test-begin "XPath 3.1 parser")

(define (parse-it parser text)
  (define lseq (generator->lseq (string->generator text)))
  (parser lseq))

(define (success-test parser text expected)
  (let-values (((s v nl) (parse-it parser text)))
    ;; (write v) (newline)
    (test-assert (parse-success? s))
    (test-equal text expected v)))

(success-test $xpath:for-expr "for $x in X return $x"
	      '(for (x "X") (ref x)))
(success-test $xpath:for-expr "for $x in \"X\", $y in 'Y' return $x + $y"
	      '(for (x (str "X")) (for (y (str "Y")) (+ (ref x) (ref y)))))

(success-test $xpath:expr-single "\"\"\"\"" '(str "\""))
(success-test $xpath:expr-single "''''" '(str "'"))

(success-test $xpath:expr-single "/foo/bar" '((/ "foo") (/ "bar")))
(success-test $xpath:expr-single "/foo/bar/baz"
	      '((/ "foo") (/ "bar") (/ "baz")))

(success-test $xpath:expr-single "/foo//baz" '((/ "foo") (// "baz")))
(success-test $xpath:expr-single "/" '((/)))
(success-test $xpath:expr-single "/foo" '((/ "foo")))
(success-test $xpath:expr-single "//bar" '((// "bar")))

(test-end)