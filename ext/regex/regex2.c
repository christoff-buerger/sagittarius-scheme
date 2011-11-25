/* regex2.c                                               -*- coding: utf-8; -*-
 *
 *   Copyright (c) 2010-2011  Takashi Kato <ktakashi@ymail.com>
 *
 *   Redistribution and use in source and binary forms, with or without
 *   modification, are permitted provided that the following conditions
 *   are met:
 *
 *   1. Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *
 *   2. Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 *   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 *   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 *   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 *   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 *   TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 *   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 *   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 *   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 *   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *  $Id: $
 */
#include <string.h>
#include <ctype.h>
#include "regex2.h"
#include <sagittarius/extend.h>

#define DEBUG_REGEX 1

static SgSymbol *consant_symbol_table[39] = {NULL};

#define SYM_ALTER           	  	   (consant_symbol_table[0])
#define SYM_NON_GREEDY_REP  	  	   (consant_symbol_table[1])
#define SYM_GREEDY_REP      	  	   (consant_symbol_table[2])
#define SYM_CLOSE_PAREN     	  	   (consant_symbol_table[3])
#define SYM_VERTICAL_BAR    	  	   (consant_symbol_table[4])
#define SYM_QUESTION_MARK   	  	   (consant_symbol_table[5])
#define SYM_EVERYTHING      	  	   (consant_symbol_table[6])
#define SYM_END_ANCHOR      	  	   (consant_symbol_table[7])
#define SYM_INVERTED_CHAR_CLASS   	   (consant_symbol_table[8])
#define SYM_MODELESS_START_ANCHOR 	   (consant_symbol_table[9])
#define SYM_MODELESS_END_ANCHOR   	   (consant_symbol_table[10])
#define SYM_MODELESS_END_ANCHOR_NO_NEWLINE (consant_symbol_table[11])
#define SYM_START_ANCHOR      		   (consant_symbol_table[12])
#define SYM_BACKREF           		   (consant_symbol_table[13])
#define SYM_WORD_BOUNDARY     		   (consant_symbol_table[14])
#define SYM_NON_WORD_BOUNDARY 		   (consant_symbol_table[15])
#define SYM_BRANCH             		   (consant_symbol_table[16])
#define SYM_FLAGS              		   (consant_symbol_table[17])
#define SYM_OPEN_PAREN         		   (consant_symbol_table[18])
#define SYM_OPEN_PAREN_PAREN   		   (consant_symbol_table[19])
#define SYM_OPEN_PAREN_GREATER 		   (consant_symbol_table[20])
#define SYM_OPEN_PAREN_EQUAL 		   (consant_symbol_table[21])
#define SYM_OPEN_PAREN_LESS_EXCLAMATION    (consant_symbol_table[22])
#define SYM_OPEN_PAREN_COLON 	   	   (consant_symbol_table[23])
#define SYM_OPEN_PAREN_EXCLAMATION 	   (consant_symbol_table[24])
#define SYM_OPEN_PAREN_LESS_LETTER 	   (consant_symbol_table[25])
#define SYM_REGISTER   		  	   (consant_symbol_table[26])
#define SYM_STANDALONE 		  	   (consant_symbol_table[27])
#define SYM_LOOKAHEAD  		  	   (consant_symbol_table[28])
#define SYM_OPEN_PAREN_LESS_EQUAL 	   (consant_symbol_table[29])
#define SYM_CASE_INSENSITIVE 		   (consant_symbol_table[30])
#define SYM_CASE_SENSITIVE   		   (consant_symbol_table[31])
#define SYM_MULTI_LINE_MODE  		   (consant_symbol_table[32])
#define SYM_NOT_MULTI_LINE_MODE 	   (consant_symbol_table[33])
#define SYM_SINGLE_LINE_MODE 	 	   (consant_symbol_table[34])
#define SYM_NOT_SINGLE_LINE_MODE 	   (consant_symbol_table[35])
#define SYM_SEQUENCE  	    	 	   (consant_symbol_table[36])
#define SYM_LOOKBHIND 	    	 	   (consant_symbol_table[37])
#define SYM_FLAGED_SEQUENCE 	 	   (consant_symbol_table[38])

/* convenient macros */
#define has(p, f) (((p)->flags & (f)) != 0)

/* lexer_ctx_t is used to hold the regex string which is currently
   lexed and to keep track of the lexer's state.
*/
typedef struct lexer_ctx_rec_t
{
  SgChar *str;
  SgChar *ostr;			/* original string for error message */
  int     len;
  int     reg;
  int     pos;
  SgObject last_pos;
  int     flags;
  int     reg_num;
  SgObject reg_names;
} lexer_ctx_t;

/* convenient macro */
/* we don't use vm.h's PUSH and POP here */
#ifdef PUSH
# undef PUSH
#endif
#ifdef POP
# undef POP
#endif
#define PUSH(v, l) ((l) = Sg_Cons((v), (l)))
#define POP(l)     ((l) = SG_CDR(l))

static void remove_qe_quoting(lexer_ctx_t *ctx)
{
  const int plen = ctx->len;
  int i = 0, j, inQuote = TRUE;
  SgChar *newtemp;
  while (i < plen - 1) {
    if (ctx->str[i] != '\\') i += 1;
    else if (ctx->str[i+1] != 'Q') i += 2;
    else break;
  }
  if (i >= plen - 1) return;	/* no \Q sequence found */
  j = i;
  i += 2;
  newtemp = SG_NEW_ATOMIC2(SgChar *, sizeof(SgChar)*(j+2*(plen-i)+2));
  memcpy(newtemp, ctx->str, j*sizeof(SgChar));
  while (i < plen) {
    SgChar c = ctx->str[i++];
    if (!isascii(c) || isalnum(c)) {
      newtemp[j++] = c;
    } else if (c != '\\') {
      if (inQuote) newtemp[j++] = '\\';
      newtemp[j++] = c;
    } else if (inQuote) {
      if (ctx->str[i] == 'E') {
	i++;
	inQuote = FALSE;
      } else {
	newtemp[j++] = '\\';
	newtemp[j++] = '\\';
      }
    } else {
      if (ctx->str[i] == 'Q') {
	i++;
	inQuote = TRUE;
      } else {
	newtemp[j++] = c;
	if (i != plen) newtemp[j++] = ctx->str[i++];
      }
    }
  }
  ctx->len = j;
  ctx->str = SG_NEW_ATOMIC2(SgChar *, sizeof(SgChar)*j);
  memcpy(ctx->str, newtemp, sizeof(SgChar)*j);
  newtemp = NULL;		/* gc friendliness */
}

static void init_lexer(lexer_ctx_t *ctx, SgString *str, int flags)
{
  ctx->ostr = ctx->str = SG_STRING_VALUE(str);
  ctx->len = SG_STRING_SIZE(str);
  ctx->reg = ctx->pos = 0;
  ctx->last_pos = SG_NIL;
  ctx->flags = flags;
  ctx->reg_num = 1;		/* 0 is the whole matched string */
  ctx->reg_names = SG_NIL;
  if (!has(ctx, SG_LITERAL)) {
    /* remove \Q \E quoting now */
    remove_qe_quoting(ctx);
  }
}

/* error */
static void raise_syntax_error(lexer_ctx_t *ctx, int pos, const SgChar *str)
{
  /* TODO create regex parser error or so */
  Sg_Error(UC("bad regex syntax in %s: %s, [posision %d]"),
	   ctx->ostr, str, pos);
}

/* null sequence */
static SgObject null_seq()
{
  return SG_LIST1(SYM_SEQUENCE);
}

/* lexer functions */
/*
  Tests whether we're at the end of the regex string
 */
#define END_OF_STRING_P(ctx) ((ctx)->len <= (ctx)->pos)
/*
  Tests whether we're at the end of the regex string
 */
#define LOOKING_AT_P(ctx, c) (!END_OF_STRING_P(ctx) && c == ctx->str[ctx->pos])

static SgObject get_number(lexer_ctx_t *ctx, int radix, int maxlen,
			   int nowhilespace);
static SgChar next_char(lexer_ctx_t *ctx);
static SgChar next_char_non_extended(lexer_ctx_t *ctx);
/* 
   Create character from char-code number. number can be #f
   which is interpreted as 0. error-pos is the position where
   the corresponding number started within the regex string.
 */
static SgObject make_char_from_code(lexer_ctx_t *ctx, SgObject number,
				    int error_pos)
{
  int code;
  if (SG_FALSEP(number)) code = 0;
  else {
    /* only look at right most eight bits in compliance with Perl */
    code = 0xFF & SG_INT_VALUE(number);
  }
  if (code <= SG_CHAR_MAX) return SG_MAKE_CHAR(code);
  raise_syntax_error(ctx, error_pos,
		     UC("No character of given code"));
  return SG_UNDEF;		/* dummy */
}

/* 
   Convert the characters(s) following a backslash into a token
   which is returned. This function is to be called when the backslash
   has already been consumed. Special character classes like \\W are
   handled elsewhere.
 */
static SgObject unescape_char(lexer_ctx_t *ctx)
{
  SgChar chr, nc;
  int error_pos;
  SgObject n;
  if (END_OF_STRING_P(ctx)) {
    raise_syntax_error(ctx, -1, UC("String ends with backslash."));
  }
  chr = next_char_non_extended(ctx);
  switch (chr) {
    /* it's already resolved. */
    /* case 'E': return SYM_VOID; */
  case 'c':
    /* \cx means control-x in Perl */
    nc = next_char_non_extended(ctx);
    if (nc == EOF) {
      raise_syntax_error(ctx, ctx->pos,
			 UC("Character missing after '\\c'."));
    }
    return SG_MAKE_CHAR(Sg_CharUpCase(nc) | 0x40);
  case 'x':
    /* \x should be followed by hexadecimal char code, two digis or less */
    error_pos = --ctx->pos;
    n = get_number(ctx, 16, 2, TRUE);
    return make_char_from_code(ctx, n, error_pos);
  case '0': case '1': case '2': case '3': case '4':
  case '5': case '6': case '7': case '8': case '9':
    error_pos = --ctx->pos;
    n = get_number(ctx, 8, 3, FALSE);
    return make_char_from_code(ctx, n, error_pos);
  case 't': return SG_MAKE_CHAR('\t');
  case 'n': return SG_MAKE_CHAR('\n');
  case 'r': return SG_MAKE_CHAR('\r');
  case 'f': return SG_MAKE_CHAR('\f');
  case 'b': return SG_MAKE_CHAR('\b');
  case 'a': return SG_MAKE_CHAR(0x07);
  case 'e': return SG_MAKE_CHAR(0x27);
  default:
    return SG_MAKE_CHAR(chr);
  }
}

