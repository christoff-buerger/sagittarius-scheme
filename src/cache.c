/* -*- C -*- */
/*
 * cache.c
 *
 *   Copyright (c) 2010  Takashi Kato <ktakashi@ymail.com>
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
#include <setjmp.h>
#include <ctype.h>
#define LIBSAGITTARIUS_BODY
#include "sagittarius/cache.h"
#include "sagittarius/bytevector.h"
#include "sagittarius/closure.h"
#include "sagittarius/code.h"
#include "sagittarius/core.h"
#include "sagittarius/file.h"
#include "sagittarius/gloc.h"
#include "sagittarius/hashtable.h"
#include "sagittarius/identifier.h"
#include "sagittarius/instruction.h"
#include "sagittarius/keyword.h"
#include "sagittarius/library.h"
#include "sagittarius/macro.h"
#include "sagittarius/number.h"
#include "sagittarius/pair.h"
#include "sagittarius/port.h"
#include "sagittarius/reader.h"	/* for shared reference */
#include "sagittarius/string.h"
#include "sagittarius/symbol.h"
#include "sagittarius/system.h"
#include "sagittarius/thread.h"
#include "sagittarius/vector.h"
#include "sagittarius/vm.h"
#include "sagittarius/writer.h"

#define VALIDATE_TAG SG_CPP_CAT("Sagittarius version ", SAGITTARIUS_VERSION)

static SgString *CACHE_DIR = NULL;

/* assume id is path. however just in case, we encode invalid path characters */
static SgString* id_to_filename(SgString *id)
{
  SgVM *vm = Sg_VM();
  SgObject sl = Sg_StringToList(id, 0, -1);
  SgObject cp, h = SG_NIL, t = SG_NIL;
  static const SgObject perc = SG_MAKE_CHAR('%');

  if (CACHE_DIR == NULL) {
    Sg_LockMutex(&vm->vmlock);
    if (CACHE_DIR == NULL) {
      CACHE_DIR = Sg_GetTemporaryDirectory();
    }
    Sg_UnlockMutex(&vm->vmlock);
  }

  SG_FOR_EACH(cp, sl) {
    SgObject c = SG_CAR(cp);
    SgChar ch = SG_CHAR_VALUE(c);
    if (!isalnum(ch)){
      int high = (ch >> 4) & 0xF;
      int low  = ch & 0xF;
      SG_APPEND1(h, t, perc);
      SG_APPEND1(h, t, SG_MAKE_CHAR((high < 0xa) ? high + '0' : high + 0x57));
      SG_APPEND1(h, t, SG_MAKE_CHAR((low < 0xa) ? low + '0' : low + 0x57));
    } else {
      SG_APPEND1(h, t, c);
    }
  }
  return Sg_StringAppend(SG_LIST4(CACHE_DIR,
				  Sg_MakeString(Sg_NativeFileSeparator(), SG_LITERAL_STRING),
				  Sg_ListToString(h),
				  Sg_MakeString(UC(".cache"), SG_LITERAL_STRING)));
}

/*
  compiled cashe tags.
  
  we do not cache all objects. if we can not cache it cache file will be marked
  as invalid cache. the files will be marked as invalid are using quasiquote and
  try to create non readable object which are written like #<something> or
  extended object such as thread, regex etc.
  we might support these objects, but for now only primitives.
  NB: tag must be read as signed char because we use -1 as invalid cache.
 */
enum {
  INVALID_CACHE_TAG = -1,
  /* tag len insn */
  INSTRUCTION_TAG = 1,
  /* tag len # for reference */
  MARK_TAG,			/* mark tag for closure */
  CODE_BUILDER_TAG,
  CODE_BUILDER_END_TAG,
  /* tag len ${object}(library name) */
  LIBRARY_TAG,
  IMPORT_TAG,
  EXPORT_TAG,
  IMMEDIATE_TAG,		/* fixnum, char, boolean etc. */
  /* primitives */
  STRING_TAG,
  INTERNED_SYMBOL_TAG,
  UNINTERNED_SYMBOL_TAG,
  KEYWORD_TAG,
  NUMBER_TAG,			/* this number is not fixnum */
  IDENTIFIER_TAG,
  BYTE_VECTOR_TAG,
  CLOSURE_TAG,
  /* these can contain other pointers */
  VECTOR_TAG,
  PLIST_TAG,
  DLIST_TAG,
  /* macro needs special treat */
  MACRO_TAG,
  MACRO_TRANSFORM_TAG,
  LIBRARY_REF_TAG,
  LOOKUP_TAG,
  DEFINING_SHARED_TAG,
  BOUNDARY_TAG,			/* boundary */
};

/* symbol, string, keyword, identifier, bytevector, vector,
   pair, number, macro
 */
#define cachable_p(obj)							\
  (SG_SYMBOLP(obj) || SG_STRINGP(obj) || SG_KEYWORD(obj) ||		\
   SG_IDENTIFIERP(obj) || SG_BVECTORP(obj) || SG_VECTORP(obj) ||	\
   SG_PAIRP(obj) || SG_NUMBERP(obj) || SG_MACROP(obj) || SG_GLOCP(obj))

#define put_4byte(v)				\
  do {						\
    Sg_PutbUnsafe(out, ((v) >> 24) & 0xFF);	\
    Sg_PutbUnsafe(out, ((v) >> 16) & 0xFF);	\
    Sg_PutbUnsafe(out, ((v) >> 8) & 0xFF);	\
    Sg_PutbUnsafe(out, (v) & 0xFF);		\
  } while (0)

