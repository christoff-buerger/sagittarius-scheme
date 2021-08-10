;;; -*- mode:scheme;coding:utf-8 -*-
;;;
;;; control/theading.scm - Threading macro
;;;  
;;;   Copyright (c) 2021  Takashi Kato  <ktakashi@ymail.com>
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

#!nounbound
(library (control threading)
    (export ~> lazy~> if~> cond~> 
	    => else force ;; for convenience
	    )
    (import (rnrs)
	    (scheme lazy))

;; full execution
(define-syntax ~>
  (syntax-rules ()
    ((_ seed exp* ...)
     (force (lazy~> seed exp* ...)))))

(define-syntax lazy~>
  (syntax-rules ()
    ((_ "thread" seed) seed) ;; returns promise here ;)
    ((_ "thread" seed exp exp* ...)
     (let ((v seed)
	   (proc exp))
       (lazy~> "thread" (delay-force (proc (force v))) exp* ...)))
    ((_ seed exp* ...)
     (lazy~> "thread" (delay-force seed) exp* ...))))

(define-syntax if~>
  (syntax-rules ()
    ((_ seed pred then) (if~> seed pred then (lambda (v) #f)))
    ((_ seed pred then else)
     (let ((p pred) (t then) (e else))
       (lazy~> seed (lambda (v) (if (p v) (t v) (e v))))))))

(define-syntax cond~>
  (syntax-rules (=> else)
    ((_ "parse" seed ((pred exp* ...)))
     (let ((t (lambda (v) (lazy~> v exp* ...))))
       (if~> seed pred t)))
    ((_ "parse" seed ((pred exp* ...) (else exp2* ...)))
     (let ((t (lambda (v) (lazy~> v exp* ...)))
	   (e (lambda (v) (lazy~> v exp2* ...))))
       (if~> seed pred t e)))
    ((_ "parse" seed ((pred exp* ...) clause* ...))
     (let ((t (lambda (v) (lazy~> v exp* ...))))
       (if~> seed pred t (cond~> "parse" seed (clause* ...)))))
    ((_ seed clause* ...)
     (cond~> "parse" seed (clause* ...)))))

)