/* I forgot to make ustrchr in unicode.c */
static int ustrchr(const SgChar *str, SgChar c, int len)
{
  int i;
  for (i = 0; i < len; i++, str++) {
    if (*str == c) return i;
  }
  return -1;
}

/*
  Returns the next character which is to be examined and updates the pos.
  Does not respect extended mode.
 */
static SgChar next_char_non_extended(lexer_ctx_t *ctx)
{
  if (END_OF_STRING_P(ctx)) return EOF;
  return ctx->str[ctx->pos++];
}

/*
  Returns the next character which is to be examined and updates the pos.
  Respects extended mode, i.e. white spece, comments, and also nested comments
  are skipped if applicable.
 */
static SgChar next_char(lexer_ctx_t *ctx)
{
  SgChar nc = next_char_non_extended(ctx);
  int last_pos;
  while (1) {
    last_pos = ctx->pos;
    if (nc != EOF && nc == '(' && LOOKING_AT_P(ctx, '?')) {
      ctx->pos++;
      if (LOOKING_AT_P(ctx, '#')) {
	/* "(?#" must be a nested comment - so we have to search for the
	   closing parenthesis
	*/
	int error_pos = ctx->pos - 2;
	SgChar skip_char = nc;
	while (skip_char != EOF && skip_char != ')') {
	  skip_char = next_char_non_extended(ctx);
	  if (skip_char == EOF) {
	    raise_syntax_error(ctx, error_pos,
			       UC("Comment group not closed"));
	  }
	}
	nc = next_char_non_extended(ctx);
      } else {
	/* undo */
	ctx->pos--;
      }
    }
    if (has(ctx, SG_COMMENTS)) {
      /* now - if we're in extended mode - we skip whitespace and comments;
	 repeat the following loop while we look at whitespace or #\#
       */
      while (nc != EOF && (nc == '#' || Sg_Ucs4WhiteSpaceP(nc))) {
	if (nc == '#') {
	  /* if we saw a comment marker skip util we're behinf \n */
	  SgChar skip_char = nc;
	  while(skip_char != EOF && skip_char != '\n') {
	    skip_char = next_char_non_extended(ctx);
	  }
	  nc = next_char_non_extended(ctx);
	} else {
	  /* ...otherwise (whitespace) skip until we see the next
	     non-whitespace character
	   */
	  SgChar skip_char = nc;
	  while (skip_char != EOF && Sg_Ucs4WhiteSpaceP(skip_char)) {
	    skip_char = next_char_non_extended(ctx);
	  }
	  nc = skip_char;
	}
      }
    }
    /*
      if the position has moved we have to repeat out tests because of cases
      like /^a (?#xxx) (?#yyy) {3}c/x 
     */
    if (ctx->pos <= last_pos) {
      return nc;
    }
  }
}
/* 
   Tests whether the next token can start a valid sub-expression, i.e. a
   stand-alone regex
 */
static int start_of_subexpr_p(lexer_ctx_t *ctx)
{
  int pos = ctx->pos;
  SgChar nc = next_char(ctx);
  if (nc == EOF) return FALSE;
  /* rest position */
  ctx->pos = pos;
  return !(nc == ')' || nc == '|');
}

static SgObject read_char_property(lexer_ctx_t *ctx, SgChar first)
{
  if (next_char_non_extended(ctx) != '{') {
    /* one letter property */
    /* well, what shall we do with one letter property? just a character */
    ctx->pos--;
    return SG_MAKE_CHAR(first);
  } else {
    /* a bit tricky. char property must start with 'In' or 'Is'. I have no idea
       what the difference is. So for now we treat both the same.
     */
    SgObject es;
    SgGloc *gloc;
    int pos;
    /* first check the property has 'Is' or 'In. */
    if (ctx->len-ctx->pos <= 2 ||
	!(ctx->str[ctx->pos] == 'I' &&
	  (ctx->str[ctx->pos + 1] == 's' || ctx->str[ctx->pos + 1] == 'n'))) {
      raise_syntax_error(ctx, ctx->pos,
			 UC("Invalid character property name."));
    }

    pos = ustrchr(ctx->str+ctx->pos+2, '}', ctx->len-ctx->pos-2);
    if (pos == -1) {
      /* no closing '}' */
      raise_syntax_error(ctx, ctx->pos,
			 UC("Character property does not have '}'"));
    }
    /* we convert property name with prefix 'char-set:' then we can look up
       from builtin charset.
     */
    /* does not seem smart solution ... */
    es = Sg_MakeString(UC("char-set:"), SG_LITERAL_STRING);
    es = Sg_StringAppendC(SG_STRING(es), ctx->str+ctx->pos+2, pos);
    es = Sg_StringDownCase(es);
    gloc = Sg_FindBinding(Sg_VM()->currentLibrary, Sg_Intern(es), SG_FALSE);
    if (SG_FALSEP(gloc) || !SG_CHAR_SET_P(SG_GLOC_GET(gloc))) {
      raise_syntax_error(ctx, ctx->pos,
			 UC("Given character property is not supported"));
    }
    ctx->pos += pos+3;
    return SG_GLOC_GET(gloc);
  }
}

/* I'm not sure if this one should be in charset.c */
static int digit_to_int(SgChar ch, int radix)
{
  if (ch < '0') return -1;
  if (radix <= 10) {
    if (ch < '0' + radix) return ch - '0';
  } else {
    if (ch <= '9') return ch - '0';
    if (ch < 'A') return -1;
    if (ch < 'A' + radix - 10) return ch - 'A' + 10;
    if (ch < 'a') return -1;
    if (ch < 'a' + radix - 10) return ch - 'a' + 10;
  }
  return -1;
}

static SgChar read_xdigit(lexer_ctx_t *ctx, int ndigits,
			  char *buf, int *nread)
{
  int i, c, val = 0, dig;
  for (i = 0; i < ndigits; i++) {
    c = next_char_non_extended(ctx);
    if (c == EOF) break;
    dig = digit_to_int(c, 16);
    if (dig < 0) {
      ctx->pos--;
      break;
    }
    buf[i] = (char)c;
    val = val * 16 + dig;
  }
  *nread = i;
  if (i < ndigits) return -1;
  return (SgChar)val;
}

static SgChar read_charset_xdigits(lexer_ctx_t *ctx, int ndigs, int key)
{
  char buf[8];			/* max 8 */
  int nread;
  SgChar r;
  ASSERT(ndigs <= 8);
  r = read_xdigit(ctx, ndigs, buf, &nread);
  if (r == -1) {
    raise_syntax_error(ctx, ctx->pos,
		       UC("Character class contains invalid escaped character")
		       );
  }
  return r;
}

static SgObject read_defined_charset(lexer_ctx_t *ctx)
{
  /* almost the same as read_char_property.
  */
  SgObject es;
  SgGloc *gloc;
  int pos;
  /* first check the property has 'Is' or 'In. */
  if (ctx->len-ctx->pos < 2 ||
      ctx->str[0] != ':') {
    raise_syntax_error(ctx, ctx->pos,
		       UC("Invalid character set name."));
  }
  /* skip first ':' */
  pos = ustrchr(ctx->str+ctx->pos+1, ':', ctx->len - ctx->pos-1);
  if (pos == -1) {
    /* no closing ':' */
    raise_syntax_error(ctx, ctx->pos,
		       UC("Invalid charset name. You forgot ':'"));
  }
  /* we convert property name with prefix 'char-set:' then we can look up
     from builtin charset.
  */
  /* does not seem smart solution ... */
  es = Sg_MakeEmptyString();
  /* including ':' */
  es = Sg_StringAppendC(SG_STRING(es), ctx->str+ctx->pos, pos+1);
  gloc = Sg_FindBinding(Sg_VM()->currentLibrary, Sg_Intern(es), SG_FALSE);
  if (SG_FALSEP(gloc) || !SG_CHAR_SET_P(SG_GLOC_GET(gloc))) {
    raise_syntax_error(ctx, ctx->pos,
		       UC("Given character set is not supported"));
  }
  ctx->pos += pos;
  return SG_GLOC_GET(gloc);
}

