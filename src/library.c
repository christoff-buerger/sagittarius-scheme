/* -*- C -*- */
/*
 * library.c
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
#include <sagittarius/config.h>
#ifndef __GNUC__
# ifdef HAVE_ALLOCA_H
#  include <alloca.h>
# else
#  ifdef _AIX
#pragma alloca
#  else
#   ifndef alloca /* predefined by HP cc +Olibcalls */
char *alloca ();
#   endif
#  endif
# endif
#else
# ifdef HAVE_ALLOCA_H
#  include <alloca.h>
# endif
# ifdef HAVE_MALLOC_H
/* MinGW helds alloca() in "malloc.h" instead of "alloca.h" */
#  include <malloc.h>
# endif
#endif

/* To secure the cache file between processes */
#ifdef HAVE_SEMAPHORE_H
/* if the platform have semaphore.h then it must have the rest 2 files. */
# include <fcntl.h>
# include <sys/stat.h>
# include <semaphore.h>
#endif

#include <ctype.h>
#define LIBSAGITTARIUS_BODY
#include "sagittarius/library.h"
#include "sagittarius/pair.h"
#include "sagittarius/file.h"
#include "sagittarius/hashtable.h"
#include "sagittarius/string.h"
#include "sagittarius/keyword.h"
#include "sagittarius/number.h"
#include "sagittarius/symbol.h"
#include "sagittarius/writer.h"
#include "sagittarius/error.h"
#include "sagittarius/vm.h"
#include "sagittarius/port.h"
#include "sagittarius/load.h"
#include "sagittarius/system.h"
#include "sagittarius/gloc.h"
#include "sagittarius/compare.h"
#include "sagittarius/thread.h"
#include "sagittarius/cache.h"
#include "sagittarius/reader.h"
#include "sagittarius/unicode.h"
#include "sagittarius/identifier.h"
#include "sagittarius/builtin-keywords.h"
#include "sagittarius/builtin-symbols.h"

static void library_print(SgObject obj, SgPort *port, SgWriteContext *ctx)
{
  SgLibrary *lib = obj;
  Sg_Putuz(port, UC("#<library "));
  Sg_Write(lib->name, port, SG_WRITE_DISPLAY);
  Sg_Putc(port, '>');
}

SG_DEFINE_BUILTIN_CLASS_SIMPLE(Sg_LibraryClass, library_print);

static SgLibrary* make_library()
{
  SgLibrary *z = SG_NEW(SgLibrary);
  SG_SET_CLASS(z, SG_CLASS_LIBRARY);
  z->table = Sg_MakeHashTableSimple(SG_HASH_EQ, 1024);
  z->imported = SG_NIL;
  z->exported = SG_FALSE;
  z->defined = SG_NIL;
  z->version = SG_NIL;
  z->parents = SG_NIL;
  z->reader = SG_FALSE;
  Sg_InitMutex(&z->lock, FALSE);
  return z;
}

/* return library id and version pair
   cf ((lib name) . (1 2))
 */
static void check_version_reference(SgObject name, SgObject o)
{
  SG_FOR_EACH(o, o) {
    SgObject v = SG_CAR(o);
    if (!(SG_EXACT_INTP(v) && !Sg_NegativeP(v)) && 
	/* version symbols */
	!(SG_EQ(v, SG_SYMBOL_LESS_EQUAL) ||
	  SG_EQ(v, SG_SYMBOL_GREATER_EQUAL) ||
	  SG_EQ(v, SG_SYMBOL_OR) ||
	  SG_EQ(v, SG_SYMBOL_AND) ||
	  SG_EQ(v, SG_SYMBOL_NOT))) {
      if (SG_PAIRP(v)) {
	/* check recursively */
	check_version_reference(name, v);
      } else {
	Sg_Error(UC("malformed library version %S"), name);
      }
    }
  }
  if (!SG_NULLP(o)) {
    Sg_Error(UC("malformed library version %S"), name);
  }
}

static SgObject library_name_to_id_version(SgObject name)
{
  SgObject h = SG_NIL, t = SG_NIL, cp;
  if (!SG_NULLP(name) && SG_PAIRP(name)) {
    int len = Sg_Length(name);
    if (len >= 0) {
      SG_FOR_EACH(cp, name) {
	SgObject o = SG_CAR(cp);
	if (SG_SYMBOLP(o) || SG_KEYWORDP(o)) {
	  SG_APPEND1(h, t, o);
	} else if (SG_IDENTIFIERP(o)) {
	  SG_APPEND1(h, t, SG_IDENTIFIER_NAME(o));
	} else if (SG_EXACT_INTP(o)) {
	  /* R7RS allow unsigned exact integer as a library name */
	  if (Sg_Sign(o) < 0) {
	    Sg_Error(UC("malformed library name %S"), name);
	  }
	  SG_APPEND1(h, t, o);
	} else if (SG_LISTP(o) && SG_NULLP(SG_CDR(cp))) {
	  check_version_reference(name, o);
	  return Sg_Cons(h, o);
	} else {
	  Sg_Error(UC("malformed library name %S"), name);
	}
      }
      /* no version number */
      return Sg_Cons(h, SG_NIL);
    }
    /* fall throughw */
  } else if (SG_SYMBOLP(name)) {
    /* must be 'null' or 'user' but we won't check */
    return Sg_Cons(name, SG_NIL);
  }
  Sg_Error(UC("malformed library name %S"), name);
  return SG_UNDEF;		/* dummy */
}

static SgSymbol* convert_name_to_symbol(SgObject name)
{
  if (SG_STRINGP(name)) return Sg_Intern(name);
  else if (SG_SYMBOLP(name)) return SG_SYMBOL(name);
  else if (SG_PAIRP(name))  return Sg_Intern(Sg_Sprintf(UC("%L"), name));
  else Sg_Error(UC("invalid library name %S"), name);
  return SG_UNDEF;		/* dummy */
}

/* 
   All libraries are stored here.
 */
static struct
{
  SgHashTable *libraries;
  SgInternalMutex mutex;
} libraries = { SG_OBJ(SG_UNDEF), };

#define ALL_LIBRARIES      libraries.libraries
#define MUTEX              libraries.mutex
/* #ifdef HAVE_SEMAPHORE_H */
/* this actually doesn't solve the problem plus causes dead lock.  */
#if 0
static sem_t *process_lock = NULL;
# define SEMAPHORE_NAME "/sagittarius-semaphore"
# define LOCK_LIBRARIES()					\
  do {								\
    process_lock = sem_open(SEMAPHORE_NAME, O_CREAT,		\
			    S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH);	\
    sem_wait(process_lock);					\
    Sg_LockMutex(&MUTEX);					\
  } while (0)
# define UNLOCK_LIBRARIES()			\
  do {						\
    Sg_UnlockMutex(&MUTEX);			\
    sem_close(process_lock);			\
    sem_unlink(SEMAPHORE_NAME);			\
  } while (0)
#else
/* Most definitely Windows and its mutex can lock process,
   if I understand correctly. */
# define LOCK_LIBRARIES()   Sg_LockMutex(&MUTEX)
# define UNLOCK_LIBRARIES() Sg_UnlockMutex(&MUTEX)
#endif


static void add_library(SgLibrary *lib)
{
  LOCK_LIBRARIES();
  Sg_HashTableSet(ALL_LIBRARIES, SG_LIBRARY_NAME(lib), lib, 
		  SG_HASH_NO_OVERWRITE);
  UNLOCK_LIBRARIES();
}

static void remove_library(SgLibrary *lib)
{
  LOCK_LIBRARIES();
  Sg_HashTableDelete(ALL_LIBRARIES, SG_LIBRARY_NAME(lib));
  SG_LIBRARY_TABLE(lib) = NULL;	/* gc friendliness */
  UNLOCK_LIBRARIES();
}

SgObject Sg_MakeLibrary(SgObject name)
{
  SgLibrary *z = make_library();
  SgVM *vm = Sg_VM();
  /* TODO if it's from Sg_FindLibrary, this is processed twice. */
  SgObject id_version = library_name_to_id_version(name);
  
  z->name = convert_name_to_symbol(SG_CAR(id_version));
  z->version = SG_CDR(id_version);

  add_library(z);

  if (SG_VM_LOG_LEVEL(vm, SG_DEBUG_LEVEL)) {
    Sg_Printf(vm->logPort, UC(";; library %S has been created\n"), name);
  }
  return SG_OBJ(z);
}

/* creates anonymous library */
SgObject Sg_MakeEvalLibrary()
{
  SgObject name = Sg_MakeSymbol(SG_MAKE_STRING("(eval environment)"), FALSE);
  return Sg_MakeChildLibrary(Sg_VM(), name);
}

SgObject Sg_MakeChildLibrary(SgVM *vm, SgObject name)
{
  SgLibrary *z = make_library();
  z->name = name;
  z->version = SG_FALSE;
  z->init = NULL;		/* well in case */
  /* add_library(z); */
  return z;
}

void Sg_RemoveLibrary(SgLibrary *lib)
{
  remove_library(lib);
}

static int need_encode(SgChar ch, SgChar *h, SgChar *l)
{
  if (!isalnum(ch) &&
      (ch == '/'  ||
       ch == '\\' ||
       ch == ':'  ||
       ch == '*'  ||
       ch == '?'  ||
       ch == '"'  ||
       ch == '<'  ||
       ch == '>'  ||
       ch == '|')){
    int high = (ch >> 4) & 0xF;
    int low  = ch & 0xF;
    if (h) {
      *h = (high < 0xa) ? high + '0' : high + 0x57;
    }
    if (l) {
      *l = (low < 0xa) ? low + '0' : low + 0x57;
    }
    return TRUE;
  } else if (ch >= 128) {
    Sg_Error(UC("multi byte characters are not supported"
		" for library name. %A"), SG_MAKE_CHAR(ch));
    return FALSE;		/* dummy */
  } else {
    return FALSE;
  }
}
static SgString* encode_string(SgString *s, int keywordP)
{
  SgString *r;
  int size = SG_STRING_SIZE(s), i, offset;
  SgChar high, low;
  if (keywordP) size += 3;	/* extra %3a */
  /* calculate size */
  for (i = 0; i < SG_STRING_SIZE(s); i++) {
    if (need_encode(SG_STRING_VALUE_AT(s, i), NULL, NULL)) {
      size += 2;
    }
  }
  r = Sg_ReserveString(size, 0);
  offset = 0;
  if (keywordP) {
    SG_STRING_VALUE_AT(r, offset++) = '%';
    SG_STRING_VALUE_AT(r, offset++) = '3';
    SG_STRING_VALUE_AT(r, offset++) = 'a';
  }
  for (i = 0; i < SG_STRING_SIZE(s); i++) {
    if (need_encode(SG_STRING_VALUE_AT(s, i), &high, &low)) {
      SG_STRING_VALUE_AT(r, offset++) = '%';
      SG_STRING_VALUE_AT(r, offset++) = high;
      SG_STRING_VALUE_AT(r, offset++) = low;
    } else {
      SG_STRING_VALUE_AT(r, offset++) = SG_STRING_VALUE_AT(s, i);
    }
  }
  return r;
}

/*
  library path convertion must be like this.
   (lib a b (1)) -> lib/a/b
   we only manage library id, not version on file system.
 */
static SgString* library_name_to_path(SgObject name)
{
  const SgObject separator = Sg_MakeString(Sg_NativeFileSeparator(),
					   SG_LITERAL_STRING);
  SgObject item;
  /* i'm not sure which is better memory. 
     - create a list and string.
     - append string each time.
     TODO profile.
   */
  SgObject h = SG_NIL, t = SG_NIL;

  if (!SG_PAIRP(name)) {
    /* for cache */
    SgObject in = Sg_MakeStringInputPort(SG_SYMBOL(name)->name, TRUE);
    name = Sg_Read(in, TRUE);
  }

  SG_FOR_EACH(item, name) {
    if (SG_SYMBOLP(SG_CAR(item))) {
      SgObject o = encode_string(SG_SYMBOL(SG_CAR(item))->name, FALSE);
      SG_APPEND1(h, t, o);
    } else if (SG_KEYWORDP(SG_CAR(item))) {
      /* for srfi-97.
	 NB: when I create srfi library, it must be #!compatible or #!core
	 or else :1 won't be a keyword.
       */
      SgObject o = encode_string(SG_KEYWORD(SG_CAR(item))->name, TRUE);
      SG_APPEND1(h, t, o);
    } else if (SG_EXACT_INTP(SG_CAR(item))) {
      SgObject o;
      if (Sg_Sign(SG_CAR(item)) < 0) goto error;
      o = Sg_NumberToString(SG_CAR(item), 10, FALSE);
      SG_APPEND1(h, t, o);
    } else {
    error:
      Sg_Error(UC("library name can contain only symbols, keywords or"
		  " unsigned exact integers"
		  " but got %S"), SG_CAR(item));
    }
    if (!SG_NULLP(SG_CDR(item))) {
      SG_APPEND1(h, t, separator);
    }
  }
  return Sg_StringAppend(h);
}

static SgObject extensions = NULL;
static SgObject userlib = NULL;
/*
   this takes only library name part. we don't manage version
   on file system.
 */
#ifndef MAXPATHLEN
#define MAXPATHLEN 1024
#endif

/* FIXME the same as in string.c */
#ifdef _MSC_VER
/* _alloca is in <malloc.h> */
#include <malloc.h>
#define alloca _alloca
#endif

#define STRING_ALLOC_SIZE(size)			\
  (sizeof(SgString)+sizeof(SgChar)*size)

#ifdef HAVE_ALLOCA
#define ALLOC_TEMP_STRING(var, size)					\
  do {									\
    (var) = SG_STRING(alloca(STRING_ALLOC_SIZE(size)));			\
    SG_SET_CLASS(var, SG_CLASS_STRING);					\
    SG_STRING_SIZE(var) = (size);					\
  } while (0)
#else
#define ALLOC_TEMP_STRING(var, size) (var) = Sg_ReserveString(size, 0);
#endif

#define copy_string(dst, offset, src, start)				\
  do {									\
    int __i;								\
    for (__i = 0; __i < SG_STRING_SIZE(src)-(start); __i++) {		\
      SG_STRING_VALUE_AT(dst, __i+(offset)) =				\
	SG_STRING_VALUE_AT(src, __i+(start));				\
    }									\
  } while(0)


#define copy_string0(dst, src, offset) \
  do {				       \
    copy_string(dst, offset, src, 0);  \
    (offset) += SG_STRING_SIZE(src);   \
  } while (0)

#define copy_uz(dst, src, offset, len)				\
  do {								\
    int __i;							\
    for (__i = 0; __i < (len); __i++) {				\
      SG_STRING_VALUE_AT(dst, __i+(offset))=(src)[__i];		\
    }								\
    (offset) += (len);						\
  } while(0)

static SgObject get_possible_paths(SgVM *vm, SgObject name)
{
  /* length of '.sagittarius' */
#define SPECIFIC_SIZE 12
  static const char *specific = ".sagittarius";

  SgString *path;
  SgObject ext, paths = SG_NIL, t = SG_NIL;
  SgString *buf;
  const SgChar *sep = Sg_NativeFileSeparator();
  size_t sep_size = ustrlen(sep);

  path = library_name_to_path(name);
  ALLOC_TEMP_STRING(buf, MAXPATHLEN);
/* to save some memory */
#define check_length(len) if (MAXPATHLEN < offset+(len)) break;
  
  SG_FOR_EACH(ext, extensions) {
    SgObject dir;
    int offset = 0, save, first = TRUE;
    SG_FOR_EACH(dir, vm->loadPath) {
      /* first specific otherwise it won't handle specific file properly */
      check_length(SG_STRING_SIZE(SG_CAR(dir)));
      copy_string0(buf, SG_CAR(dir), offset);
      check_length(sep_size);
      copy_uz(buf, sep, offset, sep_size);
      check_length(SG_STRING_SIZE(path));
      copy_string0(buf, path, offset);

      save = offset;
      check_length(SPECIFIC_SIZE);
      copy_uz(buf, specific, offset, SPECIFIC_SIZE);
    second:
      check_length(SG_STRING_SIZE(SG_CAR(ext)));
      copy_string0(buf, SG_CAR(ext), offset);
      SG_STRING_VALUE_AT(buf, offset) = 0;
      SG_STRING_SIZE(buf) = offset;
      if (Sg_FileExistP(buf)) {
	SG_APPEND1(paths, t, Sg_AbsolutePath(buf));
      }
      if (first) {
	first = FALSE;
	offset = save;
	goto second;
      }
      /* reset */
      offset = save = 0;
      first = TRUE;
    }
  }
#undef check_length
  return paths;
}

static SgObject search_library(SgObject name, int onlyPath)
{
  SgObject libname, lib, paths;
  SgVM *vm = Sg_VM();

  /* pre-check if the library is already compiled, then we don't
     want to search real path */
  if (!onlyPath) {
    libname = convert_name_to_symbol(name);
    LOCK_LIBRARIES();
    lib = Sg_HashTableRef(ALL_LIBRARIES, libname, SG_FALSE);
    if (!SG_FALSEP(lib)) {
      UNLOCK_LIBRARIES();
      return lib;
    }
    UNLOCK_LIBRARIES();
  }
  paths = get_possible_paths(vm, name);
  if (onlyPath) return paths;

  libname = convert_name_to_symbol(name);  
  SG_FOR_EACH(paths, paths) {
    SgObject r;
    SgObject path = SG_STRING(SG_CAR(paths));
    /* this must creates a new library */
    if (Sg_FileExistP(path)) {
      int state;
      /* once library is created, then it must not be re-created.
	 so we need to get lock for reading cache. */
      LOCK_LIBRARIES();
      lib = Sg_HashTableRef(ALL_LIBRARIES, libname, SG_FALSE);
      if (!SG_FALSEP(lib)) {
	UNLOCK_LIBRARIES();
	return lib;
      }
      state = Sg_ReadCache(path);
      if (state != CACHE_READ) {
	int save = vm->state;
	SgObject saveLib = vm->currentLibrary;
	if (userlib == NULL) {
	  userlib = Sg_FindLibrary(SG_INTERN("user"), FALSE);
	}
	vm->state = IMPORTING;
	/* creates new cache */
	vm->cache = Sg_Cons(SG_NIL, vm->cache);
	/* if find-library called inside of library and the library does not
	   import (sagittarius) it can not compile.*/
	vm->currentLibrary = userlib;
	Sg_Load(path);		/* check again, or flag? */
	vm->currentLibrary = saveLib;
	/* if Sg_ReadCache returns INVALID_CACHE, then we don't have to write
	   it. it's gonna be invalid anyway.
	*/
	if (state == RE_CACHE_NEEDED) {
	  /* write cache */
	  Sg_WriteCache(name, path, Sg_ReverseX(SG_CAR(vm->cache)));
	}
	/* we don't need the first cache, so discard it */
	vm->cache = SG_CDR(vm->cache);
	/* restore state */
	vm->state = save;
      }
      UNLOCK_LIBRARIES();
    } else {
      /* first creation or no file. */
      return SG_FALSE;
    }
    r = Sg_HashTableRef(ALL_LIBRARIES, libname, SG_FALSE);
    /*
      in case of the same base name but different extension.
    */
    if (!SG_FALSEP(r)) {
      if (!SG_FALSEP(SG_LIBRARY_DEFINEED(r)))
	SG_LIBRARY_DEFINEED(r) = SG_NIL;
      return r;
    }
  }
  return SG_FALSE;
}

/* for cache */
SgObject Sg_SearchLibraryPath(SgObject name)
{
  SgObject id_version = library_name_to_id_version(name);
  SgObject path = search_library(SG_CAR(id_version), TRUE);
  return path;
}

SgObject Sg_FindLibrary(SgObject name, int createp)
{
  SgObject lib;
  SgObject id_version;

  /* fast path. for define-syntax. see compiler.scm */
  if (SG_LIBRARYP(name)) {
    return name;
  }
  id_version = library_name_to_id_version(name);
  lib = Sg_HashTableRef(ALL_LIBRARIES,
			convert_name_to_symbol(SG_CAR(id_version)), SG_FALSE);
  /* TODO check version number */
  if (SG_FALSEP(lib)) {
    if (createp) {
      return Sg_MakeLibrary(name);
    } else {
      lib = search_library(SG_CAR(id_version), FALSE);
#if 0
      if (SG_FALSEP(lib)) {
	Sg_Error(UC("no library named %S"), name);
      }
#endif
    }
  } else if (SG_LIBRARY(lib)->init) {
    void (*init)() = SG_LIBRARY(lib)->init;
    SG_LIBRARY(lib)->init = NULL;
    init();
  }
  return lib;
}


SgObject Sg_SearchLibrary(SgObject lib)
{
  SgObject id_version;
  /* i'm not sure if i need this, but just in case */
  if (SG_LIBRARYP(lib)) {
    return lib;
  }
  id_version = library_name_to_id_version(lib);
  return search_library(SG_CAR(id_version), FALSE);
}

#define ENSURE_LIBRARY(o, e)						\
  if (SG_LIBRARYP(o)) {							\
    e = SG_LIBRARY(o);							\
  } else {								\
    e = Sg_FindLibrary((o), FALSE);					\
    if (SG_FALSEP(e)) {							\
      Sg_Error(UC("no library named %S"), o);				\
    }									\
  }

static SgObject import_parents(SgLibrary *fromlib, SgObject spec)
{
  SgObject parents = fromlib->parents;
  /* we need to check if fromlib's export spec exports variables */
  SgObject exported = SG_NIL, cp;
  SG_FOR_EACH(cp, parents) {
    SgObject lib = SG_CAAR(cp);
    SgObject alist = SG_CDAR(cp);
    SgObject h = SG_NIL, t = SG_NIL;
    if (!SG_NULLP(alist) && SG_EQ(fromlib, SG_CAR(alist))) {
      SG_APPEND(h, t, Sg_Cons(lib, spec));
    }
    if (!SG_NULLP(h)) {
      exported = Sg_Acons(lib, h, exported);
    }
  }
  return exported;
}

static void import_reader_macro(SgLibrary *to, SgLibrary *from)
{
  /* try */
  if (SG_LIBRARY_READTABLE(from)) {
    SG_LIBRARY_READTABLE(to) = Sg_CopyReadTable(SG_LIBRARY_READTABLE(from));
  }
}

/*
  To keep imported library be resolved by imported order, we need to do some
  ugly trick. The goal for the trick is importing libraries parents order
  like this;

  ;; importing
  ;; foo has parent library (foo parent) and (foo) is exporting its variable.
  (import (buzz))
  (import (foo) (bar))
  
  library parents must be like this;
  ((#<(bar)> ...)
   (#<(foo)> ...)
   (#<(foo parent)> ...)
   (#<(buzz)> ...))

  The purpos for this is, if (buzz) contains the same exported variable as
  (foo parent) does, then (foo parent)'s one must be used. R6RS actually
  prohibits this behaviour, however it's inconvenient for me. So we allow to
  overwrite exported variables and resolve it as it's imported.
 */
void Sg_ImportLibraryFullSpec(SgObject to, SgObject from, SgObject spec)
{
  SgLibrary *tolib, *fromlib;
  SgObject parents, slot, exportSpec;
  SgVM *vm = Sg_VM();

  ENSURE_LIBRARY(to, tolib);
  ENSURE_LIBRARY(from, fromlib);
  Sg_LockMutex(&tolib->lock);

  slot = Sg_Cons(fromlib, SG_NIL);
  exportSpec = SG_LIBRARY_EXPORTED(fromlib);
  if (SG_VM_LOG_LEVEL(vm, SG_DEBUG_LEVEL)) {
    Sg_Printf(vm->logPort, UC(";; importing library (from %S, to %S)\n"),
	      SG_LIBRARY_NAME(from), SG_LIBRARY_NAME(to));
  }
  SG_LIBRARY_IMPORTED(tolib) = Sg_Acons(fromlib, spec,
					SG_LIBRARY_IMPORTED(tolib));
  {
    /* means something is defined, we add all information here */
    SgObject h = SG_NIL, t = SG_NIL;
    SG_APPEND(h, t, Sg_Cons(fromlib, spec));
    SG_SET_CDR(slot, h);
  }
  parents = import_parents(fromlib, spec);

  tolib->parents = Sg_Append2X(Sg_Cons(slot, parents), tolib->parents);
  if (!SG_FALSEP(exportSpec)) {
    if (!SG_FALSEP(Sg_Memq(SG_KEYWORD_EXPORT_READER_MACRO,
			   SG_CAR(exportSpec)))) {
      import_reader_macro(tolib, fromlib);
    }
    if (!SG_FALSEP(Sg_Memq(SG_KEYWORD_EXPORT_READER, SG_CAR(exportSpec)))) {
      SG_LIBRARY_READER(tolib) = SG_LIBRARY_READER(fromlib);
    }
  } else {
    import_reader_macro(tolib, fromlib);
    SG_LIBRARY_READER(tolib) = SG_LIBRARY_READER(fromlib);
  }

  Sg_UnlockMutex(&tolib->lock);
}

void Sg_LibraryExportedSet(SgObject lib, SgObject exportSpec)
{
  SgLibrary *l;
  ENSURE_LIBRARY(lib, l);
  SG_LIBRARY_EXPORTED(l) = exportSpec;
}

SgGloc* Sg_MakeBinding(SgLibrary *lib, SgSymbol *symbol,
		       SgObject value, int flags)
{
  SgGloc *g;
  SgObject v;
  SgObject oldval = SG_UNDEF;
  int prev_const = FALSE;
  Sg_LockMutex(&lib->lock);

  v = Sg_HashTableRef(lib->table, symbol, SG_FALSE);
  if (SG_GLOCP(v)) {
    g = SG_GLOC(v);
    prev_const = Sg_GlocConstP(g);
    oldval = SG_GLOC_GET(g);
  } else {
    g = SG_GLOC(Sg_MakeGloc(symbol, lib));
    Sg_HashTableSet(lib->table, symbol, SG_OBJ(g), 0);
  }
  Sg_UnlockMutex(&lib->lock);

  SG_GLOC_SET(g, value);
  /* NB: for now, only TRUE or FALSE */
  g->constant = flags;

  if (prev_const) {
    if (prev_const != flags || !Sg_EqualP(value, oldval)) {
      Sg_Warn(UC("constant value %S bounded with %S was overwitten by %S"),
	      oldval, symbol, value);
    }
  }
  return g;
}

/* utility */
static SgObject cadr_assq(SgObject v, SgObject l)
{
  SgObject cp;
  SG_FOR_EACH(cp, l) {
    SgObject slot = SG_CAR(cp);
    if (SG_PAIRP(slot) && SG_EQ(v, SG_CADR(slot))) return slot;
  }
  return SG_FALSE;
}

static SgObject two_memq(SgObject v1, SgObject v2, SgObject l)
{
  SgObject cp;
  SG_FOR_EACH(cp, l) {
    SgObject o = SG_CAR(cp);
    if (SG_EQ(v1, o) || SG_EQ(v2, o)) return o;
  }
  return SG_FALSE;
}

/*
  To save some memory allocation, we resolve variables renaming at runtime.
  The library parents structure is now like this;
  ((<lib> <parent-lib> . <import spec>) ...)
 */
static SgObject unrename_variable(SgObject key, SgObject specs)
{
  SgObject cp;

  if (SG_NULLP(specs)) return key;

  SG_FOR_EACH(cp, specs) {
    SgObject spec = SG_CAR(cp);
    if (SG_EQ(SG_CAR(spec), SG_SYMBOL_ONLY)) {
      if (SG_FALSEP(Sg_Memq(key, SG_CDR(spec)))) return SG_FALSE;
    } else if (SG_EQ(SG_CAR(spec), SG_SYMBOL_RENAME)) {
      if (SG_FALSEP(Sg_Assq(key, SG_CDR(spec)))) {
	SgObject rename = cadr_assq(key, SG_CDR(spec));
	if (!SG_FALSEP(rename)) key = SG_CAR(rename);
      } else {
	return SG_FALSE;
      }
    } else if (SG_EQ(SG_CAR(spec), SG_SYMBOL_EXCEPT)) {
      if (!SG_FALSEP(Sg_Memq(key, SG_CDR(spec)))) return SG_FALSE;
    } else if (SG_EQ(SG_CAR(spec), SG_SYMBOL_PREFIX)) {
      SgObject prefix, name, buf;
      int i;
      name = SG_SYMBOL(key)->name;
      prefix = SG_SYMBOL(SG_CDR(spec))->name;
      /* obvious case */
      if (SG_STRING_SIZE(name) < SG_STRING_SIZE(prefix)) return SG_FALSE;
      for (i = 0; i < SG_STRING_SIZE(prefix); i++) {
	if (SG_STRING_VALUE_AT(prefix, i) != SG_STRING_VALUE_AT(name, i))
	  return SG_FALSE;
      }
      ALLOC_TEMP_STRING(buf, SG_STRING_SIZE(name) - i);
      copy_string(buf, 0, name, i);
      key = Sg_Intern(buf);
    }
  }
  return key;
}

SgGloc* Sg_FindBinding(SgObject library, SgObject name, SgObject callback)
{
  SgLibrary *lib;
  SgObject ret;
  ASSERT(SG_SYMBOLP(name));

  if (SG_LIBRARYP(library)) lib = SG_LIBRARY(library);
  else if (SG_FALSEP(library)) lib = Sg_VMCurrentLibrary();
  else lib = Sg_FindLibrary(library, FALSE);
  if (SG_FALSEP(lib)) return callback;

 reent:
  /* first look up from library table */
  ret = Sg_HashTableRef(SG_LIBRARY_TABLE(lib), name, SG_UNBOUND);
  if (SG_UNBOUNDP(ret)) {
    /* second we need to look up from parents */
    SgObject cp;
    SG_FOR_EACH(cp, lib->parents) {
      /* (<lib> <parent-lib> . spec) */
      SgObject head = SG_CAR(cp);
      SgObject plib = SG_CADR(head), spec = SG_CDDR(head);
      /* TODO reverse it in compile time */
      SgObject unrenamed = unrename_variable(name, spec);
      if (!SG_FALSEP(unrenamed)) {
	/* if parent exports it, do it recursively */
	SgObject pexport = SG_LIBRARY_EXPORTED(plib);
	SgObject slot = SG_FALSE;
	SgObject mq = SG_FALSE;
	if (SG_FALSEP(pexport) ||
	    !SG_FALSEP((mq = two_memq(unrenamed, SG_KEYWORD_ALL, 
				      SG_CAR(pexport)))) ||
	    !SG_FALSEP((slot = cadr_assq(unrenamed, SG_CDR(pexport))))) {
	  /* some manual optimisation */
	  if (!SG_FALSEP(slot)) {
	    lib = plib; name = SG_CAR(slot);
	    goto reent;
	  } else {
	    /* c stub or :all doesn't always have the variables,
	       so we need to keep searching. */
	    if (SG_FALSEP(pexport) || SG_EQ(SG_KEYWORD_ALL, mq)) {
	      ret = Sg_FindBinding(plib, unrenamed, callback);
	      if (ret != callback) goto out;
	    } else {
	      lib = plib; name = unrenamed;
	      goto reent;
	    }
	  }
	}
      }
    }
    ret = callback;
  }
 out:
  return ret;
}

void Sg_InsertBinding(SgLibrary *library, SgObject name, SgObject value_or_gloc)
{
  SgObject value;
  if (SG_GLOCP(value_or_gloc)) {
    value = SG_GLOC_GET(SG_GLOC(value_or_gloc));
  } else {
    value = value_or_gloc;
  }
  if (SG_SYMBOLP(name)) {
    Sg_MakeBinding(library, name, value, 0);
  } else if (SG_IDENTIFIERP(name)) {
    Sg_MakeBinding(library, SG_IDENTIFIER_NAME(name), value, 0);
  } else {
    Sg_Error(UC("symbol or identifier required, but got %S"), name);
  }
}

/* #define list6(a, b, c, d, e, f) Sg_Cons(a, SG_LIST5(b,c,d,e,f)) */
void Sg__InitLibrary()
{
  Sg_InitMutex(&MUTEX, TRUE);
  ALL_LIBRARIES = Sg_MakeHashTableSimple(SG_HASH_EQ, 1024);
  
  extensions = SG_LIST3(SG_MAKE_STRING(".ss"),
			SG_MAKE_STRING(".sls"),
			SG_MAKE_STRING(".scm"));

}

/*
  end of file
  Local Variables:
  coding: utf-8-unix
  End:
*/
