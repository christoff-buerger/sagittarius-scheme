#!/bin/env sash

;;(use util.match)
;;(use srfi-1)
(import (rnrs)
	(match)
	(srfi :1 lists))


(define (header-c++ out)
  (format out "/* -*- C -*- */~%")
  (format out "/* do not edit! this file was automatically generated by gen-instruction.scm.*/~%")
  (format out "#ifndef SAGITTARIUS_INSTRUCATIONS_H~%")
  (format out "#define SAGITTARIUS_INSTRUCATIONS_H~%~%")
  (format out "#include \"sagittariusdefs.h\"~%")
  (format out "#define INSN_MASK 0xFF~%")
  (format out "#define INSN_VALUE1_MASK  0xFFF~%")
  (format out "#define INSN_VALUE2_MASK  ((1 << (sizeof(intptr_t) * 8)) - 1)~%")
  (format out "#define INSN_VALUE1_SHIFT 8~%")
  (format out "#define INSN_VALUE2_SHIFT 20~%")
  (format out "#ifdef _MSC_VER~%")
  (format out "/* what a stupid macro definition on windows.h*/~%")
  (format out "#undef CONST~%")
  (format out "#endif~%")
  (format out "/**~%")
  (format out "   @brief set of instructions.~%~%")
  ;; newline
  (format out "   For Sagittarius' instruction, it must be 1 byte, so that there are~%")
  (format out "   maximam 255 of instructions.~%~%")
  ;; newline
  (format out "   @author Takashi Kato~%")
  (format out " */~%"))

(define (footer-c++ out)
  (format out "typedef struct InsnInfoRec InsnInfo;~%")
  (format out "struct InsnInfoRec~%")
  (format out "{~%")
  (format out "  const char *name;~%")
  (format out "  int         number;~%")
  (format out "  int         instValues;~%")
  (format out "  int         argc;~%")
  (format out "  int         hasSrc;~%")
  (format out "  int         label;~%")
  (format out "};~%")
  (format out "#define INSN(o)            ((o) & INSN_MASK)~%")
  (format out "#define INSN_VAL1(v, insn) ((v) = ((int)(insn)) >> INSN_VALUE1_SHIFT)~%")
  (format out "#define INSN_VAL2(v1, v2, insn)	\\~%")
  (format out "  do {				\\~%")
  (format out "    (v1) = ((((int)(insn)) >> INSN_VALUE1_SHIFT) & INSN_VALUE1_MASK);	\\~%")
  (format out "    (v2) = ((((int)(insn)) >> INSN_VALUE2_SHIFT) & INSN_VALUE2_MASK);	\\~%")
  (format out "  } while (0)~%")
  (format out "#define MERGE_INSN_VALUE1(insn, value)      \\~%")
  (format out "  ((insn) | ((value) << INSN_VALUE1_SHIFT))~%")
  (format out "#define MERGE_INSN_VALUE2(insn, val1, val2) \\~%")
  (format out "  ((insn) | ((val1) << INSN_VALUE1_SHIFT) | ((val2) << INSN_VALUE2_SHIFT))~%")
  (format out "SG_CDECL_BEGIN~%")
  (format out "SG_EXTERN InsnInfo* Sg_LookupInsnName(Instruction insn);~%")
  (format out "SG_CDECL_END~%")
  (format out "#endif~%"))