static SgObject read_char_set(lexer_ctx_t *ctx, int *complement_p)
{
#define REAL_BEGIN 1
#define CARET_BEGIN 2
  int begin = REAL_BEGIN, complement = FALSE;
  int lastchar = -1, inrange = FALSE, moreset_complement = FALSE;
  SgCharSet *set = SG_CHAR_SET(Sg_MakeEmptyCharSet());
  SgObject moreset;
  SgObject chars = SG_NIL;
  SgChar ch = 0;

  for (;;) {
    ch = next_char_non_extended(ctx);
    if (ch == EOF) goto err;
    chars = Sg_Cons(SG_MAKE_CHAR(ch), chars);
    if (begin == REAL_BEGIN && ch == '^') {
      complement = TRUE;
      begin = CARET_BEGIN;
      continue;
    }
    if (begin && ch == ']') {
      Sg_CharSetAddRange(set, ch, ch);
      lastchar = ch;
      begin = FALSE;
      continue;
    }
    begin = FALSE;
    switch (ch) {
    case '-':
      if (inrange) goto ordchar;
      inrange = TRUE;
      continue;
    case ']':
      if (inrange) {
	if (lastchar >= 0) {
	  Sg_CharSetAddRange(set, lastchar, lastchar);
	  Sg_CharSetAddRange(set, '-', '-');
	} else {
	  Sg_CharSetAddRange(set, '-', '-');
	}
      }
      break;
    case '\\':
      ch = next_char_non_extended(ctx);
      if (ch == EOF) goto err;
      chars = Sg_Cons(SG_MAKE_CHAR(ch), chars);
      switch (ch) {
      case 'a': ch = 7; goto ordchar;
      case 'b': ch = 8; goto ordchar;
      case 'n': ch = '\n'; goto ordchar;
      case 'r': ch = '\r'; goto ordchar;
      case 't': ch = '\t'; goto ordchar;
      case 'f': ch = '\f'; goto ordchar;
      case 'e': ch = 0x1b; goto ordchar;
      case 'x':
	ch = read_charset_xdigits(ctx, 2, 'x'); goto ordchar;
      case 'u':
	ch = read_charset_xdigits(ctx, 4, 'u'); goto ordchar;
      case 'U':
	ch = read_charset_xdigits(ctx, 8, 'u'); goto ordchar;
      case 'd':
	moreset_complement = FALSE;
	moreset = Sg_GetStandardCharSet(SG_CHAR_SET_DIGIT);
	break;
      case 'D':
	moreset_complement = TRUE;
	moreset = Sg_GetStandardCharSet(SG_CHAR_SET_DIGIT);
	break;
      case 's':
	moreset_complement = FALSE;
	moreset = Sg_GetStandardCharSet(SG_CHAR_SET_SPACE);
	break;
      case 'S':
	moreset_complement = TRUE;
	moreset = Sg_GetStandardCharSet(SG_CHAR_SET_SPACE);
	break;
      case 'w':
	moreset_complement = FALSE;
	moreset = Sg_GetStandardCharSet(SG_CHAR_SET_WORD);
	break;
      case 'W':
	moreset_complement = TRUE;
	moreset = Sg_GetStandardCharSet(SG_CHAR_SET_WORD);
	break;
      case 'p':
	moreset_complement = FALSE;
	moreset = read_char_property(ctx, ch);
	break;
      case 'P':
	moreset_complement = TRUE;
	moreset = read_char_property(ctx, ch);
	break;
      default: goto ordchar;
      }
      if (moreset_complement) {
	moreset = SG_CHAR_SET(Sg_CharSetComplement(SG_CHAR_SET(Sg_CharSetCopy(moreset))));
      }
      Sg_CharSetAdd(set, SG_CHAR_SET(moreset));
      continue;
    case '[':
      moreset = read_defined_charset(ctx);
      if (!SG_CHAR_SET_P(moreset)) goto err;
      Sg_CharSetAdd(set, SG_CHAR_SET(moreset));
      continue;
    ordchar:
    default:
      if (inrange) {
	if (lastchar < 0) {
	  Sg_CharSetAddRange(set, '-', '-');
	  Sg_CharSetAddRange(set, ch, ch);
	  lastchar = ch;
	} else {
	  Sg_CharSetAddRange(set, lastchar, ch);
	  lastchar = -1;
	}
	inrange = FALSE;
      } else {
	Sg_CharSetAddRange(set, ch, ch);
	lastchar = ch;
      }
      continue;
    }
    break;
  }
  if (complement_p) {
    *complement_p = complement;
    return SG_OBJ(set);
  } else {
    if (complement) Sg_CharSetComplement(set);
    return SG_OBJ(set);
  }

 err:
  return SG_FALSE;
}

static void unget_token(lexer_ctx_t *ctx)
{
  if (SG_NULLP(ctx->last_pos)) {
    Sg_Error(UC("[internal error] No token to unget."));
  }
  ctx->pos = SG_INT_VALUE(SG_CAR(ctx->last_pos));
  POP(ctx->last_pos);
}

static SgObject fail(lexer_ctx_t *ctx)
{
  if (SG_NULLP(ctx->last_pos)) {
    raise_syntax_error(ctx, -1,
		       UC("last-pos stack of lexer is empty"));
  }
  ctx->pos = SG_INT_VALUE(SG_CAR(ctx->last_pos));
  POP(ctx->last_pos);
  return SG_FALSE;
}

static SgObject get_number(lexer_ctx_t *ctx, int radix, int maxlen,
			   int nowhilespace)
{
  int i, size = ctx->len - ctx->pos, end, n = 0;
  if (nowhilespace &&
      Sg_Ucs4WhiteSpaceP(ctx->str[ctx->pos])) {
    return SG_FALSE;
  }
  if (maxlen > 0) {
    int end_pos = ctx->pos + maxlen;
    if (end_pos < size) end = end_pos;
    else end = size;
  } else {
    end = size;
  }
  for (i = 0; i < end; i++) {
    if ((radix == 10 && isdigit(ctx->str[ctx->pos + i])) ||
	(radix == 16 && isxdigit(ctx->str[ctx->pos + i]))) {
      n = n*i*radix + digit_to_int(ctx->str[ctx->pos + i], radix);
    } else {
      if (i == 0) n = -1;
      /* something else is here */
      break;
    }
  }

  if (n != -1) {
    /* saniti */
    ctx->pos += i;
    return SG_MAKE_INT(n);
  } else {
    return SG_FALSE;
  }
}

static SgObject try_number(lexer_ctx_t *ctx, int radix, int maxlen,
			   int nowhilespace)
{
  SgObject n;
  PUSH(SG_MAKE_INT(ctx->pos), ctx->last_pos);
  n = get_number(ctx, radix, maxlen, nowhilespace);
  if (SG_FALSEP(n)) return fail(ctx);
  return n;
}

/*
  Reads a sequence of modifiers (including #\\- to reverse their
  meaning) and returns a corresponding list of "flag" tokens.
 */
static SgObject maybe_parse_flags(lexer_ctx_t *ctx)
{
  SgChar c = next_char_non_extended(ctx);
  SgObject h = SG_NIL, t = SG_NIL;
  int set = TRUE;
  while (1) {
    switch (c) {
    case '-':
      set = FALSE;
      break;
    case 'x':
      if (set) {
	ctx->flags |= SG_COMMENTS;
      } else {
	ctx->flags &= ~SG_COMMENTS;
      }
      break;
    case 'i':
      if (set) {
	ctx->flags |= SG_CASE_INSENSITIVE;
	SG_APPEND1(h, t, Sg_Cons(SG_MAKE_CHAR(c), SG_TRUE));
      } else {
	ctx->flags &= ~SG_CASE_INSENSITIVE;
	SG_APPEND1(h, t, Sg_Cons(SG_MAKE_CHAR(c), SG_FALSE));
      }
      break;
    case 'm':
      if (set) {
	ctx->flags |= SG_MULTILINE;
	SG_APPEND1(h, t, Sg_Cons(SG_MAKE_CHAR(c), SG_TRUE));
      } else {
	ctx->flags &= ~SG_MULTILINE;
	SG_APPEND1(h, t, Sg_Cons(SG_MAKE_CHAR(c), SG_FALSE));
      }
      break;
    case 's':
      if (set) {
	ctx->flags |= SG_DOTALL;
	SG_APPEND1(h, t, Sg_Cons(SG_MAKE_CHAR(c), SG_TRUE));
      } else {
	ctx->flags &= ~SG_DOTALL;
	SG_APPEND1(h, t, Sg_Cons(SG_MAKE_CHAR(c), SG_FALSE));
      }
      break;
    default: goto end;
    }
    c = next_char_non_extended(ctx);
  }
 end:
  ctx->pos--;
  return h;
}

/*
  Returns a list of two values (min max) if what the lexer is looking at can be
  interpreted as a quantifier. Otherwise returns #f and resets the lexer to its
  old position.
*/
static SgObject get_quantifier(lexer_ctx_t *ctx, int *standalone)
{
  SgChar nc;
  PUSH(SG_MAKE_INT(ctx->pos), ctx->last_pos);
  nc = next_char(ctx);
  switch (nc) {
  case '*': 
    return SG_LIST2(SG_MAKE_INT(0), SG_FALSE); /* 0 or more times */
  case '+':
    return SG_LIST2(SG_MAKE_INT(1), SG_FALSE); /*  1 or more times */
  case '?':
    return SG_LIST2(SG_MAKE_INT(0), SG_MAKE_INT(1)); /* 0 or 1 */
  case '{':
    /* one of
       {n}:   match exactly n times
       {n,}:  match at least n times
       {n,m}: match at least n but not more than m times
       Note: anything not matching one of these patterns will be interpreted
             literally - even whitespace isn't allowed.
     */
    {
      SgObject num1 = get_number(ctx, 10, -1, TRUE), num2;
      if (SG_FALSEP(num1)) {
	/* no number following left curly brace, so we treat it like a normal
	   character*/
	return fail(ctx);
      } else {
	nc = next_char_non_extended(ctx);
	switch (nc) {
	case ',': 
	  num2 = get_number(ctx, 10, -1, TRUE);
	  nc = next_char_non_extended(ctx);
	  switch (nc) {
	  case '}': return SG_LIST2(num1, num2); /* {n,} or {n,m} */
	  default: return fail(ctx);
	  }
	case '}': return SG_LIST2(num1, num1); /* {n} */
	default: return fail(ctx);
	}
      }
    }
  default: return fail(ctx);
  }
}
/* 
   Reads and returns the name in a named register group. It is assumed that the
   starting #\< character has already been read. The closing #\> will also be
   consumed.
 */
static SgObject parse_register_name_aux(lexer_ctx_t *ctx)
{
  /* we have to look for an ending > character now */
  int end_name = ustrchr(ctx->str+ctx->pos, '>', ctx->len-ctx->pos), i;
  SgObject s;
  if (end_name < 0) {
    raise_syntax_error(ctx, ctx->pos - 1,
		       UC("Opening #\\< in named group has no closing #\\>."));
  }
  s = Sg_ReserveString(end_name, 0);
  for (i = 0; i < end_name; i++) {
    SgChar c = ctx->str[ctx->pos + i];
    if (isalnum(c) || c == '-') {
      SG_STRING_VALUE_AT(s, i) = c;
    } else {
      raise_syntax_error(ctx, ctx->pos,
			 UC("Invalid character in named register group."));
    }
  }
  /* advance lexer beyond "<name>" part */
  ctx->pos += i + 1;
  return s;
}


/* 
   Returns and consumes the next token from the regex string or '#f
 */
