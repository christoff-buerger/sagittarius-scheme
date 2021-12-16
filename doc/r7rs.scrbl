@; -*- mode:scribble; coding: utf-8 -*-

@section{R7RS Support}

Sagittarius supports the latest Scheme standard R7RS. Even though the R7RS
has incompatible from R6RS, however users can use both R6RS and R7RS libraries
seamlessly.

@subsection{R7RS library system}

On Sagittarius, user can call R7RS libraries on R6RS script and also other way
around. However syntaxes are different. User can choose which syntax use.

@define[Syntax]{@name{define-library} @args{name clauses}}
@desc{[R7RS]@var{name} must be a list which can only contains symbol or exact
integer.

@var{clauses} may be one of these:
@itemlist[
@item{(@code{export} @var{export-spec} @dots{})}
@item{(@code{import} @var{import-set} @dots{})}
@item{(@code{begin} @var{command-or-definition} @dots{})}
@item{(@code{include} @var{filenames} @dots{})}
@item{(@code{include-ci} @var{filenames} @dots{})}
@item{(@code{include-library-declarations} @var{filenames} @dots{})}
@item{(@code{cond-expand} @var{cond-expand-clause} @dots{})}
]
@code{export} and @code{import} are the same as R6RS. And on R7RS renaming
export syntax is different from R6RS, however on Sagittarius both can be
accepted.

@code{begin} starts the library contents. However it can appear more than once.

@code{include} and @code{include-ci} includes the files which are specified
@var{filenames}. @var{filenames} must be string. This resolves file path from
current loading file. If the library file is /usr/local/lib/lib1.scm, then
search path will be /usr/local/lib. It can also take absolute path.
@code{include-ci} reads the file case insensitive.

@code{cond-exnpand} is the same as builtin syntax @code{cond-expand}. For more
detail, see @secref["lib.sagittarius.builtin.syntax"]{Builtin Syntax}.
}

@subsection{R7RS libraries}

Sagittarius supports all R7RS libraries. However to avoid duplication,
this section only describes the different procedures from R6RS. The same
procedures are explicitly said 'the same as R6RS'.

@subsubsection{Base library}

@define[Library]{@name{(scheme base)}}
@desc{[R7RS]R7RS base library.

These procedures/macros are the same as R6RS;

@codeblock{
 * + - ... / < <= = => > >= 

 abs and append apply assoc assq assv 

 begin binary-port? boolean=? boolean? 
 bytevector-copy bytevector-length bytevector-u8-ref
 bytevector-u8-set! bytevector?

 caar cadr call-with-current-continuation call-with-port
 call-with-values call/cc car case cdar cddr cdr ceiling
 char->integer char<=? char<? char=? char>=? char>? char?
 close-input-port close-output-port close-port complex?
 cond cons current-error-port current-input-port current-output-port
 
 define define-record-type define-syntax denominator do dynamic-wind

 else eof-object eof-object? eq? eqv? error even?
 exact exact-integer-sqrt exact? expt

 floor flush-output-port for-each

 gcd guard

 if inexact inexact? input-port? integer->char integer?

 lambda lcm length let let* let*-values let-values
 letrec letrec* list list->string list->vector
 list-ref list-tail list?

 make-bytevector make-string make-vector map max member memq memv min
 modulo

 negative? newline not null? number->string number? numerator

 odd? or output-port?

 pair? peek-char port? positive? procedure?

 quasiquote quote quotient

 raise raise-continuable rational? rationalize
 read-char real? remainder reverse round

 set! set-car! set-cdr!
 string string->list string->number string->symbol string->utf8
 string-append string-copy string-for-each string-length string-ref
 string-fill! string-set!
 string<=? string<? string=? string>=? string>? string? substring
 symbol->string symbol=? symbol? syntax-rules

 textual-port? truncate 

 unless unquote unquote-splicing utf8->string

 values vector vector->list vector-fill! vector-for-each vector-length
 vector-map vector-ref vector-set! vector? 

 when with-exception-handler write-char 

 zero?}

This is defined in @secref["lib.sagittarius"]{(sagittarius)};

@codeblock{cond-expand}
}

