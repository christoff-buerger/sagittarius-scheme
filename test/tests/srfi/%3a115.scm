(import (rnrs) (core base) (srfi :64) (srfi :115))

(define-syntax test
  (syntax-rules ()
    ((_ expect actual)
     (test-equal 'expect expect actual))))

(define (maybe-match->sexp rx str . o)
  (guard (e (else (print (condition-message e)
			 (condition-irritants e)))) (regexp rx))
  (let ((res (apply regexp-matches rx str o)))
    (and res (regexp-match->list res))))

(define-syntax test-re
  (syntax-rules ()
    ((test-re res rx str start end)
     (test res (maybe-match->sexp rx str start end)))
    ((test-re res rx str start)
     (test-re res rx str start (string-length str)))
    ((test-re res rx str)
     (test-re res rx str 0))))

(define (maybe-search->sexp rx str . o)
  (let ((res (apply regexp-search rx str o)))
    (and res (regexp-match->list res))))

(define-syntax test-re-search
  (syntax-rules ()
    ((test-re-search res rx str start end)
     (test res (maybe-search->sexp rx str start end)))
    ((test-re-search res rx str start)
     (test-re-search res rx str start (string-length str)))
    ((test-re-search res rx str)
     (test-re-search res rx str 0))))

(test-begin "SRFI-115 regexp")

(test-re '("ababc" "abab")
         '(: ($ (* "ab")) "c")
         "ababc")

(test-re '("ababc" "abab")
         '(: ($ (* "ab")) "c")
         "xababc"
         1)

(test-re-search '("y") '(: "y") "xy")

(test-re-search '("ababc" "abab")
                '(: ($ (* "ab")) "c")
                "xababc")

(test-re #f
         '(: (* any) ($ "foo" (* any)) ($ "bar" (* any)))
         "fooxbafba")

(test-re '("fooxbarfbar" "fooxbarf" "bar")
         '(: (* any) ($ "foo" (* any)) ($ "bar" (* any)))
         "fooxbarfbar")

(test-re '("abcd" "abcd")
         '($ (* (or "ab" "cd")))
         "abcd")

;; out of SRFI
;; first match is a list of ab's, second match is the last (temporary) cd
;; (test-re '("abcdc" (("ab") ("cd")) "cd")
;;          '(: (* (*$ (or "ab" "cd"))) "c")
;;          "abcdc")
(test "ab"
    (regexp-match-submatch
     (regexp-matches '(or (-> foo "ab") (-> foo "cd")) "ab")
     'foo))

(test "cd"
    (regexp-match-submatch
     (regexp-matches '(or (-> foo "ab") (-> foo "cd")) "cd")
     'foo))

(test-re '("ababc" "abab")
         '(: bos ($ (* "ab")) "c")
         "ababc")
(test-re '("ababc" "abab")
         '(: ($ (* "ab")) "c" eos)
         "ababc")
(test-re '("ababc" "abab")
         '(: bos ($ (* "ab")) "c" eos)
         "ababc")
(test-re #f
         '(: bos ($ (* "ab")) eos "c")
         "ababc")
(test-re #f
         '(: ($ (* "ab")) bos "c" eos)
         "ababc")

(test-re '("ababc" "abab")
         '(: bol ($ (* "ab")) "c")
         "ababc")
(test-re '("ababc" "abab")
         '(: ($ (* "ab")) "c" eol)
         "ababc")
(test-re '("ababc" "abab")
         '(: bol ($ (* "ab")) "c" eol)
         "ababc")
(test-re #f
         '(: bol ($ (* "ab")) eol "c")
         "ababc")
(test-re #f
         '(: ($ (* "ab")) bol "c" eol)
         "ababc")
(test-re '("\nabc\n" "abc")
         '(: (* #\newline) bol ($ (* alpha)) eol (* #\newline))
         "\nabc\n")
(test-re #f
         '(: (* #\newline) bol ($ (* alpha)) eol (* #\newline))
         "\n'abc\n")
(test-re #f
         '(: (* #\newline) bol ($ (* alpha)) eol (* #\newline))
         "\nabc.\n")

(test-re '("ababc" "abab")
         '(: bow ($ (* "ab")) "c")
         "ababc")
(test-re '("ababc" "abab")
         '(: ($ (* "ab")) "c" eow)
         "ababc")
(test-re '("ababc" "abab")
         '(: bow ($ (* "ab")) "c" eow)
         "ababc")
(test-re #f
         '(: bow ($ (* "ab")) eow "c")
         "ababc")
(test-re #f
         '(: ($ (* "ab")) bow "c" eow)
         "ababc")
(test-re '("  abc  " "abc")
         '(: (* space) bow ($ (* alpha)) eow (* space))
         "  abc  ")
(test-re #f
         '(: (* space) bow ($ (* alpha)) eow (* space))
         " 'abc  ")
(test-re #f
         '(: (* space) bow ($ (* alpha)) eow (* space))
         " abc.  ")

(test-re-search '("foo") '(: "foo") " foo ")
(test-re-search #f '(: nwb "foo" nwb) " foo ")
(test-re-search '("foo") '(: nwb "foo" nwb) "xfoox")

(test-re '("beef")
         '(* (/"af"))
         "beef")

(test-re '("12345beef" "beef")
         '(: (* digit) ($ (* (/"af"))))
         "12345beef")

(let ((number '($ (+ digit))))
  (test '("555" "867" "5309")
      (cdr
       (regexp-match->list
        (regexp-search `(: ,number "-" ,number "-" ,number)
                       "555-867-5309"))))
  (test '("555" "5309")
      (cdr
       (regexp-match->list
        (regexp-search `(: ,number "-" (w/nocapture ,number) "-" ,number)
                       "555-867-5309")))))

(test-re '("12345BeeF" "BeeF")
         '(: (* digit) (w/nocase ($ (* (/"af")))))
         "12345BeeF")

(test-re #f '(* lower) "abcD")

(test-re '("abcD") '(w/nocase (* lower)) "abcD")
(test-re '("σζ") '(* lower) "σζ")
(test-re '("Σ") '(* upper) "Σ")
(test-re '("\x01C5;") '(* title) "\x01C5;")
(test-re '("σζ\x01C5;") '(w/nocase (* lower)) "σζ\x01C5;")

(test-re '("кириллица") '(* alpha) "кириллица")
(test-re #f '(w/ascii (* alpha)) "кириллица")

(test-re '("１２３４５") '(* digit) "１２３４５")
(test-re #f '(w/ascii (* digit)) "１２３４５")

(test-re '("한") 'grapheme "한")
(test-re '("글") 'grapheme "글")

(test-re '("한") '(: bog grapheme eog) "한")
(test-re #f '(: "ᄒ" bog grapheme eog "ᆫ") "한")

(test '("123" "456" "789") (regexp-extract '(+ digit) "abc123def456ghi789"))
(test '("123" "456" "789") (regexp-extract '(* digit) "abc123def456ghi789"))
(test '("abc" "def" "ghi") (regexp-split '(+ digit) "abc123def456ghi789"))

;; *** ditto
(test '("a" "b" "c" "d" "e" "f" "g" "h" "i")
      (regexp-split '(* digit) "abc123def456ghi789"))

(test '("a" "b") (regexp-split '(+ whitespace) "a b"))

(test '("한" "글")
    (regexp-extract
     'grapheme
     (utf8->string '#u8(#xe1 #x84 #x92 #xe1 #x85 #xa1 #xe1 #x86 #xab
                        #xe1 #x84 #x80 #xe1 #x85 #xb3 #xe1 #x86 #xaf))))

(test "abc def" (regexp-replace '(+ space) "abc \t\n def" " "))

(test "  abc-abc"
    (regexp-replace '(: ($ (+ alpha)) ":" (* space)) "  abc: " '(1 "-" 1)))
(test "  abc-  abc"
    (regexp-replace '(: ($ (+ alpha)) ":" (* space)) "  abc: " '(1 "-" pre 1)))

(test "-abc \t\n d ef  "
    (regexp-replace '(+ space) "  abc \t\n d ef  " "-" 0))
(test "-abc \t\n d ef  "
    (regexp-replace '(+ space) "  abc \t\n d ef  " "-" 0 #f 0))
(test "  abc-d ef  "
    (regexp-replace '(+ space) "  abc \t\n d ef  " "-" 0 #f 1))
(test "  abc \t\n d-ef  "
    (regexp-replace '(+ space) "  abc \t\n d ef  " "-" 0 #f 2))
(test "  abc \t\n d ef-"
    (regexp-replace '(+ space) "  abc \t\n d ef  " "-" 0 #f 3))
(test "  abc \t\n d ef  "
    (regexp-replace '(+ space) "  abc \t\n d ef  " "-" 0 #f 4))

(test " abc d ef " (regexp-replace-all '(+ space) "  abc \t\n d ef  " " "))

(let* ((elapsed '(: (** 1 2 num) ":" num num (? ":" num num))))
  (test-equal "dynamic SRE problem"
	      "1:45:02-2:06:13"
	      (let ((span (rx ,elapsed (: "-") ,elapsed)))
		(regexp-match-submatch (regexp-search span " 1:45:02-2:06:13 ")
				       0))))
;; this causes macro expansion error.
;; FIXME
#;
(test-equal "dynamic SRE problem"
	    "1:45:02-2:06:13"
	    (let* ((elapsed '(: (** 1 2 num) ":" num num (? ":" num num)))
		   (span (rx ,elapsed "-" ,elapsed)))
	      (regexp-match-submatch (regexp-search span " 1:45:02-2:06:13 ")
				     0)))

(test-end)