static SgObject get_token(lexer_ctx_t *ctx, SgObject *ret)
{
  SgChar nc;
  PUSH(SG_MAKE_INT(ctx->pos), ctx->last_pos);
  nc = next_char(ctx);
  if (nc != EOF) {
    switch (nc) {
      /* the each cases first - the following six characters always have a
	 special meaning and get translated into tokens immediately
       */
    case ')': return SYM_CLOSE_PAREN;
    case '|':
      /* as far as I know I've never seen this pattern, and this must be
         error.*/
      raise_syntax_error(ctx, SG_INT_VALUE(SG_CAR(ctx->last_pos)),
			 UC("Please report this regex to the developper."));
      return SG_UNDEF;		/* dummy */
      /* return SYM_VERTICAL_BAR; */
    case '?':
      /* well this question mark must be error.
	 or should this be literal character?
       */
      /* return SYM_QUESTION_MARK; */
      raise_syntax_error(ctx, SG_INT_VALUE(SG_CAR(ctx->last_pos)),
			 UC("Quantifier('?') follows nothing in regex."));
      return SG_UNDEF;		/* dummy */
    case '.': return SYM_EVERYTHING;
    case '^': return SYM_START_ANCHOR;
    case '$': return SYM_END_ANCHOR;
    case '+': case '*':
      /* quantifiers will always be consumed by get_quantifier, they must not
	 appear here */
      raise_syntax_error(ctx, ctx->pos - 1,
			 UC("Quanrifier '+' or '*' not allowed."));
      return SG_FALSE;		/* dummy */
    case '{':
      /* left brace isn't a special character in it's own right but we must
	 check if what follows might look like a quantifier.*/
      {
	int here = ctx->pos;
	SgObject last = ctx->last_pos;
	unget_token(ctx);
	if (!SG_FALSEP(get_quantifier(ctx, NULL))) {
	  raise_syntax_error(ctx, SG_INT_VALUE(SG_CAR(last)),
			     UC("Quanrifier not allowed"));
	}
	ctx->pos = here;
	ctx->last_pos = last;
	return SG_MAKE_CHAR(nc);
      }
    case '[':
      /* left bracket always starts */
      {
	int comp = FALSE;
	SgObject cs = read_char_set(ctx, &comp);
	if (comp) {
	  return SG_LIST2(SYM_INVERTED_CHAR_CLASS, cs);
	} else {
	  return cs;
	}
      }
    case '\\':
      /* backslash might mean different things so we have to peek one char
	 ahead */
      nc = next_char_non_extended(ctx);
      switch (nc) {
      case 'A': return SYM_MODELESS_START_ANCHOR;
      case 'Z': return SYM_MODELESS_END_ANCHOR;
      case 'z': return SYM_MODELESS_END_ANCHOR_NO_NEWLINE;
      case 'b': return SYM_WORD_BOUNDARY;
      case 'B': return SYM_NON_WORD_BOUNDARY;
      case 'k': 
	if (LOOKING_AT_P(ctx, '<')) {
	  SgObject name, names, cp, num = SG_FALSE;
	  int pos = ctx->pos - 2;
	  ctx->pos++;
	  name = parse_register_name_aux(ctx);
	  /* search backref name from context */
	  names = ctx->reg_names;
	  SG_FOR_EACH(cp, names) {
	    /* slot: ("name" . num) */
	    SgObject slot = SG_CAR(cp);
	    if (Sg_StringEqual(SG_CAR(slot), name)) {
	      num = SG_CDR(slot);
	      break;
	    }
	  }
	  if (SG_FALSEP(num)) {
	    raise_syntax_error(ctx, pos,
			       UC("Non defined named register is refered."));
	  }
	  return SG_LIST2(SYM_BACKREF, num);	
	} else{
	  return SG_MAKE_CHAR('k');
	}
      case 'd': return Sg_GetStandardCharSet(SG_CHAR_SET_DIGIT);
      case 'D': return SG_LIST2(SYM_INVERTED_CHAR_CLASS,
				Sg_GetStandardCharSet(SG_CHAR_SET_DIGIT));
      case 'w': return Sg_GetStandardCharSet(SG_CHAR_SET_WORD);
      case 'W': return SG_LIST2(SYM_INVERTED_CHAR_CLASS,
				Sg_GetStandardCharSet(SG_CHAR_SET_WORD));
      case 's': return Sg_GetStandardCharSet(SG_CHAR_SET_SPACE);
      case 'S': return SG_LIST2(SYM_INVERTED_CHAR_CLASS,
				Sg_GetStandardCharSet(SG_CHAR_SET_SPACE));
      case '1': case '2': case '3': case '4': case '5': 
      case '6': case '7': case '8': case '9': 
	{
	  int oldpos = --ctx->pos;
	  SgObject num = get_number(ctx, 10, -1, FALSE);
	  if (SG_INT_VALUE(num) > ctx->reg &&
	      10 <= SG_INT_VALUE(num)) {
	    /* \10 and higher are treaded as octal character codes if we haven't
	       opened that much register groups yet. */
	    ctx->pos = oldpos;
	    return make_char_from_code(ctx, 
				       get_number(ctx, 8, 3, FALSE), oldpos);
	  } else {
	    return SG_LIST2(SYM_BACKREF, num);
	  }
	}
      case '0':
	/* this always means an octal character code */
	{
	  int oldpos = --ctx->pos;
	  return make_char_from_code(ctx, get_number(ctx, 8, 3, FALSE), oldpos);
	}
      case 'P': case 'p':
	/* might be a named property */
	return read_char_property(ctx, nc);
      default:
	ctx->pos--;
	return unescape_char(ctx);
      }
    case '(':
      /* an open parenthesis might mean different thigs depending on what
	 follows... */
      if (LOOKING_AT_P(ctx, '?')) {
	/* this is the case '(?' (and probably more behind) */
	SgObject flags;
	ctx->pos++;
	flags = maybe_parse_flags(ctx);
	nc = next_char_non_extended(ctx);
	/* modifiers are only allowed if a colon or closing parenthesis are
	   following. */
	if (!SG_NULLP(flags) && !(nc == ':' || nc == ')')) {
	  raise_syntax_error(ctx, SG_INT_VALUE(SG_CAR(ctx->last_pos)),
			     UC("Sequence not recoginzed"));
	}
	switch (nc) {
	case EOF: raise_syntax_error(ctx, -1,
				     UC("End of string following '(?'."));
	case ')':
	  /* an empty group except for the flags */
	  if (!SG_NULLP(flags)) return Sg_Cons(SYM_FLAGS, flags);
	  return null_seq();
	/* branch */
	case '(': return SYM_OPEN_PAREN_PAREN;
	/* standalone */
	case '>': return SYM_OPEN_PAREN_GREATER;
	  /* positive look-ahead */
	case '=': return SYM_OPEN_PAREN_EQUAL;
	  /* negative look-ahead */
	case '!': return SYM_OPEN_PAREN_EXCLAMATION;
	case ':': 
	  /* non capturing group - return flags if it not NULL*/
	  if (ret) *ret = flags;
	  return SYM_OPEN_PAREN_COLON;
	case '<':
	  /* might be look-behing assertion or a named group, so check next */
	  nc = next_char_non_extended(ctx);
	  if (isalpha(nc)) {
	    /* we have encountered a named group. */
	    ctx->pos--;
	    return SYM_OPEN_PAREN_LESS_LETTER;
	  } else {
	    switch (nc) {
	    case '=': return SYM_OPEN_PAREN_LESS_EQUAL; /* positive */
	    case '!': return SYM_OPEN_PAREN_LESS_EXCLAMATION; /* negative */
	    case ')':
	      /* Perl allows "(?<" and treats it like a null string*/
	      return null_seq();
	    case EOF:
	      raise_syntax_error(ctx, -1, UC("End of string following '(?<'."));
	    default:
	      raise_syntax_error(ctx, ctx->pos -1,
				 UC("'(?<' is followed by illigal character."));
	    }
	  }
	default:
	  raise_syntax_error(ctx, ctx->pos -1,
			     UC("'(?' is followed by illigal character."));
	}
      } else {
	/* if nc was not '?' (this is within the first switch, we've just seen
	   an opening parenthesis and leave it like that*/
	return SYM_OPEN_PAREN;
      }
    default:
      /* all other characters are their onw tokens */
      return SG_MAKE_CHAR(nc);
    }
  } else {
    /* we didn't get a character (this if the "else" branch form the first if),
       so we don't return a token but #f.
     */
    POP(ctx->last_pos);
    return SG_FALSE;
  }
}

/* parser functions*/
static SgObject reg_expr(lexer_ctx_t *ctx);

/*
  Parses and consumes a <group>.
  The productions are: <group> -> "(" <regex> ")"
                                  "(?:" <regex> ")"
				  "(?>" <regex> ")"
				  "(?<flags>:" <regex> ")"
				  "(?=" <regex> ")"
				  "(?!" <regex> ")"
				  "(?<=" <regex> ")"
				  "(?<!" <regex> ")"
				  "(?(" <num> ")" <regex> ")"
				  "(?(" <regex> ")" <regex> ")"
				  "(?<name>" <regex> ")"
				  <legal-token>
  where <flags> is parsed by the lexer function MAYBE-PARSE-FLAGS.
  Will return <parse-tree> or (<grouping-type> <parse-tree>) where
  <grouping-type> is one of six keywords.
 */
static SgObject group(lexer_ctx_t *ctx)
{
  SgObject flags = SG_NIL;
  int save = ctx->flags;
  SgObject open_token = get_token(ctx, &flags);
  SgObject ret = SG_UNDEF;

  if (SG_EQ(open_token, SYM_OPEN_PAREN_PAREN)) {
    /* special case for conditional regular expression; not that at this point
       we accespt a couple of illegal combinations which'll be sorted out later
       by the converter
     */
    int open_paren_pos = SG_INT_VALUE(SG_CAR(ctx->last_pos));
    /* check if what follows "(?(" is a number*/
    SgObject number = try_number(ctx, 10, -1, TRUE);
    if (!SG_FALSEP(number)) {
      /* condition is a number (i.e refers to a back-reference */
      SgObject inner_close_token = get_token(ctx, NULL);
      SgObject regexpr = reg_expr(ctx);
      SgObject close_token = get_token(ctx, NULL);
      if (!SG_EQ(inner_close_token, SYM_CLOSE_PAREN)) {
	raise_syntax_error(ctx, open_paren_pos + 2,
			   UC("Opening paren has no matching closing paren"));
      }
      if (!SG_EQ(close_token, SYM_CLOSE_PAREN)) {
	raise_syntax_error(ctx, open_paren_pos,
			   UC("Opening paren has no matching closing paren"));
      }
      ret = SG_LIST3(SYM_BRANCH, number, regexpr);
      goto end_group;
    } else {
      /* condition must be a full regex (actually a look-behind or look-ahead);
	 and comes a terrible kludge: instead of being cleanly separated from
	 the lexer, the parser pushes back lexer by one position, thereby
	 landing in the middle of the 'token' "(?(".
       */
      SgObject inner_reg_expr, regexpr, close_token;
      ctx->pos--;
      inner_reg_expr = group(ctx);
      regexpr = reg_expr(ctx);
      close_token = get_token(ctx, NULL);
      if (!SG_EQ(close_token, SYM_CLOSE_PAREN)) {
	raise_syntax_error(ctx, open_paren_pos,
			   UC("Opening paren has no matching closing paren."));
      }
      if (!(SG_PAIRP(inner_reg_expr) &&
	    (SG_EQ(SG_CAR(inner_reg_expr), SYM_LOOKBHIND) ||
	     SG_EQ(SG_CAR(inner_reg_expr), SYM_LOOKAHEAD)))) {
	raise_syntax_error(ctx, open_paren_pos,
			   UC("Branch test must be lookahead, look-behind or number"));
      }
      ret = SG_LIST3(SYM_BRANCH, inner_reg_expr, regexpr);
      goto end_group;
    }

  } else if (SG_EQ(open_token, SYM_OPEN_PAREN) ||
	     SG_EQ(open_token, SYM_OPEN_PAREN_EQUAL) ||
	     SG_EQ(open_token, SYM_OPEN_PAREN_COLON) ||
	     SG_EQ(open_token, SYM_OPEN_PAREN_GREATER) ||
	     SG_EQ(open_token, SYM_OPEN_PAREN_EXCLAMATION) ||
	     SG_EQ(open_token, SYM_OPEN_PAREN_LESS_EQUAL) ||
	     SG_EQ(open_token, SYM_OPEN_PAREN_LESS_EXCLAMATION) ||
	     SG_EQ(open_token, SYM_OPEN_PAREN_LESS_LETTER)) {
    /* we saw one of the six token representing opening parentheses */
    int open_paren_pos = SG_INT_VALUE(SG_CAR(ctx->last_pos));
    SgObject register_name = (SG_EQ(open_token, SYM_OPEN_PAREN_LESS_LETTER))
      ? parse_register_name_aux(ctx) : SG_FALSE;
    SgObject regexpr = reg_expr(ctx);
    SgObject close_token = get_token(ctx, NULL);
    if (SG_EQ(open_token, SYM_OPEN_PAREN) ||
	SG_EQ(open_token, SYM_OPEN_PAREN_LESS_LETTER)) {
      /* if this is the "(" <regex> ")" or "(?" <name> "" <regex> ")" production
	 we have to increment the register counter of the lexer
       */
      ctx->reg++;
    }
    if (!SG_EQ(close_token, SYM_CLOSE_PAREN)) {
      raise_syntax_error(ctx, open_paren_pos,
			 UC("Opening paren has no matching closing paren."));
    }
    if (!SG_NULLP(flags)) {
      /* if the lexer has returned a list of flags this must have been the
	 "(?:" <regex> ")" production
       */
      ret = SG_LIST3(SYM_FLAGED_SEQUENCE, flags, regexpr);
      goto end_group;
    } else {
      if (SG_EQ(open_token, SYM_OPEN_PAREN_LESS_LETTER)) {
	/* make alist */
	PUSH(Sg_Cons(register_name, SG_MAKE_INT(ctx->reg_num)),
	     ctx->reg_names);
	ret = SG_LIST4(SYM_REGISTER,
		       SG_MAKE_INT(ctx->reg_num++),
		       register_name,
		       regexpr);
	goto end_group;
      } else {
	if (SG_EQ(open_token, SYM_OPEN_PAREN)) {
	  ret = SG_LIST4(SYM_REGISTER, SG_MAKE_INT(ctx->reg_num++),
			 SG_FALSE, regexpr);
	} else if (SG_EQ(open_token, SYM_OPEN_PAREN_COLON)) {
	  /* (?:...) does not create any group */
	  ret = regexpr;
	} else if (SG_EQ(open_token, SYM_OPEN_PAREN_GREATER)) {
	  ret = SG_LIST2(SYM_STANDALONE, regexpr);
	} else if (SG_EQ(open_token, SYM_OPEN_PAREN_EQUAL)) {
	  ret = SG_LIST3(SYM_LOOKAHEAD, SG_TRUE, regexpr);
	} else if (SG_EQ(open_token, SYM_OPEN_PAREN_EXCLAMATION)) {
	  ret = SG_LIST3(SYM_LOOKAHEAD, SG_FALSE, regexpr);
	} else if (SG_EQ(open_token, SYM_OPEN_PAREN_LESS_EQUAL)) {
	  ret = SG_LIST3(SYM_LOOKBHIND, SG_TRUE, regexpr);
	} else if (SG_EQ(open_token, SYM_OPEN_PAREN_LESS_EXCLAMATION)) {
	  ret = SG_LIST3(SYM_LOOKBHIND, SG_FALSE, regexpr);
	} else {
	  ASSERT(FALSE);
	  ret = SG_UNDEF;	/* dummy */
	}
	goto end_group;
      }
    }
  } else {
    /* This is the <lexical-token> production; <legal-token> is any token which
       passes start_of_subexpr_p (otherwise parsing had already stopped int the
       sequence.
     */
    ret = open_token;
  }
 end_group:
  ctx->flags = save;
  return ret;
}

/* 
   Parses and consume a <greedy-quant>.
   The productions are: <greedy-quant> -> <group> | <group><quantifier>
   where <quantifier> is parsed by the lexer function get_quantifier.
   Will return <parse-tree> or (SYM_GREEDY_REP <min> <max> <parse-tree).
 */
static SgObject greedy_quant(lexer_ctx_t *ctx)
{
  SgObject grp = group(ctx);
  int standalone = FALSE;
  SgObject token = get_quantifier(ctx, &standalone);
  if (!SG_FALSEP(token)) {
    /* if get_quantifier returned a true value it's the tow element list
       (<min> <max)
     */
    return SG_LIST4(SYM_GREEDY_REP, SG_CAR(token), SG_CADR(token), grp);
  }
  return grp;
}

/* 
   Parses and consume a <quant>.
   The productions are: <quant> -> <greedy-quant> | <greedy-quant>"?".
   Will return the <parse-tree> returned by greedy_quant and optionally change
   SYM_GREEDY_REP to SYM_NON_GREEDY_REP.
 */
static SgObject quant(lexer_ctx_t *ctx)
{
  SgObject greedy = greedy_quant(ctx);
  int pos = ctx->pos;
  SgChar nc = next_char(ctx);
  if (nc != EOF) {
    if (nc == '?') {
      SG_SET_CAR(greedy, SYM_NON_GREEDY_REP);
    } else if (nc == '+') {
      greedy = SG_LIST2(SYM_STANDALONE, greedy);
    } else {
      ctx->pos = pos;
    }
  }
  return greedy;
}

/*
  Parses and consumes a <seq>.
  The productions are: <sex> -> <quant> | <quant><seq>.
  Will return <parse-tree> or (sequence <parse-tree> <parse-tree>).
 */
static SgObject make_string_from_two_char(SgObject c1, SgObject c2)
{
  /* for the smarter way we should use, list->string, however it is slow */
  SgObject s = Sg_ReserveString(2, 0);
  ASSERT(SG_CHARP(c1) && SG_CHARP(c2));
  SG_STRING_VALUE_AT(s, 0) = SG_CHAR_VALUE(c1);
  SG_STRING_VALUE_AT(s, 1) = SG_CHAR_VALUE(c2);
  return s;
}
static SgObject sequence(lexer_ctx_t *ctx)
{
  if (start_of_subexpr_p(ctx)) {
    SgObject quan = quant(ctx);
    if (start_of_subexpr_p(ctx)) {
      SgObject seq = sequence(ctx);
      int is_quant_char = SG_CHARP(quant);
      int is_seq_sequence = (SG_PAIRP(seq) && SG_EQ(SG_CAR(seq), SYM_SEQUENCE));
      if (is_seq_sequence && SG_CHARP(seq)) {
	return make_string_from_two_char(seq, quan);
      } else if (is_quant_char && SG_STRINGP(seq)) {
	SgChar ca[1];
	ca[0] = SG_CHAR_VALUE(quan);
	return Sg_StringAppendC(seq, ca, 1);
      } else if (is_quant_char && is_seq_sequence && SG_CHARP(SG_CADR(seq))) {
	if (SG_NULLP(SG_CDDR(seq))) {
	  SG_SET_CDR(seq,
		     Sg_Cons(make_string_from_two_char(SG_CADR(seq), quan),
			     SG_CDDR(seq)));
	  return seq;
	} else {
	  return make_string_from_two_char(SG_CADR(seq), quan);
	}
      } else if (is_seq_sequence) {
	/* if <seq> is also a 'sequence parse tree we merge both lists into one
	   to avoid unneccessary consing*/
	SG_SET_CDR(seq, Sg_Cons(quan, SG_CDR(seq)));
	return seq;
      } else {
	return SG_LIST3(SYM_SEQUENCE, quan, seq);
      }
    } else {
      return quan;
    }
  }
  return null_seq();
}

/* 
   Parses and consumes a <regex>, a complete regular expression. The productions
are: <regex> -> <seq> | <seq> "|" <regex>.
Will return <parse-tree> or (SYM_ALTER <parse-tree> <parse-tree>).
 */
