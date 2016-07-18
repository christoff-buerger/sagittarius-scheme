@; -*- mode:scribble; coding: utf-8 -*-

@section[:tag "ext.sagittarius"]{Sagittarius extensions}

Sagittarius has its own extension libraries because even R6RS is huge however I
know it is not  sufficient to write practical program. To  support to write it,
Sagittarius provides some useful libraries.

@subsection[:tag "lib.sagittarius"]{(sagittarius) - builtin library}

@define[Library]{@name{(sagittarius)}}
@desc{This library has Sagittarius specific functions which are not supported
in R6RS such as extra file system functions and so.
}

@subsubsection[:tag "lib.sagittarius.builtin.syntax"]{Builtin Syntax}
@define[Syntax]{@name{define-constant} @args{variable expression}}
@desc{Similar to the @code{define} however the @code{define-constant} binds
@var{variable} as a constant value and the compiler try to fold it if it is
constant value i.e. literal string, literal vector, literal number and so.

If the defined @var{variable} is being overwritten, the VM shows a warning
message on the standard error. I am not sure if it should raise an error or not,
so this behaviour might be changed in future.
}

@define[Syntax]{@name{receive} @args{formals expression body}}
@desc{[SRFI-8] @var{formals} and @var{body} the same as @code{lambda}.
@var{Expression} must be an expression.

@code{receive} binds values which are generated by @var{expressions} to
@var{formals}.

The expressions in @var{body} are evaluated sequentially in the extended
environment. The results of the last expression in the body are the values of
the @code{receive}-expression.
}

@define[Syntax]{@name{cond-expand} @args{clauses @dots{}}}
@desc{[R7RS][SRFI-0] Compile time condition. The @code{cond-expand} resolves
platform dependencies such as C's @code{#ifdef} preprocessor.

@var{clauses} must be one of these forms:
@itemlist{
@item{(@var{feature-identifier} @var{body} @dots{})}
@item{((@code{library} @var{library-name}) @var{body} @dots{})}
@item{((@code{and} @var{feature-identifier} @dots{}) @var{body} @dots{})}
@item{((@code{or} @var{feature-identifier} @dots{}) @var{body} @dots{})}
@item{(@code{not} @var{feature-identifier})}
}
@code{library} form searches the given @var{library-name} and if it is found,
then compiles @var{body}.

@code{and}, @code{or} and @code{not} are the same as usual syntax.

Possible @var{feature-identifier}s are @code{sagittarius} and
@code{sagittarius.os.@var{osname}}. @var{osname} can be @code{cygwin},
@code{windows} or @code{linux} so on.
}

@subsubsection{Macro transformer}

