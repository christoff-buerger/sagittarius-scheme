(import (rnrs)
	(text yaml builder)
	(text yaml nodes)
	(text yaml tags)
	(rfc base64)
	(srfi :64))

(test-begin "YAML builder")

(define (->yaml sexp) (yaml->sexp (canonical-sexp->yaml-node sexp)))

(test-equal "string" (->yaml `(,+yaml-tag:str+ . "string")))

(test-equal #vu8(1 2 3 4)
	    (->yaml `(,+yaml-tag:binary+
		      . ,(utf8->string (base64-encode #vu8(1 2 3 4))))))

(test-equal #t (->yaml `(,+yaml-tag:bool+ . "y")))
(test-equal #t (->yaml `(,+yaml-tag:bool+ . "yes")))
(test-equal #t (->yaml `(,+yaml-tag:bool+ . "Yes")))
(test-equal #t (->yaml `(,+yaml-tag:bool+ . "true")))
(test-equal #t (->yaml `(,+yaml-tag:bool+ . "True")))
(test-equal #t (->yaml `(,+yaml-tag:bool+ . "On")))
(test-equal #t (->yaml `(,+yaml-tag:bool+ . "on")))
(test-equal #f (->yaml `(,+yaml-tag:bool+ . "n")))
(test-equal #f (->yaml `(,+yaml-tag:bool+ . "no")))
(test-equal #f (->yaml `(,+yaml-tag:bool+ . "No")))
(test-equal #f (->yaml `(,+yaml-tag:bool+ . "false")))
(test-equal #f (->yaml `(,+yaml-tag:bool+ . "False")))
(test-equal #f (->yaml `(,+yaml-tag:bool+ . "off")))
(test-equal #f (->yaml `(,+yaml-tag:bool+ . "Off")))

(test-equal 685230 (->yaml `(,+yaml-tag:int+ . "685230")))
(test-equal 685230 (->yaml `(,+yaml-tag:int+ . "+685_230")))
(test-equal 685230 (->yaml `(,+yaml-tag:int+ . "02472256")))
(test-equal 685230 (->yaml `(,+yaml-tag:int+ . "0x_0A_74_AE")))
(test-equal 685230 (->yaml `(,+yaml-tag:int+ . "0b1010_0111_0100_1010_1110")))
(test-equal 685230 (->yaml `(,+yaml-tag:int+ . "190:20:30")))


(test-end)