static SgObject reg_expr(lexer_ctx_t *ctx)
{
  int pos = ctx->pos;
  switch (next_char(ctx)) {
  case EOF:
    /* if we didn't get any token we return 'void which stands for
       "empty regular expression"
     */
    return null_seq();
  case '|':
    /* now check whether the expression started with a vertical bar,
       i.e. <seq> - the left alternation - is empty
     */
    return SG_LIST3(SYM_ALTER, null_seq(), reg_expr(ctx));
  default: {
    /* otherwise un-read the character we just saw and parse a <seq> plus
       the character following it
     */
    SgObject seq;
    ctx->pos = pos;
    seq = sequence(ctx);
    pos = ctx->pos;
    switch (next_char(ctx)) {
    case EOF:
      /* no further character, just a <seq> */
      return seq;
    case '|': {
      /* if the character was a vertical bar, this is an alternation and we
	 have the second production
       */
      SgObject expr = reg_expr(ctx);
      if (SG_PAIRP(expr) &&
	  SG_EQ(SG_CAR(expr), SYM_ALTER)) {
	/* again we try to merge as above in SEQ */
	SG_SET_CDR(expr, Sg_Cons(seq, SG_CDR(expr)));
	return expr;
      } else {
	return SG_LIST3(SYM_ALTER, seq, expr);
      }
    }
    default:
      /* a character which is not a vertical bar - this is either a syntax
	 error or we're inside of a group and the next character is closing
	 parenthesis; so we just un-read the character and let another function
	 take care of it
       */
      ctx->pos = pos;
      return seq;
    }
  }
  }
}

static SgObject parse_string(lexer_ctx_t *ctx)
{
  SgObject r;
  if (has(ctx, SG_LITERAL)) {
    /* the whole input string is just literal */
    SgObject h = SG_NIL, t = SG_NIL;
    int i;
    SG_APPEND1(h, t, SYM_SEQUENCE);
    for (i = 0; i < ctx->len; i++) {
      SG_APPEND1(h, t, SG_MAKE_CHAR(ctx->str[i]));
    }
    ctx->pos = ctx->len;
    r = h;
  } else {
    r = reg_expr(ctx);
  }
  return SG_LIST4(SYM_REGISTER, SG_MAKE_INT(0), SG_FALSE, r);
}

/* optimization */
/*
  cl-ppcre does convertion from s-expression tree to regex object to use generic
  methods.
  however on Sagittarius, we don't create such class and we do not use generic
  method(we can not!). So let's optimize AST directly and destructively.

  we do:
   - flattening nested sequence: (sequence a (sequence b) c) => (sequence a b c)
   - splits a repetition into constant and varying part: a{3,} -> a{3}a*
*/
static SgObject optimize(SgObject ast, SgObject rest);

/*
  a{3,} -> a{3}a*
  If the given regex is (abc|efg){3,}, then the back reference of $1 is "efg".
  So we can simple omit the first register tag if there is.
  (checked with Perl v5.10.1, with this one liner;
   $ perl -e 'my $s="abcabcabcefg"; $s=~/(abc|efg){3,}/; print $1."\n";'
   efg
  )
 */
static SgObject maybe_split_repetition(SgObject ast, SgObject regex)
{
  int minimum, maximum = -1;
  SgObject max = SG_CAR(SG_CDDR(ast));
  SgObject constant = SG_NIL;
  minimum = SG_INT_VALUE(SG_CADR(ast));
  if (!SG_FALSEP(max)) {
    maximum = SG_INT_VALUE(max);
    /* trivial case: don't repeat at all */
    if (maximum == 0) return null_seq();
    /* another trivial case "repeat" exactly once */
    if (minimum == 1 && maximum == 1) return ast;
  }
  if (minimum > 0) {
    SgObject in;
    if (SG_PAIRP(regex) && SG_EQ(SG_CAR(regex), SYM_REGISTER))
      in = SG_CADR(SG_CDDR(regex));
    else in = regex;
    constant = SG_LIST4(SG_CAR(ast), SG_CADR(ast), SG_CADR(ast), in);
  }
  if (!SG_FALSEP(max) &&
      maximum == minimum) {
    /* no varying part needed bacuause min = max */
    return constant;
  } else {
    SgObject varying = SG_LIST4(SG_CAR(ast),
				SG_MAKE_INT(0),
				(SG_FALSEP(max)
				 ? SG_FALSE : SG_MAKE_INT(maximum - minimum)),
				regex);
    if (minimum == 0) return varying; /* min = 0, no constant part needed */
    else if (minimum == 1) {
      /* min = 1, constant part needs not repetition wrapped around */
      return SG_LIST3(SYM_SEQUENCE, regex, varying);
    } else {
      return SG_LIST3(SYM_SEQUENCE, constant, varying);
    }
  }			
}

static SgObject optimize_seq(SgObject seq, SgObject rest)
{
  SgObject elt, tail, etype, opted;
  if (!SG_PAIRP(seq)) return seq;
  elt = SG_CAR(seq);
  tail = optimize_seq(SG_CDR(seq), rest);
  rest = SG_NULLP(tail) ? rest : tail;
  if (!SG_PAIRP(elt) || SG_EQ(SG_CAR(elt), SYM_INVERTED_CHAR_CLASS)) {
    if (SG_EQ(tail, SG_CDR(seq))) return seq;
    else return Sg_Cons(elt, tail);
  }
  etype = SG_CAR(elt);
  if (SG_EQ(etype, SYM_SEQUENCE)) {
    return Sg_Append2(optimize_seq(SG_CDR(elt), rest), tail);
  }
  opted = optimize(elt, rest);
  if (SG_EQ(elt, opted) && SG_EQ(tail, SG_CDR(seq))) return seq;
  else return Sg_Cons(opted, tail);
}

static SgObject optimize(SgObject ast, SgObject rest)
{
  /* assume given AST is not literal list. so caller must copy original AST. */
  SgObject type, seq, seqo;
  if (!SG_PAIRP(ast)) return ast;
  type = SG_CAR(ast);
  /* we know after inverted-char-class it has only char-set. so just return */
  if (SG_EQ(type, SYM_INVERTED_CHAR_CLASS)) return ast;
  
  if (SG_EQ(type, SYM_GREEDY_REP) ||
      SG_EQ(type, SYM_NON_GREEDY_REP)) {
    return maybe_split_repetition(ast, optimize(SG_CADR(SG_CDDR(ast)), rest));
  }

  if (SG_EQ(type, SYM_ALTER)) {
    SgObject sp, sp2, e = SG_UNBOUND, h, t;
    SG_FOR_EACH(sp, SG_CDR(ast)) {
      e = optimize(SG_CAR(sp), rest);
      if (!SG_EQ(e, SG_CAR(sp))) break;
    }
    if (SG_NULLP(sp)) return ast;
    /* need to copy the spine */
    h = t = SG_NIL;
    SG_FOR_EACH(sp2, SG_CDR(ast)) {
      if (SG_EQ(sp, sp2)) { SG_APPEND1(h, t, e); break; }
      SG_APPEND1(h, t, SG_CAR(sp2));
    }
    SG_FOR_EACH(sp2, SG_CDR(ast)) {
      SG_APPEND1(h, t, optimize(SG_CAR(sp2), rest));
    }
    return Sg_Cons(SYM_ALTER, h);
  }
  if (SG_EQ(type, SYM_SEQUENCE)) {
    seq = SG_CDR(ast);
    seqo = optimize_seq(seq, rest);
    if (SG_EQ(seq, seqo)) return ast;
    return Sg_Cons(type, seqo);
  }
  seq = SG_CDR(ast);
  seqo = optimize(seq, rest);
  if (SG_EQ(seq, seqo)) return ast;
  return Sg_Cons(type, seqo);
}

/* compile */
/* Instructions */
enum {
  RX_ANY,			/* match everything (one character) */
  RX_CHAR,			/* match one character */
  RX_SET,			/* match one charset */
  RX_NSET,			/* match one charset */
  RX_STR,			/* match string(not supported yet) */
  RX_SPLIT,			/* split current (virtual) thread */
  RX_JMP,
  RX_SAVE,			/* save current match for submatch */
  /* add more */
  RX_START,			/* start anchor */
  RX_END,			/* end anchor */
  RX_WB,			/* word boundary */
  RX_NWB,			/* non word boundary */
  RX_FAIL,			/* match failed */
  RX_MATCH,			/* matched */
};

typedef struct
{
  inst_t *pc;			/* current pc */
  int     flags;		/* compile time flags */
  int     emitp;		/* flag for count or emit */
  int     codemax;		/* max code count */
  prog_t *prog;			/* building prog */
  int     index;		/* current inst index */
} compile_ctx_t;

static inst_arg_t null_arg = {0};
static inst_t     null_inst = {0};

static int check_start_anchor(SgObject ast, int *modelessp)
{
  SgObject type;
  if (!SG_PAIRP(ast)) 
    type = ast;
  else 
    type = SG_CAR(ast);    

  if (SG_EQ(type, SYM_START_ANCHOR)) return TRUE;
  else if (SG_EQ(type, SYM_MODELESS_START_ANCHOR)) {
    if (modelessp) *modelessp = TRUE;
    return TRUE;
  }
  else return FALSE;
}

static void emit(compile_ctx_t *ctx, unsigned char opcode,
		 inst_arg_t arg)
{
  if (ctx->emitp) {
    inst_t *i = &ctx->prog->root[ctx->index++];
    i->opcode = opcode;
    i->arg = arg;
    ctx->pc = ++i;
  } else {
    ctx->codemax++;
  }
}
static void compile_rec(compile_ctx_t *ctx, SgObject ast, int lastp);

static void compile_seq(compile_ctx_t *ctx, SgObject seq, int lastp)
{
  SgObject cp;
  /* todo look behind */
  SG_FOR_EACH(cp, seq) {
    SgObject item = SG_CAR(cp);
    inst_arg_t arg;
    if (SG_CHARP(item)) {
      /* TODO we need to concat chars to string. but it must be done by 
 	      optimization.*/
      arg.c = SG_CHAR_VALUE(item);
      emit(ctx, RX_CHAR, arg);
    } else {
      int p;
      /* TODO lookbehind */
      p = lastp && SG_NULLP(SG_CDR(cp));
      compile_rec(ctx, item, p);
    }
  }
}

static void compile_rep_seq(compile_ctx_t *ctx, SgObject seq,
			    int count, int lastp)
{
  SgObject h = SG_NIL, t = SG_NIL;
  if (count <= 0) return;
  while (count-- > 0) {
    SG_APPEND(h, t, Sg_CopyList(seq));
  }
  /* h is ((sequence ...) ...) so we can simply pass it to compile_seq
     TODO maybe we need to flatten */
  compile_seq(ctx, h, lastp);
}

static void compile_min_max(compile_ctx_t *ctx, SgObject type,
			    int count, SgObject item, int lastp)
{
  /* TODO later */
  Sg_Error(UC("not supported yet"));
  return;
}

static void compile_rec(compile_ctx_t *ctx, SgObject ast, int lastp)
{
  SgObject type;
  inst_arg_t arg;
  /* first, deal with atom */
  if (!SG_PAIRP(ast)) {
    /* a char */
    if (SG_CHARP(ast)) {
      /* TODO maybe we can deal with case insensitive here */
      arg.c = SG_CHAR_VALUE(ast);
      emit(ctx, RX_CHAR, arg);
      return;
    }
    /* charset */
    if (SG_CHAR_SET_P(ast)) {
      arg.set = ast;
      emit(ctx, RX_SET, arg);
      return;
    }
    /* special stuff */
    if (SG_SYMBOLP(ast)) {
      if (SG_EQ(ast, SYM_EVERYTHING)) {
	emit(ctx, RX_ANY, null_arg);
	return;
      }
      if (SG_EQ(ast, SYM_START_ANCHOR) ||
	  SG_EQ(ast, SYM_MODELESS_START_ANCHOR)) {
	/* check flags */
	arg.bol = SG_EQ(ast, SYM_START_ANCHOR);
	emit(ctx, RX_START, arg);
	return;
      }
      if (SG_EQ(ast, SYM_END_ANCHOR) ||
	  SG_EQ(ast, SYM_MODELESS_END_ANCHOR) ||
	  SG_EQ(ast, SYM_MODELESS_END_ANCHOR_NO_NEWLINE)) {
	if (lastp) {
	  /* check flags */
	  arg.eol = SG_EQ(ast, SYM_END_ANCHOR);
	  emit(ctx, RX_END, arg);
	} else {
	  /* literal character '$' */
	  arg.c = '$';
	  emit(ctx, RX_CHAR, arg);
	}
	return;
      }
      if (SG_EQ(ast, SYM_WORD_BOUNDARY)) {
	emit(ctx, RX_WB, null_arg);
	return;
      }
      if (SG_EQ(ast, SYM_NON_WORD_BOUNDARY)) {
	emit(ctx, RX_NWB, null_arg);
	return;
      }
      /* fallback */
    }
    Sg_Error(UC("[internal:regex] unrecognized AST item: %S"), ast);
  }
  /* structured node */
  type = SG_CAR(ast);
  /* do with simple ones */
  if (SG_EQ(type, SYM_SEQUENCE)) {
    /* we do not have any implicit sequence */
    compile_seq(ctx, SG_CDR(ast), lastp);
    return;
  }

  if (SG_EQ(type, SYM_INVERTED_CHAR_CLASS)) {
    SgObject cs = SG_CADR(ast);
    ASSERT(SG_CHAR_SET_P(cs));
    arg.set = cs;
    emit(ctx, RX_NSET, arg);
    return;
  }
  if (SG_EQ(type, SYM_REGISTER)) {
    /* (register <number> <name> <ast>) */
    int grpno = SG_INT_VALUE(SG_CADR(ast));
    arg.n = 2*grpno;
    emit(ctx, RX_SAVE, arg);
    compile_rec(ctx, SG_CADR(SG_CDDR(ast)), lastp);
    arg.n = 2*grpno+1;
    emit(ctx, RX_SAVE, arg);
    return;
  }
  
  if (SG_EQ(type, SYM_ALTER)) {
    if (SG_PAIRP(SG_CDR(ast))) {
      inst_t *pc1 = ctx->pc, *pc2;
      emit(ctx, RX_SPLIT, null_arg);
      pc1->arg.pos.x = ctx->pc;
      compile_rec(ctx, SG_CADR(ast), lastp);
      pc2 = ctx->pc;
      emit(ctx, RX_JMP, null_arg);
      pc1->arg.pos.y = ctx->pc;
      compile_rec(ctx, SG_CAR(SG_CDDR(ast)), lastp);
      pc2->arg.pos.x = ctx->pc;
    } else {
      emit(ctx, RX_FAIL, null_arg);
    }
    return;
  }

  if (SG_EQ(type, SYM_GREEDY_REP) || SG_EQ(type, SYM_NON_GREEDY_REP)) {
    SgObject min = SG_CADR(ast), max = SG_CAR(SG_CDDR(ast));
    SgObject item = SG_CADR(SG_CDDR(ast));
    int multip = 0;
    inst_t *pc1, *pc2;
    if (SG_FALSEP(max) || SG_INT_VALUE(max) > 1)
      multip = TRUE;
    compile_rep_seq(ctx, item, SG_INT_VALUE(min), multip);

    if (SG_EQ(min, max)) return; /* well, it must match exact times */
    if (!SG_FALSEP(max)) {
      int count = SG_INT_VALUE(max) - SG_INT_VALUE(min);
      compile_min_max(ctx, type, count, item, lastp);
      return;
    }
    /* save current instruction position */
    pc1 = ctx->pc;
    emit(ctx, RX_SPLIT, arg);
    pc1->arg.pos.x = ctx->pc;
    compile_rec(ctx, item, FALSE);
    /* we've already resolved minimam match so let introduce jmp here */
    arg.pos.x = pc1;
    emit(ctx, RX_JMP, arg);
    pc1->arg.pos.y = ctx->pc;
    if (SG_EQ(type, SYM_NON_GREEDY_REP)) {
      pc2 = pc1->arg.pos.x;
      pc1->arg.pos.x = pc1->arg.pos.y;
      pc1->arg.pos.y = pc2;
    }
    return;
  }

  Sg_Error(UC("unknown AST type: %S"), type);
}

static prog_t* compile(compile_ctx_t *ctx, SgObject ast)
{
  int n, is_start_anchor, modeless = FALSE, i;
  prog_t *p;
  inst_t *start, *match;

  ctx->pc = &null_inst;		/* put dummy */
  is_start_anchor = check_start_anchor(ast, &modeless);
  ctx->emitp = FALSE;
  compile_rec(ctx, ast, TRUE);
  n = ctx->codemax + 1;

  p = SG_NEW(prog_t);
  p->root = SG_NEW_ARRAY(inst_t, n);
  p->rootLength = n;
  ctx->prog = p;
  ctx->pc = &p->root[0];
  ctx->index = 0;
  ctx->emitp = TRUE;
  compile_rec(ctx, ast, TRUE);

  match = &p->root[n-1];
  match->opcode = RX_MATCH;
  if (!is_start_anchor) {
    p->matchRoot = SG_NEW_ARRAY(inst_t, n + 1);
    p->matchRootLength = n + 1;
    start = &p->matchRoot[0];
    start->opcode = RX_START;
    start->arg.bol = FALSE;
    /* copy */
    for (i = 0; i < n; i++) {
      p->matchRoot[i+1] = p->root[i];
    }
  } else {
    /* root and matchRoot are the same */
    p->matchRoot = p->root;
    p->matchRootLength = p->rootLength;
  }

  return p;
}


/* compile takes 3 pass 
   pass1: string->ast
   pass2: optimize
   pass3: code generation
 */
static void pattern_printer(SgPort *port, SgObject self, SgWriteContext *ctx)
{
  SgPattern *pattern = SG_PATTERN(self);
  Sg_Printf(port, UC("#<pattern %S>"), pattern->pattern);
}
SG_INIT_META_OBJ(Sg_PatternMeta, &pattern_printer, NULL);

static SgPattern* make_pattern(SgString *p, SgObject ast, int flags,
			       lexer_ctx_t *ctx, prog_t *prog)
{
  SgPattern *pt = SG_NEW(SgPattern);
  SG_SET_META_OBJ(pt, SG_META_PATTERN);
  pt->pattern = p;
  pt->ast = ast;
  pt->flags = flags;
  pt->groupCount = ctx->reg_num;
  pt->prog = prog;
  return pt;
}

SgObject Sg_CompileRegex(SgString *pattern, int flags, int parseOnly)
{
  SgObject ast;
  lexer_ctx_t ctx;
  SgPattern *p;
  prog_t *prog;
  compile_ctx_t cctx = {0};

  init_lexer(&ctx, pattern, flags);
  ast = parse_string(&ctx);
  if (!END_OF_STRING_P(&ctx)) {
    raise_syntax_error(&ctx, ctx.pos,
		       UC("Expected end of string."));
  }
  if (parseOnly) return ast;
  /* optimize */
  ast = optimize(ast, SG_NIL);
  /* compile */
  cctx.flags = flags;
  prog = compile(&cctx, ast);

  p = make_pattern(pattern, ast, flags, &ctx, prog);
  return SG_OBJ(p);
}