static void put_word(SgPort *out, SgWord w, int tag)
{
  static const int WORD_SIZE = sizeof(SgObject);
  int i;
  Sg_PutbUnsafe(out, tag);
  put_4byte(WORD_SIZE);
  for (i = 0; i < WORD_SIZE; i++) {
    /* write order:
       value-> 0xaabbccdd
       write-> dd cc bb aa
     */
    Sg_PutbUnsafe(out, (uintptr_t)w & 0xFF);
    w = ((uintptr_t)w >> 8);
  }
}

static void emit_immediate(SgPort *out, SgObject o)
{
  put_word(out, SG_WORD(o), IMMEDIATE_TAG);
}

/*
  Basic strategy of writing compiled cache.
  We need 2 pass to write cache.

  Pass1: walk.
  we need to collect pointers(Symbol, Pair, etc) and closures(CodeBuilder).
  basically, we don't much care aboud pointers when we write, but closures.
  other instructions and immediate value can be ignored.
  
  Pass2: write
  write cache to file. we need to put tag before it, so that reader can know
  which data was written. the tag structure is like this:
  *tag* *length of data* *data* ...
  tag is one byte which specifies data type.
  length is byte length and must be 2bytes.
  data can be either immediate value or pointer value. for reading closure, we
  use mark tag.
  NB: we also need to write macros which need to be treated kind of special.
      because it is not in compiled code, but in library already. so we need to
      specify which library is compiled. we can know it from identifier, then
      retrieve it.
  TODO: what if somebody defined macro outside of library and use it as library?
        right now, it will be duplicated.

  we try to cache as much as possible. but for now, we do not support all
  objects, especially objects which are not able to be read by reader such as
  codec, transcoder etc. see above tag definition.
 */
typedef struct cache_ctx_rec cache_ctx;
static SgObject write_cache_pass1(SgCodeBuilder *cb, SgObject r, SgLibrary **lib, SgHashTable *sharedObjects,  jmp_buf jbuf);
static int      write_cache_pass2(SgPort *out, SgCodeBuilder *cb, SgObject r, cache_ctx *ctx, int index);
static void     write_macro_cache(SgPort *out, SgLibrary *lib, SgObject cbs, int index, int uid,  jmp_buf jbuf);
static void     write_string_cache(SgPort *out, SgString *s, int tag);
static void     write_symbol_cache(SgPort *out, SgSymbol *s);
static int      write_object_cache(SgPort *out, SgObject o, SgObject cbs, cache_ctx *ctx, int index);

struct cache_ctx_rec
{
  SgHashTable *sharedObjects;
  int          uid;
};

static int write_library(SgPort *out, SgLibrary *lib)
{
  int len;
  /* for now we don't support generic object */
  if (!SG_NULLP(lib->generics)) return FALSE;
  len = Sg_Length(lib->imported);
  Sg_PutbUnsafe(out, LIBRARY_TAG);
  put_4byte(len);
  /* we can just ignore cbs and index */
  write_symbol_cache(out, lib->name);
  return TRUE;
}

static int write_dependancy(SgPort *out, SgLibrary *lib, cache_ctx *ctx)
{
  SgObject cp;
  int len;
  if (!write_library(out, lib)) return FALSE;

  /* write import spec */
  Sg_PutbUnsafe(out, IMPORT_TAG);
  len = Sg_Length(lib->imported);
  put_4byte(len);
  SG_FOR_EACH(cp, lib->imported) {
    SgObject slot = SG_CAR(cp);
    write_symbol_cache(out, SG_LIBRARY_NAME(SG_CAR(slot)));
    write_object_cache(out, SG_CDR(slot), SG_NIL, ctx, 0);
  }
  Sg_PutbUnsafe(out, EXPORT_TAG);
  len = Sg_Length(lib->exported);
  put_4byte(len);
  write_object_cache(out, lib->exported, SG_NIL, ctx, 0);
  Sg_PutbUnsafe(out, BOUNDARY_TAG);
  return TRUE;
}

static int write_cache(SgObject name, SgCodeBuilder *cb, SgPort *out, int index)
{
  SgVM *vm = Sg_VM();
  SgLibrary *lib = NULL;		/* for macro */
  SgObject closures, closure;
  SgHashTable *sharedObjects = Sg_MakeHashTableSimple(SG_HASH_EQ, 0);
  jmp_buf jbuf;
  cache_ctx ctx;

  if (setjmp(jbuf) == 0) {
    /* pass1 collect closure and library */
    closures = write_cache_pass1(cb, SG_NIL, &lib, sharedObjects, jbuf);
  } else {
    /* if there is non cachable objects in compiled code, 
       we discard all cache.
     */
    Sg_SetPortPosition(out, 0);
    Sg_PutbUnsafe(out, (uint8_t)INVALID_CACHE_TAG);
    return -1;
  }

  /* before write cache, we need to write library info */
  ctx.sharedObjects = sharedObjects;
  ctx.uid = 0;
  if (!SG_FALSEP(name)) {
    /* when writing a cache, the library must be created. */
    if (!write_dependancy(out, (lib == NULL) ? Sg_FindLibrary(name, FALSE) : lib, &ctx)) {
      Sg_SetPortPosition(out, 0);
      Sg_PutbUnsafe(out, (uint8_t)INVALID_CACHE_TAG);
      return -1;
    }
  }

  if (SG_VM_LOG_LEVEL(vm, SG_DEBUG_LEVEL)) {
    Sg_Printf(vm->logPort, UC("collected closures: %S\n"), closures);
  }
  /* pass2 write cache. */
  index = write_cache_pass2(out, cb, closures, &ctx, index);
  SG_FOR_EACH(closure, closures) {
    SgObject slot = SG_CAR(closure);
    int i = SG_INT_VALUE(SG_CDR(slot));
    Sg_PutbUnsafe(out, CLOSURE_TAG);
    put_4byte(i);
    index = write_cache_pass2(out, SG_CODE_BUILDER(SG_CAR(slot)), closures, &ctx, index);
  }
  /* if library is NULL, the given code was empty. see core.scm */
  if (lib != NULL) {
    /* write macro */
    if (setjmp(jbuf) == 0) {
      write_macro_cache(out, lib, closures, index, ctx.uid, jbuf);
    } else {
      /* macro has something weird objects */
      Sg_SetPortPosition(out, 0);
      Sg_PutbUnsafe(out, (uint8_t)INVALID_CACHE_TAG);
      return -1;
    }
  }
  Sg_PutbUnsafe(out, BOUNDARY_TAG);
  return index;
}

#define interesting_p(obj)					\
  (SG_STRINGP(obj) || SG_SYMBOLP(obj) ||			\
   SG_PAIRP(obj) || SG_VECTORP(obj) || SG_CLOSUREP(obj))

static SgObject write_cache_scan(SgObject obj, SgHashTable *sharedObjects, SgObject cbs, jmp_buf escape)
{
  SgObject value;
 loop:
  if (!cachable_p(obj)) longjmp(escape, 1);

  value = Sg_HashTableRef(sharedObjects, obj, SG_UNBOUND);
  if (SG_FALSEP(value)) {
    Sg_HashTableSet(sharedObjects, obj, SG_TRUE, 0);
    return cbs;
  } else if (SG_TRUEP(value)) {
    return cbs;
  } else {
    Sg_HashTableSet(sharedObjects, obj, SG_FALSE, 0);
    if (SG_PAIRP(obj)) {
      cbs = write_cache_scan(SG_CAR(obj), sharedObjects, cbs, escape);
      obj = SG_CDR(obj);
      goto loop;
    } else if (SG_VECTORP(obj)) {
      int i, size = SG_VECTOR_SIZE(obj);
      for (i = 0; i < size; i++) {
	cbs = write_cache_scan(SG_VECTOR_ELEMENT(obj, i), sharedObjects, cbs, escape);
      }
    } else if (SG_CLOSUREP(obj)) {
      cbs = Sg_Acons(SG_CLOSURE(obj)->code, SG_FALSE, cbs);
      cbs = write_cache_pass1(SG_CLOSURE(obj)->code, cbs, NULL, sharedObjects, escape);
    }
  }
  return cbs;
}

/* correct code builders in code*/
static SgObject write_cache_pass1(SgCodeBuilder *cb, SgObject r, SgLibrary **lib, SgHashTable *sharedObjects, jmp_buf escape)
{
  SgWord *code = cb->code;
  int i, len = cb->size;
  for (i = 0; i < len;) {
    InsnInfo *info = Sg_LookupInsnName(INSN(code[i]));
    int j;
    for (j = 0; j < info->argc; j++) {
      SgObject o = SG_OBJ(code[i+j+1]);
      if (SG_CODE_BUILDERP(o)) {
	r = Sg_Acons(o, SG_FALSE, r);
	/* we need to check it recursively */
	r = write_cache_pass1(SG_CODE_BUILDER(o), r, lib, sharedObjects, escape);
      }
      if (info->number == LIBRARY && lib != NULL) {
	/* LIBRARY instruction is a mark for this.
	   FIXME: actually I don't like this, so remove it.
	 */
	*lib = SG_LIBRARY(o);
	/* we know after this check we don't have any interest in
	   this object. so go to next.
	 */
	break;
      }
      if (!cachable_p(o)) longjmp(escape, 1);
      if (interesting_p(o)) {
	r = write_cache_scan(o, sharedObjects, r, escape);
      }
    }
    i += 1 + info->argc;
  }
  return r;
}

static void write_string_cache(SgPort *out, SgString *s, int tag)
{
  SgChar *str = SG_STRING_VALUE(s);
  int size = SG_STRING_SIZE(s);
  Sg_PutbUnsafe(out, tag);
  put_4byte(size);
  Sg_WritebUnsafe(out, (uint8_t*)str, 0, sizeof(SgChar) * size);
}

static void write_symbol_cache(SgPort *out, SgSymbol *s)
{
  write_string_cache(out, SG_SYMBOL(s)->name, (SG_INTERNED_SYMBOL(s)) ? INTERNED_SYMBOL_TAG : UNINTERNED_SYMBOL_TAG);
}

static void write_number_cache(SgPort *out, SgObject o)
{
  /* lazy way for now */
  SgObject str = Sg_NumberToString(o, 10, FALSE);
  write_string_cache(out, SG_STRING(str), NUMBER_TAG);
}