@sub*section{Bytevectors}

@define[Function]{@name{bytevector} @args{bytes @dots{}}}
@desc{@var{bytes} must be a list of non negative exact integer and its
value is up to 255.

Creates a bytevector whose content is values of @var{bytes}.
}

@define[Function]{@name{bytevector-append} @args{bytevectors @dots{}}}
@desc{Returns a newly allocated bytevector whose contents are the
concatenation of the contents in @var{bytevectors}.

NOTE: R6RS also has the same named procedure and does the same however
the arguments lists are different.
}

@define[Function]{@name{bytevector-copy!}
 @args{to at from :optional (start 0) (end (bytevector-length from))}}
@desc{@var{to} and @var{from} must be bytevectors. @var{at} must be
a non negative exact integer in range of @var{to} size. Optional arguments
@var{start} and @var{end} must be non negative exact integer in range of
@var{from} and @var{end} must be bigger than @var{end}.

Copies content of @var{from} starting from @var{start} until @var{end} 
(exclusive) to @var{to} starting @var{at}. The operation is done
destructively.
}

@sub*section{Lists}

@define[Function]{@name{list-copy} @args{obj}}
@desc{Returns a newly allocated copy of @var{obj} if it is a list. The
list elements stays intact. So changing element's content affects original
@var{obj}.
}

@define[Function]{@name{list-set!} @args{list index value}}
@desc{Stores @var{value} in element @var{index} of @var{list}.}

@define[Function]{@name{make-list} @args{k :optional fill}}
@desc{Creates a list whose size is @var{k}.

If the optional argument @var{fill} is given then returning list is filled
with @var{fill}, otherwise unspecified value is used.
} 

@sub*section{Vectors}

@define[Function]{@name{vector->string}
 @args{vector :optional (start 0) (end (vector-length vector))}}
@desc{@var{vector} must be a vector whose elements of range from @var{start}
to @var{end} (exclusive) are characters.

Returns a string constructed with the above range of characters.
}
@define[Function]{@name{string->vector}
 @args{string :optional (start 0) (end (string-length string))}}
@desc{Returns a vector whose elements are characters of @var{string} in range
of @var{start} and @var{end} (exclusive).
}
@define[Function]{@name{vector-append} @args{vectors @dots{}}}
@desc{Returns a newly allocated vector whose contents are the
concatenation of the contents in @var{vectors}.}
@define[Function]{@name{vector-copy}
 @args{vector :optional (start 0) (end (vector-length vector))}}
@desc{Returns a vector whose elements are elements of given @var{vector}
between @var{start} and @var{end}.
}
@define[Function]{@name{vector-copy!}
 @args{to at from :optional (start 0) (end (vector-length from))}}
@desc{@var{to} and @var{from} must be vectors. @var{at} must be
a non negative exact integer in range of @var{to} size. Optional arguments
@var{start} and @var{end} must be non negative exact integer in range of
@var{from} and @var{end} must be bigger than @var{end}.

Copies content of @var{from} starting from @var{start} until @var{end} 
(exclusive) to @var{to} starting @var{at}. The operation is done
destructively.
}

@sub*section{Strings}

@define[Function]{@name{string-copy!}
 @args{to at from :optional (start 0) (end (vector-length from))}}
@desc{@var{to} and @var{from} must be strings. @var{at} must be
a non negative exact integer in range of @var{to} size. Optional arguments
@var{start} and @var{end} must be non negative exact integer in range of
@var{from} and @var{end} must be bigger than @var{end}.

Copies content of @var{from} starting from @var{start} until @var{end} 
(exclusive) to @var{to} starting @var{at}. The operation is done
destructively.
}

