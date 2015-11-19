@; -*- mode:scribble; coding: utf-8 -*-

@subsection[:tag "lib.sagittarius.generators"]{(sagittarius generators) - Generators}

@define[Library]{@name{(sagittarius generators)}}
@desc{This library provides procedures for generator.

@; From SRFI-121 Abstract
A generator is simply a procedure with no arguments that works as a source
of a series of values. Every time it is called, it yields a value. Generators
may be finite or infinite; a finite generator returns an EOF object to 
indicate that it is exhausted. For example, read-char is a generator that
generates characters from the current input port. Generators provide 
lightweight laziness. 
}


@subsubsection{Generator constructors}

The following procedures creates a generator. Except @code{null-generator},
all procedures have prefix @code{'g'}. Arguments named @var{generator}
indicates a generator.

@define[Function]{@name{null-generator}}
@desc{Returns a generator which always returns EOF object.}

@define[Function]{@name{gcons*} @args{object ... generator}}
@desc{Returns a generator which adds @var{object}s in front of @var{generator}.
}

@define[Function]{@name{gappend} @args{generator ...}}
@desc{Returns a generator which yields values from the first @var{generator}
and when it's exhausted continues to next.
}

@define[Function]{@name{gcombine} @args{proc seed generator generators ...}}
@desc{Returns a generator for mapping with state. It yields a sequence of 
sub-folds over @var{proc}. 

The @var{proc} argument is a procedure which takes as many arguments as 
the input generators plus one. It is called as 
@code{(@var{proc} @var{v1} @var{v2} ... @var{seed})}, where 
@var{v1}, @var{v2},@code{...} are the values yielded from the input 
generators, and @var{seed} is the current seed value. It must return two
values, the yielding value and the next seed. 
}

@define[Function]{@name{gfilter} @args{pred generator}}
@define[Function]{@name{gremove} @args{pred generator}}
@desc{Return generators which yield the items from the source generator, 
except those on which @var{pred} returns false or true respectively. 
}

@define[Function]{@name{gtake} @args{generator k :optional padding}}
@define[Function]{@name{gdrop} @args{generator k}}
@desc{Return generators which take or drop @var{k} items from @var{generator},
respectively. Returning generators won't raise errors when it's exhausted
before reaching @var{k}.

Optional argument @var{padding} for @code{gtake} is passed, then the value
is filled until the procedure reaches @var{k}.

These procedures are analogues of SRFI-1 @code{take} and @code{drop}.
}

@define[Function]{@name{gtake-while} @args{generator pred}}
@define[Function]{@name{gdrop-while} @args{generator pred}}
@desc{Return generators which take or drop until procedure @var{pred} returns
false value respectively.

These procedures are analogues of SRFI-1 @code{take-while} 
and @code{drop-while}.
}

