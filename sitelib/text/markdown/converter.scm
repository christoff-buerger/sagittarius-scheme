;;; -*- mode:scheme; coding:utf-8 -*-
;;;
;;; text/markdown/converter.scm - Markdown node converter
;;;  
;;;   Copyright (c) 2022  Takashi Kato  <ktakashi@ymail.com>
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

;; wrapper library 
#!nounbound
(library (text markdown converter)
    (export markdown-node->sxml
	    markdown-document->sxml

	    markdown->html-converter
	    markdown-converter:convert
	    )
    (import (rnrs)
	    (text markdown parser nodes)
	    (text markdown converter api)
	    (text markdown converter html)
	    (text xml dom converter))

(define default-options
  (dom->sxml-options-builder (use-prefix? #t)))
  
(define markdown-node->sxml
  (case-lambda
   ((node) (markdown-node->sxml node default-options))
   ((node options) (dom->sxml (markdown-node->dom-tree node) options))))

(define markdown-document->sxml
  (case-lambda
   ((node) (markdown-document->sxml node default-options))
   ((node options) (dom->sxml (markdown-document->xml-document node) options))))

)