@define[Function]{@name{string-map} @args{proc string strings @dots{}}}
@desc{Calls @var{proc} with given @var{strings} elements and returns
a string whose content is constructed by the results of @var{proc}.
}

@sub*section{Parameters}

@define[Function]{@name{make-parameter} @args{init :optional converter}}
@desc{[SRFI-39] Returns a parameter object, which is an applicable object
that can take zero or one argument. 

The initial value is @code{(@var{converter} @var{init})} if @var{converter}
is given, otherwise @var{init}.

If the parameter object is applied without an argument, then it returns
the value associated with the parameter object.

If the parameter object is applied with an argument, then it changes the
associated value with the given value which may converted by @var{converter}
if the parameter object is created with @var{converter}.

}
@define[Macro]{@name{parameterize} @args{((param1 value1) @dots{}) body @dots{}}}
@desc{[SRFI-39] A @code{parameterize} expression is used to change the
values returned by specified parameter objects during the evaluation of
@var{body}.}

@sub*section{Inclusion}

@define[Syntax]{@name{include} @args{file files @dots{}}}
@define[Syntax]{@name{include-ci} @args{file files @dots{}}}
@desc{@var{files} must be strings.

Includes @var{files} as if it's written there. @code{include-ci} reads
files case insensitively.
}

@sub*section{Multiple-value definition}

@define[Macro]{@name{define-values} @args{formals expression}}
@desc{@var{expression} is evaluated and the @var{formals} are bound to the
return values in the same way that the @var{formals} in @code{lambda}
expression are matched to the arguments in a procedure call.
}

