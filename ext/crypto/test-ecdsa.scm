(define-syntax test-ecdsa
  (syntax-rules ()
    ((_ param hash msg d Qx Qy k R S)
     (%test-ecdsa 'param param hash msg d Qx Qy k R S))))

(include "test-b-163.scm")
(include "test-b-233.scm")
(include "test-b-283.scm")
(include "test-b-409.scm")
(include "test-b-571.scm")
(include "test-k-163.scm")
(include "test-k-233.scm")
(include "test-k-283.scm")
(include "test-k-409.scm")
(include "test-k-571.scm")
(include "test-p-192.scm")
(include "test-p-224.scm")
(include "test-p-256.scm")
(include "test-p-384.scm")
(include "test-p-521.scm")
