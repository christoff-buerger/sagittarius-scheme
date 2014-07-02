;;; -*- mode:scheme; coding:utf-8; -*-
;;;
;;; text/sre.scm - SRE utilities
;;;  
;;;   Copyright (c) 2010-2014  Takashi Kato  <ktakashi@ymail.com>
;;;   
;;;   Redistribution and use in source and binary forms, with or without
;;;   modification, are permitted provided that the following conditions
;;;   are met:
;;;   
;;;   1. Redistributions of source code must retain the above copyright
;;;      notice, this list of conditions and the following disclaimer.
;;;  
;;;   2. Redistributions in binary form must reproduce the above copyright
;;;      notice, this list of conditions and the following disclaimer in the
;;;      documentation and/or other materials provided with the distribution.
;;;  
;;;   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;;;   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;;;   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
;;;   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
;;;   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;;;   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
;;;   TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
;;;   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
;;;   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;;;   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;;;   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;;;  

;; SRE -- S-expression regexp notation
;;   http://www.scsh.net/docu/post/sre.html
(library (text sre)
    (export &sre-parse-error sre-parse-error?
	    sre->regex
	    sre-parse
	    rx)
    (import (rnrs)
	    (srfi :1 lists)
	    (srfi :14 char-sets)
	    (srfi :26 cut)
	    (srfi :39 parameters)
	    (util list) ;; for slices
	    (sagittarius)
	    (sagittarius regex)
	    (sagittarius control)
	    (core misc) ;; for define-macro
	    (match))

(define-condition-type &sre-parse-error &error
  make-sre-parse-error sre-parse-error?)

(define (sre-parse-error who msg . irr)
  (raise (apply condition
		(filter values
			(list (make-sre-parse-error)
			      (and who (make-who-condition who))
			      (make-message-condition msg)
			      (make-irritants-condition irr))))))

;; based on 
;;  http://www.katch.ne.jp/~leque/software/repos/gauche-sre/util/
(define case-sensitive? (make-parameter #t))

(define (sre->regex sre) (compile-regex-ast (sre-parse sre)))

(define-macro (rx . sre)
  (define (check name)
    (lambda (x)
      (and (or (symbol? x) (identifier? x))
	   (eq? (identifier->symbol x) name))))
  (define unquote? (check 'unquote))
  (define unquote-splicing? (check 'unquote-splicing))
  (define (expand-dynamic-re xs)
    (define (f xs)
      (define (wrap sym s)
	`(,sym ,(list 'unquote s)))
      (match xs
	((? (lambda (x) (not (pair? x)))) xs)
	(((? unquote?) x) (wrap '%interpolate x))
	(((? unquote-splicing?) x) (wrap '%splice x))
	(else (map f xs))))
    (list 'quasiquote (f xs)))
  `(sre->regex ,(expand-dynamic-re (cons 'seq sre))))

(define (sre-parse expr)
  (let1 match-num 0
    (define (err msg sre) (sre-parse-error 'sre-parse msg sre))
    (define named-submatch-table (make-eq-hashtable))
    (define sp (cut map parse <>))
    (define (sre-literal? x) (or (char? x) (char-set? x) (string? x)))
    (define (seq* sres)
      (match sres
        ((sre) sre)
        (else `(sequence ,@sres))))
    (define (backref n) `(back-reference . ,n))
    (define (rep-b sym n m ast)
      (cond ((= n m 0) '(sequence))
	    ((> n m) char-set:empty)
	    (else `(,sym ,n ,m ,(seq* (sp ast))))))
    (define-syntax inc!
      (syntax-rules ()
	((_ n) (set! n (+ n 1)))))
    (define submatch-name caddr)
    (define submatch-body cadddr)
    (define (submatch? ast)
      (and (eq? (car ast) 'register)
	   (number? (cadr ast))))
    (define (replace-submatches ast gen)
      (if (list? ast)
          (if (submatch? ast)
              (let1 expr (gen ast)
                (append expr
			(map (cut replace-submatches <> gen) (cdddr ast))))
              (map (cut replace-submatches <> gen) ast))
          ast))
    (define (renum-submatches ast)
      (replace-submatches ast (lambda (orig)
				(inc! match-num)
				(list 'register match-num 
				      (submatch-name orig)))))
    (define (remove-submatches ast)
      (replace-submatches ast (lambda (_) '(sequence))))
    (define (do-interpolate f obj)
      (define (regex-unoptimized-ast re) 
	(compile-regex (regex-pattern re) (regex-flags re) #t))
      (cond ((string? obj) `(sequence ,@(string->list obj)))
            ((or (char? obj) (char-set? obj)) obj)
            ((regex-pattern? obj)
             `(sequence ,(f (submatch-body (regex-unoptimized-ast obj)))))
            (else
             (err "Invalid dynamic SRE:" obj))))
    (define (parse sre)
      (define (parse-symbol sre)
	(case sre
	  ((any) 'everything)
	  ((bos) 'modeless-start-anchor)
	  ((eos) 'modeless-end-anchor)
	  ((bol) 'start-anchor)
	  ((eol) 'end-anchor)
	  ((bow eow) 'word-boundary)
	  ((nwb) 'non-word-boundary)
	  ;; hmmm how should we treat them?
	  ;; ((bog) ...)
	  ;; ((eog) ...)
	  ;; ((grapheme) ...)
          ((ascii)	char-set:ascii)
          ((nonl)	`(inverted-char-class ,(string->char-set "\n")))
          ((blank)	char-set:blank)
          ((control cntrl)	char-set:iso-control)
          ((graphic graph)	char-set:graphic)
          ((printing print)	char-set:printing)
          ((alphabetic alpha)	char-set:letter)
          ((lower-case lower)	char-set:lower-case)
          ((upper-case upper)	char-set:upper-case)
          ((numeric num digit)	char-set:digit)
          ((punctuation punct)	char-set:punctuation)
          ((hex-digit xdigit hex)	char-set:hex-digit)
          ((whitespace white space)	char-set:whitespace)
          ((alphanumeric alnum alphanum)	char-set:letter+digit)
          ((word) (parse '(word (+ (& (or alphanumeric #\_))))))))

      (match sre
	((? sre-literal?) (parse-literal sre))
	((? symbol?)      (parse-symbol sre))
	;; SRFI-115 doesn't have this?
	(('~) (parse 'any))
	(('~ cset ..1)
	 (let1 res (re-or (sp cset))
	   (if (char-set? res)
	       `(inverted-char-class ,res)
	       (err "Invalid character class operation: " sre))))
	(('- cset ..1)
	 (let1 res (sp cset)
	   (if (for-all cset-sre? res)
	       (apply char-set-difference (map cset-sre->char-set res))
	       (err "Invalid character class operation: " sre))))
	(('& cset ..1)
	 (let1 res (sp cset)
	   (if (for-all cset-sre? res)
	       (apply char-set-intersection (map cset-sre->char-set res))
	       (err "Invalid character class operation: " sre))))
	(('or)          char-set:empty)
	(('or ast ..1)  (re-or (sp ast)))
	(('seq ast ...) (seq* (sp ast)))
	(('uncase ast) (%sre-uncase (parse ast)))
	(('uncase ast ...)
	 `(flagged-sequence ((#\i . #t)) ,(seq* (sp ast))))
	(('w/case ast ...)
	 (parameterize ((case-sensitive? #t))
	   (seq* (sp ast))))
	(('w/nocase ast ...)
	 (parameterize ((case-sensitive? #f))
	   (seq* (sp ast))))
	(('w/unicode ast ...) `(flagged-sequence ((#\u . #t)) ,(seq* (sp ast))))
	(('w/ascii ast ...)   `(flagged-sequence ((#\u . #f)) ,(seq* (sp ast))))
	;; TODO
	;; (('w/nocapture ast ...))
	(('* ast ..1)         `(greedy-repetition 0 #f ,(seq* (sp ast))))
	(('+ ast ..1)         `(greedy-repetition 1 #f ,(seq* (sp ast))))
	(('? ast ..1)         `(greedy-repetition 0 1  ,(seq* (sp ast))))
	(('= (? number? n) ast ..1)  `(greedy-repetition ,n ,n ,(seq* (sp ast))))
	(('>= (? number? n) ast ..1) `(greedy-repetition ,n #f ,(seq* (sp ast))))
	(('** (? number? n) (? number? m) ast ..1) 
	 (rep-b 'greedy-repetition n m ast))
	(('?? ast ..1)        `(non-greedy-repetition 0 1  ,(seq* (sp ast))))
	(('*? ast ..1)        `(non-greedy-repetition 0 #f ,(seq* (sp ast))))
	(('**? (? number? n) (? number? m) ast ..1) 
	 (rep-b 'non-greedy-repetition n m ast))
	(('look-ahead ast ...)  `(lookahead  #t ,(seq* (sp ast))))
	(('look-behind ast ...) `(lookbehind #t ,(seq* (sp ast))))
	(('neg-look-ahead ast ...)  `(lookahead  #f ,(seq* (sp ast))))
	(('neg-look-behind ast ...) `(lookbehind #f ,(seq* (sp ast))))
	;; TODO should we add more like ++ as non SRFI supported extension?
	(('submatch ast ...)
	 (inc! match-num)
	 `(register ,match-num #f ,(seq* (sp ast))))
	(('submatch-named name ast ...)
	 (inc! match-num)
	 (hashtable-update! named-submatch-table name
			    (lambda (v) (cons match-num v))
			    '())
	 `(register ,match-num ,name ,(seq* (sp ast))))
	(('backref (? number? n))
	 (backref n))
	(('backref (? symbol? n))
	 (match (hashtable-ref named-submatch-table n '())
	   (() (err "undefined named back reference" n))
	   ((num) (backref num))
	   (nums `(alternation ,@(map backref nums)))))
	;; TODO should we add backref?
	;; how should we treat bow?
	(('word ast ...) (parse `(seq bow ,@ast eow)))
	(('word+ ast ...) 
	 (parse `(word (+ (& (or alphanumeric #\_) (or ,@ast))))))
	(('%interpolate obj)
	 (do-interpolate remove-submatches obj))
	(('%splice obj)
	 (do-interpolate renum-submatches obj))
	(else (err "Invalid SRE:" sre))))
    (list 'register 0 #f (parse (sre-normalize expr)))))

;; (sre-normalize sre) -> SRE
;; "?" -> #\?
;; ("..."), (/ ...) -> <char-set>
;; (: ...) -> (seq ...)
;; (| ...) -> (or ...)
;; ($ ...) -> (submatch ...)
;; (-> ...) -> (submatch-named ...)
;; (?= ...) -> (look-ahead ...)
;; (?! ...) -> (neg-look-ahead ...)
;; (?<= ...) -> (look-behind ...)
;; (?<! ...) -> (neg-look-behind ...)
(define (sre-normalize sre)
  (match sre
    ((? string?)
     (if (= (string-length sre) 1)
	 (string-ref sre 0)
	 sre))
    (((? string? s))
     (string->char-set s))
    (((or ': '|:|) tail ...)
     `(seq ,@(map sre-normalize tail)))
    (('|\|| tail ...)
     `(or ,@(map sre-normalize tail)))
    (('/ (or (? string?) (? char?)) ...)
     (sre-range->char-set (cdr sre)))
    (('$ tail ...)
     `(submatch ,@(map sre-normalize tail)))
    (('-> name tail ...)
     `(submatch-named ,name ,@(map sre-normalize tail)))
    (('?= tail ...)
     `(look-ahead ,@(map sre-normalize tail)))
    (('?! tail ...)
     `(neg-look-ahead ,@(map sre-normalize tail)))
    (('?<= tail ...)
     `(look-behind ,@(map sre-normalize tail)))
    (('?<! tail ...)
     `(neg-look-behind ,@(map sre-normalize tail)))
    ((? list?)
     (map sre-normalize sre))
    (else sre)))

(define (parse-literal sre)
  (cond ((or (char? sre) (char-set? sre))
	 (if (case-sensitive?)
	     sre
	     (sre-uncase-char-set sre)))
	((string? sre)
	 (if (case-sensitive?)
             `(sequence ,@(string->list sre))
             (sre-uncase-string sre)))))

(define (sre-uncase-char-set sre)
  (let1 nsre (sre-normalize sre)
    (cond ((char? nsre)
           (char-set (char-downcase nsre) (char-upcase nsre)))
          ((char-set? nsre) (char-set-uncase nsre))
          ((cset-sre? sre)
           (sre-uncase-char-set (cset-sre->char-set nsre)))
          (else
           (let1 cs (cadr (sre-parse nsre))
             (if (char-set? cs)
                 (sre-uncase-char-set cs)
                 (sre-parse-error 'sre-uncase-char-set
				  "Invalid charset:" sre)))))))

(define (char-set-uncase cs)
  (char-set-union (char-set-upcase cs) (char-set-downcase cs)))

(define (char-set-upcase cs)
  (receive (d i) (char-set-diff+intersection cs char-set:lower-case)
    (char-set-union d (char-set-map char-upcase i))))

(define (char-set-downcase cs)
  (receive (d i) (char-set-diff+intersection cs char-set:upper-case)
    (char-set-union d (char-set-map char-downcase i))))

(define (sre-uncase-string str)
  `(seq ,@(map sre-uncase-char-set (string->list str))))

(define (sre-uncase sre)
  (%sre-uncase (sre-normalize sre)))

(define (%sre-uncase sre)
  (match sre
    ('everything 'everything)
    (('inverted-char-class [? cset-sre? cs])
     (sre-uncase-char-set (char-set-complement cs)))
    ([? cset-sre? cs]
     (sre-uncase-char-set cs))
    (else
     `(flagged-sequence ((#\i . #t)) ,sre))))

(define (re-or args)
  (if (for-all cset-sre? args)
      (apply char-set-union (map cset-sre->char-set args))
      (cons 'alternation args)))

(define (cset-sre? sre)
  (match sre 
    ((or 'everything
	 (? char?)
	 (? char-set?)
	 ('inverted-char-class (? cset-sre?)))
     #t)
    (else #f)))

(define (cset-sre->char-set sre)
  (match sre
    ('everything char-set:full)
    ((? char?) (char-set sre))
    ((? char-set?) sre)
    (('inverted-char-class (? cset-sre? cs))
     (char-set-complement cs))))

(define (sre-range->char-set range-spec)
  (define (char-range-spec->char-set c1 c2)
    (ucs-range->char-set (char->integer c1) (+ (char->integer c2) 1)))
  (let loop ((ss range-spec) (result '()))
    (match ss
      (()
       (apply char-set-union result))
      (((? string? str) rest ...)
       (if (odd? (string-length str))
	   (sre-parse-error 'sre-range->char-set "Invalid charset range"
			    ss range-spec)
	   (loop rest (append! (map (cut apply char-range-spec->char-set <>)
				    (slices (string->list str) 2))
			       result))))
      (((? char? c1) (? char? c2) rest ...)
       (loop rest (cons (char-range-spec->char-set c1 c2) result)))
      (_ (sre-parse-error 'sre-range->char-set "Invalid charset range" 
			  ss range-spec)))))
)