static int write_list_cache(SgPort *out, SgObject o, SgObject cbs, cache_ctx *ctx, int index)
{
  SgObject v = SG_NIL, t = SG_NIL;
  int first = FALSE;
  while (SG_PAIRP(o)) {
    if (!first && SG_TRUEP(Sg_HashTableRef(ctx->sharedObjects, o, SG_FALSE))) {
      Sg_HashTableSet(ctx->sharedObjects, o, SG_LIST1(SG_MAKE_INT(ctx->uid++)), 0);
      break;
    }
    if (!first && SG_INTP(Sg_HashTableRef(ctx->sharedObjects, o, SG_FALSE))) {
      break;
    } else {
      SG_APPEND1(v, t, SG_CAR(o));
      o = SG_CDR(o);
    }
    first = FALSE;
  }
  if (SG_NULLP(o)) {
    int size = Sg_Length(v);
    SgObject cp;
    Sg_PutbUnsafe(out, PLIST_TAG);
    put_4byte(size);
    SG_FOR_EACH(cp, v) {
      index = write_object_cache(out, SG_CAR(cp), cbs, ctx, index);
    }
  } else {
    int size = Sg_Length(v);
    SgObject cp, p;
    Sg_PutbUnsafe(out, DLIST_TAG);
    put_4byte(size);
    p = Sg_HashTableRef(ctx->sharedObjects, o, SG_FALSE);
    if (SG_PAIRP(p)) {
      put_word(out, SG_INT_VALUE(SG_CAR(p)), DEFINING_SHARED_TAG);
    }
    index = write_object_cache(out, o, cbs, ctx, index);
    p = Sg_HashTableRef(ctx->sharedObjects, o, SG_FALSE);
    if (SG_PAIRP(p)) {
      Sg_HashTableSet(ctx->sharedObjects, o, SG_CAR(p), 0);
    }
    SG_FOR_EACH(cp, v) {
      index = write_object_cache(out, SG_CAR(cp), cbs, ctx, index);
    }    
  }
  return index;
}

static int write_object_cache(SgPort *out, SgObject o, SgObject cbs, cache_ctx *ctx, int index)
{
  SgObject sharedState = Sg_HashTableRef(ctx->sharedObjects, o, SG_FALSE);
  if (SG_INTP(sharedState)) {
    put_word(out, SG_INT_VALUE(sharedState), LOOKUP_TAG);
    return index;
  } else if (SG_TRUEP(sharedState)) {
    int uid = ctx->uid++;
    put_word(out, uid, DEFINING_SHARED_TAG);
    Sg_HashTableSet(ctx->sharedObjects, o, SG_MAKE_INT(uid), 0);
  }

  if (!SG_PTRP(o)) {
    emit_immediate(out, o);
  } else if (SG_STRINGP(o)) {
    write_string_cache(out, SG_STRING(o), STRING_TAG);
  } else if (SG_SYMBOLP(o)) {
    write_symbol_cache(out, o);
  } else if (SG_KEYWORDP(o)) {
    write_string_cache(out, SG_KEYWORD(o)->name, KEYWORD_TAG);
  } else if (SG_NUMBERP(o)) {
    /* non fixnum number */
    write_number_cache(out, o);
  } else if (SG_BVECTORP(o)) {
    int size = SG_BVECTOR_SIZE(o), j;
    Sg_PutbUnsafe(out, (uint8_t)BYTE_VECTOR_TAG);
    put_4byte(size);
    for (j = 0; j < size; j++) {
      Sg_PutbUnsafe(out, SG_BVECTOR_ELEMENT(o, j));
    }
  } else if (SG_VECTORP(o)) {
    int size = SG_VECTOR_SIZE(o), j;
    Sg_PutbUnsafe(out, (uint8_t)VECTOR_TAG);
    put_4byte(size);
    for (j = 0; j < size; j++) {
      index = write_object_cache(out, SG_VECTOR_ELEMENT(o, j), cbs, ctx, index);
    }
  } else if (SG_PAIRP(o)) {
    index = write_list_cache(out, o, cbs, ctx, index);
  } else if (SG_IDENTIFIERP(o)) {
    write_string_cache(out, SG_SYMBOL(SG_IDENTIFIER(o)->name)->name, IDENTIFIER_TAG);
    write_object_cache(out, SG_LIBRARY(SG_IDENTIFIER_LIBRARY(o))->name, cbs, ctx, index);
  } else if (SG_CLOSUREP(o)) {
    index = write_cache_pass2(out, SG_CLOSURE(o)->code, cbs, ctx, index);
  } else if (SG_LIBRARYP(o)) {
    /* this must be macro's maybeLibrary */
    write_symbol_cache(out, SG_LIBRARY_NAME(o));
  } else if (SG_GLOCP(o)) {
    /* gloc is for performance thing, it can be replaced by identifier */
    SgObject name = SG_GLOC(o)->name;
    SgObject lib = SG_GLOC(o)->library;
    write_string_cache(out, SG_SYMBOL(name)->name, IDENTIFIER_TAG);
    write_object_cache(out, SG_LIBRARY(lib)->name, cbs, ctx, index);
  }
  return index;
}

static int write_cache_pass2(SgPort *out, SgCodeBuilder *cb, SgObject cbs, cache_ctx *ctx, int index)
{
  int i, len = cb->size;
  SgWord *code = cb->code;
  Sg_PutbUnsafe(out, CODE_BUILDER_TAG);
  put_4byte(len);
  /* code builder has argc, optional and freec as meta info.
     we need to cache it.
   */
  /* TODO: do we need more than 255 argument? */
  Sg_PutbUnsafe(out, cb->argc);
  /* optional is boolean. */
  Sg_PutbUnsafe(out, cb->optional);
  /* I don't think we need this much, but just in case */
  put_4byte(cb->freec);
  for (i = 0; i < len;) {
    InsnInfo *info = Sg_LookupInsnName(INSN(code[i]));
    int j;
    /* *tag* *len* insn */
    put_word(out, code[i], INSTRUCTION_TAG);
    for (j = 0; j < info->argc; j++) {
      SgObject o = SG_OBJ(code[i+j+1]);
      if (SG_CODE_BUILDERP(o)) {
	SgObject slot = Sg_Assq(o, cbs);
	/* never happen but just in case */
	if (SG_FALSEP(slot)) Sg_Panic("non collected compiled code appeared during writing cache.");
	/* set mark */
	SG_SET_CDR(slot, SG_MAKE_INT(index));
	Sg_PutbUnsafe(out, (uint8_t)MARK_TAG);
	put_4byte(2);
	/* maximum 0xffff index
	   i think this is durable.
	 */
	put_4byte(index);
	index++;
	continue;
      }
      index = write_object_cache(out, o, cbs, ctx, index);
    }
    i += 1 + info->argc;
  }
  /* mark end */
  Sg_PutbUnsafe(out, CODE_BUILDER_END_TAG);
  return index;
}

static void write_macro_cache(SgPort *out, SgLibrary *lib, SgObject cbs, int index, int uid, jmp_buf jbuf)
{
  SgObject keys = Sg_HashTableKeys(SG_LIBRARY_TABLE(lib));
  SgObject macros = SG_NIL, t = SG_NIL;
  SgObject cp, buffer;
  SgHashTable *shared = Sg_MakeHashTableSimple(SG_HASH_EQ, 200);
  cache_ctx ctx;

  SG_FOR_EACH(cp, keys) {
    SgObject key = SG_CAR(cp);
    SgObject bind = SG_GLOC(Sg_HashTableRef(SG_LIBRARY_TABLE(lib), key, SG_FALSE));
    if (!SG_FALSEP(bind)) {
      SgGloc *gloc = SG_GLOC(bind);
      SgObject value = SG_GLOC_GET(gloc);
      if (SG_MACROP(value)) {
	SG_APPEND1(macros, t, value);
      }
    }
  }
  /* again we need pass */
  SG_FOR_EACH(cp, macros) {
    SgObject macro = SG_CAR(cp);
    /* for usual macros */
    if (SG_CLOSUREP(SG_MACRO(macro)->data)) {
      cbs = Sg_Acons(SG_MACRO(macro)->data, SG_FALSE, cbs);
      /* we don't need to check library here */
      cbs = write_cache_pass1(SG_CLOSURE(SG_MACRO(macro)->data)->code, cbs, NULL, shared, jbuf); 
    }
    /* for make-variable-transformer */
    if (SG_CLOSUREP(SG_MACRO(macro)->transformer)) {
      cbs = Sg_Acons(SG_MACRO(macro)->transformer, SG_FALSE, cbs);
      /* we don't need to check library here */
      cbs = write_cache_pass1(SG_CLOSURE(SG_MACRO(macro)->transformer)->code, cbs, NULL, shared, jbuf); 
    }
  }
  /* write macro */
  ctx.sharedObjects = shared;
  ctx.uid = uid;
  buffer = Sg_MakeStringOutputPort(0);
  SG_FOR_EACH(cp, macros) {
    SgObject macro = SG_CAR(cp);
    int subrP = SG_SUBRP(SG_MACRO(macro)->transformer);
    Sg_PutbUnsafe(out, (subrP) ? MACRO_TRANSFORM_TAG : MACRO_TAG);
    put_4byte(1);		/* dummy */
    /* index is just dummy, so we don't have to care */
    write_object_cache(out, SG_MACRO(macro)->name, cbs, &ctx, index);
    /* reset buffer */
    Sg_SetPortPosition(buffer, 0);
    if (subrP) {
      index = write_object_cache(out, SG_MACRO(macro)->env, cbs, &ctx, index);
      index = write_object_cache(out, SG_CLOSURE(SG_MACRO(macro)->data)->code, cbs, &ctx, index);
      index = write_object_cache(out, SG_MACRO(macro)->maybeLibrary, cbs, &ctx, index);
    } else {
      index = write_object_cache(out, SG_MACRO(macro)->env, cbs, &ctx, index);
      index = write_object_cache(out, SG_CLOSURE(SG_MACRO(macro)->transformer)->code, cbs, &ctx, index);
      index = write_object_cache(out, SG_MACRO(macro)->maybeLibrary, cbs, &ctx, index);
    }
  }
}

int Sg_WriteCache(SgObject name, SgString *id, SgObject caches)
{
  SgVM *vm = Sg_VM();
  SgString *cache_path = id_to_filename(id);
  SgFile *file;
  SgPort *out;
  SgObject cache;
  int index = 0;

  if (SG_VM_LOG_LEVEL(vm, SG_DEBUG_LEVEL)) {
    Sg_Printf(vm->logPort, UC("caching id=%A cache=%A\n"), id, cache_path);
  }
  file = Sg_OpenFile(cache_path, SG_CREATE | SG_WRITE | SG_TRUNCATE);
  out = Sg_MakeFileBinaryOutputPort(file, SG_BUFMODE_BLOCK);

  SG_FOR_EACH(cache, caches) {
    if (SG_VM_LOG_LEVEL(vm, SG_DEBUG_LEVEL)) {
      Sg_VMDumpCode(SG_CAR(cache));
    }
    if ((index = write_cache(name, SG_CODE_BUILDER(SG_CAR(cache)), out, index)) < 0) return FALSE;
    name = SG_FALSE;
  }

  Sg_ClosePort(out);
  return FALSE;
}
/*
  cache structure:
  toplevel     ::= (library | code-builder)
  library      ::= (LIBRARY_TAG length object IMPORT_TAG length (object)* EXPORT_TAG length object BOUNDARY_TAG)
  code-builder ::= (CODE_BUILDER_TAG length (instruction (object)*) BOUNDARY_TAG)
  length       ::= [0-9] [0-9] [0-9] [0-9]
  object       ::= (symbol | string | keyword | identifer | vector | bytevector | code-builder)
  instruction  ::= INSN

  we can read object until BOUNDARY_TAG.
 */
typedef struct read_ctx_rec read_ctx;
static SgObject read_library(SgPort *in, read_ctx *ctx);
static SgObject read_code(SgPort *in, read_ctx *ctx);
static SgObject read_object(SgPort *in, read_ctx *ctx);

struct read_ctx_rec
{
  SgHashTable *sharedObjects;
  SgHashTable *seen;
  int isLinkNeeded;
};

static int read_4byte(SgPort *in)
{
  int a = Sg_GetbUnsafe(in);
  int b = Sg_GetbUnsafe(in);
  int c = Sg_GetbUnsafe(in);
  int d = Sg_GetbUnsafe(in);
  return ((a << 24) | (b << 16) | (c << 8) | d);
}

static SgWord read_word(SgPort *in, int tag_type)
{
  int len, i;
  SgWord ret = 0;
  int tag = Sg_GetbUnsafe(in);	/* discard tag */
  if (tag != tag_type) return SG_WORD(SG_FALSE);
  len = read_4byte(in);
  /* dd cc bb aa -> aa bb cc dd */
  for (i = 0; i < len; i++) {
    int b = Sg_GetbUnsafe(in);
    ret |= (b << (i * 8));
  }
  return ret;
}

static SgObject read_toplevel(SgPort *in, SgHashTable *seen)
{
  int b;
  read_ctx ctx;
  SgHashTable *shared = Sg_MakeHashTableSimple(SG_HASH_EQ, 0);
  ctx.sharedObjects = shared;
  ctx.isLinkNeeded = FALSE;
  ctx.seen = seen;
  while ((b = (int8_t)Sg_PeekbUnsafe(in)) != EOF) {
    if (b == -1) return SG_FALSE; /* invalid cache. */
    switch (b) {
    case LIBRARY_TAG:
      return read_library(in, &ctx);
    case CODE_BUILDER_TAG:
      return read_code(in, &ctx);
    default:
      /* broken cache */
      return SG_FALSE;
    }
  }
  return SG_FALSE;
}

static SgString* read_string(SgPort *in, int length)
{
  int size = sizeof(SgChar) * length;
  SgChar *buf = SG_NEW_ATOMIC2(SgChar *, size);
  Sg_ReadbUnsafe(in, (uint8_t*)buf, size);
  return Sg_MakeString(buf, SG_LITERAL_STRING);
}

static SgObject read_symbol(SgPort *in)
{
  int tag = Sg_GetbUnsafe(in);
  int length;
  SgString *name;
  if (tag != INTERNED_SYMBOL_TAG &&
      tag != UNINTERNED_SYMBOL_TAG) {
    return SG_FALSE;
  }
  length = read_4byte(in);
  name = read_string(in, length);
  return Sg_MakeSymbol(name, tag == INTERNED_SYMBOL_TAG);
}

static SgObject read_keyword(SgPort *in)
{
  int tag = Sg_GetbUnsafe(in);
  int length;
  SgString *name;
  if (tag != KEYWORD_TAG) {
    return SG_FALSE;
  }
  length = read_4byte(in);
  name = read_string(in, length);
  return Sg_MakeKeyword(name);
}

static SgObject read_immediate(SgPort *in)
{
  return SG_OBJ(read_word(in, IMMEDIATE_TAG));
}

static SgObject read_number(SgPort *in)
{
  int len, tag = Sg_GetbUnsafe(in);
  SgString *num;
  if (tag != NUMBER_TAG) return SG_FALSE;
  len = read_4byte(in);
  num = read_string(in, len);
  return Sg_StringToNumber(num, 10, FALSE);
}

static SgObject read_identifier(SgPort *in)
{
  int len, tag = Sg_GetbUnsafe(in);
  SgString *name;
  SgObject lib;
  if (tag != IDENTIFIER_TAG) return SG_FALSE;
  len = read_4byte(in);
  name = read_string(in, len);
  /* read library name */
  lib = read_symbol(in);
  if (SG_FALSEP(lib)) return SG_FALSE;
  lib = Sg_FindLibrary(lib, FALSE);
  return Sg_MakeIdentifier(Sg_Intern(name), SG_NIL, lib);
}

static SgObject read_bvector(SgPort *in)
{
  int len, tag = Sg_GetbUnsafe(in), i;
  SgByteVector *bv;
  if (tag != BYTE_VECTOR_TAG) return SG_FALSE;
  len = read_4byte(in);
  bv = Sg_MakeByteVector(len, 0);
  for (i = 0; i < len; i++) {
    int b = Sg_GetbUnsafe(in);
    SG_BVECTOR_ELEMENT(bv, i) = b;
  }
  return bv;
}

static SgObject read_vector(SgPort *in, read_ctx *ctx)
{
  int len, tag = Sg_GetbUnsafe(in), i;
  SgVector *vec;
  if (tag != VECTOR_TAG) return SG_FALSE;
  len = read_4byte(in);
  vec = Sg_MakeVector(len, SG_UNDEF);
  for (i = 0; i < len; i++) {
    SgObject o = read_object(in, ctx);
    SG_VECTOR_ELEMENT(vec, i) = o;
  }
  return vec;
}

static SgObject read_list(SgPort *in, read_ctx *ctx)
{
  int len, tag = Sg_GetbUnsafe(in), i;
  SgObject h = SG_NIL, t = SG_NIL, o;
  if (tag != PLIST_TAG &&
      tag != DLIST_TAG) return SG_FALSE;
  len = read_4byte(in);
  for (i = 0; i < len-1; i++) {
    SG_APPEND1(h, t, read_object(in, ctx));
  }
  /* last element */
  o = read_object(in, ctx);
  if (tag == PLIST_TAG) SG_APPEND1(h, t, o);
  else SG_SET_CDR(t, o);
  return h;
}

static SgObject read_macro(SgPort *in, read_ctx *ctx)
{
  int len, tag = Sg_GetbUnsafe(in), i;
  SgObject name, data, env, lib;
  if (tag != MACRO_TAG &&
      tag != MACRO_TRANSFORM_TAG) return SG_FALSE;
  len = read_4byte(in);
  name = read_object(in, ctx);
  env  = read_object(in, ctx);
  data = read_object(in, ctx);
  lib  = read_object(in, ctx);
  if (tag == MACRO_TRANSFORM_TAG) {
    return Sg_MakeMacroTransformer(name, data, env, lib);
  } else {
    return Sg_MakeMacro(name, data, SG_NIL, env, lib);
  }
}

static SgObject read_closure(SgPort *in, read_ctx *ctx)
{
  int num, tag = Sg_GetbUnsafe(in);
  SgObject cb;
  if (tag != CLOSURE_TAG) return SG_FALSE;
  num = read_4byte(in);
  cb = read_code(in, ctx);
  Sg_HashTableSet(ctx->seen, cb, SG_MAKE_INT(num), 0);
  /* Do we need free variables? */
  return cb;
}

static SgSharedRef* make_shared_ref(int mark)
{
  SgSharedRef *z = SG_NEW(SgSharedRef);
  SG_SET_HEADER(z, TC_SHAREDREF);
  z->index = SG_MAKE_INT(mark);
  return z;
}

static SgObject get_shared(SgObject index, read_ctx *ctx)
{
  SgObject obj = Sg_HashTableRef(ctx->sharedObjects, index, SG_UNBOUND);
  ASSERT(!SG_UNBOUNDP(obj));
  return obj;
}

static void read_cache_link(SgObject obj, SgHashTable *seen, read_ctx *ctx)
{
  if (SG_TRUEP(Sg_HashTableRef(seen, obj, SG_FALSE))) {
    return;
  }
  Sg_HashTableSet(seen, obj, SG_TRUE, 0);
  if (SG_PAIRP(obj)) {
    if (SG_SHAREDREF_P(SG_CAR(obj))) {
      SgObject index = SG_SHAREDREF(SG_CAR(obj))->index;
      SG_SET_CAR(obj, get_shared(index, ctx));
    } else {
      read_cache_link(SG_CAR(obj), seen, ctx);
    }
    if (SG_SHAREDREF_P(SG_CDR(obj))) {
      SgObject index = SG_SHAREDREF(SG_CDR(obj))->index;
      SG_SET_CDR(obj, get_shared(index, ctx));
    } else {
      read_cache_link(SG_CDR(obj), seen, ctx);
    }
    return;
  }
  if (SG_VECTORP(obj)) {
    int len = SG_VECTOR_SIZE(obj), i;
    for (i = 0; i < len; i++) {
      if (SG_SHAREDREF_P(SG_VECTOR_ELEMENT(obj, i))) {
	SgObject index = SG_SHAREDREF(SG_VECTOR_ELEMENT(obj, i))->index;
	SG_VECTOR_ELEMENT(obj, i) = get_shared(index, ctx);
      } else {
	read_cache_link(SG_VECTOR_ELEMENT(obj, i), seen, ctx);
      }
    }
    return;
  }
}

static SgObject read_object(SgPort *in, read_ctx *ctx)
{
  int tag = Sg_PeekbUnsafe(in);
  int length;
  SgObject obj;
  switch (tag) {
  case INSTRUCTION_TAG:
    obj = SG_OBJ(read_word(in, INSTRUCTION_TAG));
    break;
  case MARK_TAG: {
    int index;
    /* discards tag and length  */
    Sg_GetbUnsafe(in);
    read_4byte(in);
    index = read_4byte(in);
    obj = make_shared_ref(index);
    break;
  }
  case IMMEDIATE_TAG:
    obj = read_immediate(in);
    break;
  case LOOKUP_TAG: {
    int uid;
    SgObject o;
    Sg_GetbUnsafe(in);		/* discards */
    uid = read_4byte(in);
    o = Sg_HashTableRef(ctx->sharedObjects, SG_MAKE_INT(uid), SG_UNBOUND);
    if (SG_UNBOUNDP(o)) {
      ctx->isLinkNeeded = TRUE;
      obj = make_shared_ref(uid);
    } else {
      obj = o;
    }
    break;
  }
  case DEFINING_SHARED_TAG: {
    int uid;
    SgObject o;
    Sg_GetbUnsafe(in);		/* discards */
    uid = read_4byte(in);
    o = read_object(in, ctx);
    Sg_HashTableSet(ctx->sharedObjects, SG_MAKE_INT(uid), o, 0);
    obj = o;
    break;
  }
  case STRING_TAG: 
    Sg_GetbUnsafe(in);
    length = read_4byte(in);
    obj = read_string(in, length);
    break;
  case INTERNED_SYMBOL_TAG:
  case UNINTERNED_SYMBOL_TAG:
    obj = read_symbol(in);
    break;
  case KEYWORD_TAG:
    obj = read_keyword(in);
    break;
  case NUMBER_TAG:
    obj = read_number(in);
    break;
  case IDENTIFIER_TAG:
    obj = read_identifier(in);
    break;
  case BYTE_VECTOR_TAG:
    obj = read_bvector(in);
    break;
  case CLOSURE_TAG:
    obj = read_closure(in, ctx);
    break;
  case VECTOR_TAG:
    obj = read_vector(in, ctx);
    break;
  case PLIST_TAG: 
  case DLIST_TAG:
    obj = read_list(in, ctx);
    break;
  case MACRO_TAG:
  case MACRO_TRANSFORM_TAG:
    obj = read_macro(in, ctx);
    break;
  default:
    /* maybe broken cache. */
    return SG_FALSE;
  }
  if (ctx->isLinkNeeded) {
    read_cache_link(obj, Sg_MakeHashTableSimple(SG_HASH_EQ, 0), ctx);
  }
  return obj;
}

static SgObject read_library(SgPort *in, read_ctx *ctx)
{
  int length, tag, i;
  SgObject name, from, import, export;
  SgLibrary *lib;
  Sg_GetbUnsafe(in);		/* discard tag */
  length = read_4byte(in);	/* length is import spec length */
  name = read_symbol(in);
  if (SG_FALSEP(name)) return SG_FALSE;
  /* if vm is reading a cache, which means library is not loaded yet.
     so we need to create it.
   */
  lib = Sg_MakeLibrary(name);
  tag = Sg_GetbUnsafe(in);
  if (tag != IMPORT_TAG) return SG_FALSE;
  length = read_4byte(in);		/* we don't need IMPORT_TAG's length  */
  for (i = 0; i < length; i++) {
    from = read_object(in, ctx);
    import = read_object(in, ctx);
    /* import must be (only rename except prefix)
       see library.c
     */
    Sg_ImportLibraryFullSpec(lib, Sg_FindLibrary(from, FALSE), SG_CAR(import),
			     SG_CADR(import), SG_CAR(SG_CDDR(import)),
			     SG_CADR(SG_CDDR(import)));
  }
  /* read export */
  tag = Sg_GetbUnsafe(in);
  if (tag != EXPORT_TAG) return SG_FALSE;
  read_4byte(in);		/* we don't need EXPORT_TAG's length */
  export = read_object(in, ctx);
  lib->exported = export;

  tag = Sg_GetbUnsafe(in);
  if (tag != BOUNDARY_TAG) return SG_FALSE;

  return lib;
}

static SgObject read_code(SgPort *in, read_ctx *ctx)
{
  int len, tag = Sg_GetbUnsafe(in), argc, optional, freec, index;
  SgWord *code;
  if (tag != CODE_BUILDER_TAG) return SG_FALSE;
  len = read_4byte(in);
  argc = Sg_GetbUnsafe(in);
  optional = Sg_GetbUnsafe(in);
  freec = read_4byte(in);
  code = SG_NEW_ARRAY(SgWord, len);
  /* now we need to construct code builder */
  index = 0;
  while ((tag = Sg_PeekbUnsafe(in)) != BOUNDARY_TAG) {
    code[index++] = SG_WORD(read_object(in, ctx));
  }
  /* link code builder */
  return Sg_MakeCodeBuilderFromCache(code, len, argc, optional, freec);
}

int Sg_ReadCache(SgString *id)
{
  SgVM *vm = Sg_VM();
  SgString *cach_path = id_to_filename(id);
  SgFile *file;
  SgPort *in;
  SgObject obj;
  SgHashTable *seen = Sg_MakeHashTableSimple(SG_HASH_EQ, 0);
  SgLibrary *save = vm->currentLibrary;

  if (!Sg_FileExistP(cach_path)) {
    return RE_CACHE_NEEDED;
  }
  file = Sg_OpenFile(cach_path, SG_READ);
  in = Sg_MakeFileBinaryInputPort(file, SG_BUFMODE_BLOCK);

  while ((obj = read_toplevel(in, seen)) != SG_FALSE) {
    if (SG_LIBRARYP(obj)) {
      save = vm->currentLibrary;
      vm->currentLibrary = SG_LIBRARY(obj);
      continue;
    }
    /* obj must be cb */
    Sg_VMExecute(obj);
    if (!SG_LIBRARYP(obj))
      vm->currentLibrary = save;
  }
  return RE_CACHE_NEEDED;
}