@define[Function]{@name{er-macro-transformer} @args{proc}}
@desc{@var{Proc} must take 3 arguments, @var{form}, @var{rename} and
@var{compare}.

@dl-list[
@dl-item[@var{form}]{The input form of this macro. It is mere s-expression.}
@dl-item[@var{rename}]{A procedure. It takes an object as its argument and
convert it to a syntax object. The procedure is similar with 
@code{datum->syntax}, it doesn't require template identifier.}
@dl-item[@var{compare}]{A procedure. It takes 2 arguments and compares if they
are the same object in sense of @code{free-identifier=?}. If the given
arguments are list or vector, then the procedure checks its elements.}
]

The @code{er-macro-transformer} returns explicit renaming macro transformer, so
you can write both hygine and non-hygine macro with it. For example:
@codeblock[=> (a a a)]{
(define-syntax loop
  (er-macro-transformer
   (lambda (form rename compare)
     (let ((body (cdr form)))
       `(,(rename 'call/cc)
	 (,(rename 'lambda) (break)
	  (,(rename 'let) ,(rename 'f) () ,@atmark{}body (,(rename 'f)))))))))

(let ((n 3) (ls '()))
  (loop
    (if (= n 0) (break ls))
    (set! ls (cons 'a ls))
    (set! n (- n 1))))
}
This example has the same functionality as the example written in
@code{datum->syntax} description. The basic of @code{er-macro-transformer} is
the opposite way of the @code{syntax-case}. The @code{syntax-case} always makes
macro hygine, however the @code{er-macro-transformer} can make macro hygine.
Moreover, if you do not use @var{rename}, it always makes it non-hygine.

}

@subsubsection{Arithmetic operations}

@define[Function]{@name{+.} @args{z @dots{}}}
@define[Function]{@name{*.} @args{z @dots{}}}
@define[Function]{@name{-.} @args{z @dots{}}}
@define[Function]{@name{-.} @args{z1 z2 @dots{}}}
@define[Function]{@name{/.} @args{z @dots{}}}
@define[Function]{@name{/.} @args{z1 z2 @dots{}}}
@desc{The same as @code{+}, @code{*}, @code{-} and @code{/}. The difference is
these procedures converts given arguments inexact number.}

@define[Function]{@name{mod-inverse} @args{x m}}
@desc{@var{x} and @var{m} must be exact integer.

Returns @code{@var{x} ^ -1 mod @var{m}}}

@define[Function]{@name{mod-expt} @args{x e m}}
@desc{@var{x}, @var{e} and @var{m} must be exact integer.

Returns @code{@var{x} ^ @var{e} mod @var{m}}}

@subsubsection{File system operations}

@define[Function]{@name{file-size-in-bytes} @args{filename}}
@desc{Returns file size of filename in bytes. If filename does not exist, it
raises @code{&assertion} condition.
}

@define[Function]{@name{file-regular?} @args{filename}}
@define[Function]{@name{file-directory?} @args{filename}}
@define[Function]{@name{file-symbolic-link?} @args{filename}}
@define[Function]{@name{file-readable?} @args{filename}}
@define[Function]{@name{file-writable?} @args{filename}}
@define[Function]{@name{file-executable?} @args{filename}}
@desc{Returns file type or permission of given @var{filename}.}

@define[Function]{@name{file-stat-ctime} @args{filename}}
@define[Function]{@name{file-stat-mtime} @args{filename}}
@define[Function]{@name{file-stat-atime} @args{filename}}
@desc{Returns file statistics time in nano sec.

The @code{file-stat-ctime} procedure returns last change time of @var{filename}.

The @code{file-stat-mtime} returns last modified time of @var{filename}.

The @code{file-stat-atime} returns last accesse time of @var{filename}.
}

@define[Function]{@name{create-symbolic-link} @args{old-filename new-filename}}
@desc{Creates symbolic link of @var{old-filename} as @var{new-filename}.}

@define[Function]{@name{rename-file} @args{old-filename new-filename}}
@desc{Renames given @var{old-filename} to @var{new-filename}.

If @var{old-filename} does not exist, it raises @code{&assertion}.

If @var{new-filename} exists, it overwrite the existing file.
}

@define[Function]{@name{create-directory} @args{path}}
@define[Function]{@name{delete-directory} @args{path}}
@desc{Creates/deletes given directory. If it fails, it raises condition
@code{&assertion}.
}

@define[Function]{@name{read-directory} @args{path}}
@desc{Reads directory and returns contents as a string list. If @var{path} does
not exist, it returns #f.
}

@define[Function]{@name{copy-file} @args{src dst :optional overwrite}}
@desc{@var{src} and @var{dst} must be string and indicating existing file path.

Copies given @var{src} file to @var{dst} and returns #t if it's copied otherwise
#t.

If optional argument @var{overwrite} is #t then it will over write the file even
if it exists.
}

@define[Function]{@name{current-directory} @args{:optional path}}
@desc{Returns current working directory.

If optional argument @var{path} is given, the @code{current-directory} sets
current working directory to @var{path} and returns unspecified value.
}

@define[Function]{@name{set-current-directory} @args{path}}
@desc{Sets current working directory to @var{path}.}

@define[Function]{@name{build-path} @args{path1 path2}}
@desc{@var{path1} and @var{path2} must be string.

Concatenate given parameter with platform dependent path separator.
}


@subsubsection{Hashtables}

@define[Function]{@name{make-equal-hashtable} @args{:optional k weakness}}
@define[Function]{@name{make-string-hashtable} @args{:optional k weakness}}
@desc{Creates a hashtable. The same as @code{make-eq-hashtable} and
@code{make-eqv-hashtable}. It uses @code{equal?} or @code{string=?} as
comparing procedure, respectively.}

@define[Function]{@name{hashtable-values} @args{hashtable}}
@desc{Returns all @var{hashtable}'s values. This procedure is for consistancy of
@code{hashtable-keys}.}

@define[Function]{@name{hashtable-keys-list} @args{hashtable}}
@define[Function]{@name{hashtable-values-list} @args{hashtable}}
@desc{Returns given @var{hashtable}'s @var{keys} or @var{values}, respectively.

The R6RS required procedure @code{hashtable-keys} and @code{hashtable-values}
are implemented with these procedures.
}

@define[Function]{@name{hashtable-type} @args{hashtable}}
@desc{Returns @var{hashtable}'s hash type as a symbol. The possible return
values are @code{eq}, @code{eqv}, @code{equal}, @code{string} and
@code{general}.
}

@define[Function]{@name{hashtable-weakness} @args{hashtable}} 
@desc{Returns @var{hashtable}'s hash weakness as a symbol if the given
@var{hashtable} is weak hashtable, otherwise #f. The possible return values are
@code{key}, @code{value} and @code{both}.  }

@subsubsection{I/O}

@define[Function]{@name{port-closed?} @args{port}}
@desc{Returns #t if given @var{port} is closed, otherwise #f.}

@define[Function]{@name{put-u16} @args{out v endian}}
@define[Function]{@name{put-s16} @args{out v endian}}
@define[Function]{@name{put-u32} @args{out v endian}}
@define[Function]{@name{put-s32} @args{out v endian}}
@desc{@var{out} must be binary output port. @var{endian} must be a value
returned from @code{endianness} macro.

Write @var{v} to @var{out} as unsigned/signed 16/32 bit integer.}

@define[Function]{@name{get-u16} @args{in endian}}
@define[Function]{@name{get-s16} @args{in endian}}
@define[Function]{@name{get-u32} @args{in endian}}
@define[Function]{@name{get-s32} @args{in endian}}
@desc{@var{in} must be binary input port. @var{endian} must be a value
returned from @code{endianness} macro.

Read a number from @var{in} as unsigned/signed 16/32.}

NOTE: above @code{put-*} and @code{get-*} have only 16 and 32 bit integers.
This is because benchmark told us there's not much difference between C and
Scheme implementation. We may add 64 bit integers and floting number 
versions in future if there's enough demand.

@define[Function]{@name{read/ss}
 @args{:optional (port @code{(current-input-port)})}}
@define[Function]{@name{write/ss}
 @args{obj :optional (port @code{(current-output-port)})}}
@desc{[SRFI-38] The @code{read/ss} reads a datum from given @var{port}.

The @code{write/ss} writes @var{obj} to given @var{port}.

These are the same as @code{read} and @code{write} procedure, but it can handle
circular list.
}

@define[Function]{@name{format} @args{port string arg @dots{}}}
@define[Function]{@name{format} @args{string arg @dots{}}}
@desc{[SRFI-28+] Formats @var{arg} accoding to @var{string}. @var{Port}
specifies the destination; if it is an output port, the formatted result is
written to it; if it is #t, the result is written to current output port; if it
is #f, the formatted result is returned as a string. @var{Port} can be omitted
and the result is the same as when #f is given.

@var{String} is a string that contains format directives. A format directive is
a character sequence begins with tilda @code{'~'}, and ends with some specific
characters. A format directive takes the corresponding arg and formats it. The
rest of string is copied to the output as is.

@snipet[=> "the anser is 48"]{(format #f "the answer is ~a" 48)}

The format directive can take one or more parameters, separated by comma
characters. A parameter may be an integer or a character; if it is a character, 
it should be preceded by a quote character. Parameter can be omitted, in such
case the system default value is used. The interpretation of the parameters
depends on the format directive.

Furthermore, a format directive can take two additional flags: atmark
@code{'@atmark{}'} and colon @code{':'}. One or both of them may modify the
behaviour of the format directive. Those flags must be placed immediately
before the directive character.

The following complete list of the supported directives. Either upper case or
lower case character can be used for the format directive; usually they have no
distinction, except noted.

@dl-list[
@dl-item[@string{~@var{mincol},@var{colinc},@var{minpad},@var{padchar},@var{maxcol}@b{A}}]{
Ascii output. The corresponding argument is printed by @code{display}. If an
integer @var{mincol} is given, it specifies the minimum number of characters to
be output; if the formatted result is shorter than @var{mincol}, a whitespace is
padded to the right (i.e. the result is left justified).

The @var{colinc}, @var{minpad} and @var{padchar} parameters control, if given,
further padding. A character padchar replaces the padding character for the
whitespace. If an integer @var{minpad} is given and greater than 0, at least
@var{minpad} padding character is used, regardless of the resulting width. If an
integer @var{colinc} is given, the padding character is added (after minpad) in
chunk of @var{colinc} characters, until the entire width exceeds @var{mincol}.

If atmark-flag is given, the format result is right justified, i.e. padding is
added to the left.

The @var{maxcol} parameter, if given, limits the maximum number of characters to
be written. If the length of formatted string exceeds @var{maxcol}, only
@var{maxcol} characters are written. If colon-flag is given as well and the
length of formatted string exceeds @var{maxcol}, @var{maxcol} - 4 characters
are written and a string @code{" @dots{}"} is attached after it.

@snipet[=> "|oops|"       ]{(format #f "|~a|" "oops")}
@snipet[=> "|oops      |" ]{(format #f "|~10a|" "oops")}
@snipet[=> "|      oops|" ]{(format #f "|~10@atmark{}a|" "oops")}
@snipet[=> "|******oops|" ]{(format #f "|~10,,,'*@atmark{}a|" "oops")}
@snipet[=> "|abc def gh|" ]{(format #f "|~,,,,10a|" '(abc def ghi jkl))}
@snipet[=> "|abc de ...|" ]{(format #f "|~,,,,10:a|" '(abc def ghi jkl))}
}
@dl-item[@string{~@var{mincol},@var{colinc},@var{minpad},@var{padchar},@var{maxcol}@b{S}}]{
S-expression output. The corresponding argument is printed by @code{write}. The
semantics of parameters and flags are the same as @b{~A} directive.

@snipet[=> "|\"oops\"|"	   ]{(format #f "|~s|" "oops")}
@snipet[=> "|\"oops\"    |"]{(format #f "|~10s|" "oops")}
@snipet[=> "|    \"oops\"|"]{(format #f "|~10@atmark{}s|" "oops")}
@snipet[=> "|****\"oops\"|"]{(format #f "|~10,,,'*@atmark{}s|" "oops")}
}

@dl-item[@string{~@var{mincol},@var{padchar},@var{commachar},@var{interval}@b{D}}]{
Decimal output. The argument is formatted as an decimal integer. If the argument
is not an integer, all parameters are ignored and it is formatted by @b{~A}
directive.

If an integer parameter @var{mincol} is given, it specifies minimum width of the
formatted result; if the result is shorter than it, @var{padchar} is padded on
the left (i.e. the result is right justified). The default of padchar is a
whitespace.

@snipet[=> "|12345|"     ]{(format #f "|~d|" 12345)}
@snipet[=> "|     12345|"]{(format #f "|~10d|" 12345)}
@snipet[=> "|0000012345|"]{(format #f "|~10,'0d|" 12345)}

If atmark-flag is given, the sign @code{'+'} is printed for the positive
argument.

If colon-flag is given, every @var{interval}th digit of the result is grouped
and commachar is inserted between them. The default of @var{commachar} is
@code{','}, and the default of @var{interval} is 3.

@snipet[=> "|12,345|"    ]{(format #f "|~:d|" 12345)}
@snipet[=> "|-1234_5678|"]{(format #f "|~,,'_,4:d|" -12345678)}
}
@dl-item[@string{~@var{mincol},@var{padchar},@var{commachar},@var{interval}@b{B}}]{
Binary output. The argument is formatted as a binary integer. The semantics of
parameters and flags are the same as the @b{~D} directive.
}
@dl-item[@string{~@var{mincol},@var{padchar},@var{commachar},@var{interval}@b{O}}]{
Octet output. The argument is formatted as a octal integer. The semantics of
parameters and flags are the same as the @b{~D} directive.
}
@dl-itemx[2
@string{~@var{mincol},@var{padchar},@var{commachar},@var{interval}@b{X}}
@string{~@var{mincol},@var{padchar},@var{commachar},@var{interval}@b{x}}]{
Hexadecimal output. The argument is formatted as a hexadecimal integer. If
@code{'X'} is used, upper case alphabets are used for the digits larger than 10.
If @code{'x'} is used, lower case alphabets are used. The semantics of
parameters and flags are the same as the @b{~D} directive.
@snipet[=> "0f7cf5a8"]{(format #f "~8,'0x" 259847592)}
@snipet[=> "0F7CF5A8"]{(format #f "~8,'0X" 259847592)}
}
]
Note: The format procedure's implementation and most of documentation is quoted
from Gauche.
}

@define[Function]{@name{port-ready?}
 @args{:optional (port (current-input-port))}}
@desc{Returns #t when port data are ready, otherwise #f.

If the given @var{port} implementation does not support this functionality,
the return value will be always #t. Following example describes when this
always returns #t;
@codeblock[=> #t]{
;; Assume read! is provided.
(define user-port (make-custom-binary-input-port "my-port" read! #f #f))
(port-ready user-port)
}

}

@define[Function]{@name{buffered-port} @args{port buffer-mode :key buffer}}
@desc{@var{port} must be binary port.

Converts given @var{port} to buffered port if the @var{port} is not
buffered port.

Buffered port is a type of port which does not read or write immediately
but uses internal buffer. For example, file port with 
@code{(buffer-mode block)} or @code{(buffer-mode line)} uses the buffered
port. This is useful when actual I/O is more expensive than memory access.

The @var{buffer-mode} must be a symbol the macro @code{buffer-mode} can
return. Converted port uses the specified buffer. If the @code{buffer-mode}
is @code{none}, then the procedure does not convert the given @var{port}.

If the keyword argument @var{buffer} is specified, it must be
a bytevector, then the converted buffered port uses specified bytevector
as its internal buffer. If the bytevector size is zero or literal bytevector
then @code{&assertion} is raised.
}

@define[Function]{@name{make-codec} @args{symbol getc putc data}}
@desc{Creates a custom codec. @var{Symbol} is the name of the codec. @var{Getc}
and @var{putc} must be procedures. @var{Data} is an user data used in @var{getc}
and @var{putc}.

@var{Getc} must take 4 arguments, @var{input-port}, @var{error-handling-mode},
@var{check-bom?} and @var{userdata}. @var{Input-port} is binary input port.
@var{Error-handling-mode} is symbol can be @code{ignore}, @code{raise} or
@code{replace} depending on a transcoder which uses this custom codec.
@var{Check-bom?} is boolean, if @var{getc} is being called first time, it is #t,
otherwise #f. @var{Userdata} is user defined data which is given when the codec
is created.

The basic process of @var{getc} is reading binary data from @var{input-port} and
converting the data to UCS4. Returning UCS4 must be integer and does not have to
be 4 byte.

@var{Putc} must take 4 arguments, @var{output-port}, @var{char}, 
@var{error-handling-mode} and @var{userdata}. @var{Output-port} is binary output
port. @var{Char} is character object which needs to be converted from UCS4.
@var{Error-handling-mode} is symbol can be @code{ignore}, @code{raise} or
@code{replace} depending on a transcoder which uses this custom codec.
@var{Userdata} is user defined data which is given when the codec is created.

The basic process of @var{putc} is converting given UCS4 charactner to target
encoding data and putting it to @var{output-port} as binary data.

For sample implementation, see sitelib/encoding directory. You can find some
custom codecs.
}

@subsubsection{Symbols}

@define[Function]{@name{symbol<?} @args{symbol1 symbol2 symbols @dots{}}}
@define[Function]{@name{symbol<=?} @args{symbol1 symbol2 symbols @dots{}}}
@define[Function]{@name{symbol>?} @args{symbol1 symbol2 symbols @dots{}}}
@define[Function]{@name{symbol>=?} @args{symbol1 symbol2 symbols @dots{}}}
@desc{Return #t if given @var{symbol1} is less than, less than or equal to,
greater than or greater than or equal to @var{symbol2}. If @var{symbols} are
not null, then the procedures continue to compare until the given arguments
are exhausted.

These procedures are analogy of @code{string<?}, @code{string<=?},
@code{string>?} and @code{string>=?}.

These can also be implemented as follows:
@snipet{(define (symbol<? . syms) (apply string<? (map symbol->string syms)))}
However, this build-in version won't converts given symbols to strings.
}

@subsubsection{Keywords}

Sagittarius has keyword objects which starts with @code{':'}. It has almost the
same feature as symbol, however it can not be bounded with any values. The 
keyword objects are self quoting so users don't have to put @code{'} explicitly.

The keyword notation is *NOT* available on R6RS or R7RS reader mode. Thus
@code{#!r6rs} or @code{#!r7rs} directive and @code{-r6} or @code{-r7}
command line option disable it.

@define[Function]{@name{make-keyword} @args{symbol}}
@define[Function]{@name{symbol->keyword} @args{symbol}}
@desc{Creates a new keyword from @var{symbol}.}

@define[Function]{@name{string->keyword} @args{string}}
@desc{Creates a new keyword from @var{string}.}

@define[Function]{@name{keyword?} @args{obj}}
@desc{Returns #t if @var{obj} is keyword, otherwise #f.
}

@define[Function]{@name{keyword->symbol} @args{keyword}}
@desc{Returns a symbol representation of given keyword @var{keyword}.}

@define[Function]{@name{keyword->string} @args{keyword}}
@desc{Returns a string representation of given keyword @var{keyword}.}

@define[Function]{@name{get-keyword} @args{keyword list :optional fallback}}
@desc{Returns the element after given @var{keyword} from given @var{list}.

The elements count of the @var{list} should be even number, otherwise the
procedure might raise @code{&error} when @var{keyword} is not found in
@var{list}.

If @var{fallback} is given and the procedure could not find the @var{keyword}
from the @var{list}, the @var{fallback} will be return. Otherwise it raises
@code{&error}.

@snipet[=> d]{(get-keyword :key '(a b c :key d))}
@snipet[=> &error]{(get-keyword :key '(a b c d e))}
@snipet[=> &error]{(get-keyword :key '(a b c d e) 'fallback)}
@snipet[=> fallback]{(get-keyword :key '(a b c d e f) 'fallback)}

}

@subsubsection{Weak box}

A weak  box is a reference  to an object  that doesn’t prevent the  object from
being garbage-collected.

@define[Function]{@name{weak-box?} @args{obj}}
@desc{Returns #t if @var{obj} is weak box otherwise #f.}

@define[Function]{@name{make-weak-box} @args{obj}}
@desc{Returns a weak box whose value is @var{obj}.}

@define[Function]{@name{weak-box-empty?} @args{wb}}
@desc{Returns #t if the value of given weak box @var{wb} is garbage collocted.
Otherwise #f.}

@define[Function]{@name{weak-box-ref} @args{wb :optional (fallback #f)}}
@desc{Returns the value of given weak box @var{wb} if it's not garbage 
collocted. Otherwise returns @var{fallback}.}

@define[Function]{@name{weak-box-set!} @args{wb obj}}
@desc{Replace the value of given @var{wb} with @var{obj}.}


@subsubsection{Weak vector}

A weak vector  is like a vector  of objects, except each object  can be garbage
collected if it is not referenced from objects other than weak vectors.  If the
object is collected, the entry of the weak vector is replaced to #f.

@define[Function]{@name{weak-vector?} @args{obj}}
@desc{Returns #t if @var{obj} is weak vector otherwise #f.}

@define[Function]{@name{make-weak-vector} @args{size}}
@desc{Creates and returns a weak vector of size @var{size}.}

@define[Function]{@name{weak-vector-length} @args{wvec}}
@desc{Returns the length of given weak vector @var{wvec}}

@define[Function]{@name{weak-vector-ref} @args{wvec k :optional fallback}}
@desc{Returns @var{k}-th element of a weak vector @var{wvec}.

By default, @code{weak-vector-ref} raise an @code{&assertion} if @var{k} is
negative, or greater than or equal to the size of @var{wvec}. However, if an
optional argument @var{fallback} is given, it is returned for such case.

If the element has been garbage collected, this procedure returns @var{fallback}
if it is given, #f otherwise. 
}

@define[Function]{@name{weak-vector-set!} @args{wvec k value}}
@desc{Sets @var{k}-th element of the weak vector @var{wvec} to @var{value}. It
raises an @code{&assertion} if @var{k} is negative or greater than or equal to
the size of @var{wvec}. 
}

@subsubsection{Weak hashtable}

A weak hashtable  is a reference to  an object that doesn’t  prevent the object
from being garbage-collected the same as  weak vector. A weak hashtable is like
a hashtable, except each entry can be garbage collected if it is not referenced
from objects other than weak hashtable according to the constructed condition.

@define[Function]{@name{weak-hashtable?} @args{obj}}
@desc{Returns #t if @var{obj} is weak hashtable otherwise #f.}

@define[Function]{@name{make-weak-eq-hashtable}
 @args{:key (init-size 200) (weakness 'both) default}}
@define[Function]{@name{make-weak-eqv-hashtable}
 @args{:key (init-size 200) (weakness 'both) default}}
@desc{Make a weak hashtable with the hash procedure @code{eq?} and @code{eqv?},
respectively.

The keyword argument @var{init-size} specifies the initial size of the
weak hashtable.

The kwyword argument @var{weakness} specifies the place where the weak pointer
is. This must be one of the @code{key}, @code{value} and @code{both}. If the
@code{key} is specified, then weak hashtable's weak pointer will be the key
so is @code{value}. If the @code{both} is specified, then it will be both.

The keyword argument @var{default} specifies the default value when the entry
is garbage collected. If this is not spceified, then undefined value will be
used.
}

@define[Function]{@name{weak-hashtable-ref}
 @args{weak-hashtable key :optional (default #f)}}
@desc{Returns the value in @var{weak-hashtable} associated with @var{key}. If
@var{weak-hashtable} does not contain an association for @var{key}, 
@var{default} is returned.
}

@define[Function]{@name{weak-hashtable-set!} @args{weak-hashtable key obj}}
@desc{Changes @var{weak-hashtable} to associate @var{key} with @var{obj},
adding a new association or replacing any existing association for @var{key},
and returns unspecified values.
}

@define[Function]{@name{weak-hashtable-delete!} @args{weak-hashtable key}}
@desc{Removes any association for @var{key} within @var{weak-hashtable} and
returns unspecified values.
}

@define[Function]{@name{weak-hashtable-keys-list} @args{weak-hashtable}}
@define[Function]{@name{weak-hashtable-values-list} @args{weak-hashtable}}
@desc{Returns a list of keys and values in the given @var{weak-hashtable},
respectively.
}

@define[Function]{@name{weak-hashtable-copy} @args{weak-hashtable}}
@desc{Returns a copy of @var{weak-hashtable}.}

@define[Function]{@name{weak-hashtable-shrink} @args{weak-hashtable}}
@desc{Shrink the given @var{weak-hashtable} and returns the number of
removed entry. This is only for GC friendliness.}


@subsubsection{Bytevector operations}

@define[Function]{@name{bytevector->sinteger}
 @args{bytevector :optional start end}}
@define[Function]{@name{bytevector->uinteger}
 @args{bytevector :optional start end}}
@define[Function]{@name{bytevector->integer}
 @args{bytevector :optional start end}}
@desc{Converts given bytevector @var{bytevector} to exact integer. If optional
argument @var{start} is given, conversion starts with index @var{start}. If
optional argument @var{end} is given, convertion ends by index @var{end}. The
conversion only happens in big endian. 

The first form converts to signed integer and the rest convert to unsigned
integer.
}

@define[Function]{@name{sinteger->bytevector} @args{ei :optional size}}
@define[Function]{@name{uinteger->bytevector} @args{ei :optional size}}
@define[Function]{@name{integer->bytevector} @args{ei :optional size}}
@desc{@var{Ei} must be exact integer. Converts exact integer @var{ei} to a
bytevector.

The first form can accept signed integer and converts with two's complement
form. The rest forms only accept unsigned integer and simply convert to
bytes.

If optional argument @var{size} is given, then the procedure returns @var{size}
size bytevector.

NOTE: The conversion is processed from right most byte so if the @var{size} is
smaller than given @var{ei} bytes, then the rest of left bytes will be dropped.

NOTE: the endianness is always big integer.

@snipet[=> "#vu8(#x00 #x12 #x34 #x56 #x78)"]{(integer->bytevector #x12345678 5)}
@snipet[=> "#vu8(#x34 #x56 #x78)"]{(integer->bytevector #x12345678 3)}
}

@define[Function]{@name{bytevector-append} @args{bvs @dots{}}}
@desc{Returns a newly allocated bytevector that contains all elements in
order from the subsequent locations in @var{bvs @dots{}}.
}

@define[Function]{@name{bytevector-concatenate} @args{list-of-bytevectors}}
@desc{Appends each bytevectors in @var{list-of-bytevectors}. This is
equivalent to:

@snipet{(apply bytevector-append @var{list-of-bytevectors})}
}


@subsubsection{List operations}

@define[Function]{@name{circular-list?} @args{list}}
@define[Function]{@name{dotted-list?} @args{list}}
@desc{[SRFI-1] Returns #t if @var{list} is circular or dotted list,
respectively. Otherwise #f.}

@define[Function]{@name{acons} @args{obj1 obj2 obj3}}
@desc{Returns @code{(cons (cons @var{obj1} @var{obj2}) @var{obj3})}. Useful to
put an entry at the head of an associative list.
}

@define[Function]{@name{append!} @args{list @dots{}}}
@desc{[SRFI-1] Returns a list consisting of the elements of the first @var{list}
followed by the elements of the other @var{lists}. The cells in the lists except
the last one may be reused to construct the result. The last argument may be any
object.
}

@define[Function]{@name{reverse!} @args{list @dots{}}}
@desc{[SRFI-1] Returns a list consisting of the elements of @var{list} in
reverse order. The cells of list may be reused to construct the returned list.
}

@subsubsection{Vector operations}

@define[Function]{@name{vector-copy} @args{vector :optional start end fill}}
@desc{[SRFI-43] Copies a vector @var{vector}. Optional @var{start} and @var{end}
arguments can be used to limit the range of @var{vector} to be copied. If the
range specified by @var{start} and @var{end} falls outside of the original
vector, the @var{fill} value is used to fill the result vector.
}

@define[Function]{@name{vector-append} @args{vector @dots{}}}
@desc{[SRFI-43] Returns a newly allocated vector that contains all elements in
order from the subsequent locations in @var{vector @dots{}}.
}

@define[Function]{@name{vector-concatenate} @args{list-of-vectors}}
@desc{[SRFI-43] Appends each vectors in @var{list-of-vectors}. This is
equivalent to:

@snipet{(apply vector-append @var{list-of-vectors})}
}

@define[Function]{@name{vector-reverse} @args{vector :optional start end}}
@define[Function]{@name{vector-reverse!} @args{vector :optional start end}}
@desc{[SRFI-43] Reverse the given @var{vector}'s elements.

The second form reverses the given @var{vector} destructively.

Optional arguments @var{start} and @var{end} must be non negative integer
if it's given. And it restricts the range of the target elements.
}

@subsubsection{String operations}

@define[Function]{@name{string-scan} @args{string item :optional return}}
@desc{Scan @var{item} (either a string or a character) in @var{string}.

The @var{return} argument specified what value should be returned when
@var{item} is found in @var{string}. It must be one of the following symbols;

@dl-list{
@dl-item[@code{index}]{
	Returns the index in @var{string} if @var{item} is found, or @code{#f}.
	This is the default behaviour.
}
@dl-item[@code{before}]{
	Returns a substring of @var{string} before @var{item}, or @code{#f} if
	@var{item} is not found.
}
@dl-item[@code{after}]{
	Returns a substring of @var{string} after @var{item}, or @code{#f} if
	@var{item} is not found.
}
@dl-item[@code{before*}]{
	Returns a substring of @var{string} before @var{item}, and the substring
	after it. If @var{item} is not found then return @code{(values #f #f)}.
}
@dl-item[@code{after*}]{
	Returns a substring of @var{string} up to the end of @var{item}, and the
	rest. after it. If @var{item} is not found then return 
	@code{(values #f #f)}.
}
@dl-item[@code{both}]{
	Returns a substring of @var{string} before @var{item} and after
	 @var{item}. If @var{item} is not found, return @code{(values #f #f)}.
}
}
}


@define[Function]{@name{string-concatenate} @args{list-of-strings}}
@desc{[SRFI-13] Appends each strings in @var{list-of-strings}. This is
equivalent to:

@snipet{(apply string-append @var{list-of-strings})}
}

@define[Function]{@name{istring?} @args{obj}}
@desc{Returns #t if the given @var{obj} is an immutable string, otherwise #f.

Immutable strings are one of the followings:
@itemlist{
@item{String literals. (c.f. @code{"abc"})}
@item{Strings converted to immutable string by @code{string->istring}}
}
}

@define[Function]{@name{string->istring} @args{string}}
@desc{Returns copy of the given @var{string}. The returning string is
converted to immutable string.
}

@subsubsection{Load path}

@define[Function]{@name{add-load-path} @args{path :key (append #f)}}
@desc{Add given @var{path} to current loading path list.

If keyword argument @var{append} is @code{#t}, then given @var{path} is
appended to the current loading path list, otherwise prepend to the list.
}

@define[Function]{@name{add-load-suffix} @args{suffix :key (append #f)}}
@desc{Add given @var{suffix} to current suffix list.

If keyword argument @var{append} is @code{#t}, then given @var{suffix} is
appended to the current suffix list, otherwise prepend to the list.

The @var{suffix} should contain @code{.} as well.
}

@define[Function]{@name{load-path} @args{}}
@define[Function]{@name{load-path} @args{paths}}
@desc{Retrives/sets current loading path.

If the latter form is used, then the given path list @var{paths} is set
to current loading path list. Otherwise retrieves the list.

The returning value is not copied, thus modifying the list may cause
unexpected results.
}

@subsubsection{System and platform}

@define[Function]{@name{uname} @args{}}
@desc{Return a vector which contains the following information.

@dl-list{
 @dl-item["System name"]{Operating system name. E.g. "Linux"}
 @dl-item["Node name"]{The name of the computer.}
 @dl-item["Release"]{Release number of the system if availabel.}
 @dl-item["Version"]{Version number of the system if availabel.}
 @dl-item["Machine"]{Machine architecture of the system.}
}

On POSIX environment, this is the result of @code{uname(2)}.

On Windows environment, this is the result of couple of Win32 API calls
and formatted to look like the result of @code{uname(2)}.
}

@define[Function]{@name{get-mac-address} @args{:optional (position 0)}}
@desc{Retrieves MAC address. The returning value is a bytevector which
contains 6 elements.

If optional argument specifies which NIC's MAC address should be returned.
}

@define[Function]{@name{gc} @args{}}
@desc{Invokes garbage collection manually.}

@define[Function]{@name{cpu-count} @args{}}
@desc{Returns number of CPUs. The result contains hyperthreading, for example,
if the CPU is Core i5 which have 2 cores and hyperthreading is enabled, then
the returning value is 4.

On Linux environment, the procedure also considers @code{taskset(1)}.

This procedure returns static value initialised during initialisation of
Sagittarius process. Thus, if the process is restricted after its 
initialisation by @code{taskset(1)}, for example the environment has 4 CPUs
but restricted to 1, then this process, however, returns 4.
}

@subsubsection{Debugging aid}

@define[Function]{@name{disasm} @args{closure}}
@desc{Disassembles the compiled body of @var{closure} and print it.
}

@define[Function]{@name{arity} @args{procedure}}
@desc{Returns arity of given @var{procedure}.

It returns a pair whose car part is required arguments count and cdr part
is boolean which indicates if the procedure accepts optional arguments or
not.
}

@define[Library]{@name{(time)}}
@desc{Exports @code{time} macro}

@define[Macro]{@name{time} @args{expr}}
@desc{Evaluate @var{expr} and shows time usage.

The macro return the result of @var{expr}.}


@include-section["sagittarius/control.scrbl"]
@include-section["sagittarius/ffi.scrbl"]
@include-section["sagittarius/filewatch.scrbl"]
@include-section["sagittarius/io.scrbl"]
@include-section["sagittarius/mop.scrbl"]
@include-section["sagittarius/object.scrbl"]
@include-section["sagittarius/process.scrbl"]
@include-section["sagittarius/reader.scrbl"]
@include-section["sagittarius/record.scrbl"]
@include-section["sagittarius/regex.scrbl"]
@include-section["sagittarius/socket.scrbl"]
@include-section["sagittarius/threads.scrbl"]
@include-section["sagittarius/timezone.scrbl"]
@include-section["sagittarius/debug.scrbl"]
@include-section["sagittarius/generators.scrbl"]

@; end of file
@; Local Variables:
@; mode: scrbl
@; fill-column: 75
@; End:

