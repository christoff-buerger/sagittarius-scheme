;; -*- scheme -*-
;; This file is a part of Sagittarius Scheme system.
(library (core struct)
    (export define-struct)
    (import null
	    (core base)
	    (sagittarius))
;; TODO improve
(define-syntax define-struct
  (er-macro-transformer
   (lambda (form rename compare)
     (define (create-accessor name fields)
       (define (get-accessor field type)
	 (if (pair? field)
	     (case type
	       ((get) 
		(or (>= (length field) 2)
		    (error 'define-struct "no getter for the struct" name))
		(cadr field))
	       ((set)
		(if (>= (length field) 3)
		    (caddr field)
		    (string->symbol (string-append (symbol->string (car field)) "-set!")))))
	     field))
       (let ((n (rename 'name))
	     (v (rename 'value)))
	 (let loop ((fields fields)
		    (r '()))
	   (if (null? fields)
	       r
	       (loop (cdr fields)
		     (cons 
		      `(,(rename 'define) (,(get-accessor (car fields) 'get) ,n)
			(,(rename 'generic-ref) ,n ',(if (pair? (car fields))
							 (caar fields)
							 (car fields))))
		      (cons
		       `(,(rename 'define) (,(get-accessor (car fields) 'set) ,n ,v)
			 (,(rename 'generic-set!) ,n ',(if (pair? (car fields))
							   (caar fields)
							   (car fields))
			  ,v))
		       r)))))))

     (let ((name (cadr form))
	   (constructor (caddr form))
	   (predicate (cadddr form))
	   (printer (car (cddddr form)))
	   (fields (cdr (cddddr form))))
       (let ((field-names (map (lambda (field)
				 (cond ((symbol? field) field)
				       ((pair? field) (car field))
				       (else
					(error 'define-struct
					       "invalid field name" field))))
			       fields))
	     (temp (rename 'temp))
	     (ins  (rename 'ins)))
	 `(,(rename 'begin)
	   ,@(create-accessor name fields)
	   (,(rename 'define) ,constructor
	    (,(rename 'let) ((,ins  (create-instance ,name)))
	      ,@(let loop ((params (cdr constructor))
			   (field-names field-names)
			   (r '()))
		  (if (null? params)
		      r
		      (loop (cdr params) (cdr field-names)
			    (cons `(,(rename 'generic-set!) ,ins ',(car field-names) ,(car params))
				  r))))
	      ,ins))
	   (,(rename 'define) ,name (,(rename 'make-generic) ',name ,printer ,(car constructor) 
				     ,@(map (lambda (x)
					      `(,(rename 'quote) ,x))
					    field-names)))
	   ))))))
)