@sub*section{Numerical operations}
@define[Function]{@name{exact-integer?} @args{obj}}
@desc{Returns #t if @var{obj} is exact integer. Otherwise #f.}

@define[Function]{@name{floor/} @args{n1 n2}}
@define[Function]{@name{floor-quotient} @args{n1 n2}}
@define[Function]{@name{floor-remainder} @args{n1 n2}}
@define[Function]{@name{truncate/} @args{n1 n2}}
@define[Function]{@name{truncate-quotient} @args{n1 n2}}
@define[Function]{@name{truncate-remainder} @args{n1 n2}}
@desc{These procedures implement number-theoretic (integer) division.
It is an error if @var{n2} is zero.

The procedure ending @code{/} returns two integers; the other procedures
return an integer. All the procedures compute a quotient @var{nq} and
remainder @var{nr} such that @code{@var{n1} = @var{n2}*@var{nq} + @var{nr}}.
for each of the division operators, there are three procedures defined as
follows;

@snipet[=> "nq nr"]{(<operator>/ @var{n1} @var{n2})}
@snipet[=> "nq"]{(<operator>-quotient @var{n1} @var{n2})}
@snipet[=> "nr"]{(<operator>-remainder @var{n1} @var{n2})}

The remainder @var{nr} is determined by the choice of integer
@code{@var{nq}:@var{nr} = @var{n1} - @var{n2}*@var{nq}}. Each set of
operations uses a different choice of @var{nq}:

@code{floor}: @code{@var{nq} = [@var{n1}/@var{n2}]}

@code{truncate}: @code{@var{nq} = truncate(@var{n1}/@var{n2})}

Examples;

@snipet[=> "2 1"]{(floor/ 5 2)}
@snipet[=> "-3 1"]{(floor/ -5 2)}
@snipet[=> "-3 -1"]{(floor/ 5 -2)}
@snipet[=> "2 -1"]{(floor/ -5 -2)}
@snipet[=> "2 1"]{(truncate/ 5 2)}
@snipet[=> "-2 -1"]{(truncate/ -5 2)}
@snipet[=> "-2 1"]{(truncate/ 5 -2)}
@snipet[=> "2 -1"]{(truncate/ -5 -2)}
@snipet[=> "2.0 -1.0"]{(truncate/ -5.0 -2)}
}

@define[Function]{@name{square} @args{z}}
@desc{Returns the square of @var{z}.}

@sub*section{Error objects}

@define[Macro]{@name{syntax-error} @args{msg forms @dots{}}}
@desc{Raises an @code{&syntax} with @code{syntax-violation}.

The macro is defined like this;

@codeblock{
(define-syntax syntax-error
  (syntax-rules ()
    ((_ msg args @dots{})
     (syntax-violation 'syntax-error msg (quote args @dots{})))))
}

}

@define[Function]{@name{error-object?} @args{obj}}
@desc{Returns #t if @var{obj} is condition object. This is a renaming
exported procedure of @code{consition?}.
}
@define[Function]{@name{error-object-irritants} @args{err}}
@desc{Returns irritants if the given @var{err} satisfies 
@code{irritants-condition?}. Otherwise #f.
}
@define[Function]{@name{error-object-message} @args{err}}
@desc{Returns error message if the given @var{err} satisfies
@code{message-condition?}. Otherwise #f.
}

@sub*section{I/O}

@define[Function]{@name{file-error?} @args{obj}}
@desc{Returns #t if @var{obj} is a file related condition, otherwise #f.
}
@define[Function]{@name{read-error?} @args{obj}}
@desc{Renaming export of @code{i/o-read-error?}.}

@define[Function]{@name{input-port-open?} @args{input-port}}
@define[Function]{@name{output-port-open?} @args{output-port}}
@desc{Return #t if given @var{input-port} or @var{output-port} is open,
respectively. Otherwise #f.
}

@define[Function]{@name{u8-ready?} @args{input-port}}
@define[Function]{@name{char-ready?} @args{input-port}}
@desc{Renaming export of @code{port-ready?}.
}

@define[Function]{@name{peek-u8}
 @args{:optional (input-port (current-input-port))}}
@define[Function]{@name{read-u8}
 @args{:optional (input-port (current-input-port))}}
@desc{@var{input-port} must be a binary input port.

Peeks or reads a byte from given @var{input-port}.
}

@define[Function]{@name{read-bytevector}
 @args{len :optional (input-port (current-input-port))}}
@desc{@var{input-port} must be a binary input port.

Reads @var{len} from @var{input-port} and returns a bytevector.
}

@define[Function]{@name{read-bytevector!}
 @args{bv :optional (input-port (current-input-port))
		    (start 0) (end (bytevector-length bv))}}
@desc{@var{input-port} must be a binary input port.

Reads @var{end} - @var{start} size of data from @var{input-port} and put it
into @var{bv} from @var{start} index.
}

@define[Function]{@name{write-u8}
 @args{u8 :optional (output-port (current-output-port))}}
@desc{@var{u8} must be a byte. @var{output-port} must be a binary output port.

Writes @var{u8} to @var{output-port}.
}

@define[Function]{@name{write-bytevector}
 @args{bv :optional (output-port (current-output-port))
		    (start 0) (end (bytevector-length bv))}}
@desc{@var{output-port} must be a binary output port.

Writes @var{bv} from @var{start} to @var{end} (exclusive) to @var{output-port}.
}

@define[Function]{@name{read-line}
 @args{:optional (input-port (current-input-port))}}
@desc{@var{input-port} must be a textual input port.

Reads line from @var{input-port}. For convenience, @code{\n}, @code{\r}
and @code{\r\n} are considered end of line.
}

@define[Function]{@name{read-string}
 @args{k :optional (input-port (current-input-port))}}
@desc{@var{input-port} must be a textual input port.

Reads @var{k} length of string from @var{input-port}.
}

@define[Function]{@name{write-string}
 @args{str :optional (output-port (current-output-port))
		     (start 0) (end (string-length str))}}
@desc{@var{output-port} must be a binary output port.

Writes @var{bv} from @var{start} to @var{end} (exclusive) to @var{output-port}.
}

@define[Function]{@name{open-input-bytevector} @args{bv}}
@define[Function]{@name{open-input-string} @args{string}}
@desc{Returns binary or textual input port whose source is @var{bv}
or @var{string}, respectively.
}

@define[Function]{@name{open-output-bytevector}}
@define[Function]{@name{open-output-string}}
@desc{Returns binary or textual output port. The port is opened on memory.}

@define[Function]{@name{get-output-bytevector} @args{output-port}}
@define[Function]{@name{get-output-string} @args{output-port}}
@desc{Retrieves buffered bytevector or string from given @var{output-ports},
respectively.
}

@sub*section{System interface}

@define[Function]{@name{features}}
@desc{Returns a list of the feature identifiers which @code{cond-expand}
treas as true.
}

@sub*section{Differ from R6RS}

The following procedures or macros are re-defined to strictly follow either
R6RS or R7RS. It is users' responsibility to make sure proper ones are used
in their script.

@define[Function]{@name{equal?} @args{a b}}
@desc{Returns #t if @var{a} and @var{b} are equivalent.

The difference between the one from @code{(rnrs base)} is that this procedure
inspect record fields as well. For example:

@codeblock[=> #f]{
(import (rnrs))
(define-record-type (<pare> kons pare?)
  (fields (mutable a kar set-kar!)
	  (mutable d kdr set-kdr!)))

(let ((a (kons 'a 'b))
      (b (kons 'a 'b)))
  (equal? a b))
}

@codeblock[=> #t]{
(import (scheme base))
(define-record-type (<pare> kons pare?)
  (fields (mutable a kar set-kar!)
	  (mutable d kdr set-kdr!)))

(let ((a (kons 'a 'b))
      (b (kons 'a 'b)))
  (equal? a b))
}
}

@define[Macro]{@name{let-syntax} @args{((var trans) @dots{}) expr @dots{}}}
@define[Macro]{@name{letrec-syntax} @args{((var trans) @dots{}) expr @dots{}}}
@desc{Binds macro transformer @var{trans} to @var{var}.

The difference between the one from @code{(rnrs base)} and these macros is
that these macro create scope. Thus the following is unbound variable error:
@codeblock[=> &undefined]{
(import (scheme base))
(let-syntax ()
  (define foo 'foo))
foo
}
}

@subsubsection{Case-lambda library}

@define[Library]{@name{(scheme case-lambda)}}
@desc{[R7RS] This library exports the @code{case-lambda} syntax.

Exported macro is the same as R6RS;

@code{case-lambda}
}

@subsubsection{Char library}

@define[Library]{@name{(scheme char)}}
@desc{[R7RS]This library exports procedures for dealing with Unicode character
operations.


These procedures are the same as R6RS;

@codeblock{
 char-alphabetic? char-ci<=? char-ci<? char-ci=? char-ci>=? char-ci>?
 char-downcase char-foldcase char-lower-case? char-numeric? char-upcase
 char-upper-case? char-whitespace? string-ci<=? string-ci<?
 string-ci=? string-ci>=? string-ci>? string-downcase string-foldcase
 string-upcase}
}

@define[Function]{@name{digit-value} @args{c}}
@desc{[R7RS+] Converts given character to it's numeric value. If the given
character does not have numeric value, then it returns #f.

This procedure is extended from R7RS definition.

@snipet[=> "1"]{(digit-value #\1)}
@snipet[=> "4"]{(digit-value #\x0664)}
@snipet[=> "#f"]{(digit-value #\x0EA6)}
@snipet[=> "1/4"]{(digit-value #\xbc)}
@snipet[=> "10"]{(digit-value #\xbf0)}

}

@subsubsection{Complex library}

@define[Library]{@name{(scheme complex)}}
@desc{[R7RS]This library exports procedures for complex numbers.

These procedures are the same as R6RS;

@code{angle imag-part magnitude make-polar make-rectangular real-part}
}

@subsubsection{CxR library}

@define[Library]{@name{(scheme cxr)}}
@desc{[R7RS]This library exports twenty-four procedures
which are the compositions of from three to four car and
cdr operations.

These procedures are the same as R6RS;

@codeblock{caaaar caaadr
caaar caadar
caaddr caadr
cadaar cadadr
cadar caddar
cadddr caddr
cdaaar cdaadr
cdaar cdadar
cdaddr cdadr
cddaar cddadr
cddar cdddar
cddddr cdddr}
}

@subsubsection{Eval library}

@define[Library]{@name{(scheme eval)}}
@desc{[R7RS]This library exports exports procedures for evaluating
Scheme data as programs.

These procedures are the same as R6RS;

@code{environment eval}
}

@subsubsection{File library}

@define[Library]{@name{(scheme file)}}
@desc{[R7RS]This library exports procedures for accessing files.

These procedures are the same as R6RS;

@codeblock{
 call-with-input-file call-with-output-file
 delete-file file-exists?
 open-input-file open-output-file
 with-input-from-file with-output-to-file}
}

@define[Function]{@name{open-binary-input-file} @args{file}}
@define[Function]{@name{open-binary-output-file} @args{file}}
@desc{Returns file binary input or output port associated with given
@var{file}, respectively.
}
@subsubsection{Inexact library}

@define[Library]{@name{(scheme inexact)}}
@desc{[R7RS]This library exports procedures for inexact value.

These procedures are the same as R6RS;

@code{acos asin atan cos exp finite? infinite? log nan? sin sqrt tan}
}

@subsubsection{Lazy library}

@define[Library]{@name{(scheme lazy)}}
@desc{[R7RS]This library exports procedures and syntax
keywords for lazy evaluation.

These procedures/macros are the same as R6RS;

@code{delay force make-promise promise?}
}

@define[Macro]{@name{delay-force} @args{expression}}
@desc{The expression @code{(delay-force @var{expression})} is conceptually
similar to @code{(delay (force @var{expression}))}, with the difference that
forcing the result of @code{delay-force} will in effect result in a tail call
to @code{(force @var{expression})}, while forcing the result of
@code{(delay (force @var{expression}))} might not.
}

@subsubsection{Load library}

@define[Library]{@name{(scheme load)}}
@desc{[R7RS]This library exports procedures for loading Scheme expressions
from files.
}

@define[Function]{@name{load} @args{file :optional environment}}
@desc{Reads expression in @var{file} and evaluates it until it gets to
end of file. If @var{environment} is passed, then the evaluation is done
in that environment. Otherwise it is done in current environment.
}

@subsubsection{Process-Context library}

@define[Library]{@name{(scheme process-context)}}
@desc{[R7RS] This library exports procedures for accessing with the program's
calling context.

These procedures are the same as R6RS;
@code{command-line exit}
}

@define[Function]{@name{emergency-exit} @args{:optional obj}}
@desc{Exist process without any cleanup. The optional argument @var{obj}
is given then it's translated to proper return value of the process.
}

@define[Function]{@name{get-enviromnent-variable} @args{name}}
@desc{@var{name} must be a string.

Retrieves environment variable associated to @var{name}.
}

@define[Function]{@name{get-enviromnent-variables}}
@desc{Returns alist of environment variables.}

@subsubsection{Read library}

@define[Library]{@name{(scheme read)}}
@desc{[R7RS]This library exports procedures for reading Scheme objects.
}

@define[Function]{@name{read} @args{:optional port}}
@desc{Renaming export of @code{read/ss}.}

@subsubsection{Repl library}

@define[Library]{@name{(scheme repl)}}
@desc{[R7RS]This library library exports the
@code{interaction-environment} procedure.}

@define[Function]{@name{interaction-environment}}
@desc{Returns interaction environment.}

@subsubsection{Time library}

@define[Library]{@name{(scheme time)}}
@desc{[R7RS]This library provides access to time-related values.
}

@define[Function]{@name{current-jiffy}}
@desc{Returns the number of jiffies as an exact integer.}
@define[Function]{@name{jiffies-per-second}}
@desc{Returns an exact integer representing the number of jiffies per SI
second.}

@define[Function]{@name{current-second}}
@desc{Returns an inexact number representing the current time on
International Atomic Time (TAI) scale.}


@subsubsection{Write library}

@define[Library]{@name{(scheme write)}}
@desc{[R7RS]This library exports procedures for writing Scheme objects.

This procedures is the same as R6RS
@code{display}
}

@define[Function]{@name{write}
 @args{obj :optional (output-port (current-output-port))}}
@desc{Writes a representation of @var{obj} to @var{output-port}.

If the @var{obj} contains cyclic, the procedure writes with datum label.
}

@define[Function]{@name{write-shared}
 @args{obj :optional (output-port (current-output-port))}}
@define[Function]{@name{write-simple}
 @args{obj :optional (output-port (current-output-port))}}
@desc{Renaming export of @code{write/ss} and @code{write}, respectively.
}

@subsubsection{R5RS library}

@define[Library]{@name{(scheme r5rs)}}
@desc{[R7RS]The (scheme r5rs) library provides the identifiers defined
by R5RS, except that @code{transcript-on} and @code{transcript-off} are
not present. Note that the @code{exact} and @code{inexact} procedures
appear under their R5RS names @code{inexact->exact} and 
@code{exact->inexact} respectively. However, if an implementation does
not provide a particular library such as the complex library, the
corresponding identifiers will not appear in this library either. This
library exports procedures for writing Scheme objects.
}

@subsection{R7RS-large}

R7RS-large makes Scheme specification more practical. It contains
lots of useful libraries as well. This section lists supporting
R7RS-large libraries.

@subsubsection{List library}
@define[Library]{@name{(scheme list)}}
@desc{This library exports the procedures and macros defined in
SRFI-1 @code{(srfi :1)}.
}

@subsubsection{Vector library}
@define[Library]{@name{(scheme vector)}}
@desc{This library exports the procedures and macros defined in
SRFI-133 @code{(srfi :133)}.
}

@subsubsection{Sorting library}
@define[Library]{@name{(scheme sort)}}
@desc{This library exports the procedures and macros defined in
SRFI-132 @code{(srfi :132)}.
}

@subsubsection{Set library}
@define[Library]{@name{(scheme set)}}
@desc{This library exports the procedures and macros defined in
SRFI-113 @code{(srfi :113)}.
}

@subsubsection{Character set library}
@define[Library]{@name{(scheme charset)}}
@desc{This library exports the procedures and macros defined in
SRFI-14 @code{(srfi :14)}.
}

@subsubsection{Hashtable library}
@define[Library]{@name{(scheme hash-table)}}
@desc{This library exports the procedures and macros defined in
SRFI-125 @code{(srfi :125)}.
}

@subsubsection{Immutable list library}
@define[Library]{@name{(scheme ilist)}}
@desc{This library exports the procedures and macros defined in
SRFI-116 @code{(srfi :116)}.
}

@subsubsection{Random access list library}
@define[Library]{@name{(scheme rlist)}}
@desc{This library exports the procedures and macros defined in
SRFI-101 @code{(srfi :101)} with the following exceptions:

@code{make-list} is renamed to @code{make-rlist}.

@code{random-access-list->linear-access-list} is renamed to @code{rlist->list}.

@code{linear-access-list->random-access-list} is renamed to @code{list->rlist}.

All other procedures are prefixed with @code{r}. For example, @code{pair?}
exported from @code{(srfi :101)} is @code{rpair?}.
}

@subsubsection{Immutable deque library}
@define[Library]{@name{(scheme ideque)}}
@desc{This library exports the procedures and macros defined in
SRFI-134 @code{(srfi :134)}.
}

@subsubsection{Immutable text library}
@define[Library]{@name{(scheme text)}}
@desc{This library exports the procedures and macros defined in
SRFI-135 @code{(srfi :135)}.
}

@subsubsection{Generator library}
@define[Library]{@name{(scheme generator)}}
@desc{This library exports the procedures and macros defined in
SRFI-158 @code{(srfi :158)}.
}

@subsubsection{Lazy sequence library}
@define[Library]{@name{(scheme lazy-seq)}}
@desc{This library exports the procedures and macros defined in
SRFI-127 @code{(srfi :127)}.
}

@subsubsection{Stream library}
@define[Library]{@name{(scheme stream)}}
@desc{This library exports the procedures and macros defined in
SRFI-41 @code{(srfi :41)}.
}

@subsubsection{Box library}
@define[Library]{@name{(scheme box)}}
@desc{This library exports the procedures and macros defined in
SRFI-111 @code{(srfi :111)}.
}

@subsubsection{List queue library}
@define[Library]{@name{(scheme list queue)}}
@desc{This library exports the procedures and macros defined in
SRFI-117 @code{(srfi :117)}.
}

@subsubsection{Ephemeron library}
@define[Library]{@name{(scheme ephemeron)}}
@desc{This library exports the procedures and macros defined in
SRFI-124 @code{(srfi :124)}.
}

@subsubsection{Comparator library}
@define[Library]{@name{(scheme comparator)}}
@desc{This library exports the procedures and macros defined in
SRFI-128 @code{(srfi :128)}.
}

@; Tangerine
@subsubsection{Division library}
@define[Library]{@name{(scheme division)}}
@desc{This library exports the procedures and macros defined in
SRFI-141 @code{(srfi :141)}.
}

@subsubsection{Fixnum library}
@define[Library]{@name{(scheme fixnum)}}
@desc{This library exports the procedures and macros defined in
SRFI-143 @code{(srfi :143)}.
}

@subsubsection{Flonum library}
@define[Library]{@name{(scheme flonum)}}
@desc{This library exports the procedures and macros defined in
SRFI-144 @code{(srfi :144)}.
}

@subsubsection{Mapping library}
@define[Library]{@name{(scheme mapping)}}
@desc{This library exports the procedures and macros defined in
SRFI-146 @code{(srfi :146)}.
}

@subsubsection{Hash mapping library}
@define[Library]{@name{(scheme mapping hash)}}
@desc{This library exports the procedures and macros defined in
SRFI-146 @code{(srfi :146 hash)}.
}

@subsubsection{Bitwise library}
@define[Library]{@name{(scheme bitwise)}}
@desc{This library exports the procedures and macros defined in
SRFI-151 @code{(srfi :151)}.
}

@subsubsection{Format library}
@define[Library]{@name{(scheme format)}}
@desc{This library exports the procedures and macros defined in
SRFI-159 @code{(srfi :159)}.
}

@subsubsection{Homogeneous vector library base}
@define[Library]{@name{(scheme vector base)}}
@desc{This library exports the procedures and macros defined in
SRFI-160 @code{(srfi :160 base)}.
}

@subsubsection{Homogeneous vector library per types}
@define[Library]{@name{(scheme vector @atmark{})}}
@desc{This library exports the procedures and macros defined in
SRFI-160 @code{(srfi :160 @atmark{})}. Where @code{@atmark{}} is one of
@code{u8 s8 u16 s16 u32 s32 u64 s64 f32 f64 c64 c128}
}

@subsubsection{Bytevector library}
@define[Library]{@name{(scheme bytevector)}}
@desc{This library exports the procedures and macros defined in
R6RS bytevectors library @code{(rnrs bytevectors)}.

NOTE: The exporting names may conflicts with the ones exported from R7RS
libraries (e.g. @code{bytevector-copy!} from @code{(scheme base)}).
}