void Sg_DumpRegex(SgPattern *pattern, SgObject port)
{
#ifdef DEBUG_REGEX
  int i;
  const int size = pattern->prog->rootLength;
  inst_t *start = &pattern->prog->root[0];
  Sg_Printf(port, UC("input regex: %S\n"), pattern->pattern);

  for (i = 0; i < size; i++) {
    inst_t *inst = &pattern->prog->root[i];
    switch (inst->opcode) {
    case RX_ANY:
      Sg_Printf(port, UC("%3d: RX_ANY\n"), i);
      break;
    case RX_CHAR:
      Sg_Printf(port, UC("%3d: RX_CHAR %c\n"), i, inst->arg.c);
      break;
    case RX_SET:
      Sg_Printf(port, UC("%3d: RX_SET %S\n"), i, inst->arg.set);
      break;
    case RX_NSET:
      Sg_Printf(port, UC("%3d: RX_NSET %S\n"), i, inst->arg.set);
      break;
    case RX_STR:
      Sg_Printf(port, UC("%3d: RX_STR\n"), i);
      break;
    case RX_SPLIT:
      Sg_Printf(port, UC("%3d: RX_SPLIT %d %d\n"),
		i, inst->arg.pos.x - start, inst->arg.pos.y - start);
      break;
    case RX_JMP:
      Sg_Printf(port, UC("%3d: RX_JMP %d\n"),
		i, inst->arg.pos.x - start);
      break;
    case RX_SAVE:
      Sg_Printf(port, UC("%3d: RX_SAVE %d\n"), i, inst->arg.n);
      break;
    case RX_START:
      Sg_Printf(port, UC("%3d: RX_START %s\n"), i,
		(inst->arg.bol) ? UC("bol") : UC(""));
      break;
    case RX_END:
      Sg_Printf(port, UC("%3d: RX_END %s\n"), i,
		(inst->arg.eol) ? UC("eol") : UC(""));
      break;
    case RX_WB:
      Sg_Printf(port, UC("%3d: RX_WB\n"), i);
      break;
    case RX_NWB:
      Sg_Printf(port, UC("%3d: RX_NWB\n"), i);
      break;
    case RX_FAIL:
      Sg_Printf(port, UC("%3d: RX_FAIL\n"), i);
      break;
    case RX_MATCH:
      Sg_Printf(port, UC("%3d: RX_MATCH\n"), i);
      break;
    default:
      Sg_Printf(port, UC("%3d: ??? %d\n"), i, inst->opcode);
      break;
    }
  }
#endif
}

typedef struct
{
  inst_t     *pc;
  submatch_t *sub;
} thread_t;

/* We might want to swith to sparse array, so make it as abstract as possible */
typedef struct
{
  int size;			/* thread size */
  int n;			/* used size */
  thread_t *threads[1];		/* threads */
} thread_list_t;

static thread_list_t* alloc_thread_lists(int n)
{
  thread_list_t *tq = SG_NEW2(thread_list_t*,
			      sizeof(thread_list_t) + (n-1)*sizeof(thread_t*));
  tq->size = n;
  return tq;
}

static void thread_list_clear(thread_list_t *tq)
{
  int i;
  for (i = 0; i < tq->size; i++) {
    tq->threads[i] = NULL;
  }
}

static int thread_list_has_index(thread_list_t *tq, int index)
{
  return !(tq->threads[index]);
}

static thread_t* thread_list_set_new(thread_list_t *tq, int index, thread_t *t)
{
  if (index >= tq->size) {
    /* TODO throw error */
    ASSERT(FALSE);
    return NULL;
  }
  ASSERT(!thread_list_has_index(tq, index));
  tq->threads[index] = t;
  return t;
}

#define ALLOCATE_THREADQ(n) alloc_thread_lists(n)
#define THREADQ_SIZE(tq)    ((tq)->n)
#define THREADQ_REF(tq, i)  ((tq)->threads[i])
#define THREADQ_SET(tq, i, v)  thread_list_set((tq), (i), (v))
#define THREADQ_T           thread_list_t*

/* match */
typedef struct
{
  int id;			/* inst to process */
  int j;
  const SgChar *cap_j;
} add_state_t;

typedef struct
{
  SgMatcher   *m;
  int          nstack;
  add_state_t *astack;
  THREADQ_T    q0;
  THREADQ_T    q1;
  int          matched;
  submatch_t  *subs;
} match_ctx_t;
static match_ctx_t* init_match_ctx(match_ctx_t *ctx, SgMatcher *m, int size);

/* internal match process
   based on pikevm from RE1 pike.c
 */
static int matcher_match0(match_ctx_t *ctx, int from, int anchor, inst_t *inst,
			  int size)
{
  int i;
  return FALSE;
}


/* match entry point*/
static int matcher_match(SgMatcher *m, int from, int anchor)
{
  match_ctx_t ctx;
  /* we use root, not rootMatch for looking-at */
  init_match_ctx(&ctx, m, m->pattern->prog->matchRootLength);
  return matcher_match0(&ctx, from, anchor, m->pattern->prog->matchRoot,
			m->pattern->prog->matchRootLength);
}

static match_ctx_t* init_match_ctx(match_ctx_t *ctx, SgMatcher *m, int size)
{
  ctx->m = m;
  ctx->nstack = size*2;
  ctx->astack = SG_NEW_ARRAY(add_state_t, ctx->nstack);
  ctx->q0 = ALLOCATE_THREADQ(size);
  ctx->q1 = ALLOCATE_THREADQ(size);
  ctx->matched = FALSE;
  ctx->subs = m->submatch;
  return ctx;
}

static void matcher_printer(SgPort *port, SgObject self, SgWriteContext *ctx)
{
  Sg_Printf(port, UC("#<matcher %S %S>"), SG_MATCHER(self)->pattern,
	    SG_MATCHER(self)->text);
}
SG_INIT_META_OBJ(Sg_MatcherMeta, matcher_printer, NULL);

static SgMatcher* reset_matcher(SgMatcher *m)
{
  m->first = -1;
  m->from = 0;
  m->to = SG_STRING_SIZE(m->text);
  m->last = 0;
  m->oldLast = -1;
  return m;
}

static SgMatcher* make_matcher(SgPattern *p, SgString *text)
{
  SgMatcher *m = SG_NEW2(SgMatcher*, sizeof(SgMatcher) + 
			 sizeof(submatch_t) * (p->groupCount-1));
  SG_SET_META_OBJ(m, SG_META_MATCHER);
  m->pattern = p;
  m->text = text;
  m->anchorBounds = TRUE;
  return reset_matcher(m);
}


SgMatcher* Sg_RegexMatcher(SgPattern *pattern, SgString *text)
{
  SgMatcher *m = make_matcher(pattern, text);
  return m;
}

int Sg_RegexLookingAt(SgMatcher *m)
{
  return matcher_match(m, m->from, UNANCHORED);
}

extern void Sg__Init_sagittarius_regex2_impl();

SG_EXTENSION_ENTRY void Sg_Init_sagittarius__regex2()
{
  SgLibrary *lib;
  SG_INIT_EXTENSION(sagittarius__regex2);
  Sg__Init_sagittarius_regex2_impl();

  lib = Sg_FindLibrary(SG_INTERN("(sagittarius regex2 impl)"), FALSE);
#define insert_binding(name, value)			\
  Sg_MakeBinding(lib, SG_INTERN(#name), SG_MAKE_INT(value), TRUE);
  insert_binding(CASE-INSENSITIVE, SG_CASE_INSENSITIVE);
  insert_binding(COMMENTS, SG_COMMENTS);
  insert_binding(MULTILINE, SG_MULTILINE);
  insert_binding(LITERAL, SG_LITERAL);
  insert_binding(DOTAIL, SG_DOTALL);
  insert_binding(UNICODE-CASE, SG_UNICODE_CASE);
#undef insert_binding

  SYM_ALTER = SG_INTERN("alternation");
  SYM_NON_GREEDY_REP = SG_INTERN("non-greedy-repetition");
  SYM_GREEDY_REP = SG_INTERN("greedy-repetition");
  SYM_CLOSE_PAREN = SG_INTERN("close-paren");
  SYM_VERTICAL_BAR = SG_INTERN("vertical-bar");
  SYM_QUESTION_MARK = SG_INTERN("question-mark");
  SYM_EVERYTHING = SG_INTERN("everything");
  SYM_END_ANCHOR = SG_INTERN("end-anchor");
  SYM_INVERTED_CHAR_CLASS = SG_INTERN("inverted-char-class");
  SYM_MODELESS_START_ANCHOR = SG_INTERN("modeless-start-anchor");
  SYM_MODELESS_END_ANCHOR = SG_INTERN("modeless-end-anchor");
  SYM_MODELESS_END_ANCHOR_NO_NEWLINE
    = SG_INTERN("modeless-end-anchor-no-newline");
  SYM_START_ANCHOR = SG_INTERN("start-anchor");
  SYM_BACKREF = SG_INTERN("back-reference");
  SYM_WORD_BOUNDARY = SG_INTERN("word-boundary");
  SYM_NON_WORD_BOUNDARY = SG_INTERN("non-word-boundary");
  SYM_BRANCH = SG_INTERN("branch");
  SYM_FLAGS = SG_INTERN("flags");
  SYM_OPEN_PAREN = SG_INTERN("open-paren");
  SYM_OPEN_PAREN_PAREN = SG_INTERN("open-paren-paren");
  SYM_OPEN_PAREN_GREATER = SG_INTERN("open-paren-greater");
  SYM_OPEN_PAREN_EQUAL = SG_INTERN("open-paren-equal");
  SYM_OPEN_PAREN_LESS_EXCLAMATION = SG_INTERN("open-paren-less-exclamation");
  SYM_OPEN_PAREN_COLON = SG_INTERN("open-paren-colon");
  SYM_OPEN_PAREN_EXCLAMATION = SG_INTERN("open-paren-exclamation");
  SYM_OPEN_PAREN_LESS_LETTER = SG_INTERN("open-paren-less-letter");
  SYM_REGISTER = SG_INTERN("register");
  SYM_STANDALONE = SG_INTERN("standalone");
  SYM_LOOKAHEAD = SG_INTERN("lookahead");
  SYM_OPEN_PAREN_LESS_EQUAL = SG_INTERN("open-paren-less-equal");
  SYM_CASE_INSENSITIVE = SG_INTERN("case-insensitive");
  SYM_CASE_SENSITIVE = SG_INTERN("case-sensitive");
  SYM_MULTI_LINE_MODE = SG_INTERN("multi-line-mode");
  SYM_NOT_MULTI_LINE_MODE = SG_INTERN("not-multi-line-mode");
  SYM_SINGLE_LINE_MODE = SG_INTERN("single-line-mode");
  SYM_NOT_SINGLE_LINE_MODE = SG_INTERN("not-single-line-mode");
  SYM_SEQUENCE = SG_INTERN("sequence");
  SYM_LOOKBHIND = SG_INTERN("lookbehind");
  SYM_FLAGED_SEQUENCE = SG_INTERN("flaged-sequence");
}
