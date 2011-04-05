(library (core syntax template)
    (export generate-output)
    (import (core)
	    (core base)
	    (core errors)
	    (core syntax pattern)
	    (core syntax helper)
	    (core misc)
	    (sagittarius))
  ;; from Ypsilon
  #;(define collect-rename-ids
    (lambda (template ranks)
      (let ((ids (collect-unique-ids template)))
	(let loop ((lst ids))
	  (if (null? lst)
	      lst
	      (if (assq (car lst) ranks)
		  (loop (cdr lst))
		  (cons (car lst) (loop (cdr lst)))))))))

  (define (parse-ellipsis-splicing form rename compare)
    (let loop ((len 2) (tail (cdddr form)))
      (cond ((and (pair? tail) (compare (car tail) (rename '...)))
	     (loop (+ len 1) (cdr tail)))
	    (else
	     (values (list-head form len) tail len)))))

  (define (rank-of name sids compare)
    (let ((slot (any (lambda (sid)
		       (compare name (sid-name sid)))
		     sids)))
      (if slot (sid-depth slot) -1)))

  #;(define (check-template tmpl sids rename compare)
    (define (control-patvar-exists? tmpl depth)
      (let loop ((lst tmpl) (depth depth))
	(cond ((variable? lst)
	       (>= (rank-of lst sids compare) depth))
	      ((ellipsis-quote? lst rename compare)
	       (any1 (lambda (id) (>= (rank-of id sids compare) depth)) (collect-unique-ids lst)))
	      ((ellipsis-splicing-pair? lst rename compare)
	       (receive (body tail len) (parse-ellipsis-splicing lst rename compare)
		 (or (loop body (+ depth 1))
		     (and (loop body 1)
			  (loop tail depth)))))
	      ((ellipsis-pair? lst rename compare)
	       (or (loop (car lst) (+ depth 1))
		   (and (loop (car lst) 1)
			(loop (cddr lst) depth))))
	      ((pair? lst)
	       (or (loop (car lst) depth)
		   (loop (cdr lst) depth)))
	      ((vector? lst)
	       (loop (vector->list lst) depth))
	      (else #f))))

    (define (check-escaped lst depth)
      (let loop ((lst lst))
	(cond ((variable? lst)
	       (and (< 0 (rank-of lst sids compare) depth)
		    (syntax-violation "syntax template" "too few ellipsis following subtemplate" tmpl lst)))
	      ((pair? lst)
	       (loop (car lst))
	       (loop (cdr lst)))
	      ((vector? lst)
	       (loop (vector->list lst))))))

    (if (and (= (safe-length tmpl) 2) (compare (car tmpl) (rename '...)))
	(check-escaped (cadr tmpl) 0)
	(let loop ((lst tmpl) (depth 0))
	  (cond ((variable? lst)
		 (and (compare lst (rename '...))
		      (syntax-violation "syntax template" "misplaced ellipsis" tmpl))
		 (and (> (rank-of lst sids compare) depth)
		      (syntax-violation "syntax template" "too few ellipsis following subtemplate" tmpl lst)))
		((ellipsis-quote? lst rename compare)
		 (check-escaped (cadr lst) depth))
		((ellipsis-splicing-pair? lst rename compare)
		 (receive (body tail len) (parse-ellipsis-splicing lst rename compare)
		   (and (= depth 0)
			(or (control-patvar-exists? (car lst) len)
			    (syntax-violation "syntax template" "missing pattern variable that used in same level as in pattern" tmpl lst)))
		   (loop body (+ depth 1))
		   (loop tail depth)))
		((ellipsis-pair? lst rename compare)
		 (cond ((variable? (car lst))
			(let ((rank (rank-of (car lst) sids compare)))
			  (cond ((< rank 0)
				 (syntax-violation "syntax template" "misplace ellipsis following literal" tmpl (car lst)))
				((> rank (+ depth 1))
				 (syntax-violation "syntax template" "too few ellipsis following subtemplate" tmpl (car lst)))
				(else
				 (loop (cddr lst) depth)))))
		       ((pair? (car lst))
			(and (= depth 0)
			     (or (control-patvar-exists? (car lst) (+ depth 1))
				 (syntax-violation "syntax template" "missing pattern variable that used in same level as in pattern" tmpl (car lst))))
			(loop (car lst) (+ depth 1))
			(loop (cddr lst) depth))
		       ((null? (car lst))
			(syntax-violation "syntax template" "misplaced ellipsis following empty list" tmpl))
		       (else
			(syntax-violation "syntax template" "misplaced ellipsis following literal" tmpl (car lst)))))
		((pair? lst)
		 (loop (car lst) depth)
		 (loop (cdr lst) depth))
		((vector? lst)
		 (loop (vector->list lst) depth))))))


  (define (generate-output tmplate sids rename compare expr emit)
    (let ((_cdr (rename 'cdr))       (_car (rename 'car))
	  (_quote (rename 'quote))   (_lambda (rename 'lambda))
	  (_null? (rename 'null?))   (_pair? (rename 'pair?))
	  (_map (rename 'map))       (_apply (rename 'apply))	  
	  (_list->vector (rename 'list->vector))
	  (_rename (rename 'rename)) (_compare (rename 'compare)))

      (define (generate-ellipsis ellipsis body)
	(let ((sids (ellipsis-sids ellipsis)))
	  (if (pair? sids)
	      (let ((name (sid-name (car sids)))
		    (expression (sid-expression (car sids))))
		(cond ((and (null? (cdr sids))
			    (eq? body name))
		       expression)
		      ((and (null? (cdr sids))
			    (pair? body)
			    (eq? (cadr body) name)
			    (null? (cddr body)))
		       `(,_map ,(car body) ,expression))
		      (else
		       `(,_map (,_lambda
				,(map sid-name sids)
				,body)
			 ,@(map sid-expression sids)))))
	      (assertion-violation 'syntax-rules "missing ellipsis in expansion." 
				   (list rename ellipsis body)))))
      (define (expand-variable tmpl ellipses)
	(let ((sid (let lp ((sids sids))
		     (and (pair? sids)
			  (if (compare (sid-name (car sids)) tmpl)
			      (car sids)
			      (lp (cdr sids)))))))
	  (if sid
	      (begin
		(add-control! sid ellipses)
		(sid-expression sid))
	      `(,_rename (,_quote ,tmpl)))))

      (define (loop tmpl ellipses)
	(cond ((variable? tmpl)
	       (expand-variable tmpl ellipses))
	      ((ellipsis-quote? tmpl rename compare)
	       `(,_quote ,(if (pair? (cdr tmpl))
			      (if (pair? (cddr tmpl)) (cddr tmpl) (cadr tmpl))
			      (cdr tmpl))))
	      ;; TODO
	      #;((ellipsis-splicing-pair? tmpl rename compare)
	       (expand-escaped-template (cadr tmpl) dim))
	      ;; (p ...)
	      ((ellipsis-pair? tmpl rename compare)
	       ;;(print tmpl)
	       (cond #;((variable? (car tmpl))
		      (optimized-append rename compare
					(expand-variable (car tmpl) ellipses)
					(loop (cddr tmpl) ellipses)))
		     (#t #;(pair? (car tmpl))
		      (optimized-append rename compare
					(let ((ellipsis (make-ellipsis '())))
					  (generate-ellipsis ellipsis
							     (loop (car tmpl)
								   (cons ellipsis
									 ellipses))))
					(loop (cddr tmpl) ellipses)))))
	      ((pair? tmpl)
	       (optimized-cons rename compare
				 (loop (car tmpl) ellipses)
				 (loop (cdr tmpl) ellipses)))
	      ((vector? tmpl)
	       `(,_list->vector ,(loop (vector->list tmpl) ellipses)))
	      ((null? tmpl)
	       `(,_quote ()))
	      (else 
	       `(,_quote ,tmpl))))
      (loop tmplate '())))

)
;; end of file
;; Local Variables:
;; coding: utf-8-unix
;; End: