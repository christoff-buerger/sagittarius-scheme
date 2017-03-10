;;; Copyright (C) William D Clinger (2016).
;;; 
;;; Permission is hereby granted, free of charge, to any person
;;; obtaining a copy of this software and associated documentation
;;; files (the "Software"), to deal in the Software without
;;; restriction, including without limitation the rights to use,
;;; copy, modify, merge, publish, distribute, sublicense, and/or
;;; sell copies of the Software, and to permit persons to whom the
;;; Software is furnished to do so, subject to the following
;;; conditions:
;;; 
;;; The above copyright notice and this permission notice shall be
;;; included in all copies or substantial portions of the Software.
;;; 
;;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
;;; OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
;;; NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
;;; HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
;;; WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
;;; FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
;;; OTHER DEALINGS IN THE SOFTWARE. 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Tests for immutable texts.
;;;
;;; To run in Larceny, Sagittarius, or Chibi,
;;; cd to the directory containing this file and incant:
;;;
;;;     larceny --r7rs --path . --program texts-test.sps
;;;     sagittarius -c -r7 -L . texts-test.sps
;;;     chibi-scheme -I . texts-test.sps
;;;
;;; Larceny, Sagittarius, and Chibi will look for the (srfi ???)
;;; library in the srfi subdirectory.

;; For Sagittarius tests
;; (import (scheme base)
;;         (scheme write)
;;         (scheme char)
;;         (srfi 135))
;; 
;; (define (writeln . xs)
;;   (for-each display xs)
;;   (newline))
;; 
;; (define (fail token . more)
;;   (newline)
;;   (writeln "Error: test failed: " token)
;;   (display " ")
;;   (write current-test)
;;   (newline)
;;   #f)

;;; To display tests that fail, change "(or " to "(OR ".
;;; To display tests before they are run, uncomment the write below.

;;(define current-test #f)
;;
;;(define-syntax OR
;;  (syntax-rules ()
;;    ((_ expr1 expr ...)
;;     (begin (set! current-test 'expr1)
;;            ;;          (write current-test)
;;            ;;          (newline)
;;            (or expr1 expr ...)))))

(import (rnrs)
	(rnrs mutable-strings)
	(sagittarius)
	(srfi :135 texts)
	(srfi :64))

(test-begin "SRFI-135: Immutable Texts")
(define-syntax writeln 
  (syntax-rules ()
    ((_ ignore) (test-end))))

(define-syntax OR
  (syntax-rules (fail)
    ((_ exprs ... (fail name))
     (test-assert 'name (or exprs ...)))))
(define open-input-string open-string-input-port)

;;; Help functions for testing.

(define (as-text . args)
  (textual-concatenate (map (lambda (x)
                              (cond ((text? x) x)
                                    ((string? x) (string->text x))
                                    ((char? x) (text x))
                                    (else
                                     (error "as-text: illegal argument" x))))
                            args)))

(define (result=? str txt)
  (and (text? txt)
       (textual=? str txt)))

;;; Unicode is a strong motivation for immutable texts, so we ought
;;; to use at least some non-ASCII strings for testing.
;;; Some systems would blow up if this file were to contain non-ASCII
;;; characters, however, so we have to be careful here.
;;;
;;; FIXME: need more tests with really high code points

(cond-expand ((or sagittarius
                  chibi
                  full-unicode-strings)
              (define ABC
                (as-text
                 (list->string (map integer->char
                                    '(#x3b1 #x3b2 #x3b3)))))
              (define ABCDEF
                (as-text
                 (list->string (map integer->char
                                    '(#x0c0 #x062 #x0c7 #x064 #x0c9 #x066)))))
              (define DEFABC
                (as-text
                 (list->string (map integer->char
                                    '(#x064 #x0c9 #x066 #x0c0 #x062 #x0c7)))))
              (define eszett (integer->char #xDF))
              (define fuss (text #\F #\u eszett))
              (define chaos0
                (as-text
                 (list->string (map integer->char
                                    '(#x39E #x391 #x39F #x3A3)))))
              (define chaos1
                (as-text
                 (list->string (map integer->char
                                    '(#x3BE #x3B1 #x3BF #x3C2)))))
              (define chaos2
                (as-text
                 (list->string (map integer->char
                                    '(#x3BE #x3B1 #x3BF #x3C3)))))
              (define beyondBMP
                (as-text
                 (list->string (map integer->char
                                    '(#x61 #xc0 #x3bf
                                           #x1d441 #x1d113 #x1d110 #x7a))))))
             (else
              (define ABC (as-text "abc"))
              (define ABCDEF (as-text "ABCdef"))
              (define DEFABC (as-text "defabc"))))


;;; Predicates

(OR (text? (text))
    (fail 'text?))

(OR (not (text? (string)))
    (fail 'text?))

(OR (not (text? #\a))
    (fail 'text?))

(OR (textual? (text))
    (fail 'textual?))

(OR (textual? (string))
    (fail 'textual?))

(OR (not (textual? #\a))
    (fail 'textual?))

(OR (textual-null? (text))
    (fail 'textual-null?))

(OR (not (textual-null? ABC))
    (fail 'textual-null?))


(OR (eqv? #t (textual-every (lambda (c) (if (char? c) c #f))
                            (text)))
    (fail 'textual-every))

(OR (eqv? #\c (textual-every (lambda (c) (if (char? c) c #f))
                             (as-text "abc")))
    (fail 'textual-every))

(OR (eqv? #f (textual-every (lambda (c) (if (char>? c #\b) c #f))
                            (as-text "abc")))
    (fail 'textual-every))

(OR (eqv? #\c (textual-every (lambda (c) (if (char>? c #\b) c #f))
                             (as-text "abc") 2))
    (fail 'textual-every))

(OR (eqv? #t (textual-every (lambda (c) (if (char>? c #\b) c #f))
                            (as-text "abc") 1 1))
    (fail 'textual-every))

(OR (eqv? #f (textual-any (lambda (c) (if (char? c) c #f))
                          (text)))
    (fail 'textual-any))

(OR (eqv? #\a (textual-any (lambda (c) (if (char? c) c #f))
                           (as-text "abc")))
    (fail 'textual-any))

(OR (eqv? #\c (textual-any (lambda (c) (if (char>? c #\b) c #f))
                           (as-text "abc")))
    (fail 'textual-any))

(OR (eqv? #\c (textual-any (lambda (c) (if (char>? c #\b) c #f))
                           (as-text "abc") 2))
    (fail 'textual-any))

(OR (eqv? #f (textual-any (lambda (c) (if (char>? c #\b) c #f))
                          (as-text "abc") 0 2))
    (fail 'textual-any))


(OR (eqv? #t (textual-every (lambda (c) (if (char? c) c #f)) ""))
    (fail 'textual-every))

(OR (eqv? #\c (textual-every (lambda (c) (if (char? c) c #f)) "abc"))
    (fail 'textual-every))

(OR (eqv? #f (textual-every (lambda (c) (if (char>? c #\b) c #f)) "abc"))
    (fail 'textual-every))

(OR (eqv? #\c (textual-every (lambda (c) (if (char>? c #\b) c #f)) "abc" 2))
    (fail 'textual-every))

(OR (eqv? #t (textual-every (lambda (c) (if (char>? c #\b) c #f)) "abc" 1 1))
    (fail 'textual-every))

(OR (eqv? #f (textual-any (lambda (c) (if (char? c) c #f)) ""))
    (fail 'textual-any))

(OR (eqv? #\a (textual-any (lambda (c) (if (char? c) c #f)) "abc"))
    (fail 'textual-any))

(OR (eqv? #\c (textual-any (lambda (c) (if (char>? c #\b) c #f)) "abc"))
    (fail 'textual-any))

(OR (eqv? #\c (textual-any (lambda (c) (if (char>? c #\b) c #f)) "abc" 2))
    (fail 'textual-any))

(OR (eqv? #f (textual-any (lambda (c) (if (char>? c #\b) c #f)) "abc" 0 2))
    (fail 'textual-any))


;;; Constructors

(OR (result=? ""
              (text-tabulate (lambda (i)
                               (integer->char (+ i (char->integer #\a))))
                             0))
    (fail 'text-tabulate))

(OR (result=? "abc"
              (text-tabulate (lambda (i)
                               (integer->char (+ i (char->integer #\a))))
                             3))
    (fail 'text-tabulate))


(OR (result=? "abc"
              (let ((p (open-input-string "abc")))
                (text-unfold eof-object?
                             values
                             (lambda (x) (read-char p))
                             (read-char p))))
    (fail 'text-unfold))

(OR (result=? "" (text-unfold null? car cdr '()))
    (fail 'text-unfold))

(OR (result=? "abc"
              (text-unfold null? car cdr (string->list "abc")))
    (fail 'text-unfold))

(OR (result=? "def"
              (text-unfold null? car cdr '() (string->text "def")))
    (fail 'text-unfold))

(OR (result=? "defabcG"
              (text-unfold null?
                           car
                           cdr
                           (string->list "abc")
                           (string->text "def")
                           (lambda (x) (if (null? x) (text #\G) ""))))
    (fail 'text-unfold))

(OR (result=? "" (text-unfold-right null? car cdr '()))
    (fail 'text-unfold-right))

(OR (result=? "cba"
              (text-unfold-right null? car cdr (string->list "abc")))
    (fail 'text-unfold-right))

(OR (result=? "def"
              (text-unfold-right null? car cdr '() (string->text "def")))
    (fail 'text-unfold-right))

(OR (result=? "Gcbadef"
              (text-unfold-right null?
                                 car
                                 cdr
                                 (string->list "abc")
                                 (string->text "def")
                                 (lambda (x) (if (null? x) (text #\G) ""))))
    (fail 'text-unfold-right))


(OR (result=? "def"
              (text-unfold null? car cdr '() "def"))
    (fail 'text-unfold))

(OR (result=? "defabcG"
              (text-unfold null?
                           car
                           cdr
                           (string->list "abc")
                           "def"
                           (lambda (x) (if (null? x) "G" ""))))
    (fail 'text-unfold))

(OR (result=? "dabcG"
              (text-unfold null?
                           car
                           cdr
                           (string->list "abc")
                           #\d
                           (lambda (x) (if (null? x) "G" ""))))
    (fail 'text-unfold))

(OR (result=? (string-append "%="
                             (make-string 200 #\*)
                             "A B C D E F G H I J K L M "
                             "N O P Q R S T U V W X Y Z "
                             (make-string (* 200 (- (char->integer #\a)
                                                    (char->integer #\Z)
                                                    1))
                                          #\*)
                             "abcdefghijklmnopqrstuvwxyz"
                             " ")
              (text-unfold (lambda (n) (char>? (integer->char n) #\z))
                           (lambda (n)
                             (let ((c (integer->char n)))
                               (cond ((char<=? #\a c #\z) c)
                                     ((char<=? #\A c #\Z) (text c #\space))
                                     (else (make-string 200 #\*)))))
                           (lambda (n) (+ n 1))
                           (char->integer #\@)
                           "%="
                           (lambda (n) #\space)))
    (fail 'text-unfold))

(OR (result=? "def"
              (text-unfold-right null? car cdr '() "def"))
    (fail 'text-unfold-right))

(OR (result=? "Gcbadef"
              (text-unfold-right null?
                                 car
                                 cdr
                                 (string->list "abc")
                                 "def"
                                 (lambda (x) (if (null? x) "G" ""))))
    (fail 'text-unfold-right))

(OR (result=? "Gcbad"
              (text-unfold-right null?
                                 car
                                 cdr
                                 (string->list "abc")
                                 #\d
                                 (lambda (x) (if (null? x) "G" ""))))
    (fail 'text-unfold-right))

(OR (result=? (string-append " "
                             (list->string
                              (reverse
                               (string->list "abcdefghijklmnopqrstuvwxyz")))
                             (make-string (* 200 (- (char->integer #\a)
                                                    (char->integer #\Z)
                                                    1))
                                          #\*)
                             "Z Y X W V U T S R Q P O N "
                             "M L K J I H G F E D C B A "
                             (make-string 200 #\*)
                             "%=")
              (text-unfold-right
               (lambda (n) (char>? (integer->char n) #\z))
               (lambda (n)
                 (let ((c (integer->char n)))
                   (cond ((char<=? #\a c #\z) c)
                         ((char<=? #\A c #\Z) (text c #\space))
                         (else (make-string 200 #\*)))))
               (lambda (n) (+ n 1))
               (char->integer #\@)
               "%="
               (lambda (n) #\space)))
    (fail 'text-unfold-right))

(OR (result=? " The English alphabet: abcdefghijklmnopqrstuvwxyz "
              (text-unfold-right (lambda (n) (< n (char->integer #\A)))
                                 (lambda (n)
                                   (char-downcase (integer->char n)))
                                 (lambda (n) (- n 1))
                                 (char->integer #\Z)
                                 #\space
                                 (lambda (n) " The English alphabet: ")))
    (fail 'text-unfold-right))


;;; Conversion

(OR (let ((txt (textual->text "str")))
      (and (text? txt)
           (textual=? txt "str")))
    (fail 'textual->text))

#;(OR (let ((txt (textual->text (text #\s #\t #\r))))
      (and (text? txt)
           (textual=? txt "str")))
    (fail 'textual->text))

#;(OR (let ((txt (textual->text "str" "not a textual")))
      (and (text? txt)
           (textual=? txt "str")))
    (fail 'textual->text))

#;(OR (let ((txt (textual->text (text #\s #\t #\r) "bad textual")))
      (and (text? txt)
           (textual=? txt "str")))
    (fail 'textual->text))


(OR (string=? "" (textual->string (text)))
    (fail 'textual->string))

(OR (string=? "" (textual->string (text) 0))
    (fail 'textual->string))

(OR (string=? "" (textual->string (text) 0 0))
    (fail 'textual->string))

(OR (string=? "abc" (textual->string (text #\a #\b #\c)))
    (fail 'textual->string))

(OR (string=? "" (textual->string (text #\a #\b #\c) 3))
    (fail 'textual->string))

(OR (string=? "bc" (textual->string (text #\a #\b #\c) 1 3))
    (fail 'textual->string))


(OR (string=? "" (textual->string ""))
    (fail 'textual->string))

(OR (string=? "" (textual->string "" 0))
    (fail 'textual->string))

(OR (string=? "" (textual->string "" 0 0))
    (fail 'textual->string))

(OR (string=? "abc" (textual->string "abc"))
    (fail 'textual->string))

(OR (string=? "" (textual->string "abc" 3))
    (fail 'textual->string))

(OR (string=? "bc" (textual->string "abc" 1 3))
    (fail 'textual->string))


(OR (equal? '#() (textual->vector (text)))
    (fail 'textual->vector))

(OR (equal? '#() (textual->vector (text) 0))
    (fail 'textual->vector))

(OR (equal? '#() (textual->vector (text) 0 0))
    (fail 'textual->vector))

(OR (equal? '#(#\a #\b #\c) (textual->vector (text #\a #\b #\c)))
    (fail 'textual->vector))

(OR (equal? '#() (textual->vector (text #\a #\b #\c) 3))
    (fail 'textual->vector))

(OR (equal? '#(#\b #\c) (textual->vector (text #\a #\b #\c) 1 3))
    (fail 'textual->vector))


(OR (equal? '#() (textual->vector ""))
    (fail 'textual->vector))

(OR (equal? '#() (textual->vector "" 0))
    (fail 'textual->vector))

(OR (equal? '#() (textual->vector "" 0 0))
    (fail 'textual->vector))

(OR (equal? '#(#\a #\b #\c) (textual->vector "abc"))
    (fail 'textual->vector))

(OR (equal? '#() (textual->vector "abc" 3))
    (fail 'textual->vector))

(OR (equal? '#(#\b #\c) (textual->vector "abc" 1 3))
    (fail 'textual->vector))


(OR (equal? '() (textual->list (text)))
    (fail 'textual->list))

(OR (equal? '() (textual->list (text) 0))
    (fail 'textual->list))

(OR (equal? '() (textual->list (text) 0 0))
    (fail 'textual->list))

(OR (equal? '(#\a #\b #\c) (textual->list (text #\a #\b #\c)))
    (fail 'textual->list))

(OR (equal? '() (textual->list (text #\a #\b #\c) 3))
    (fail 'textual->list))

(OR (equal? '(#\b #\c) (textual->list (text #\a #\b #\c) 1 3))
    (fail 'textual->list))


(OR (equal? '() (textual->list ""))
    (fail 'textual->list))

(OR (equal? '() (textual->list "" 0))
    (fail 'textual->list))

(OR (equal? '() (textual->list "" 0 0))
    (fail 'textual->list))

(OR (equal? '(#\a #\b #\c) (textual->list "abc"))
    (fail 'textual->list))

(OR (equal? '() (textual->list "abc" 3))
    (fail 'textual->list))

(OR (equal? '(#\b #\c) (textual->list "abc" 1 3))
    (fail 'textual->list))


(OR (result=? "" (string->text ""))
    (fail 'string->text))

(OR (result=? "" (string->text "" 0))
    (fail 'string->text))

(OR (result=? "" (string->text "" 0 0))
    (fail 'string->text))

(OR (result=? "abc" (string->text "abc"))
    (fail 'string->text))

(OR (result=? "bc" (string->text "abc" 1))
    (fail 'string->text))

(OR (result=? "" (string->text "abc" 3))
    (fail 'string->text))

(OR (result=? "b" (string->text "abc" 1 2))
    (fail 'string->text))

(OR (result=? "bc" (string->text "abc" 1 3))
    (fail 'string->text))


(OR (result=? "" (vector->text '#()))
    (fail 'vector->text))

(OR (result=? "" (vector->text '#() 0))
    (fail 'vector->text))

(OR (result=? "" (vector->text '#() 0 0))
    (fail 'vector->text))

(OR (result=? "abc" (vector->text '#(#\a #\b #\c)))
    (fail 'vector->text))

(OR (result=? "bc" (vector->text '#(#\a #\b #\c) 1))
    (fail 'vector->text))

(OR (result=? "" (vector->text '#(#\a #\b #\c) 3))
    (fail 'vector->text))

(OR (result=? "b" (vector->text '#(#\a #\b #\c) 1 2))
    (fail 'vector->text))

(OR (result=? "bc" (vector->text '#(#\a #\b #\c) 1 3))
    (fail 'vector->text))


(OR (result=? "" (list->text '()))
    (fail 'list->text))

(OR (result=? "" (list->text '() 0))
    (fail 'list->text))

(OR (result=? "" (list->text '() 0 0))
    (fail 'list->text))

(OR (result=? "abc" (list->text '(#\a #\b #\c)))
    (fail 'list->text))

(OR (result=? "bc" (list->text '(#\a #\b #\c) 1))
    (fail 'list->text))

(OR (result=? "" (list->text '(#\a #\b #\c) 3))
    (fail 'list->text))

(OR (result=? "b" (list->text '(#\a #\b #\c) 1 2))
    (fail 'list->text))

(OR (result=? "bc" (list->text '(#\a #\b #\c) 1 3))
    (fail 'list->text))


(OR (result=? "" (reverse-list->text '()))
    (fail 'reverse-list->text))

(OR (result=? "cba" (reverse-list->text '(#\a #\b #\c)))
    (fail 'reverse-list->text))


(OR (equal? '#u8(97 98 99)
            (textual->utf8 (as-text "abc")))
    (fail 'textual->utf8))

(OR (equal? '#u8(97 98 99)
            (textual->utf8 "abc"))
    (fail 'textual->utf8))

(OR (equal? '#u8(97 98 99 121 121 121 122 122 122)
            (textual->utf8 (as-text "xxxabcyyyzzz") 3))
    (fail 'textual->utf8))

(OR (equal? '#u8(97 98 99 121 121 121 122 122 122)
            (textual->utf8 "xxxabcyyyzzz" 3))
    (fail 'textual->utf8))

(OR (equal? '#u8(97 98 99)
            (textual->utf8 (as-text "xxxabcyyyzzz") 3 6))
    (fail 'textual->utf8))

(OR (equal? '#u8(97 98 99)
            (textual->utf8 "xxxabcyyyzzz" 3 6))
    (fail 'textual->utf8))


(OR (equal? '#u8(254 255 0 97 0 98 0 99)
            (textual->utf16 (as-text "abc")))
    (fail 'textual->utf16))

(OR (equal? '#u8(254 255 0 97 0 98 0 99)
            (textual->utf16 "abc"))
    (fail 'textual->utf16))

(OR (equal? '#u8(254 255 0 97 0 98 0 99 0 121 0 121 0 121 0 122 0 122 0 122)
            (textual->utf16 (as-text "xxxabcyyyzzz") 3))
    (fail 'textual->utf16))

(OR (equal? '#u8(254 255 0 97 0 98 0 99 0 121 0 121 0 121 0 122 0 122 0 122)
            (textual->utf16 "xxxabcyyyzzz" 3))
    (fail 'textual->utf16))

(OR (equal? '#u8(254 255 0 97 0 98 0 99)
            (textual->utf16 (as-text "xxxabcyyyzzz") 3 6))
    (fail 'textual->utf16))

(OR (equal? '#u8(254 255 0 97 0 98 0 99)
            (textual->utf16 "xxxabcyyyzzz" 3 6))
    (fail 'textual->utf16))


(OR (equal? '#u8(0 97 0 98 0 99)
            (textual->utf16be (as-text "abc")))
    (fail 'textual->utf16be))

(OR (equal? '#u8(0 97 0 98 0 99)
            (textual->utf16be "abc"))
    (fail 'textual->utf16be))

(OR (equal? '#u8(0 97 0 98 0 99 0 121 0 121 0 121 0 122 0 122 0 122)
            (textual->utf16be (as-text "xxxabcyyyzzz") 3))
    (fail 'textual->utf16be))

(OR (equal? '#u8(0 97 0 98 0 99 0 121 0 121 0 121 0 122 0 122 0 122)
            (textual->utf16be "xxxabcyyyzzz" 3))
    (fail 'textual->utf16be))

(OR (equal? '#u8(0 97 0 98 0 99)
            (textual->utf16be (as-text "xxxabcyyyzzz") 3 6))
    (fail 'textual->utf16be))

(OR (equal? '#u8(0 97 0 98 0 99)
            (textual->utf16be "xxxabcyyyzzz" 3 6))
    (fail 'textual->utf16be))


(OR (equal? '#u8(97 0 98 0 99 0)
            (textual->utf16le (as-text "abc")))
    (fail 'textual->utf16le))

(OR (equal? '#u8(97 0 98 0 99 0)
            (textual->utf16le "abc"))
    (fail 'textual->utf16le))

(OR (equal? '#u8(97 0 98 0 99 0 121 0 121 0 121 0 122 0 122 0 122 0)
            (textual->utf16le (as-text "xxxabcyyyzzz") 3))
    (fail 'textual->utf16le))

(OR (equal? '#u8(97 0 98 0 99 0 121 0 121 0 121 0 122 0 122 0 122 0)
            (textual->utf16le "xxxabcyyyzzz" 3))
    (fail 'textual->utf16le))

(OR (equal? '#u8(97 0 98 0 99 0)
            (textual->utf16le (as-text "xxxabcyyyzzz") 3 6))
    (fail 'textual->utf16le))

(OR (equal? '#u8(97 0 98 0 99 0)
            (textual->utf16le "xxxabcyyyzzz" 3 6))
    (fail 'textual->utf16le))


(OR (result=? "abc"
              (utf8->text '#u8(97 98 99)))
    (fail 'textual->utf8))

(OR (result=? "abcyyyzzz"
              (utf8->text '#u8(0 1 2 97 98 99 121 121 121 122 122 122) 3))
    (fail 'textual->utf8))

(OR (result=? "abc"
              (utf8->text '#u8(41 42 43 97 98 99 100 101 102) 3 6))
    (fail 'textual->utf8))


(OR (result=? "abc"
              (utf16->text '#u8(254 255 0 97 0 98 0 99)))
    (fail 'textual->utf16))

(OR (result=? "abc"
              (utf16->text '#u8(255 254 97 0 98 0 99 0)))
    (fail 'textual->utf16))

(OR (result=? "abc"
              (utf16->text (textual->utf16 "abc") 2))
    (fail 'textual->utf16))

(OR (result=? "bcdef"
              (utf16->text (textual->utf16 "abcdef") 4))
    (fail 'textual->utf16))

(OR (result=? "bcd"
              (utf16->text (textual->utf16 "abcdef") 4 10))
    (fail 'textual->utf16))


(OR (result=? "abc"
              (utf16be->text '#u8(0 97 0 98 0 99)))
    (fail 'textual->utf16be))

(OR (result=? "bc"
              (utf16be->text (textual->utf16be "abc") 2))
    (fail 'textual->utf16be))

(OR (result=? "bcd"
              (utf16be->text (textual->utf16be "abcdef") 2 8))
    (fail 'textual->utf16be))


(OR (result=? "abc"
              (utf16le->text '#u8(97 0 98 0 99 0)))
    (fail 'textual->utf16le))

(OR (result=? "bc"
              (utf16le->text (textual->utf16le "abc") 2))
    (fail 'textual->utf16le))

(OR (result=? "bcd"
              (utf16le->text (textual->utf16le "abcdef") 2 8))
    (fail 'textual->utf16le))


(cond-expand
 ((or sagittarius
      chibi
      full-unicode-strings)

  (OR (equal?
       '#u8(97 195 128 206 191
               240 157 145 129 240 157 132 147 240 157 132 144 122)
       (textual->utf8 beyondBMP))
      (fail 'textual->utf8))

  (let ((bv (textual->utf16 beyondBMP)))
    (OR (equal? bv
                '#u8(254 255 0 97 0 192 3 191
                         216 53 220 65 216 52 221 19 216 52 221 16 0 122))
        (equal? bv
                '#u8(255 254 97 0 192 0 191 3
                         53 216 65 220 52 216 19 221 52 216 16 221 122 0))
        (fail 'textual->utf16)))

  (OR (equal?
       '#u8(0 97 0 192 3 191 216 53 220 65 216 52 221 19 216 52 221 16 0 122)
       (textual->utf16be beyondBMP))
      (fail 'textual->utf8))

  (OR (equal?
       '#u8(97 0 192 0 191 3 53 216 65 220 52 216 19 221 52 216 16 221 122 0)
       (textual->utf16le beyondBMP))
      (fail 'textual->utf8))

  (OR (textual=?
       beyondBMP
       (utf8->text
        '#u8(97 195 128 206 191
                240 157 145 129 240 157 132 147 240 157 132 144 122)))
      (fail 'utf8->text))

  (OR (textual=? beyondBMP (utf16->text (textual->utf16 beyondBMP)))
      (fail 'utf16->text))

  (OR (textual=? beyondBMP
                 (utf16->text (textual->utf16 beyondBMP) 2))
      (fail 'utf16->text))
  
  (OR (textual=? beyondBMP (utf16be->text (textual->utf16be beyondBMP)))
      (fail 'utf16be->text))

  (OR (textual=? beyondBMP (utf16le->text (textual->utf16le beyondBMP)))
      (fail 'utf16le->text))

  (OR (result=? (string-append (string (integer->char #xfeff)) "abc")
                (utf16be->text '#u8(254 255 0 97 0 98 0 99)))
      (fail 'utf16be->text))

  (OR (result=? (string-append (string (integer->char #xfeff)) "abc")
                (utf16le->text '#u8(255 254 97 0 98 0 99 0)))
      (fail 'utf16le->text))
  )

 (else))

;;; Selection

(OR (= 0 (text-length (text)))
    (fail 'text-length))

(OR (= 6 (text-length ABCDEF))
    (fail 'text-length))

(OR (= 1234 (text-length (make-text 1234 (text-ref ABC 0))))
    (fail 'text-length))


(OR (char=? #\a (text-ref (text #\a #\b #\c) 0))
    (fail 'text-ref))

(OR (char=? #\c (text-ref (text #\a #\b #\c) 2))
    (fail 'text-ref))

(OR (char=? (string-ref (textual->string ABCDEF) 3)
            (text-ref ABCDEF 3))
    (fail 'text-ref))


(OR (= 0 (textual-length (text)))
    (fail 'textual-length))

(OR (= 6 (textual-length ABCDEF))
    (fail 'textual-length))

(OR (= 1234 (textual-length (make-text 1234 (text-ref ABC 0))))
    (fail 'textual-length))


(OR (char=? #\a (textual-ref (text #\a #\b #\c) 0))
    (fail 'textual-ref))

(OR (char=? #\c (textual-ref (text #\a #\b #\c) 2))
    (fail 'textual-ref))

(OR (char=? (string-ref (textual->string ABCDEF) 3)
            (textual-ref ABCDEF 3))
    (fail 'textual-ref))


(OR (result=? ""
              (subtext (text) 0 0))
    (fail 'subtext))

(OR (result=? ""
              (subtext (string->text "abcdef") 0 0))
    (fail 'subtext))

(OR (result=? ""
              (subtext (string->text "abcdef") 4 4))
    (fail 'subtext))

(OR (result=? ""
              (subtext (string->text "abcdef") 6 6))
    (fail 'subtext))

(OR (result=? "abcd"
              (subtext (string->text "abcdef") 0 4))
    (fail 'subtext))

(OR (result=? "cde"
              (subtext (string->text "abcdef") 2 5))
    (fail 'subtext))

(OR (result=? "cdef"
              (subtext (string->text "abcdef") 2 6))
    (fail 'subtext))

(OR (result=? "abcdef"
              (subtext (string->text "abcdef") 0 6))
    (fail 'subtext))


(OR (result=? ""
              (subtextual (text) 0 0))
    (fail 'subtextual))

(OR (result=? ""
              (subtextual (string->text "abcdef") 0 0))
    (fail 'subtextual))

(OR (result=? ""
              (subtextual (string->text "abcdef") 4 4))
    (fail 'subtextual))

(OR (result=? ""
              (subtextual (string->text "abcdef") 6 6))
    (fail 'subtextual))

(OR (result=? "abcd"
              (subtextual (string->text "abcdef") 0 4))
    (fail 'subtextual))

(OR (result=? "cde"
              (subtextual (string->text "abcdef") 2 5))
    (fail 'subtextual))

(OR (result=? "cdef"
              (subtextual (string->text "abcdef") 2 6))
    (fail 'subtextual))

(OR (result=? "abcdef"
              (subtextual (string->text "abcdef") 0 6))
    (fail 'subtextual))


(OR (result=? ""
              (subtextual "" 0 0))
    (fail 'subtextual))

(OR (result=? ""
              (subtextual "abcdef" 0 0))
    (fail 'subtextual))

(OR (result=? ""
              (subtextual "abcdef" 4 4))
    (fail 'subtextual))

(OR (result=? ""
              (subtextual "abcdef" 6 6))
    (fail 'subtextual))

(OR (result=? "abcd"
              (subtextual "abcdef" 0 4))
    (fail 'subtextual))

(OR (result=? "cde"
              (subtextual "abcdef" 2 5))
    (fail 'subtextual))

(OR (result=? "cdef"
              (subtextual "abcdef" 2 6))
    (fail 'subtextual))

(OR (result=? "abcdef"
              (subtextual "abcdef" 0 6))
    (fail 'subtextual))


(OR (result=? ""
              (textual-copy (text)))
    (fail 'textual-copy))

(OR (let* ((txt (string->text "abcdef"))
           (copy (textual-copy txt)))
      (and (result=? "abcdef"
                     copy)
           (not (eqv? txt copy))))
    (fail 'textual-copy))


(OR (result=? ""
              (textual-copy ""))
    (fail 'textual-copy))

(OR (result=? "abcdef"
              (textual-copy "abcdef"))
    (fail 'textual-copy))


(OR (result=? ""
              (textual-copy (text) 0))
    (fail 'textual-copy))

(OR (result=? "abcdef"
              (textual-copy (string->text "abcdef") 0))
    (fail 'textual-copy))

(OR (result=? "ef"
              (textual-copy (string->text "abcdef") 4))
    (fail 'textual-copy))

(OR (result=? ""
              (textual-copy (string->text "abcdef") 6))
    (fail 'textual-copy))


(OR (result=? ""
              (textual-copy "" 0))
    (fail 'textual-copy))

(OR (result=? "abcdef"
              (textual-copy "abcdef" 0))
    (fail 'textual-copy))

(OR (result=? "ef"
              (textual-copy "abcdef" 4))
    (fail 'textual-copy))

(OR (result=? ""
              (textual-copy "abcdef" 6))
    (fail 'textual-copy))


(OR (result=? ""
              (textual-copy (text) 0 0))
    (fail 'textual-copy))

(OR (result=? ""
              (textual-copy (string->text "abcdef") 0 0))
    (fail 'textual-copy))

(OR (result=? ""
              (textual-copy (string->text "abcdef") 4 4))
    (fail 'textual-copy))

(OR (result=? ""
              (textual-copy (string->text "abcdef") 6 6))
    (fail 'textual-copy))

(OR (result=? "abcd"
              (textual-copy (string->text "abcdef") 0 4))
    (fail 'textual-copy))

(OR (result=? "cde"
              (textual-copy (string->text "abcdef") 2 5))
    (fail 'textual-copy))

(OR (result=? "cdef"
              (textual-copy (string->text "abcdef") 2 6))
    (fail 'textual-copy))

(OR (result=? "abcdef"
              (textual-copy (string->text "abcdef") 0 6))
    (fail 'textual-copy))


(OR (result=? ""
              (textual-copy "" 0 0))
    (fail 'textual-copy))

(OR (result=? ""
              (textual-copy "abcdef" 0 0))
    (fail 'textual-copy))

(OR (result=? ""
              (textual-copy "abcdef" 4 4))
    (fail 'textual-copy))

(OR (result=? ""
              (textual-copy "abcdef" 6 6))
    (fail 'textual-copy))

(OR (result=? "abcd"
              (textual-copy "abcdef" 0 4))
    (fail 'textual-copy))

(OR (result=? "cde"
              (textual-copy "abcdef" 2 5))
    (fail 'textual-copy))

(OR (result=? "cdef"
              (textual-copy "abcdef" 2 6))
    (fail 'textual-copy))

(OR (result=? "abcdef"
              (textual-copy "abcdef" 0 6))
    (fail 'textual-copy))


(OR (result=? "" (textual-take (text) 0))
    (fail 'textual-take))

(OR (result=? "" (textual-take (string->text "abcdef") 0))
    (fail 'textual-take))

(OR (result=? "ab" (textual-take (string->text "abcdef") 2))
    (fail 'textual-take))

(OR (result=? "" (textual-drop (string->text "") 0))
    (fail 'textual-drop))

(OR (result=? "abcdef" (textual-drop (string->text "abcdef") 0))
    (fail 'textual-drop))

(OR (result=? "cdef" (textual-drop (string->text "abcdef") 2))
    (fail 'textual-drop))

(OR (result=? "" (textual-take-right (text) 0))
    (fail 'textual-take-right))

(OR (result=? "" (textual-take-right (string->text "abcdef") 0))
    (fail 'textual-take-right))

(OR (result=? "ef" (textual-take-right (string->text "abcdef") 2))
    (fail 'textual-take-right))

(OR (result=? "" (textual-drop-right (text) 0))
    (fail 'textual-drop-right))

(OR (result=? "abcdef"
              (textual-drop-right (string->text "abcdef") 0))
    (fail 'textual-drop-right))

(OR (result=? "abcd"
              (textual-drop-right (string->text "abcdef") 2))
    (fail 'textual-drop-right))


(OR (result=? "" (textual-take "" 0))
    (fail 'textual-take))

(OR (result=? "" (textual-take "abcdef" 0))
    (fail 'textual-take))

(OR (result=? "ab" (textual-take "abcdef" 2))
    (fail 'textual-take))

(OR (result=? "" (textual-drop "" 0))
    (fail 'textual-drop))

(OR (result=? "abcdef" (textual-drop "abcdef" 0))
    (fail 'textual-drop))

(OR (result=? "cdef" (textual-drop "abcdef" 2))
    (fail 'textual-drop))

(OR (result=? "" (textual-take-right "" 0))
    (fail 'textual-take-right))

(OR (result=? "" (textual-take-right "abcdef" 0))
    (fail 'textual-take-right))

(OR (result=? "ef" (textual-take-right "abcdef" 2))
    (fail 'textual-take-right))

(OR (result=? "" (textual-drop-right "" 0))
    (fail 'textual-drop-right))

(OR (result=? "abcdef" (textual-drop-right "abcdef" 0))
    (fail 'textual-drop-right))

(OR (result=? "abcd" (textual-drop-right "abcdef" 2))
    (fail 'textual-drop-right))


(OR (result=? "" 
              (textual-pad (string->text "") 0))
    (fail 'textual-pad))

(OR (result=? "     " 
              (textual-pad (string->text "") 5))
    (fail 'textual-pad))

(OR (result=? "  325" 
              (textual-pad (string->text "325") 5))
    (fail 'textual-pad))

(OR (result=? "71325" 
              (textual-pad (string->text "71325") 5))
    (fail 'textual-pad))

(OR (result=? "71325" 
              (textual-pad (string->text "8871325") 5))
    (fail 'textual-pad))

(OR (result=? "" 
              (textual-pad (string->text "") 0 #\*))
    (fail 'textual-pad))

(OR (result=? "*****" 
              (textual-pad (string->text "") 5 #\*))
    (fail 'textual-pad))

(OR (result=? "**325" 
              (textual-pad (string->text "325") 5 #\*))
    (fail 'textual-pad))

(OR (result=? "71325" 
              (textual-pad (string->text "71325") 5 #\*))
    (fail 'textual-pad))

(OR (result=? "71325" 
              (textual-pad (string->text "8871325") 5 #\*))
    (fail 'textual-pad))

(OR (result=? "" 
              (textual-pad (string->text "") 0 #\* 0))
    (fail 'textual-pad))

(OR (result=? "*****" 
              (textual-pad (string->text "") 5 #\* 0))
    (fail 'textual-pad))

(OR (result=? "**325" 
              (textual-pad (string->text "325") 5 #\* 0))
    (fail 'textual-pad))

(OR (result=? "71325" 
              (textual-pad (string->text "71325") 5 #\* 0))
    (fail 'textual-pad))

(OR (result=? "71325" 
              (textual-pad (string->text "8871325") 5 #\* 0))
    (fail 'textual-pad))

(OR (result=? "***25" 
              (textual-pad (string->text "325") 5 #\* 1))
    (fail 'textual-pad))

(OR (result=? "*1325" 
              (textual-pad (string->text "71325") 5 #\* 1))
    (fail 'textual-pad))

(OR (result=? "71325" 
              (textual-pad (string->text "8871325") 5 #\* 1))
    (fail 'textual-pad))

(OR (result=? "" 
              (textual-pad (string->text "") 0 #\* 0 0))
    (fail 'textual-pad))

(OR (result=? "*****" 
              (textual-pad (string->text "") 5 #\* 0 0))
    (fail 'textual-pad))

(OR (result=? "**325" 
              (textual-pad (string->text "325") 5 #\* 0 3))
    (fail 'textual-pad))

(OR (result=? "**713" 
              (textual-pad (string->text "71325") 5 #\* 0 3))
    (fail 'textual-pad))

(OR (result=? "**887" 
              (textual-pad (string->text "8871325") 5 #\* 0 3))
    (fail 'textual-pad))

(OR (result=? "***25" 
              (textual-pad (string->text "325") 5 #\* 1 3))
    (fail 'textual-pad))

(OR (result=? "**132" 
              (textual-pad (string->text "71325") 5 #\* 1 4))
    (fail 'textual-pad))

(OR (result=? "*8713" 
              (textual-pad (string->text "8871325") 5 #\* 1 5))
    (fail 'textual-pad))

(OR (result=? "" 
              (textual-pad-right (string->text "") 0))
    (fail 'textual-pad-right))

(OR (result=? "     " 
              (textual-pad-right (string->text "") 5))
    (fail 'textual-pad-right))

(OR (result=? "325  " 
              (textual-pad-right (string->text "325") 5))
    (fail 'textual-pad-right))

(OR (result=? "71325" 
              (textual-pad-right (string->text "71325") 5))
    (fail 'textual-pad-right))

(OR (result=? "88713" 
              (textual-pad-right (string->text "8871325") 5))
    (fail 'textual-pad-right))

(OR (result=? "" 
              (textual-pad-right (string->text "") 0 #\*))
    (fail 'textual-pad-right))

(OR (result=? "*****" 
              (textual-pad-right (string->text "") 5 #\*))
    (fail 'textual-pad-right))

(OR (result=? "325**" 
              (textual-pad-right (string->text "325") 5 #\*))
    (fail 'textual-pad-right))

(OR (result=? "71325" 
              (textual-pad-right (string->text "71325") 5 #\*))
    (fail 'textual-pad-right))

(OR (result=? "88713" 
              (textual-pad-right (string->text "8871325") 5 #\*))
    (fail 'textual-pad-right))

(OR (result=? "" 
              (textual-pad-right (string->text "") 0 #\* 0))
    (fail 'textual-pad-right))

(OR (result=? "*****" 
              (textual-pad-right (string->text "") 5 #\* 0))
    (fail 'textual-pad-right))

(OR (result=? "325**" 
              (textual-pad-right (string->text "325") 5 #\* 0))
    (fail 'textual-pad-right))

(OR (result=? "71325" 
              (textual-pad-right (string->text "71325") 5 #\* 0))
    (fail 'textual-pad-right))

(OR (result=? "88713" 
              (textual-pad-right (string->text "8871325") 5 #\* 0))
    (fail 'textual-pad-right))

(OR (result=? "25***" 
              (textual-pad-right (string->text "325") 5 #\* 1))
    (fail 'textual-pad-right))

(OR (result=? "1325*" 
              (textual-pad-right (string->text "71325") 5 #\* 1))
    (fail 'textual-pad-right))

(OR (result=? "87132" 
              (textual-pad-right (string->text "8871325") 5 #\* 1))
    (fail 'textual-pad-right))

(OR (result=? "" 
              (textual-pad-right (string->text "") 0 #\* 0 0))
    (fail 'textual-pad-right))

(OR (result=? "*****" 
              (textual-pad-right (string->text "") 5 #\* 0 0))
    (fail 'textual-pad-right))

(OR (result=? "325**" 
              (textual-pad-right (string->text "325") 5 #\* 0 3))
    (fail 'textual-pad-right))

(OR (result=? "713**" 
              (textual-pad-right (string->text "71325") 5 #\* 0 3))
    (fail 'textual-pad-right))

(OR (result=? "887**" 
              
              (textual-pad-right (string->text "8871325") 5 #\* 0 3))
    (fail 'textual-pad-right))

(OR (result=? "25***" 
              (textual-pad-right (string->text "325") 5 #\* 1 3))
    (fail 'textual-pad-right))

(OR (result=? "132**" 
              (textual-pad-right (string->text "71325") 5 #\* 1 4))
    (fail 'textual-pad-right))

(OR (result=? "8713*" 
              
              (textual-pad-right (string->text "8871325") 5 #\* 1 5))
    (fail 'textual-pad-right))


(OR (result=? "" (textual-pad "" 0))
    (fail 'textual-pad))

(OR (result=? "     " (textual-pad "" 5))
    (fail 'textual-pad))

(OR (result=? "  325" (textual-pad "325" 5))
    (fail 'textual-pad))

(OR (result=? "71325" (textual-pad "71325" 5))
    (fail 'textual-pad))

(OR (result=? "71325" (textual-pad "8871325" 5))
    (fail 'textual-pad))

(OR (result=? "" (textual-pad "" 0 #\*))
    (fail 'textual-pad))

(OR (result=? "*****" (textual-pad "" 5 #\*))
    (fail 'textual-pad))

(OR (result=? "**325" (textual-pad "325" 5 #\*))
    (fail 'textual-pad))

(OR (result=? "71325" (textual-pad "71325" 5 #\*))
    (fail 'textual-pad))

(OR (result=? "71325" (textual-pad "8871325" 5 #\*))
    (fail 'textual-pad))

(OR (result=? "" (textual-pad "" 0 #\* 0))
    (fail 'textual-pad))

(OR (result=? "*****" (textual-pad "" 5 #\* 0))
    (fail 'textual-pad))

(OR (result=? "**325" (textual-pad "325" 5 #\* 0))
    (fail 'textual-pad))

(OR (result=? "71325" (textual-pad "71325" 5 #\* 0))
    (fail 'textual-pad))

(OR (result=? "71325" (textual-pad "8871325" 5 #\* 0))
    (fail 'textual-pad))

(OR (result=? "***25" (textual-pad "325" 5 #\* 1))
    (fail 'textual-pad))

(OR (result=? "*1325" (textual-pad "71325" 5 #\* 1))
    (fail 'textual-pad))

(OR (result=? "71325" (textual-pad "8871325" 5 #\* 1))
    (fail 'textual-pad))

(OR (result=? "" (textual-pad "" 0 #\* 0 0))
    (fail 'textual-pad))

(OR (result=? "*****" (textual-pad "" 5 #\* 0 0))
    (fail 'textual-pad))

(OR (result=? "**325" (textual-pad "325" 5 #\* 0 3))
    (fail 'textual-pad))

(OR (result=? "**713" (textual-pad "71325" 5 #\* 0 3))
    (fail 'textual-pad))

(OR (result=? "**887" (textual-pad "8871325" 5 #\* 0 3))
    (fail 'textual-pad))

(OR (result=? "***25" (textual-pad "325" 5 #\* 1 3))
    (fail 'textual-pad))

(OR (result=? "**132" (textual-pad "71325" 5 #\* 1 4))
    (fail 'textual-pad))

(OR (result=? "*8713" (textual-pad "8871325" 5 #\* 1 5))
    (fail 'textual-pad))

(OR (result=? "" (textual-pad-right "" 0))
    (fail 'textual-pad-right))

(OR (result=? "     " (textual-pad-right "" 5))
    (fail 'textual-pad-right))

(OR (result=? "325  " (textual-pad-right "325" 5))
    (fail 'textual-pad-right))

(OR (result=? "71325" (textual-pad-right "71325" 5))
    (fail 'textual-pad-right))

(OR (result=? "88713" (textual-pad-right "8871325" 5))
    (fail 'textual-pad-right))

(OR (result=? "" (textual-pad-right "" 0 #\*))
    (fail 'textual-pad-right))

(OR (result=? "*****" (textual-pad-right "" 5 #\*))
    (fail 'textual-pad-right))

(OR (result=? "325**" (textual-pad-right "325" 5 #\*))
    (fail 'textual-pad-right))

(OR (result=? "71325" (textual-pad-right "71325" 5 #\*))
    (fail 'textual-pad-right))

(OR (result=? "88713" (textual-pad-right "8871325" 5 #\*))
    (fail 'textual-pad-right))

(OR (result=? "" (textual-pad-right "" 0 #\* 0))
    (fail 'textual-pad-right))

(OR (result=? "*****" (textual-pad-right "" 5 #\* 0))
    (fail 'textual-pad-right))

(OR (result=? "325**" (textual-pad-right "325" 5 #\* 0))
    (fail 'textual-pad-right))

(OR (result=? "71325" (textual-pad-right "71325" 5 #\* 0))
    (fail 'textual-pad-right))

(OR (result=? "88713" (textual-pad-right "8871325" 5 #\* 0))
    (fail 'textual-pad-right))

(OR (result=? "25***" (textual-pad-right "325" 5 #\* 1))
    (fail 'textual-pad-right))

(OR (result=? "1325*" (textual-pad-right "71325" 5 #\* 1))
    (fail 'textual-pad-right))

(OR (result=? "87132" (textual-pad-right "8871325" 5 #\* 1))
    (fail 'textual-pad-right))

(OR (result=? "" (textual-pad-right "" 0 #\* 0 0))
    (fail 'textual-pad-right))

(OR (result=? "*****" (textual-pad-right "" 5 #\* 0 0))
    (fail 'textual-pad-right))

(OR (result=? "325**" (textual-pad-right "325" 5 #\* 0 3))
    (fail 'textual-pad-right))

(OR (result=? "713**" (textual-pad-right "71325" 5 #\* 0 3))
    (fail 'textual-pad-right))

(OR (result=? "887**" (textual-pad-right "8871325" 5 #\* 0 3))
    (fail 'textual-pad-right))

(OR (result=? "25***" (textual-pad-right "325" 5 #\* 1 3))
    (fail 'textual-pad-right))

(OR (result=? "132**" (textual-pad-right "71325" 5 #\* 1 4))
    (fail 'textual-pad-right))

(OR (result=? "8713*" (textual-pad-right "8871325" 5 #\* 1 5))
    (fail 'textual-pad-right))


(OR (result=? ""
              (textual-trim (string->text "")))
    (fail 'textual-trim))

(OR (result=? "a  b  c  "
              (textual-trim (string->text "  a  b  c  ")))
    (fail 'textual-trim))

(OR (result=? ""
              (textual-trim (string->text "") char-whitespace?))
    (fail 'textual-trim))

(OR (result=? "a  b  c  "
              (textual-trim (string->text "  a  b  c  ") char-whitespace?))
    (fail 'textual-trim))

(OR (result=? ""
              (textual-trim (string->text "  a  b  c  ") char?))
    (fail 'textual-trim))

(OR (result=? ""
              (textual-trim (string->text "") char-whitespace? 0))
    (fail 'textual-trim))

(OR (result=? "a  b  c  "
              (textual-trim (string->text "  a  b  c  ") char-whitespace? 0))
    (fail 'textual-trim))

(OR (result=? ""
              (textual-trim (string->text "  a  b  c  ") char? 0))
    (fail 'textual-trim))

(OR (result=? "b  c  "
              (textual-trim (string->text "  a  b  c  ") char-whitespace? 3))
    (fail 'textual-trim))

(OR (result=? ""
              (textual-trim (string->text "  a  b  c  ") char? 3))
    (fail 'textual-trim))

(OR (result=? ""
              (textual-trim (string->text "  a  b  c  ") char? 0 11))
    (fail 'textual-trim))

(OR (result=? "b  c  "
              (textual-trim (string->text "  a  b  c  ")
                            char-whitespace? 3 11))
    (fail 'textual-trim))

(OR (result=? ""
              (textual-trim (string->text "  a  b  c  ") char? 3 11))
    (fail 'textual-trim))

(OR (result=? ""
              (textual-trim (string->text "  a  b  c  ") char? 0 8))
    (fail 'textual-trim))

(OR (result=? "b  "
              (textual-trim (string->text "  a  b  c  ")
                            char-whitespace? 3 8))
    (fail 'textual-trim))

(OR (result=? ""
              (textual-trim (string->text "  a  b  c  ") char? 3 8))
    (fail 'textual-trim))


(OR (result=? ""
              (textual-trim-right (string->text "")))
    (fail 'textual-trim-right))

(OR (result=? "  a  b  c"
              (textual-trim-right (string->text "  a  b  c  ")))
    (fail 'textual-trim-right))

(OR (result=? ""
              (textual-trim-right (string->text "") char-whitespace?))
    (fail 'textual-trim-right))

(OR (result=? "  a  b  c"
              (textual-trim-right (string->text "  a  b  c  ")
                                  char-whitespace?))
    (fail 'textual-trim-right))

(OR (result=? ""
              (textual-trim-right (string->text "  a  b  c  ") char?))
    (fail 'textual-trim-right))

(OR (result=? ""
              (textual-trim-right (string->text "") char-whitespace? 0))
    (fail 'textual-trim-right))

(OR (result=? "  a  b  c"
              (textual-trim-right (string->text "  a  b  c  ")
                                  char-whitespace? 0))
    (fail 'textual-trim-right))

(OR (result=? ""
              (textual-trim-right (string->text "  a  b  c  ") char? 0))
    (fail 'textual-trim-right))

(OR (result=? "  b  c"
              (textual-trim-right (string->text "  a  b  c  ")
                                  char-whitespace? 3))
    (fail 'textual-trim-right))

(OR (result=? ""
              (textual-trim-right (string->text "  a  b  c  ") char? 3))
    (fail 'textual-trim-right))

(OR (result=? ""
              (textual-trim-right (string->text "  a  b  c  ") char? 0 11))
    (fail 'textual-trim-right))

(OR (result=? "  b  c"
              (textual-trim-right (string->text "  a  b  c  ")
                                  char-whitespace? 3 11))
    (fail 'textual-trim-right))

(OR (result=? ""
              (textual-trim-right (string->text "  a  b  c  ") char? 3 11))
    (fail 'textual-trim-right))

(OR (result=? ""
              (textual-trim-right (string->text "  a  b  c  ") char? 0 8))
    (fail 'textual-trim-right))

(OR (result=? "  b"
              (textual-trim-right (string->text "  a  b  c  ")
                                  char-whitespace? 3 8))
    (fail 'textual-trim-right))

(OR (result=? ""
              (textual-trim-right (string->text "  a  b  c  ") char? 3 8))
    (fail 'textual-trim-right))


(OR (result=? ""
              (textual-trim-both (string->text "")))
    (fail 'textual-trim-both))

(OR (result=? "a  b  c"
              (textual-trim-both (string->text "  a  b  c  ")))
    (fail 'textual-trim-both))

(OR (result=? ""
              (textual-trim-both (string->text "") char-whitespace?))
    (fail 'textual-trim-both))

(OR (result=? "a  b  c"
              (textual-trim-both (string->text "  a  b  c  ")
                                 char-whitespace?))
    (fail 'textual-trim-both))

(OR (result=? ""
              (textual-trim-both (string->text "  a  b  c  ") char?))
    (fail 'textual-trim-both))

(OR (result=? ""
              (textual-trim-both (string->text "") char-whitespace? 0))
    (fail 'textual-trim-both))

(OR (result=? "a  b  c"
              (textual-trim-both (string->text "  a  b  c  ")
                                 char-whitespace? 0))
    (fail 'textual-trim-both))

(OR (result=? ""
              (textual-trim-both (string->text "  a  b  c  ") char? 0))
    (fail 'textual-trim-both))

(OR (result=? "b  c"
              (textual-trim-both (string->text "  a  b  c  ")
                                 char-whitespace? 3))
    (fail 'textual-trim-both))

(OR (result=? ""
              (textual-trim-both (string->text "  a  b  c  ") char? 3))
    (fail 'textual-trim-both))

(OR (result=? ""
              (textual-trim-both (string->text "  a  b  c  ") char? 0 11))
    (fail 'textual-trim-both))

(OR (result=? "b  c"
              (textual-trim-both (string->text "  a  b  c  ")
                                 char-whitespace? 3 11))
    (fail 'textual-trim-both))

(OR (result=? ""
              (textual-trim-both (string->text "  a  b  c  ") char? 3 11))
    (fail 'textual-trim-both))

(OR (result=? ""
              (textual-trim-both (string->text "  a  b  c  ") char? 0 8))
    (fail 'textual-trim-both))

(OR (result=? "b"
              (textual-trim-both (string->text "  a  b  c  ")
                                 char-whitespace? 3 8))
    (fail 'textual-trim-both))

(OR (result=? ""
              (textual-trim-both (string->text "  a  b  c  ") char? 3 8))
    (fail 'textual-trim-both))


(OR (result=? ""
              (textual-trim ""))
    (fail 'textual-trim))

(OR (result=? "a  b  c  "
              (textual-trim "  a  b  c  "))
    (fail 'textual-trim))

(OR (result=? ""
              (textual-trim "" char-whitespace?))
    (fail 'textual-trim))

(OR (result=? "a  b  c  "
              (textual-trim "  a  b  c  " char-whitespace?))
    (fail 'textual-trim))

(OR (result=? ""
              (textual-trim "  a  b  c  " char?))
    (fail 'textual-trim))

(OR (result=? ""
              (textual-trim "" char-whitespace? 0))
    (fail 'textual-trim))

(OR (result=? "a  b  c  "
              (textual-trim "  a  b  c  " char-whitespace? 0))
    (fail 'textual-trim))

(OR (result=? ""
              (textual-trim "  a  b  c  " char? 0))
    (fail 'textual-trim))

(OR (result=? "b  c  "
              (textual-trim "  a  b  c  " char-whitespace? 3))
    (fail 'textual-trim))

(OR (result=? ""
              (textual-trim "  a  b  c  " char? 3))
    (fail 'textual-trim))

(OR (result=? ""
              (textual-trim "  a  b  c  " char? 0 11))
    (fail 'textual-trim))

(OR (result=? "b  c  "
              (textual-trim "  a  b  c  " char-whitespace? 3 11))
    (fail 'textual-trim))

(OR (result=? ""
              (textual-trim "  a  b  c  " char? 3 11))
    (fail 'textual-trim))

(OR (result=? ""
              (textual-trim "  a  b  c  " char? 0 8))
    (fail 'textual-trim))

(OR (result=? "b  "
              (textual-trim "  a  b  c  " char-whitespace? 3 8))
    (fail 'textual-trim))

(OR (result=? ""
              (textual-trim "  a  b  c  " char? 3 8))
    (fail 'textual-trim))


(OR (result=? ""
              (textual-trim-right ""))
    (fail 'textual-trim-right))

(OR (result=? "  a  b  c"
              (textual-trim-right "  a  b  c  "))
    (fail 'textual-trim-right))

(OR (result=? ""
              (textual-trim-right "" char-whitespace?))
    (fail 'textual-trim-right))

(OR (result=? "  a  b  c"
              (textual-trim-right "  a  b  c  " char-whitespace?))
    (fail 'textual-trim-right))

(OR (result=? ""
              (textual-trim-right "  a  b  c  " char?))
    (fail 'textual-trim-right))

(OR (result=? ""
              (textual-trim-right "" char-whitespace? 0))
    (fail 'textual-trim-right))

(OR (result=? "  a  b  c"
              (textual-trim-right "  a  b  c  " char-whitespace? 0))
    (fail 'textual-trim-right))

(OR (result=? ""
              (textual-trim-right "  a  b  c  " char? 0))
    (fail 'textual-trim-right))

(OR (result=? "  b  c"
              (textual-trim-right "  a  b  c  " char-whitespace? 3))
    (fail 'textual-trim-right))

(OR (result=? ""
              (textual-trim-right "  a  b  c  " char? 3))
    (fail 'textual-trim-right))

(OR (result=? ""
              (textual-trim-right "  a  b  c  " char? 0 11))
    (fail 'textual-trim-right))

(OR (result=? "  b  c"
              (textual-trim-right "  a  b  c  " char-whitespace? 3 11))
    (fail 'textual-trim-right))

(OR (result=? ""
              (textual-trim-right "  a  b  c  " char? 3 11))
    (fail 'textual-trim-right))

(OR (result=? ""
              (textual-trim-right "  a  b  c  " char? 0 8))
    (fail 'textual-trim-right))

(OR (result=? "  b"
              (textual-trim-right "  a  b  c  " char-whitespace? 3 8))
    (fail 'textual-trim-right))

(OR (result=? ""
              (textual-trim-right "  a  b  c  " char? 3 8))
    (fail 'textual-trim-right))


(OR (result=? ""
              (textual-trim-both ""))
    (fail 'textual-trim-both))

(OR (result=? "a  b  c"
              (textual-trim-both "  a  b  c  "))
    (fail 'textual-trim-both))

(OR (result=? ""
              (textual-trim-both "" char-whitespace?))
    (fail 'textual-trim-both))

(OR (result=? "a  b  c"
              (textual-trim-both "  a  b  c  " char-whitespace?))
    (fail 'textual-trim-both))

(OR (result=? ""
              (textual-trim-both "  a  b  c  " char?))
    (fail 'textual-trim-both))

(OR (result=? ""
              (textual-trim-both "" char-whitespace? 0))
    (fail 'textual-trim-both))

(OR (result=? "a  b  c"
              (textual-trim-both "  a  b  c  " char-whitespace? 0))
    (fail 'textual-trim-both))

(OR (result=? ""
              (textual-trim-both "  a  b  c  " char? 0))
    (fail 'textual-trim-both))

(OR (result=? "b  c"
              (textual-trim-both "  a  b  c  " char-whitespace? 3))
    (fail 'textual-trim-both))

(OR (result=? ""
              (textual-trim-both "  a  b  c  " char? 3))
    (fail 'textual-trim-both))

(OR (result=? ""
              (textual-trim-both "  a  b  c  " char? 0 11))
    (fail 'textual-trim-both))

(OR (result=? "b  c"
              (textual-trim-both "  a  b  c  " char-whitespace? 3 11))
    (fail 'textual-trim-both))

(OR (result=? ""
              (textual-trim-both "  a  b  c  " char? 3 11))
    (fail 'textual-trim-both))

(OR (result=? ""
              (textual-trim-both "  a  b  c  " char? 0 8))
    (fail 'textual-trim-both))

(OR (result=? "b"
              (textual-trim-both "  a  b  c  " char-whitespace? 3 8))
    (fail 'textual-trim-both))

(OR (result=? ""
              (textual-trim-both "  a  b  c  " char? 3 8))
    (fail 'textual-trim-both))


;;; Replacement

(OR (result=? "It's lots of fun to code it up in Scheme."
              (textual-replace (as-text "It's easy to code it up in Scheme.")
                               (as-text "lots of fun")
                               5 9))
    (fail 'textual-replace))

(OR (result=? "The miserable perl programmer endured daily ridicule."
              (textual-replace "The TCL programmer endured daily ridicule."
                               (as-text "another miserable perl drone")
                               4 7 8 22))
    (fail 'textual-replace))

(OR (result=? "It's really easy to code it up in Scheme."
              (textual-replace (as-text "It's easy to code it up in Scheme.")
                               "really "
                               5 5))
    (fail 'textual-replace))

(OR (result=? "Runs in O(1) time." ; for texts (using sample implementations)
              (textual-replace "Runs in O(n) time." (text #\1) 10 11))
    (fail 'textual-replace))

;;; Comparison
;;;
;;; The comparison tests aren't perfectly black-box because the
;;; specification of these comparison procedures allows them to
;;; use an ordering other than the usual lexicographic ordering.
;;; The sample implementations use lexicographic ordering, however,
;;; and a test program that discourages implementations from using
;;; orderings that differ from the usual on such simple cases is
;;; probably doing a public service.

(OR (equal? #t (textual=? (as-text "Strasse") (as-text "Strasse")))
    (fail 'textual=?))

(OR (equal? #t (textual=? "Strasse" (as-text "Strasse") "Strasse"))
    (fail 'textual=?))

(OR (equal? #f (textual<? (as-text "z") (as-text "z")))
    (fail 'textual<?))
(OR (equal? #t (textual<? (as-text "z") "zz"))
    (fail 'textual<?))
(OR (equal? #f (textual<? (as-text "z") (as-text "Z")))
    (fail 'textual<?))
(OR (equal? #t (textual<=? (as-text "z") "zz"))
    (fail 'textual<=?))
(OR (equal? #f (textual<=? "z" "Z"))
    (fail 'textual<=?))
(OR (equal? #t (textual<=? "z" (as-text "z")))
    (fail 'textual<=?))

(OR (equal? #f (textual<? "z" (as-text "z")))
    (fail 'textual<?))
(OR (equal? #f (textual>? (as-text "z") "zz"))
    (fail 'textual>?))
(OR (equal? #t (textual>? "z" (as-text "Z")))
    (fail 'textual>?))
(OR (equal? #f (textual>=? (as-text "z") "zz"))
    (fail 'textual>=?))
(OR (equal? #t (textual>=? "z" "Z"))
    (fail 'textual>=?))
(OR (equal? #t (textual>=? (as-text "z") (as-text "z")))
    (fail 'textual>=?))


(let* ((w "a")
       (x "abc")
       (y "def")
       (z (text #\a #\b #\c)))

  (OR (equal? (textual=? x y z)                           #f)
      (fail 'textual=?))
  (OR (equal? (textual=? x x z)                           #t)
      (fail 'textual=?))
  (OR (equal? (textual=? w x y)                           #f)
      (fail 'textual=?))
  (OR (equal? (textual=? y x w)                           #f)
      (fail 'textual=?))

  (OR (equal? (textual<? x y z)                           #f)
      (fail 'textual<?))
  (OR (equal? (textual<? x x z)                           #f)
      (fail 'textual<?))
  (OR (equal? (textual<? w x y)                           #t)
      (fail 'textual<?))
  (OR (equal? (textual<? y x w)                           #f)
      (fail 'textual<?))

  (OR (equal? (textual>? x y z)                           #f)
      (fail 'textual>?))
  (OR (equal? (textual>? x x z)                           #f)
      (fail 'textual>?))
  (OR (equal? (textual>? w x y)                           #f)
      (fail 'textual>?))
  (OR (equal? (textual>? y x w)                           #t)
      (fail 'textual>?))

  (OR (equal? (textual<=? x y z)                          #f)
      (fail 'textual<=?))
  (OR (equal? (textual<=? x x z)                          #t)
      (fail 'textual<=?))
  (OR (equal? (textual<=? w x y)                          #t)
      (fail 'textual<=?))
  (OR (equal? (textual<=? y x w)                          #f)
      (fail 'textual<=?))

  (OR (equal? (textual>=? x y z)                          #f)
      (fail 'textual>=?))
  (OR (equal? (textual>=? x x z)                          #t)
      (fail 'textual>=?))
  (OR (equal? (textual>=? w x y)                          #f)
      (fail 'textual>=?))
  (OR (equal? (textual>=? y x w)                          #t)
      (fail 'textual>=?))


  (OR (equal? (textual=? x x)                             #t)
      (fail 'textual=?))
  (OR (equal? (textual=? w x)                             #f)
      (fail 'textual=?))
  (OR (equal? (textual=? y x)                             #f)
      (fail 'textual=?))

  (OR (equal? (textual<? x x)                             #f)
      (fail 'textual<?))
  (OR (equal? (textual<? w x)                             #t)
      (fail 'textual<?))
  (OR (equal? (textual<? y x)                             #f)
      (fail 'textual<?))

  (OR (equal? (textual>? x x)                             #f)
      (fail 'textual>?))
  (OR (equal? (textual>? w x)                             #f)
      (fail 'textual>?))
  (OR (equal? (textual>? y x)                             #t)
      (fail 'textual>?))

  (OR (equal? (textual<=? x x)                            #t)
      (fail 'textual<=?))
  (OR (equal? (textual<=? w x)                            #t)
      (fail 'textual<=?))
  (OR (equal? (textual<=? y x)                            #f)
      (fail 'textual<=?))

  (OR (equal? (textual>=? x x)                            #t)
      (fail 'textual>=?))
  (OR (equal? (textual>=? w x)                            #f)
      (fail 'textual>=?))
  (OR (equal? (textual>=? y x)                            #t)
      (fail 'textual>=?)))


(OR (equal? #t (textual-ci<? "a" "Z"))
    (fail 'textual-ci<?))
(OR (equal? #t (textual-ci<? "A" "z"))
    (fail 'textual-ci<?))
(OR (equal? #f (textual-ci<? "Z" "a"))
    (fail 'textual-ci<?))
(OR (equal? #f (textual-ci<? "z" "A"))
    (fail 'textual-ci<?))
(OR (equal? #f (textual-ci<? "z" "Z"))
    (fail 'textual-ci<?))
(OR (equal? #f (textual-ci<? "Z" "z"))
    (fail 'textual-ci<?))
(OR (equal? #f (textual-ci>? "a" "Z"))
    (fail 'textual-ci>?))
(OR (equal? #f (textual-ci>? "A" "z"))
    (fail 'textual-ci>?))
(OR (equal? #t (textual-ci>? "Z" "a"))
    (fail 'textual-ci>?))
(OR (equal? #t (textual-ci>? "z" "A"))
    (fail 'textual-ci>?))
(OR (equal? #f (textual-ci>? "z" "Z"))
    (fail 'textual-ci>?))
(OR (equal? #f (textual-ci>? "Z" "z"))
    (fail 'textual-ci>?))
(OR (equal? #t (textual-ci=? "z" "Z"))
    (fail 'textual-ci=?))
(OR (equal? #f (textual-ci=? "z" "a"))
    (fail 'textual-ci=?))
(OR (equal? #t (textual-ci<=? "a" "Z"))
    (fail 'textual-ci<=?))
(OR (equal? #t (textual-ci<=? "A" "z"))
    (fail 'textual-ci<=?))
(OR (equal? #f (textual-ci<=? "Z" "a"))
    (fail 'textual-ci<=?))
(OR (equal? #f (textual-ci<=? "z" "A"))
    (fail 'textual-ci<=?))
(OR (equal? #t (textual-ci<=? "z" "Z"))
    (fail 'textual-ci<=?))
(OR (equal? #t (textual-ci<=? "Z" "z"))
    (fail 'textual-ci<=?))
(OR (equal? #f (textual-ci>=? "a" "Z"))
    (fail 'textual-ci>=?))
(OR (equal? #f (textual-ci>=? "A" "z"))
    (fail 'textual-ci>=?))
(OR (equal? #t (textual-ci>=? "Z" "a"))
    (fail 'textual-ci>=?))
(OR (equal? #t (textual-ci>=? "z" "A"))
    (fail 'textual-ci>=?))
(OR (equal? #t (textual-ci>=? "z" "Z"))
    (fail 'textual-ci>=?))
(OR (equal? #t (textual-ci>=? "Z" "z"))
    (fail 'textual-ci>=?))

;;; The full-unicode feature doesn't imply full Unicode in strings,
;;; so these tests might fail even in a conforming implementation.
;;; Implementations that support full Unicode strings often have
;;; this feature, however, even though it isn't listed in the R7RS.

(cond-expand
 (full-unicode-strings
  (OR (equal? #f (textual=? ABCDEF DEFABC))
      (fail 'textual=?))
  (OR (equal? #f (textual=? DEFABC ABCDEF))
      (fail 'textual=?))
  (OR (equal? #t (textual=? DEFABC DEFABC))
      (fail 'textual=?))

  (OR (equal? #f (textual<? ABCDEF DEFABC))
      (fail 'textual=?))
  (OR (equal? #t (textual<? DEFABC ABCDEF))
      (fail 'textual=?))
  (OR (equal? #f (textual<? DEFABC DEFABC))
      (fail 'textual=?))

  (OR (equal? #t (textual>? ABCDEF DEFABC))
      (fail 'textual=?))
  (OR (equal? #f (textual>? DEFABC ABCDEF))
      (fail 'textual=?))
  (OR (equal? #f (textual>? DEFABC DEFABC))
      (fail 'textual=?))

  (OR (equal? #f (textual<=? ABCDEF DEFABC))
      (fail 'textual=?))
  (OR (equal? #t (textual<=? DEFABC ABCDEF))
      (fail 'textual=?))
  (OR (equal? #t (textual<=? DEFABC DEFABC))
      (fail 'textual=?))

  (OR (equal? #t (textual>=? ABCDEF DEFABC))
      (fail 'textual=?))
  (OR (equal? #f (textual>=? DEFABC ABCDEF))
      (fail 'textual=?))
  (OR (equal? #t (textual>=? DEFABC DEFABC))
      (fail 'textual=?))

  (OR (equal? #f (textual=? "Fuss" fuss))
      (fail 'textual=?:unicode))
  (OR (equal? #f (textual=? "Fuss" "Fuss" fuss))
      (fail 'textual=?:unicode))
  (OR (equal? #f (textual=? "Fuss" fuss "Fuss"))
      (fail 'textual=?:unicode))
  (OR (equal? #f (textual=? fuss "Fuss" "Fuss"))
      (fail 'textual=?:unicode))
  (OR (equal? #t (textual<? "z" (as-text eszett)))
      (fail 'textual<?:unicode))
  (OR (equal? #f (textual<? (as-text eszett) "z"))
      (fail 'textual<?:unicode))
  (OR (equal? #t (textual<=? "z" (as-text eszett)))
      (fail 'textual<=?:unicode))
  (OR (equal? #f (textual<=? (as-text eszett) "z"))
      (fail 'textual<=?:unicode))
  (OR (equal? #f (textual>? "z" (as-text eszett)))
      (fail 'textual>?:unicode))
  (OR (equal? #t (textual>? (as-text eszett) "z"))
      (fail 'textual>?:unicode))
  (OR (equal? #f (textual>=? "z" (as-text eszett)))
      (fail 'textual>=?:unicode))
  (OR (equal? #t (textual>=? (as-text eszett) "z"))
      (fail 'textual>=?:unicode))
  (OR (textual-ci=? fuss "Fuss")
      (fail 'textual-ci=?:unicode))
  (OR (textual-ci=? fuss "FUSS")
      (fail 'textual-ci=?:unicode))
  (OR (textual-ci=? chaos0 chaos1 chaos2)
      (fail 'textual-ci=?:chaos)))
 (else))


;;; Prefixes and suffixes

(OR (= 0 (textual-prefix-length ABC ABCDEF))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length ABCDEF ABC))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length ABCDEF DEFABC))
    (fail 'textual-prefix-length))

(OR (= 6 (textual-prefix-length DEFABC DEFABC))
    (fail 'textual-prefix-length))

(OR (= 6 (textual-prefix-length (textual->string DEFABC) DEFABC))
    (fail 'textual-prefix-length))

(OR (= 6 (textual-prefix-length DEFABC (textual->string DEFABC)))
    (fail 'textual-prefix-length))

(OR (= 6 (textual-prefix-length (textual->string DEFABC)
                                (textual->string DEFABC)))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "") (as-text "")))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "") (as-text "aabbccddee")))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "aisle") (as-text "")))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "") (as-text "aabbccddee")))
    (fail 'textual-prefix-length))

(OR (= 1 (textual-prefix-length (as-text "aisle") (as-text "aabbccddee")))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "bail") (as-text "aabbccddee")))
    (fail 'textual-prefix-length))

(OR (= 4 (textual-prefix-length (as-text "prefix") (as-text "preface")))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "") (as-text "") 0))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "") (as-text "aabbccddee") 0))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "aisle") (as-text "") 0))
    (fail 'textual-prefix-length))

(OR (= 1 (textual-prefix-length (as-text "aisle") (as-text "aabbccddee") 0))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "bail") (as-text "aabbccddee") 0))
    (fail 'textual-prefix-length))

(OR (= 4 (textual-prefix-length (as-text "prefix") (as-text "preface") 0))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "aisle") (as-text "") 1))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "aisle") (as-text "aabbccddee") 1))
    (fail 'textual-prefix-length))

(OR (= 1 (textual-prefix-length (as-text "bail") (as-text "aabbccddee") 1))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "prefix") (as-text "preface") 1))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "") (as-text "") 0 0))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "") (as-text "aabbccddee") 0 0))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "aisle") (as-text "") 0 4))
    (fail 'textual-prefix-length))

(OR (= 1 (textual-prefix-length (as-text "aisle") (as-text "aabbccddee") 0 4))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "bail") (as-text "aabbccddee") 0 1))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "aisle") (as-text "") 1 4))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "aisle") (as-text "aabbccddee") 1 4))
    (fail 'textual-prefix-length))

(OR (= 1 (textual-prefix-length (as-text "bail") (as-text "aabbccddee") 1 4))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "prefix") (as-text "preface") 1 5))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "") (as-text "") 0 0 0))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "") (as-text "aabbccddee") 0 0 0))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "aisle") (as-text "") 0 4 0))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "aisle") (as-text "aabbccddee") 0 4 2))
    (fail 'textual-prefix-length))

(OR (= 1 (textual-prefix-length (as-text "bail") (as-text "aabbccddee") 0 1 2))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "prefix") (as-text "preface") 0 5 1))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "aisle") (as-text "") 1 4 0))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "aisle") (as-text "aabbccddee") 1 4 3))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "bail") (as-text "aabbccddee") 1 4 3))
    (fail 'textual-prefix-length))

(OR (= 3 (textual-prefix-length (as-text "prefix") (as-text "preface") 1 5 1))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "") (as-text "") 0 0 0 0))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "") (as-text "aabbccddee") 0 0 0 0))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "aisle") (as-text "") 0 4 0 0))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "aisle") "aabbccddee" 0 4 2 10))
    (fail 'textual-prefix-length))

(OR (= 1 (textual-prefix-length (as-text "bail") (as-text "aabbccddee") 0 1 2 10))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "prefix") (as-text "preface") 0 5 1 6))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "aisle") (as-text "") 1 4 0 0))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "aisle") (as-text "aabbccddee") 1 4 3 3))
    (fail 'textual-prefix-length))

(OR (= 0 (textual-prefix-length (as-text "bail") (as-text "aabbccddee") 1 4 3 6))
    (fail 'textual-prefix-length))

(OR (= 3 (textual-prefix-length (as-text "prefix") (as-text "preface") 1 5 1 7))
    (fail 'textual-prefix-length))


(OR (= 0 (textual-suffix-length ABC ABCDEF))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length ABCDEF ABC))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length ABCDEF DEFABC))
    (fail 'textual-suffix-length))

(OR (= 6 (textual-suffix-length DEFABC DEFABC))
    (fail 'textual-suffix-length))

(OR (= 6 (textual-suffix-length (textual->string DEFABC) DEFABC))
    (fail 'textual-suffix-length))

(OR (= 6 (textual-suffix-length DEFABC (textual->string DEFABC)))
    (fail 'textual-suffix-length))

(OR (= 6 (textual-suffix-length (textual->string DEFABC) (textual->string DEFABC)))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "") (as-text "")))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "") (as-text "aabbccddee")))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "aisle") (as-text "")))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "") (as-text "aabbccddee")))
    (fail 'textual-suffix-length))

(OR (= 1 (textual-suffix-length (as-text "aisle") (as-text "aabbccddee")))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "bail") (as-text "aabbccddee")))
    (fail 'textual-suffix-length))

(OR (= 3 (textual-suffix-length (as-text "place") (as-text "preface")))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "") (as-text "") 0))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "") (as-text "aabbccddee") 0))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "aisle") (as-text "") 0))
    (fail 'textual-suffix-length))

(OR (= 1 (textual-suffix-length (as-text "aisle") (as-text "aabbccddee") 0))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "bail") (as-text "aabbccddee") 0))
    (fail 'textual-suffix-length))

(OR (= 3 (textual-suffix-length (as-text "place") (as-text "preface") 0))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "aisle") (as-text "") 1))
    (fail 'textual-suffix-length))

(OR (= 1 (textual-suffix-length (as-text "aisle") (as-text "aabbccddee") 1))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "bail") (as-text "aabbccddee") 1))
    (fail 'textual-suffix-length))

(OR (= 3 (textual-suffix-length (as-text "place") (as-text "preface") 1))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "") (as-text "") 0 0))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "") (as-text "aabbccddee") 0 0))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "aisle") (as-text "") 0 4))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "aisle") (as-text "aabbccddee") 0 4))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "bail") (as-text "aabbccddee") 0 1))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "aisle") (as-text "") 1 4))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "aisle") (as-text "aabbccddee") 1 4))
    (fail 'textual-suffix-length))

(OR (= 1 (textual-suffix-length (as-text "aisle") (as-text "aabbccddee") 1 5))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "bail") (as-text "aabbccddee") 1 4))
    (fail 'textual-suffix-length))

(OR (= 3 (textual-suffix-length (as-text "place") (as-text "preface") 1 5))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "") (as-text "") 0 0 0))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "") (as-text "aabbccddee") 0 0 0))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "aisle") (as-text "") 0 4 0))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "aisle") (as-text "aabbccddee") 0 4 2))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "bail") (as-text "aabbccddee") 0 1 2))
    (fail 'textual-suffix-length))

(OR (= 3 (textual-suffix-length (as-text "place") (as-text "preface") 0 5 1))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "aisle") (as-text "") 1 4 0))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "aisle") (as-text "aabbccddee") 1 4 3))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "bail") (as-text "aabbccddee") 1 4 3))
    (fail 'textual-suffix-length))

(OR (= 3 (textual-suffix-length (as-text "place") (as-text "preface") 1 5 1))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "") (as-text "") 0 0 0 0))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "") (as-text "aabbccddee") 0 0 0 0))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "aisle") (as-text "") 0 4 0 0))
    (fail 'textual-suffix-length))

(OR (= 1 (textual-suffix-length "aisle" (as-text "aabbccddee") 0 5 2 10))
    (fail 'textual-suffix-length))

(OR (= 1 (textual-suffix-length (as-text "bail") (as-text "aabbccddee") 0 1 2 4))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "place") (as-text "preface") 0 5 1 6))
    (fail 'textual-suffix-length))

(OR (= 2 (textual-suffix-length (as-text "place") (as-text "preface") 0 4 1 6))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "aisle") (as-text "") 1 4 0 0))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "aisle") (as-text "aabbccddee") 1 4 3 3))
    (fail 'textual-suffix-length))

(OR (= 0 (textual-suffix-length (as-text "bail") (as-text "aabbccddee") 1 4 3 6))
    (fail 'textual-suffix-length))

(OR (= 3 (textual-suffix-length (as-text "place") (as-text "preface") 1 5 1 7))
    (fail 'textual-suffix-length))


(OR (eq? #f (textual-prefix? ABC ABCDEF))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? ABCDEF ABC))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? ABCDEF DEFABC))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? DEFABC DEFABC))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (textual->string DEFABC) DEFABC))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? DEFABC (textual->string DEFABC)))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (textual->string DEFABC) (textual->string DEFABC)))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "") (as-text "")))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "") (as-text "abc")))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "a") (as-text "abc")))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? (as-text "c") (as-text "abc")))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "ab") (as-text "abc")))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? (as-text "ac") (as-text "abc")))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "abc") (as-text "abc")))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-suffix? ABC ABCDEF))
    (fail 'textual-suffix?))

(OR (eq? #f (textual-suffix? ABCDEF ABC))
    (fail 'textual-suffix?))

(OR (eq? #f (textual-suffix? ABCDEF DEFABC))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? DEFABC DEFABC))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (textual->string DEFABC) DEFABC))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? DEFABC (textual->string DEFABC)))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "") (as-text "")))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "") (as-text "abc")))
    (fail 'textual-suffix?))

(OR (eq? #f (textual-suffix? (as-text "a") (as-text "abc")))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "c") (as-text "abc")))
    (fail 'textual-suffix?))

(OR (eq? #f (textual-suffix? (as-text "ac") (as-text "abc")))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "bc") (as-text "abc")))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "abc") (as-text "abc")))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-prefix? (as-text "") (as-text "") 0))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "") (as-text "abc") 0))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "a") (as-text "abc") 0))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? (as-text "c") (as-text "abc") 0))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "ab") (as-text "abc") 0))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? (as-text "ac") (as-text "abc") 0))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "abc") (as-text "abc") 0))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-suffix? (as-text "") (as-text "") 0))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "") (as-text "abc") 0))
    (fail 'textual-suffix?))

(OR (eq? #f (textual-suffix? (as-text "a") (as-text "abc") 0))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "c") (as-text "abc") 0))
    (fail 'textual-suffix?))

(OR (eq? #f (textual-suffix? (as-text "ac") (as-text "abc") 0))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "bc") (as-text "abc") 0))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "abc") (as-text "abc") 0))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-prefix? (as-text "ab") (as-text "abc") 2))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "ac") (as-text "abc") 2))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? (as-text "abc") (as-text "abc") 2))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-suffix? (as-text "ac") (as-text "abc") 2))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "bc") (as-text "abc") 2))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "abc") (as-text "abc") 2))
    (fail 'textual-suffix?))


(OR (eq? #t (textual-prefix? (as-text "") (as-text "") 0 0))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "") (as-text "abc") 0 0))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "a") (as-text "abc") 0 0))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? (as-text "c") (as-text "abc") 0 1))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "ab") (as-text "abc") 0 1))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "ab") (as-text "abc") 0 2))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? (as-text "ac") (as-text "abc") 0 2))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "abc") (as-text "abc") 0 3))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-suffix? (as-text "") (as-text "") 0 0))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "") (as-text "abc") 0 0))
    (fail 'textual-suffix?))

(OR (eq? #f (textual-suffix? (as-text "a") (as-text "abc") 0 1))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "c") (as-text "abc") 0 1))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "ac") (as-text "abc") 1 2))
    (fail 'textual-suffix?))

(OR (eq? #f (textual-suffix? (as-text "ac") (as-text "abc") 0 2))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "bc") (as-text "abc") 0 2))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "abc") (as-text "abc") 0 3))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-prefix? (as-text "ab") (as-text "abc") 2 2))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "ac") (as-text "abc") 2 2))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? (as-text "abc") (as-text "abc") 2 3))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-suffix? (as-text "ac") (as-text "abc") 2 2))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "bc") (as-text "abc") 2 2))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "abc") (as-text "abc") 2 3))
    (fail 'textual-suffix?))


(OR (eq? #t (textual-prefix? (as-text "") (as-text "") 0 0 0))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "") (as-text "abc") 0 0 0))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "a") (as-text "abc") 0 0 0))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? (as-text "c") (as-text "abc") 0 1 0))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "ab") (as-text "abc") 0 1 0))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "ab") (as-text "abc") 0 2 0))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? (as-text "ac") (as-text "abc") 0 2 0))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "abc") (as-text "abc") 0 3 0))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-suffix? (as-text "") (as-text "") 0 0 0))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "") (as-text "abc") 0 0 0))
    (fail 'textual-suffix?))

(OR (eq? #f (textual-suffix? (as-text "a") (as-text "abc") 0 1 0))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "c") (as-text "abc") 0 1 0))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "ac") (as-text "abc") 1 2 0))
    (fail 'textual-suffix?))

(OR (eq? #f (textual-suffix? (as-text "ac") (as-text "abc") 0 2 0))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "bc") (as-text "abc") 0 2 0))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "abc") (as-text "abc") 0 3 0))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-prefix? (as-text "ab") (as-text "abc") 2 2 0))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "ac") (as-text "abc") 2 2 0))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? (as-text "abc") (as-text "abc") 2 3 0))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-suffix? (as-text "ac") (as-text "abc") 2 2 0))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "bc") (as-text "abc") 2 2 0))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "abc") (as-text "abc") 2 3 0))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-prefix? (as-text "") (as-text "abc") 0 0 1))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "a") (as-text "abc") 0 0 1))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "c") (as-text "abc") 0 1 2))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? (as-text "ab") (as-text "abc") 0 1 2))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? (as-text "ab") (as-text "abc") 0 2 1))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? (as-text "ac") (as-text "abc") 0 2 1))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? (as-text "abc") (as-text "abc") 0 3 1))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-suffix? (as-text "a") (as-text "abc") 0 1 2))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "c") (as-text "abc") 0 1 1))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "ac") (as-text "abc") 1 2 2))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "bc") (as-text "abc") 0 2 1))
    (fail 'textual-suffix?))

(OR (eq? #f (textual-suffix? (as-text "bc") (as-text "abc") 0 2 2))
    (fail 'textual-suffix?))


(OR (eq? #t (textual-prefix? (as-text "") (as-text "") 0 0 0 0))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "") (as-text "abc") 0 0 0 3))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "a") (as-text "abc") 0 0 0 3))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? (as-text "c") (as-text "abc") 0 1 0 3))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "ab") (as-text "abc") 0 1 0 3))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "ab") (as-text "abc") 0 2 0 3))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? (as-text "ac") (as-text "abc") 0 2 0 3))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "abc") (as-text "abc") 0 3 0 3))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-suffix? (as-text "") (as-text "abc") 0 0 0 3))
    (fail 'textual-suffix?))

(OR (eq? #f (textual-suffix? (as-text "a") (as-text "abc") 0 1 0 3))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "c") (as-text "abc") 0 1 0 3))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "ac") (as-text "abc") 1 2 0 3))
    (fail 'textual-suffix?))

(OR (eq? #f (textual-suffix? (as-text "ac") (as-text "abc") 0 2 0 3))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "bc") (as-text "abc") 0 2 0 3))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "abc") (as-text "abc") 0 3 0 3))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-prefix? (as-text "ab") (as-text "abc") 2 2 0 3))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "ac") (as-text "abc") 2 2 0 3))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? (as-text "abc") (as-text "abc") 2 3 0 3))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-suffix? (as-text "ac") (as-text "abc") 2 2 0 3))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "bc") (as-text "abc") 2 2 0 3))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "abc") (as-text "abc") 2 3 0 3))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-prefix? (as-text "") (as-text "abc") 0 0 1 3))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "a") (as-text "abc") 0 0 1 3))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "c") (as-text "abc") 0 1 2 3))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? (as-text "ab") (as-text "abc") 0 1 2 3))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? (as-text "ab") (as-text "abc") 0 2 1 3))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? (as-text "ac") (as-text "abc") 0 2 1 3))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? (as-text "abc") (as-text "abc") 0 3 1 3))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-suffix? (as-text "a") (as-text "abc") 0 1 2 3))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "c") (as-text "abc") 0 1 1 3))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "ac") (as-text "abc") 1 2 2 3))
    (fail 'textual-suffix?))

(OR (eq? #t (textual-suffix? (as-text "bc") (as-text "abc") 0 2 1 3))
    (fail 'textual-suffix?))

(OR (eq? #f (textual-suffix? (as-text "bc") (as-text "abc") 0 2 2 3))
    (fail 'textual-suffix?))


(OR (eq? #t (textual-prefix? (as-text "") (as-text "abc") 0 0 0 2))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "a") (as-text "abc") 0 0 0 2))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? (as-text "c") (as-text "abc") 0 1 0 2))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-prefix? (as-text "ab") (as-text "abc") 0 1 0 2))
    (fail 'textual-prefix?))

(OR (eq? #f (textual-prefix? (as-text "abc") (as-text "abc") 0 3 0 2))
    (fail 'textual-prefix?))

(OR (eq? #t (textual-suffix? (as-text "") (as-text "abc") 0 0 0 2))
    (fail 'textual-suffix?))

(OR (eq? #f (textual-suffix? (as-text "c") (as-text "abc") 0 1 0 2))
    (fail 'textual-suffix?))

(OR (eq? #f (textual-suffix? (as-text "ac") (as-text "abc") 1 2 0 2))
    (fail 'textual-suffix?))


;;; Searching

(OR (eqv? #f (textual-index (as-text "") char?))
    (fail 'textual-index))

(OR (eqv? 0 (textual-index (as-text "abcdef") char?))
    (fail 'textual-index))

(OR (eqv? 4 (textual-index (as-text "abcdef") (lambda (c) (char>? c #\d))))
    (fail 'textual-index))

(OR (eqv? #f (textual-index (as-text "abcdef") char-whitespace?))
    (fail 'textual-index))

(OR (eqv? #f (textual-index-right (as-text "") char?))
    (fail 'textual-index-right))

(OR (eqv? 5 (textual-index-right (as-text "abcdef") char?))
    (fail 'textual-index-right))

(OR (eqv? 5 (textual-index-right (as-text "abcdef")
                                 (lambda (c) (char>? c #\d))))
    (fail 'textual-index-right))


(OR (eqv? #f (textual-index-right (as-text "abcdef") char-whitespace?))
    (fail 'textual-index-right))

(OR (eqv? #f (textual-skip (as-text "") string?))
    (fail 'textual-skip))

(OR (eqv? 0 (textual-skip (as-text "abcdef") string?))
    (fail 'textual-skip))

(OR (eqv? 4 (textual-skip (as-text "abcdef") (lambda (c) (char<=? c #\d))))
    (fail 'textual-skip))

(OR (eqv? #f (textual-skip (as-text "abcdef") char?))
    (fail 'textual-skip))

(OR (eqv? #f (textual-skip-right (as-text "") string?))
    (fail 'textual-skip-right))

(OR (eqv? 5 (textual-skip-right (as-text "abcdef") string?))
    (fail 'textual-skip-right))

(OR (eqv? 5 (textual-skip-right (as-text "abcdef")
                                (lambda (c) (char<=? c #\d))))
    (fail 'textual-skip-right))

(OR (eqv? #f (textual-skip-right (as-text "abcdef") char?))
    (fail 'textual-skip-right))


(OR (eqv? 2 (textual-index "abcdef" char? 2))
    (fail 'textual-index))

(OR (eqv? 4 (textual-index "abcdef" (lambda (c) (char>? c #\d)) 2))
    (fail 'textual-index))

(OR (eqv? #f (textual-index "abcdef" char-whitespace? 2))
    (fail 'textual-index))

(OR (eqv? 5 (textual-index-right "abcdef" char? 2))
    (fail 'textual-index-right))

(OR (eqv? 5 (textual-index-right "abcdef"
                                 (lambda (c)
                                   (char>? c #\d)) 2))
    (fail 'textual-index-right))

(OR (eqv? #f (textual-index-right "abcdef" char-whitespace? 2))
    (fail 'textual-index-right))

(OR (eqv? 2 (textual-skip "abcdef" string? 2))
    (fail 'textual-skip))

(OR (eqv? 4 (textual-skip "abcdef"
                          (lambda (c)
                            (char<=? c #\d)) 2))
    (fail 'textual-skip))

(OR (eqv? #f (textual-skip "abcdef" char? 2))
    (fail 'textual-skip))

(OR (eqv? 5 (textual-skip-right "abcdef" string? 2))
    (fail 'textual-skip-right))

(OR (eqv? 5 (textual-skip-right "abcdef"
                                (lambda (c)
                                  (char<=? c #\d)) 2))
    (fail 'textual-skip-right))

(OR (eqv? #f (textual-skip-right "abcdef" char? 2))
    (fail 'textual-skip-right))


(OR (eqv? 2 (textual-index (as-text "abcdef") char? 2 5))
    (fail 'textual-index))

(OR (eqv? 4 (textual-index (as-text "abcdef")
                           (lambda (c) (char>? c #\d)) 2 5))
    (fail 'textual-index))

(OR (eqv? #f (textual-index (as-text "abcdef") char-whitespace? 2 5))
    (fail 'textual-index))

(OR (eqv? 4 (textual-index-right (as-text "abcdef") char? 2 5))
    (fail 'textual-index-right))

(OR (eqv? 4 (textual-index-right (as-text "abcdef")
                                 (lambda (c)
                                   (char>? c #\d)) 2 5))
    (fail 'textual-index-right))

(OR (eqv? #f (textual-index-right (as-text "abcdef")
                                  char-whitespace? 2 5))
    (fail 'textual-index-right))


(OR (eqv? 2 (textual-skip (as-text "abcdef") string? 2 5))
    (fail 'textual-skip))

(OR (eqv? 4 (textual-skip (as-text "abcdef")
                          (lambda (c) (char<=? c #\d)) 2 5))
    (fail 'textual-skip))

(OR (eqv? #f (textual-skip (as-text "abcdef") char? 2 5))
    (fail 'textual-skip))

(OR (eqv? 4 (textual-skip-right (as-text "abcdef") string? 2 5))
    (fail 'textual-skip-right))

(OR (eqv? 4 (textual-skip-right (as-text "abcdef")
                                (lambda (c)
                                  (char<=? c #\d)) 2 5))
    (fail 'textual-skip-right))

(OR (eqv? #f (textual-skip-right (as-text "abcdef") char? 2 5))
    (fail 'textual-skip-right))


(OR (eqv? 0 (textual-contains (as-text "") (as-text "")))
    (fail 'textual-contains))

(OR (eqv? 0 (textual-contains (as-text "abcdeffffoo") (as-text "")))
    (fail 'textual-contains))

(OR (eqv? 0 (textual-contains (as-text "abcdeffffoo") (as-text "a")))
    (fail 'textual-contains))

(OR (eqv? 5 (textual-contains (as-text "abcdeffffoo") (as-text "ff")))
    (fail 'textual-contains))

(OR (eqv? 4 (textual-contains (as-text "abcdeffffoo") (as-text "eff")))
    (fail 'textual-contains))

(OR (eqv? 8 (textual-contains (as-text "abcdeffffoo") (as-text "foo")))
    (fail 'textual-contains))

(OR (eqv? #f (textual-contains (as-text "abcdeffffoo") (as-text "efffoo")))
    (fail 'textual-contains))

(OR (eqv? 0 (textual-contains-right (as-text "") (as-text "")))
    (fail 'textual-contains-right))

(OR (eqv? 11 (textual-contains-right (as-text "abcdeffffoo") (as-text "")))
    (fail 'textual-contains-right))

(OR (eqv? 0 (textual-contains-right (as-text "abcdeffffoo") (as-text "a")))
    (fail 'textual-contains-right))

(OR (eqv? 7 (textual-contains-right (as-text "abcdeffffoo") (as-text "ff")))
    (fail 'textual-contains-right))

(OR (eqv? 4 (textual-contains-right (as-text "abcdeffffoo") (as-text "eff")))
    (fail 'textual-contains-right))

(OR (eqv? 8 (textual-contains-right (as-text "abcdeffffoo") (as-text "foo")))
    (fail 'textual-contains-right))

(OR (eqv? #f (textual-contains-right (as-text "abcdeffffoo")
                                     (as-text "efffoo")))
    (fail 'textual-contains-right))


(OR (eqv? 0 (textual-contains "" "" 0))
    (fail 'textual-contains))

(OR (eqv? 2 (textual-contains "abcdeffffoo" "" 2))
    (fail 'textual-contains))

(OR (eqv? #f (textual-contains "abcdeffffoo" "a" 2))
    (fail 'textual-contains))

(OR (eqv? 5 (textual-contains "abcdeffffoo" "ff" 2))
    (fail 'textual-contains))

(OR (eqv? 4 (textual-contains "abcdeffffoo" "eff" 2))
    (fail 'textual-contains))

(OR (eqv? 8 (textual-contains "abcdeffffoo" "foo" 2))
    (fail 'textual-contains))

(OR (eqv? #f (textual-contains "abcdeffffoo" "efffoo" 2))
    (fail 'textual-contains))

(OR (eqv? 0 (textual-contains-right "" "" 0))
    (fail 'textual-contains-right))

(OR (eqv? 11 (textual-contains-right "abcdeffffoo" "" 2))
    (fail 'textual-contains-right))

(OR (eqv? #f (textual-contains-right "abcdeffffoo" "a" 2))
    (fail 'textual-contains-right))

(OR (eqv? 7 (textual-contains-right "abcdeffffoo" "ff" 2))
    (fail 'textual-contains-right))

(OR (eqv? 4 (textual-contains-right "abcdeffffoo" "eff" 2))
    (fail 'textual-contains-right))

(OR (eqv? 8 (textual-contains-right "abcdeffffoo" "foo" 2))
    (fail 'textual-contains-right))

(OR (eqv? #f (textual-contains-right "abcdeffffoo" "efffoo" 2))
    (fail 'textual-contains-right))


(OR (eqv? 0 (textual-contains (as-text "") (as-text "") 0 0))
    (fail 'textual-contains))

(OR (eqv? 2 (textual-contains (as-text "abcdeffffoo") (as-text "") 2 10))
    (fail 'textual-contains))

(OR (eqv? #f (textual-contains (as-text "abcdeffffoo") (as-text "a") 2 10))
    (fail 'textual-contains))

(OR (eqv? 5 (textual-contains (as-text "abcdeffffoo") (as-text "ff") 2 10))
    (fail 'textual-contains))

(OR (eqv? 4 (textual-contains (as-text "abcdeffffoo") (as-text "eff") 2 10))
    (fail 'textual-contains))

(OR (eqv? #f (textual-contains (as-text "abcdeffffoo") (as-text "foo") 2 10))
    (fail 'textual-contains))

(OR (eqv? #f (textual-contains (as-text "abcdeffffoo") (as-text "efffoo") 2 10))
    (fail 'textual-contains))

(OR (eqv? 0 (textual-contains-right (as-text "") (as-text "") 0 0))
    (fail 'textual-contains-right))

(OR (eqv? 10 (textual-contains-right (as-text "abcdeffffoo") (as-text "") 2 10))
    (fail 'textual-contains-right))

(OR (eqv? #f (textual-contains-right (as-text "abcdeffffoo") (as-text "a") 2 10))
    (fail 'textual-contains-right))

(OR (eqv? 7 (textual-contains-right (as-text "abcdeffffoo") (as-text "ff") 2 10))
    (fail 'textual-contains-right))

(OR (eqv? 4 (textual-contains-right (as-text "abcdeffffoo") (as-text "eff") 2 10))
    (fail 'textual-contains-right))

(OR (eqv? #f (textual-contains-right (as-text "abcdeffffoo") "foo" 2 10))
    (fail 'textual-contains-right))

(OR (eqv? #f (textual-contains-right "abcdeffffoo" (as-text "efffoo") 2 10))
    (fail 'textual-contains-right))


(OR (eqv? 0 (textual-contains "" "" 0 0 0))
    (fail 'textual-contains))

(OR (eqv? 2 (textual-contains "abcdeffffoo" "" 2 10 0))
    (fail 'textual-contains))

(OR (eqv? 2 (textual-contains "abcdeffffoo" "a" 2 10 1))
    (fail 'textual-contains))

(OR (eqv? 5 (textual-contains "abcdeffffoo" "ff" 2 10 1))
    (fail 'textual-contains))

(OR (eqv? 5 (textual-contains "abcdeffffoo" "eff" 2 10 1))
    (fail 'textual-contains))

(OR (eqv? #f (textual-contains "abcdeffffoo" "foo" 2 10 1))
    (fail 'textual-contains))

(OR (eqv? #f (textual-contains "abcdeffffoo" "efffoo" 2 10 1))
    (fail 'textual-contains))

(OR (eqv? 0 (textual-contains-right "" "" 0 0 0))
    (fail 'textual-contains-right))

(OR (eqv? 10 (textual-contains-right "abcdeffffoo" "" 2 10 0))
    (fail 'textual-contains-right))

(OR (eqv? 10 (textual-contains-right "abcdeffffoo" "a" 2 10 1))
    (fail 'textual-contains-right))

(OR (eqv? 8 (textual-contains-right "abcdeffffoo" "ff" 2 10 1))
    (fail 'textual-contains-right))

(OR (eqv? 7 (textual-contains-right "abcdeffffoo" "eff" 2 10 1))
    (fail 'textual-contains-right))

(OR (eqv? #f (textual-contains-right "abcdeffffoo" "foo" 2 10 1))
    (fail 'textual-contains-right))

(OR (eqv? #f (textual-contains-right "abcdeffffoo" "efffoo" 2 10 1))
    (fail 'textual-contains-right))


(OR (eqv? 0 (textual-contains "" "" 0 0 0 0))
    (fail 'textual-contains))

(OR (eqv? 2 (textual-contains "abcdeffffoo" "" 2 10 0 0))
    (fail 'textual-contains))

(OR (eqv? 2 (textual-contains "abcdeffffoo" "a" 2 10 1 1))
    (fail 'textual-contains))

(OR (eqv? 5 (textual-contains "abcdeffffoo" "ff" 2 10 1 2))
    (fail 'textual-contains))

(OR (eqv? 5 (textual-contains "abcdeffffoo" "eff" 2 10 1 2))
    (fail 'textual-contains))

(OR (eqv? 9 (textual-contains "abcdeffffoo" "foo" 2 10 1 2))
    (fail 'textual-contains))

(OR (eqv? 4 (textual-contains "abcdeffffoo" "efffoo" 2 10 0 2))
    (fail 'textual-contains))

(OR (eqv? 0 (textual-contains-right "" "" 0 0 0 0))
    (fail 'textual-contains-right))

(OR (eqv? 10 (textual-contains-right "abcdeffffoo" "" 2 10 0 0))
    (fail 'textual-contains-right))

(OR (eqv? 10 (textual-contains-right "abcdeffffoo" "a" 2 10 1 1))
    (fail 'textual-contains-right))

(OR (eqv? 8  (textual-contains-right "abcdeffffoo" "ff" 2 10 1 2))
    (fail 'textual-contains-right))

(OR (eqv? 8 (textual-contains-right "abcdeffffoo" "eff" 2 10 1 2))
    (fail 'textual-contains-right))

(OR (eqv? 9 (textual-contains-right "abcdeffffoo" "foo" 2 10 1 2))
    (fail 'textual-contains-right))

(OR (eqv? 7 (textual-contains-right "abcdeffffoo" "efffoo" 2 10 1 3))
    (fail 'textual-contains-right))


;;; Case conversion

;;; FIXME: should test some non-ASCII cases here.

(OR (result=? "1234STRIKES" (textual-upcase (as-text "1234Strikes")))
    (fail 'textual-upcase))

(OR (result=? "1234STRIKES" (textual-upcase (as-text "1234strikes")))
    (fail 'textual-upcase))

(OR (result=? "1234STRIKES" (textual-upcase (as-text "1234STRIKES")))
    (fail 'textual-upcase))

(OR (result=? "1234strikes" (textual-downcase (as-text "1234Strikes")))
    (fail 'textual-downcase))

(OR (result=? "1234strikes" (textual-downcase (as-text "1234strikes")))
    (fail 'textual-downcase))

(OR (result=? "1234strikes" (textual-downcase (as-text "1234STRIKES")))
    (fail 'textual-downcase))

(OR (result=? "1234strikes" (textual-foldcase (as-text "1234Strikes")))
    (fail 'textual-foldcase))

(OR (result=? "1234strikes" (textual-foldcase (as-text "1234strikes")))
    (fail 'textual-foldcase))

(OR (result=? "1234strikes" (textual-foldcase (as-text "1234STRIKES")))
    (fail 'textual-foldcase))

(OR (result=? "And With Three Strikes You Are Out"
              (textual-titlecase
               (as-text "and with THREE STRIKES you are oUT")))
    (fail 'textual-titlecase))

;;; Concatenation

(OR (result=? "" (textual-append))
    (fail 'textual-append))

(OR (result=? "abcdef"
              
              (textual-append (as-text "")
                              (as-text "a")
                              (as-text "bcd")
                              "" "ef" "" ""))
    (fail 'textual-append))

(OR (result=? "" (textual-concatenate '()))
    (fail 'textual-concatenate))

(OR (result=? "abcdef"
              (textual-concatenate
               (map string->text '("" "a" "bcd" "" "ef" "" ""))))
    (fail 'textual-concatenate))

;;; textual-concatenate is likely to have special cases for longer texts.

(let* ((alphabet "abcdefghijklmnopqrstuvwxyz")
       (str1 alphabet)
       (str10 (apply string-append (vector->list (make-vector 10 str1))))
       (str100 (apply string-append (vector->list (make-vector 10 str10))))
       (str100-500 (substring str100 100 500))
       (str600-999 (substring str100 600 999))
       (alph1 (textual-copy alphabet))
       (alph10 (textual-concatenate (vector->list (make-vector 10 alph1))))
       (alph100 (textual-concatenate (vector->list (make-vector 10 alph10))))
       (t100-500 (subtext alph100 100 500))
       (t600-999 (subtext alph100 600 999)))

  (OR (result=? str10 alph10)
      (fail 'textual-concatenate))

  (OR (result=? str100 alph100)
      (fail 'textual-concatenate))

  (OR (result=? str100-500 t100-500)
      (fail 'textual-concatenate))

  (OR (result=? str600-999 t600-999)
      (fail 'textual-concatenate))

  ;; concatenating a short text with a long text

  (OR (result=? (string-append str1 str600-999)
                (textual-concatenate (list alph1 t600-999)))
      (fail 'textual-concatenate))

  (OR (result=? (string-append str1 str600-999)
                (textual-concatenate (list alph1 (textual-copy t600-999))))
      (fail 'textual-concatenate))

  (OR (result=? (string-append str600-999 str1)
                (textual-concatenate (list t600-999 alph1)))
      (fail 'textual-concatenate))

  (OR (result=? (string-append str600-999 str1)
                (textual-concatenate (list (textual-copy t600-999) alph1)))
      (fail 'textual-concatenate)))


(OR (result=? "" (textual-concatenate-reverse '()))
    (fail 'textual-concatenate-reverse))

(OR (result=? "efbcda"
              (textual-concatenate-reverse
               (map string->text '("" "a" "bcd" "" "ef" "" ""))))
    (fail 'textual-concatenate-reverse))

(OR (result=? "huh?"
              (textual-concatenate-reverse '() "huh?"))
    (fail 'textual-concatenate-reverse))

(OR (result=? "efbcdaxy"
              (textual-concatenate-reverse '("" "a" "bcd" "" "ef" "" "") "xy"))
    (fail 'textual-concatenate-reverse))

(OR (result=? "huh"
              (textual-concatenate-reverse '() "huh?" 3))
    (fail 'textual-concatenate-reverse))

(OR (result=? "efbcdax"
              (textual-concatenate-reverse
               '("" "a" "bcd" "" "ef" "" "") "x" 1))
    (fail 'textual-concatenate-reverse))


(OR (result=? "" (textual-join '()))
    (fail 'textual-join))

(OR (result=? " ab cd  e f "
              (textual-join (map string->text '("" "ab" "cd" "" "e" "f" ""))))
    (fail 'textual-join))

(OR (result=? ""
              (textual-join '() ""))
    (fail 'textual-join))

(OR (result=? "abcdef"
              (textual-join '("" "ab" "cd" "" "e" "f" "") ""))
    (fail 'textual-join))

(OR (result=? ""
              (textual-join '() "xyz"))
    (fail 'textual-join))

(OR (result=? "xyzabxyzcdxyzxyzexyzfxyz"
              (textual-join '("" "ab" "cd" "" "e" "f" "") "xyz"))
    (fail 'textual-join))

(OR (result=? ""
              (textual-join '() "" 'infix))
    (fail 'textual-join))

(OR (result=? "abcdef"
              (textual-join '("" "ab" "cd" "" "e" "f" "") "" 'infix))
    (fail 'textual-join))

(OR (result=? ""
              (textual-join '() "xyz" 'infix))
    (fail 'textual-join))

(OR (result=? "xyzabxyzcdxyzxyzexyzfxyz"
              (textual-join '("" "ab" "cd" "" "e" "f" "") (as-text "xyz") 'infix))
    (fail 'textual-join))

(OR (equal? 'horror
            (guard (exn (#t 'horror))
                   (textual-join '() "" 'strict-infix)))
    (fail 'textual-join))

(OR (result=? "abcdef"
              (textual-join '("" "ab" "cd" "" "e" "f" "") "" 'strict-infix))
    (fail 'textual-join))

(OR (equal? 'wham
            (guard (exn (else 'wham))
                   (textual-join '() "xyz" 'strict-infix)))
    (fail 'textual-join))

(OR (result=? "xyzabxyzcdxyzxyzexyzfxyz"
              (textual-join '("" "ab" "cd" "" "e" "f" "") "xyz" 'strict-infix))
    (fail 'textual-join))

(OR (result=? ""
              (textual-join '() "" 'suffix))
    (fail 'textual-join))

(OR (result=? "abcdef"
              (textual-join '("" "ab" "cd" "" "e" "f" "") "" 'suffix))
    (fail 'textual-join))

(OR (result=? ""
              (textual-join '() "xyz" 'suffix))
    (fail 'textual-join))

(OR (result=? "xyzabxyzcdxyzxyzexyzfxyzxyz"
              (textual-join '("" "ab" "cd" "" "e" "f" "") "xyz" 'suffix))
    (fail 'textual-join))

(OR (result=? ""
              (textual-join '() "" 'prefix))
    (fail 'textual-join))

(OR (result=? "abcdef"
              (textual-join '("" "ab" "cd" "" "e" "f" "") "" 'prefix))
    (fail 'textual-join))

(OR (result=? ""
              (textual-join '() "xyz" 'prefix))
    (fail 'textual-join))

(OR (result=? "xyzxyzabxyzcdxyzxyzexyzfxyz"
              (textual-join '("" "ab" "cd" "" "e" "f" "") "xyz" 'prefix))
    (fail 'textual-join))


;;; Fold & map & friends

(OR (= 8
       (textual-fold (lambda (c count)
                       (if (char-whitespace? c)
                           (+ count 1)
                           count))
                     0
                     (as-text " ...a couple of spaces in this one... ")))
    (fail 'textual-fold))

(OR (= 7
       (textual-fold (lambda (c count)
                       (if (char-whitespace? c)
                           (+ count 1)
                           count))
                     0
                     " ...a couple of spaces in this one... "
                     1))
    (fail 'textual-fold))

(OR (= 6
       (textual-fold (lambda (c count)
                       (if (char-whitespace? c)
                           (+ count 1)
                           count))
                     0
                     " ...a couple of spaces in this one... "
                     1
                     32))
    (fail 'textual-fold))

(OR (equal? (string->list "abcdef")
            (textual-fold-right cons '() "abcdef"))
    (fail 'textual-fold-right))

(OR (equal? (string->list "def")
            (textual-fold-right cons '() (as-text "abcdef") 3))
    (fail 'textual-fold-right))

(OR (equal? (string->list "cde")
            (textual-fold-right cons '() (as-text "abcdef") 2 5))
    (fail 'textual-fold-right))

(OR (string=? "aabraacaadaabraa"
              (let* ((s (as-text "abracadabra"))
                     (ans-len (textual-fold (lambda (c sum)
                                              (+ sum (if (char=? c #\a) 2 1)))
                                            0 s))
                     (ans (make-string ans-len)))
                (textual-fold (lambda (c i)
                                (let ((i (if (char=? c #\a)
                                             (begin (string-set! ans i #\a)
                                                    (+ i 1))
                                             i)))
                                  (string-set! ans i c)
                                  (+ i 1)))
                              0 s)
                ans))
    (fail 'textual-fold))


(OR (result=? "abc" (textual-map string (as-text "abc")))
    (fail 'textual-map))

(OR (result=? "ABC" (textual-map char-upcase "abc"))
    (fail 'textual-map))

(OR (result=? "Hear-here!"
              (textual-map (lambda (c0 c1 c2)
                             (case c0
                               ((#\1) c1)
                               ((#\2) (string c2))
                               ((#\-) (text #\- c1))))
                           (string->text "1222-1111-2222")
                           (string->text "Hi There!")
                           (string->text "Dear John")))
    (fail 'textual-map))

(OR (string=? "abc"
              (let ((q (open-output-string)))
                (textual-for-each (lambda (c) (write-char c q))
                                  (as-text "abc"))
                (get-output-string q)))
    (fail 'textual-for-each))

(OR (equal? '("cfi" "beh" "adg")
            (let ((x '()))
              (textual-for-each (lambda (c1 c2 c3)
                                  (set! x (cons (string c1 c2 c3) x)))
                                "abc"
                                (as-text "defxyz")
                                (as-text "ghijklmnopqrstuvwxyz"))
              x))
    (fail 'textual-for-each))

(OR (result=? "abc"
              (textual-map-index (lambda (i)
                                   (integer->char (+ i (char->integer #\a))))
                                 "xyz"))
    (fail 'textual-map-index))

(OR (result=? "def"
              (textual-map-index (lambda (i)
                                   (integer->char (+ i (char->integer #\a))))
                                 "xyz***" 3))
    (fail 'textual-map-index))

(OR (result=? "cde"
              (textual-map-index (lambda (i)
                                   (integer->char (+ i (char->integer #\a))))
                                 "......" 2 5))
    (fail 'textual-map-index))

(OR (equal? '(101 100 99 98 97)
            (let ((s (as-text "abcde"))
                  (v '()))
              (textual-for-each-index
               (lambda (i)
                 (set! v (cons (char->integer (textual-ref s i)) v)))
               s)
              v))
    (fail 'textual-for-each-index))

(OR (equal? '(101 100 99)
            (let ((s (as-text "abcde"))
                  (v '()))
              (textual-for-each-index
               (lambda (i)
                 (set! v (cons (char->integer (textual-ref s i)) v)))
               s 2)
              v))
    (fail 'textual-for-each-index))

(OR (equal? '(99 98)
            (let ((s (as-text "abcde"))
                  (v '()))
              (textual-for-each-index
               (lambda (i)
                 (set! v (cons (char->integer (textual-ref s i)) v)))
               s 1 3)
              v))
    (fail 'textual-for-each-index))

(OR (= 6 (textual-count "abcdef" char?))
    (fail 'textual-count))

(OR (= 4 (textual-count "counting  whitespace, again " char-whitespace? 5))
    (fail 'textual-count))

(OR (= 3 (textual-count "abcdefwxyz"
                        (lambda (c) (odd? (char->integer c)))
                        2 8))
    (fail 'textual-count))


(OR (result=? "aiueaaaoi"
              (textual-filter (lambda (c) (memv c (textual->list "aeiou")))
                              (as-text "What is number, that man may know it?")))
    (fail 'textual-filter))

(OR (result=? "And wmn, tht sh my knw nmbr?"
              (textual-remove (lambda (c) (memv c (textual->list "aeiou")))
                              "And woman, that she may know number?"))
    (fail 'textual-remove))

(OR (result=? "iueaaaoi"
              (textual-filter (lambda (c) (memv c (textual->list "aeiou")))
                              (as-text "What is number, that man may know it?")
                              4))
    (fail 'textual-filter))

(OR (result=? "mn, tht sh my knw nmbr?"
              (textual-remove (lambda (c) (memv c (textual->list "aeiou")))
                              "And woman, that she may know number?"
                              6))
    (fail 'textual-remove))

(OR (result=? "aaao"
              (textual-filter (lambda (c) (memv c (textual->list "aeiou")))
                              (as-text "What is number, that man may know it?")
                              16 32))
    (fail 'textual-filter))

(OR (result=? "And woman, that sh may know"
              (textual-remove (lambda (c) (memv c (textual->list "eiu")))
                              "And woman, that she may know number?"
                              0 28))
    (fail 'textual-remove))


#|
(OR (result=? "" (textual-reverse ""))
    (fail 'textual-reverse))

(OR (result=? "fedcba" (textual-reverse "abcdef"))
    (fail 'textual-reverse))

(OR (result=? "" (textual-reverse (as-text "") 0))
    (fail 'textual-reverse))

(OR (result=? "fedcba" (textual-reverse "abcdef" 0))
    (fail 'textual-reverse))

(OR (result=? "fedc" (textual-reverse (as-text "abcdef") 2))
    (fail 'textual-reverse))

(OR (result=? "" (textual-reverse "" 0 0))
    (fail 'textual-reverse))

(OR (result=? "fedcba" (textual-reverse "abcdef" 0 6))
    (fail 'textual-reverse))

(OR (result=? "edc" (textual-reverse "abcdef" 2 5))
    (fail 'textual-reverse))
|#


;;; Replication and splitting

(OR (result=? "cdefabcdefabcd"
              (textual-replicate "abcdef" -4 10))
    (fail 'textual-replicate))

(OR (result=? "bcdefbcdefbcd"
              (textual-replicate "abcdef" 90 103 1))
    (fail 'textual-replicate))

(OR (result=? "ecdecdecde"
              (textual-replicate "abcdef" -13 -3 2 5))
    (fail 'textual-replicate))

(OR (equal? '() (map textual->string (textual-split "" "")))
    (fail 'textual-split))

(OR (equal? '("a" "b" "c") (map textual->string (textual-split "abc" "")))
    (fail 'textual-split))

(OR (equal? '("too" "" "much" "" "data")
            (map textual->string
                 (textual-split "too  much  data" " ")))
    (fail 'textual-split))

(OR (equal? '("" "there" "ya" "go" "")
            (map textual->string
                 (textual-split "***there***ya***go***" "***")))
    (fail 'textual-split))

(OR (equal? '() (map textual->string (textual-split "" "" 'infix)))
    (fail 'textual-split))

(OR (equal? '("a" "b" "c")
            (map textual->string (textual-split "abc" "" 'infix)))
    (fail 'textual-split))

(OR (equal? '("too" "" "much" "" "data")
            (map textual->string
                 (textual-split "too  much  data" " " 'infix)))
    (fail 'textual-split))

(OR (equal? '("" "there" "ya" "go" "")
            (map textual->string
                 (textual-split "***there***ya***go***" "***" 'infix)))
    (fail 'textual-split))

(OR (equal? 'error
            (guard (exn (else 'error))
                   (map textual->string
                        (textual-split "" "" 'strict-infix))))
    (fail 'textual-split))

(OR (equal? '("a" "b" "c")
            (map textual->string
                 (textual-split "abc" "" 'strict-infix)))
    (fail 'textual-split))

(OR (equal? '("too" "" "much" "" "data")
            (map textual->string
                 (textual-split "too  much  data" " " 'strict-infix)))
    (fail 'textual-split))

(OR (equal? '("" "there" "ya" "go" "")
            (map textual->string
                 (textual-split "***there***ya***go***" "***" 'strict-infix)))
    (fail 'textual-split))

(OR (equal? '()
            (map textual->string
                 (textual-split "" "" 'prefix)))
    (fail 'textual-split))

(OR (equal? '("a" "b" "c")
            (map textual->string
                 (textual-split "abc" "" 'prefix)))
    (fail 'textual-split))

(OR (equal? '("too" "" "much" "" "data")
            (map textual->string
                 (textual-split "too  much  data" " " 'prefix)))
    (fail 'textual-split))

(OR (equal? '("there" "ya" "go" "")
            (map textual->string
                 (textual-split "***there***ya***go***" "***" 'prefix)))
    (fail 'textual-split))

(OR (equal? '()
            (map textual->string
                 (textual-split "" "" 'suffix)))
    (fail 'textual-split))

(OR (equal? '("a" "b" "c")
            (map textual->string
                 (textual-split "abc" "" 'suffix)))
    (fail 'textual-split))

(OR (equal? '("too" "" "much" "" "data")
            (map textual->string
                 (textual-split "too  much  data" " " 'suffix)))
    (fail 'textual-split))

(OR (equal? '("" "there" "ya" "go")
            (map textual->string
                 (textual-split "***there***ya***go***" "***" 'suffix)))
    (fail 'textual-split))


(OR (equal? '()
            (map textual->string
                 (textual-split "" "" 'infix #f)))
    (fail 'textual-split))

(OR (equal? '("a" "b" "c")
            (map textual->string
                 (textual-split "abc" "" 'infix #f)))
    (fail 'textual-split))

(OR (equal? '("too" "" "much" "" "data")
            (map textual->string
                 (textual-split "too  much  data" " " 'infix #f)))
    (fail 'textual-split))

(OR (equal? '("" "there" "ya" "go" "")
            (map textual->string
                 (textual-split "***there***ya***go***" "***" 'infix #f)))
    (fail 'textual-split))

(OR (equal? 'error
            (guard (exn (else 'error))
                   (map textual->string
                        (textual-split "" "" 'strict-infix #f))))
    (fail 'textual-split))

(OR (equal? '("a" "b" "c")
            (map textual->string
                 (textual-split "abc" "" 'strict-infix #f)))
    (fail 'textual-split))

(OR (equal? '("too" "" "much" "" "data")
            (map textual->string
                 (textual-split "too  much  data" " " 'strict-infix #f)))
    (fail 'textual-split))

(OR (equal? '("" "there" "ya" "go" "")
            (map textual->string
                 (textual-split "***there***ya***go***" "***" 'strict-infix #f)))
    (fail 'textual-split))

(OR (equal? '()
            (map textual->string
                 (textual-split "" "" 'prefix #f)))
    (fail 'textual-split))

(OR (equal? '("a" "b" "c")
            (map textual->string
                 (textual-split "abc" "" 'prefix #f)))
    (fail 'textual-split))

(OR (equal? '("too" "" "much" "" "data")
            (map textual->string
                 (textual-split "too  much  data" " " 'prefix #f)))
    (fail 'textual-split))

(OR (equal? '("there" "ya" "go" "")
            (map textual->string
                 (textual-split "***there***ya***go***" "***" 'prefix #f)))
    (fail 'textual-split))

(OR (equal? '()
            (map textual->string
                 (textual-split "" "" 'suffix #f)))
    (fail 'textual-split))

(OR (equal? '("a" "b" "c")
            (map textual->string
                 (textual-split "abc" "" 'suffix #f)))
    (fail 'textual-split))

(OR (equal? '("too" "" "much" "" "data")
            (map textual->string
                 (textual-split "too  much  data" " " 'suffix #f)))
    (fail 'textual-split))

(OR (equal? '("" "there" "ya" "go")
            (map textual->string
                 (textual-split "***there***ya***go***" "***" 'suffix #f)))
    (fail 'textual-split))


(OR (equal? 'error
            (guard (exn (else 'error))
                   (map textual->string
                        (textual-split "" "" 'strict-infix 3))))
    (fail 'textual-split))

(OR (equal? '("a" "b" "c")
            (map textual->string
                 (textual-split "abc" "" 'strict-infix 3)))
    (fail 'textual-split))

(OR (equal? '("too" "" "much" " data")
            (map textual->string
                 (textual-split "too  much  data" " " 'strict-infix 3)))
    (fail 'textual-split))

(OR (equal? '("" "there" "ya" "go***")
            (map textual->string
                 (textual-split "***there***ya***go***" "***" 'strict-infix 3)))
    (fail 'textual-split))

(OR (equal? '()
            (map textual->string
                 (textual-split "" "" 'prefix 3)))
    (fail 'textual-split))

(OR (equal? '("a" "b" "c")
            (map textual->string
                 (textual-split "abc" "" 'prefix 3)))
    (fail 'textual-split))

(OR (equal? '("too" "" "much" " data")
            (map textual->string
                 (textual-split "too  much  data" " " 'prefix 3)))
    (fail 'textual-split))

(OR (equal? '("there" "ya" "go***")
            (map textual->string
                 (textual-split "***there***ya***go***" "***" 'prefix 3)))
    (fail 'textual-split))

(OR (equal? '()
            (map textual->string
                 (textual-split "" "" 'suffix 3)))
    (fail 'textual-split))

(OR (equal? '("a" "b" "c")
            (map textual->string
                 (textual-split "abc" "" 'suffix 3)))
    (fail 'textual-split))

(OR (equal? '("too" "" "much" " data")
            (map textual->string
                 (textual-split "too  much  data" " " 'suffix 3)))
    (fail 'textual-split))

(OR (equal? '("" "there" "ya" "go***")
            (map textual->string
                 (textual-split "***there***ya***go***" "***" 'suffix 3)))
    (fail 'textual-split))


(OR (equal? 'error
            (guard (exn (else 'error))
                   (map textual->string
                        (textual-split "" "" 'strict-infix 3 0))))
    (fail 'textual-split))

(OR (equal? '("b" "c")
            (map textual->string
                 (textual-split "abc" "" 'strict-infix 3 1)))
    (fail 'textual-split))

(OR (equal? '("oo" "" "much" " data")
            (map textual->string
                 (textual-split "too  much  data" " " 'strict-infix 3 1)))
    (fail 'textual-split))

(OR (equal? '("**there" "ya" "go" "")
            (map textual->string
                 (textual-split "***there***ya***go***" "***" 'strict-infix 3 1)))
    (fail 'textual-split))

(OR (equal? '()
            (map textual->string
                 (textual-split "" "" 'prefix 3 0)))
    (fail 'textual-split))

(OR (equal? '("b" "c")
            (map textual->string
                 (textual-split "abc" "" 'prefix 3 1)))
    (fail 'textual-split))

(OR (equal? '("oo" "" "much" " data")
            (map textual->string
                 (textual-split "too  much  data" " " 'prefix 3 1)))
    (fail 'textual-split))

(OR (equal? '("**there" "ya" "go" "")
            (map textual->string
                 (textual-split "***there***ya***go***" "***" 'prefix 3 1)))
    (fail 'textual-split))

(OR (equal? '()
            (map textual->string
                 (textual-split "" "" 'suffix 3 0)))
    (fail 'textual-split))

(OR (equal? '("b" "c")
            (map textual->string
                 (textual-split "abc" "" 'suffix 3 1)))
    (fail 'textual-split))

(OR (equal? '("oo" "" "much" " data")
            (map textual->string
                 (textual-split "too  much  data" " " 'suffix 3 1)))
    (fail 'textual-split))

(OR (equal? '("**there" "ya" "go")
            (map textual->string
                 (textual-split "***there***ya***go***" "***" 'suffix 3 1)))
    (fail 'textual-split))


(OR (equal? 'error
            (guard (exn (else 'error))
                   (map textual->string
                        (textual-split "" "" 'strict-infix 3 0 0))))
    (fail 'textual-split))

(OR (equal? '("b")
            (map textual->string
                 (textual-split "abc" "" 'strict-infix 3 1 2)))
    (fail 'textual-split))

(OR (equal? '("oo" "" "much" " ")
            (map textual->string
                 (textual-split "too  much  data" " " 'strict-infix 3 1 11)))
    (fail 'textual-split))

(OR (equal? '()
            (map textual->string
                 (textual-split "" "" 'prefix 3 0 0)))
    (fail 'textual-split))

(OR (equal? '("b")
            (map textual->string
                 (textual-split "abc" "" 'prefix 3 1 2)))
    (fail 'textual-split))

(OR (equal? '("oo" "" "much" " ")
            (map textual->string
                 (textual-split "too  much  data" " " 'prefix 3 1 11)))
    (fail 'textual-split))

(OR (equal? '()
            (map textual->string
                 (textual-split "" "" 'suffix 3 0 0)))
    (fail 'textual-split))

(OR (equal? '("b")
            (map textual->string
                 (textual-split "abc" "" 'suffix 3 1 2)))
    (fail 'textual-split))

(OR (equal? '("oo" "" "much" " ")
            (map textual->string
                 (textual-split "too  much  data" " " 'suffix 3 1 11)))
    (fail 'textual-split))

(writeln "Done.")