(define (body-c++ in out)
  (let ((insts '()))
    (format out "typedef enum {~%")
    (let loop ((s (read in))
	       (count 0))
      (if (eof-object? s)
	  (set! insts (reverse insts))
	  (begin
	    (match s
	      ((define-inst name (inst-values param-count src?) . rest)
	       (receive (label? count) (parse-extra rest count)
		 (set! insts (cons (list name count param-count src? #t) insts))
		 (format out "  ~s = 0x~2'0x,~%" name count)))
	      (else
	       (set! count (- count 1)))
	      )
	    (loop (read in) (+ count 1)))))
    (format out "  ~a = ~a, ~a~%" 'INSTRUCTION_COUNT (length insts) "/** number of instructions */")
    (format out "} Instruction;~%~%")
    #;(gen-lookup-c++ insts out)))

(define (parse-extra body count)
  (let loop ((body body))
    ;; just check the first one if it has (:value 0) or :label
    (if (null? body)
	(values #f count)
	(cond ((and (pair? (car body))
		    (eq? :value (caar body)))
	       (values #f (cadar body)))
	      ((eq? (car body) :label)
	       (values #t count))
	      (else
	       (values #f count))))))

#;(define (cpp-body-c++ in out)
  (define *insns* '())
  (format out "/* -*- C -*- */~%")
  (format out "/* do not edit! this file was automatically generated by gen-instruction.scm.*/~%")
  (format out "#define LIBSAGITTARIUS_BODY~%")
  (format out "#include \"sagittarius/instruction.h\"~%")
  (format out "#include \"sagittarius/pair.h\"~%")
  (format out "#include \"sagittarius/string.h\"~%")
  (format out "#include \"sagittarius/symbol.h\"~%")
  (format out "#include \"sagittarius/vm.h\"~%")
  (format out "#include \"sagittarius/library.h\"~%")
  (format out "InsnInfo* Sg_LookupInsnName(Instruction insn)~%")
  (format out "{~%")
  (format out "  InsnInfo *info = NULL;~%")
  (let loop ((s (read in))
	     (count 0))
    (if (eof-object? s)
	#t
	(begin
	  (match s
	    ((define-inst name (inst-values param-count src?) . rest)
	     (receive (label? count) (parse-extra rest count)
	       (set! *insns* (acons name count *insns*))
	       (format out "  static InsnInfo ~s_INSN = {~s, ~a, ~a, ~a, ~s, ~s};~%"
		       name (symbol->string name) count inst-values param-count 'TRUE (if src? 'TRUE 'FALSE))))
	    (else
	     (set! count (- count 1))))
	  (loop (read in) (+ count 1)))))
  (format out "  switch (insn) {~%")
  (for-each (lambda (insn)
	      (format out "  case ~s: info = &~s_INSN; break;~%" (car insn) (car insn)))
	    *insns*)
  (format out "  }~%")
  (format out "  return info;~%")
  (format out "}~%~%")
  (format out "void Sg__InitInstruction()~%")
  (format out "{~%")
  (format out "  SgLibrary *lib = Sg_FindLibrary(SG_INTERN(\"(sagittarius vm instruction)\"), TRUE);~%")
  (for-each (lambda (insn)
	      (format out "  Sg_InsertBinding(lib, SG_INTERN(\"~s\"), SG_MAKE_INT(~s));~%"
		      (car insn) (car insn)))
	    *insns*)
  (format out "}~%~%"))

(define (header-scheme out)
  (format out ";; -*- Scheme -*-~%")
  (format out ";; do not edit! this file was automatically generated by gen-instruction.scm.~%"))

(define (footer-scheme out)
  ;; do nothing
  )

(define (body-scheme in out)
  (let ((insts '()))
    (let loop ((s (read in))
	       (count 0))
      (if (eof-object? s)
	  (set! insts (reverse insts))
	  (begin
	    (match s
	      ((define-inst name (inst-values param-count src?) . rest)
	       (receive (label? count) (parse-extra rest count)
		 (set! insts (cons (list name count inst-values param-count src? label?) insts))
		 (format out "(define-constant ~s ~a)~%" name count)))
	      (else
	       (set! count (- count 1))))
	    (loop (read in) (+ count 1)))))
    (format out "(define-constant INSTRUCTION_COUNT ~a)~%" (length insts))
    (gen-lookup-scheme insts out)))

(define (gen-lookup-scheme insts out)
  (format out "(define (lookup-insn-name insn)~%")
  (format out "  (cond~%")
  (let loop ((insts insts))
    (if (null? insts)
	(begin
	  (format out "    (else 'unknown))")
	  (format out ")~%"))
	(let ((inst (car insts)))
	  (format out "    ((eqv? insn ~a) '(~s ~s ~s ~s ~s))~%" (second inst) (first inst) (third inst) (fourth inst) (fifth inst) (sixth inst))
	  (loop (cdr insts))))))
     
(define generator-table
  `((scheme ,header-scheme ,body-scheme ,footer-scheme)
    (c++ ,header-c++ ,body-c++ ,footer-c++)))


(define (gen-file type input out #;cpp-body)
  (let ((generators (assoc type generator-table)))
    (let ((header     (cadr generators))
	  (body       (caddr generators))
	  (footer     (cadddr generators)))
      (let ((in (open-input-file input)))
	(header out)
	(body in out)
	(footer out)
	#;(unless (null? cpp-body)
	  (port-seek in 0)
	  (call-with-output-file
	      (car cpp-body)
	    (lambda (out)
	      (cpp-body-c++ in out))))
	(close-input-port in)))))

(define (main args)
  (if (< (length args) 3)
      (begin
	(print "usage: gen-instruction.scm {scheme|c++} definition-file &output-file")
	-1)
      (let ((has-out? (>= (length args) 4)))
	(let ((out (if has-out?
		       ;;(open-output-file (cadddr args))
		       (open-file-output-port (cadddr args) (file-options no-fail))
		       (current-output-port))))
	  (gen-file (string->symbol (cadr args)) (caddr args) out #;(if (>= (length args) 4)
								      (cddddr args)
								      '()))))))

(let ((args (command-line)))
  (main args))
;;;; end of file
;; Local Variables:
;; coding: utf-8-unix
;; End: