(import (rnrs)
	(text markdown)
	(srfi :64))

(test-begin "Markdown")

(define-syntax test-parser
  (syntax-rules ()
    ((_ expected str)
     (test-equal str expected (parse-markdown (open-string-input-port str))))))

(test-parser '(:doc (:h6 "hoge")) "###### hoge\n")
(test-parser '(:doc (:h6 "hoge__a")) "###### hoge__a\n")
(test-parser '(:doc (:h6 "hoge'a")) "###### hoge'a\n")

;; with inline
(test-parser '(:doc (:h6 (:emph "hoge"))) "###### *hoge*\n")
(test-parser '(:doc (:h6 (:strong "hoge"))) "###### **hoge**\n")
(test-parser '(:doc (:h6 (:emph "hoge"))) "###### _hoge_\n")
(test-parser '(:doc (:h6 (:strong "hoge"))) "###### __hoge__\n")

;; inline link
;; auto link
(test-parser '(:doc (:h1 (:link (:label "http://hogehoge")
				"http://hogehoge" "")))
	     "# <http://hogehoge>\n")
(test-parser '(:doc (:h1 (:link (:label "mailto:ktakashi@ymail.com")
				"ktakashi@ymail.com" "")))
	     "# <ktakashi@ymail.com>\n")
(test-parser '(:doc (:h1 (:link (:label "mailto:ktakashi@ymail.com")
				"ktakashi@ymail.com" "")))
	     "# <mailto:ktakashi@ymail.com>\n")

;; explicit link
(test-parser '(:doc (:h1 (:link (:label "link") "source " "title")))
	     "# [link](source 'title')\n")
(test-parser '(:doc (:h1 (:link (:label "link") "source " "title")))
	     "# [link](source \"title\")\n")

;; image
(test-parser '(:doc (:h1 (:image (:label "link") "source " "title")))
	    "# ![link](source 'title')\n")

;; note
(test-parser '(:doc (:note (:ref "note") "note"))
	     "[^note]: note\n")
(test-parser '(:doc (:note (:ref "note") "note" "note2"))
	     "[^note]: note\n    note2\n")
(test-parser '(:doc (:note (:ref "note") "note" "note2" "note3"))
	     "[^note]: note\n    note2\n \n    note3\n")

;; inline note
(test-parser '(:doc (:h1 (:note "note"))) "# ^[note]\n")

;; block quote
(test-parser '(:doc (:blockquote "hoge" "fuga" "\n")) ">hoge\n>fuga\n\n")
(test-parser '(:doc (:blockquote "hoge" "fuga" "\n")) ">hoge\nfuga\n\n")

;; paragraph
(test-parser '(:doc (:paragraph "hogehoge" "fugafuga")) 
	     "hogehoge\nfugafuga\n\n")

;; verbatim
(test-parser '(:doc (:verbatim "hogehoge\nfugafuga"))
	     "    hogehoge\n    fugafuga\n")

;; reference
(test-parser '(:doc (:reference (:label "ref") "source" "")) "[ref]: source\n")
(test-parser '(:doc (:reference (:label "ref") "source " ""))
	     "[ref]: source \"\"\n")
(test-parser '(:doc (:reference (:label "ref") "source " "title"))
	     "[ref]: source \"title\"\n")
(test-parser '(:doc (:reference (:label "ref") "source " "title"))
	     "[ref]: source 'title'\n")
(test-parser '(:doc (:reference (:label "ref") "source " "title"))
	     "[ref]: source (title)\n")


(test-end)
