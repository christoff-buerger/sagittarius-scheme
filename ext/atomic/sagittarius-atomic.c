/* atomic.c                                         -*- mode:c; coding:utf-8; -*-
 *
 *   Copyright (c) 2024  Takashi Kato <ktakashi@ymail.com>
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
 */
#include <stddef.h>
#define LIBSAGITTARIUS_EXT_BODY
#include <sagittarius/extend.h>
#include "sagittarius-atomic.h"
#include <sagittarius/private/error.h>
#include <sagittarius/private/library.h>
#include <sagittarius/private/pair.h>
#include <sagittarius/private/port.h>
#include <sagittarius/private/symbol.h>
#include <sagittarius/private/writer.h>

#if !defined(HAVE_STDATOMIC_H) && defined(HAVE_CPP_ATOMIC)

using namespace std;

#elif !defined(HAVE_STDATOMIC_H) && !defined(HAVE_CPP_ATOMIC)

#include <atomic_ops.h>

#define handle_memory_order_impl(ret, proc, order, ...)		\
  do {								\
    switch (order) {						\
    case memory_order_relaxed:					\
      ret proc(__VA_ARGS__);					\
      break;							\
    case memory_order_consume:					\
    case memory_order_acquire:					\
      ret SG_CPP_CAT(proc, _acquire)(__VA_ARGS__);		\
      break;							\
    case memory_order_release:					\
      ret SG_CPP_CAT(proc, _release)(__VA_ARGS__);		\
      break;							\
    case memory_order_acq_rel:					\
    case memory_order_seq_cst:					\
      ret SG_CPP_CAT(proc, _full)(__VA_ARGS__);			\
      break;							\
    }								\
} while (0)

#if defined(_MSC_VER)
#  define msvc_workaround(x) x
#  define handle_memory_order(ret, proc, order, ...)			\
  msvc_workaround(handle_memory_order_impl(ret, proc, order, __VA_ARGS__))
#else
#define handle_memory_order handle_memory_order_impl
#endif


static void ao_store_explicit(volatile AO_t *o, AO_t v, memory_order order)
{
  switch (order) {
  case memory_order_release:
  case memory_order_acq_rel:
  case memory_order_seq_cst:
    AO_store_release(o, v);
    break;
  default:
    AO_store(o, v);
    break;
  }
}
static AO_t ao_load_explicit(volatile AO_t * o, memory_order order)
{
  switch (order) {
  case memory_order_relaxed:
    return AO_load(o);
  default:
    return AO_load_acquire(o);
  }
}

static int ao_compare_exchange_strong(volatile AO_t *o, AO_t *e, AO_t v,
				      memory_order success,
				      memory_order failure)
{
  handle_memory_order(return, AO_compare_and_swap, success, o, *e, v);
}

static AO_t ao_exchange_explicit(volatile AO_t *o, AO_t v, memory_order order)
{
  AO_t old;

  do {
    old = ao_load_explicit(o, order);
  } while (!ao_compare_exchange_strong(o, &old, v, order, order));
  return old;
}

/* we don't use it */
/* static int ao_compare_exchange_weak(volatile AO_t *, AO_t, AO_t, */
/* 				    memory_order, memory_order); */

static AO_t ao_fetch_add(volatile AO_t *o, AO_t v, memory_order order)
{
  handle_memory_order(return, AO_fetch_and_add, order, o, v);
}
static AO_t ao_fetch_sub(volatile AO_t *o, AO_t v, memory_order order)
{
  return ao_fetch_add(o, -((long)v), order);
}
/* Fxxking MAVC, the macro doesn't work... */
static AO_t ao_fetch_or(volatile AO_t *o, AO_t v, memory_order order)
{
  AO_t r = ao_load_explicit(o, order);
  /* handle_memory_order((void), AO_or, order, o, v); */
  switch (order) {
    case memory_order_relaxed:
      AO_or(o, v);
      break;
    case memory_order_consume:
    case memory_order_acquire:
      AO_or_acquire(o, v);
      break;
    case memory_order_release:
      AO_or_release(o, v);
      break;
    case memory_order_acq_rel:
    case memory_order_seq_cst:
      AO_or_full(o, v);
      break;
  }
  return r;
}
static AO_t ao_fetch_xor(volatile AO_t *o, AO_t v, memory_order order)
{
  AO_t r = ao_load_explicit(o, order);
  /* handle_memory_order((void), AO_xor, order, o, v); */
  switch (order) {
    case memory_order_relaxed:
      AO_xor(o, v);
      break;
    case memory_order_consume:
    case memory_order_acquire:
      AO_xor_acquire(o, v);
      break;
    case memory_order_release:
      AO_xor_release(o, v);
      break;
    case memory_order_acq_rel:
    case memory_order_seq_cst:
      AO_xor_full(o, v);
      break;
  }
  return r;
}
static AO_t ao_fetch_and(volatile AO_t *o, AO_t v, memory_order order)
{
  AO_t r = ao_load_explicit(o, order);
  /* handle_memory_order((void), AO_and, order, o, v); */
  switch (order) {
    case memory_order_relaxed:
      AO_and(o, v);
      break;
    case memory_order_consume:
    case memory_order_acquire:
      AO_and_acquire(o, v);
      break;
    case memory_order_release:
      AO_and_release(o, v);
      break;
    case memory_order_acq_rel:
    case memory_order_seq_cst:
      AO_and_full(o, v);
      break;
  }
  return r;
}

static void ao_thread_fence(memory_order order)
{
  switch (order) {
    case memory_order_relaxed:
      AO_nop();
      break;
    case memory_order_consume:
    case memory_order_acquire:
      AO_nop_read();
      break;
    case memory_order_release:
      AO_nop_write();
      break;
    case memory_order_acq_rel:
    case memory_order_seq_cst:
      AO_nop_full();
      break;
  }
}

#define atomic_store(o, v) ao_store_explicit(o, v, memory_order_seq_cst)
#define atomic_store_explicit ao_store_explicit

#define atomic_load(o) ao_load_explicit(o, memory_order_seq_cst)
#define atomic_load_explicit ao_load_explicit

#define atomic_exchange(o, v) ao_exchange_explicit(o, v, memory_order_seq_cst)
#define atomic_exchange_explicit ao_exchange_explicit

#define atomic_compare_exchange_strong(o, e, v) ao_compare_exchange_strong(o, e, v, memory_order_seq_cst, memory_order_seq_cst)
#define atomic_compare_exchange_strong_explicit ao_compare_exchange_strong

#define atomic_compare_exchange_weak(o, e, v) ao_compare_exchange_weak(o, e, v, memory_order_seq_cst, memory_order_seq_cst)
#define atomic_compare_exchange_weak_explicit ao_compare_exchange_weak

#define atomic_fetch_add(ob, op) ao_fetch_add(ob, op, memory_order_seq_cst)
#define atomic_fetch_add_explicit ao_fetch_add

#define atomic_fetch_sub(ob, op) ao_fetch_sub(ob, op, memory_order_seq_cst)
#define atomic_fetch_sub_explicit ao_fetch_sub

#define atomic_fetch_or(ob, op) ao_fetch_or(ob, op, memory_order_seq_cst)
#define atomic_fetch_or_explicit ao_fetch_or

#define atomic_fetch_xor(ob, op) ao_fetch_xor(ob, op, memory_order_seq_cst)
#define atomic_fetch_xor_explicit ao_fetch_xor

#define atomic_fetch_and(ob, op) ao_fetch_and(ob, op, memory_order_seq_cst)
#define atomic_fetch_and_explicit ao_fetch_and

#define atomic_thread_fence ao_thread_fence

#undef handle_memory_order

#endif

int Sg_MemoryOrderP(SgObject o)
{
  if (!SG_INTP(o)) {
    return FALSE;
  }
  switch (SG_INT_VALUE(o)) {
  case memory_order_relaxed:
  case memory_order_consume:
  case memory_order_acquire:
  case memory_order_release:
  case memory_order_acq_rel:
  case memory_order_seq_cst:
    return TRUE;
  default:
    return FALSE;
  }
}

static void atomic_print(SgObject obj, SgPort *port, SgWriteContext *ctx)
{
  if (SG_ATOMIC_FIXNUM_P(obj)) {
    Sg_Printf(port, UC("#<atomic-fixnum %d>"),
	      atomic_load_explicit(&SG_ATOMIC_REF_FIXNUM(obj), memory_order_relaxed));
  } else if (SG_ATOMIC_FLAG_P(obj)) {
    Sg_Printf(port, UC("#<atomic-flag %p>"), obj);
  } else if (SG_ATOMIC_PAIR_P(obj)) {
    pair_t v = atomic_load_explicit(&SG_ATOMIC_REF_PAIR(obj), memory_order_relaxed);
    Sg_Printf(port, UC("#<atomic-pair %S>"), Sg_Cons(v.car, v.cdr));
  } else {
    Sg_Printf(port, UC("#<atomic %S>"),
	      atomic_load_explicit(&SG_ATOMIC_REF_OBJECT(obj), memory_order_relaxed));
  }
}

SG_DEFINE_BUILTIN_CLASS_SIMPLE(Sg_AtomicClass, atomic_print);

static void no_atomic_flag(volatile SgAtomic *o)
{
  if (SG_ATOMIC_FLAG_P(o)) {
    Sg_Error(UC("atomic-flag is not allowed for the operation: %A"), o);
  }
}


static SgAtomic * make_atomic(SgAtomicType type)
{
  SgAtomic *z = SG_NEW(SgAtomic);
  SG_SET_CLASS(z, SG_CLASS_ATOMIC);
  z->type = type;
  return z;
}

SgObject Sg_MakeAtomic(SgObject obj)
{
  SgAtomic *a = make_atomic(SG_ATOMIC_OBJECT);
  SG_ATOMIC_REF_OBJECT(a) = (object_t)obj;
  return SG_OBJ(a);
}

SgObject Sg_MakeAtomicFlag()
{
  SgAtomic *a = make_atomic(SG_ATOMIC_FLAG);
  Sg_AtomicFlagClear(a, memory_order_seq_cst);
  return SG_OBJ(a);
}

SgObject Sg_MakeAtomicPair(SgObject car, SgObject cdr)
{
  SgAtomic *a = make_atomic(SG_ATOMIC_PAIR);
  pair_t v = { car, cdr };
  atomic_init(&SG_ATOMIC_REF_PAIR(a), v);
  return SG_OBJ(a);
}

SgObject Sg_MakeAtomicFixnum(long n)
{
  SgAtomic *a = make_atomic(SG_ATOMIC_FIXNUM);
  SG_ATOMIC_REF_FIXNUM(a) = n;
  return SG_OBJ(a);
}


SgObject Sg_AtomicLoad(volatile SgAtomic *o, SgMemoryOrder order)
{
  no_atomic_flag(o);
  if (SG_ATOMIC_FIXNUM_P(o)) {
    long v = atomic_load_explicit(&SG_ATOMIC_REF_FIXNUM(o), order);
    return SG_MAKE_INT(v);
  } else if (SG_ATOMIC_PAIR_P(o)) {
    pair_t v = atomic_load_explicit(&SG_ATOMIC_REF_PAIR(o), order);
    return Sg_Cons(v.car, v.cdr);
  } else {
    object_t v = atomic_load_explicit(&SG_ATOMIC_REF_OBJECT(o), order);
    return SG_OBJ(v);
  }
}

void Sg_AtomicStore(volatile SgAtomic *o, SgObject v, SgMemoryOrder order)
{
  no_atomic_flag(o);
  if (SG_ATOMIC_FIXNUM_P(o)) {
    if (!SG_INTP(v)) {
      Sg_Error(UC("fixnum is required for atomic-fixnum but got %A"), v);
    }
    atomic_store_explicit(&SG_ATOMIC_REF_FIXNUM(o), SG_INT_VALUE(v), order);
  } else if (SG_ATOMIC_PAIR_P(o)) {
    if (!SG_PAIRP(v)) {
      Sg_Error(UC("pair is required for atomic-pair but got %A"), v);
    }
    pair_t v2 = { SG_CAR(v), SG_CDR(v) };
    atomic_store_explicit(&SG_ATOMIC_REF_PAIR(o), v2, order);
  } else {
    atomic_store_explicit(&SG_ATOMIC_REF_OBJECT(o), (object_t)v, order);
  }
}

SgObject Sg_AtomicExchange(volatile SgAtomic *o, SgObject v, SgMemoryOrder order)
{
  no_atomic_flag(o);
  if (SG_ATOMIC_FIXNUM_P(o)) {
    if (!SG_INTP(v)) {
      Sg_Error(UC("fixnum is required for atomic-fixnum but got %A"), v);
    }
    long vl = SG_INT_VALUE(v);
    long l = atomic_exchange_explicit(&SG_ATOMIC_REF_FIXNUM(o), vl, order);
    return SG_MAKE_INT(l);
  } else if (SG_ATOMIC_PAIR_P(o)) {
    if (!SG_PAIRP(v)) {
      Sg_Error(UC("pair is required for atomic-pair but got %A"), v);
    }
    pair_t v2 = { SG_CAR(v), SG_CDR(v) };
    pair_t r = atomic_exchange_explicit(&SG_ATOMIC_REF_PAIR(o), v2, order);
    return Sg_Cons(r.car, r.cdr);
  } else {
    object_t r = atomic_exchange_explicit(&SG_ATOMIC_REF_OBJECT(o),
					  (object_t)v, order);
    return SG_OBJ(r);
  }
}

long Sg_AtomicFixnumExchange(volatile SgAtomic *o, long v, SgMemoryOrder order)
{
  if (!SG_ATOMIC_FIXNUM_P(o)) {
    Sg_Error(UC("atomic-fixnum is required"));
  }
  return atomic_exchange_explicit(&SG_ATOMIC_REF_FIXNUM(o), v, order);
}

long Sg_AtomicFixnumLoad(volatile SgAtomic *o, SgMemoryOrder order)
{
  if (!SG_ATOMIC_FIXNUM_P(o)) {
    Sg_Error(UC("atomic-fixnum is required"));

  }
  return atomic_load_explicit(&SG_ATOMIC_REF_FIXNUM(o), order);
}

void Sg_AtomicFixnumStore(volatile SgAtomic *o, long v, SgMemoryOrder order)
{
  if (!SG_ATOMIC_FIXNUM_P(o)) {
    Sg_Error(UC("atomic-fixnum is required"));
  }
  atomic_store_explicit(&SG_ATOMIC_REF_FIXNUM(o), v, order);
}

#define atomic_math(o, v, order, proc)			\
  do {							\
    if (!SG_ATOMIC_FIXNUM_P(o)) {			\
      Sg_Error(UC("atomic-fixnum is required"));	\
    }							\
    return proc(&SG_ATOMIC_REF_FIXNUM(o), v, order);	\
  } while (0)

long Sg_AtomicFixnumAdd(volatile SgAtomic *o, long v, SgMemoryOrder order)
{
  atomic_math(o, v, order, atomic_fetch_add_explicit);
}
long Sg_AtomicFixnumSub(volatile SgAtomic *o, long v, SgMemoryOrder order)
{
  atomic_math(o, v, order, atomic_fetch_sub_explicit);
}
long Sg_AtomicFixnumIor(volatile SgAtomic *o, long v, SgMemoryOrder order)
{
  atomic_math(o, v, order, atomic_fetch_or_explicit);
}
long Sg_AtomicFixnumXor(volatile SgAtomic *o, long v, SgMemoryOrder order)
{
  atomic_math(o, v, order, atomic_fetch_xor_explicit);
}
long Sg_AtomicFixnumAnd(volatile SgAtomic *o, long v, SgMemoryOrder order)
{
  atomic_math(o, v, order, atomic_fetch_and_explicit);
}

int Sg_AtomicCompareAndSwap(volatile SgAtomic *o, SgObject *e, SgObject v,
			    SgMemoryOrder success, SgMemoryOrder failure)
{
  int result;
  no_atomic_flag(o);
  switch (o->type) {
  case SG_ATOMIC_FIXNUM:
    if (!SG_INTP(v) && !SG_INTP(*e)) {
      Sg_Error(UC("atomic_fixnum must take fixnum but got %A and %A"), *e, v);
    }
    {
      long ev = SG_INT_VALUE(*e);
      result = atomic_compare_exchange_strong_explicit(&SG_ATOMIC_REF_FIXNUM(o),
						       &ev,
						       SG_INT_VALUE(v),
						       success, failure);
      if (!result) {
	*e = SG_MAKE_INT(ev);
      }
    }
    break;
  case SG_ATOMIC_PAIR:
    if (!SG_PAIRP(*e) || !SG_PAIRP(v)) {
      Sg_Error(UC("atomic_pair must take pair but got %S and %S"), *e, v);
    }
    {
      pair_t ev = { SG_CAR(*e), SG_CDR(*e) };
      pair_t vv = { SG_CAR(v), SG_CDR(v) };
      result = atomic_compare_exchange_strong_explicit(&SG_ATOMIC_REF_PAIR(o),
						     &ev, vv, success, failure);
      if (!result) {
	*e = Sg_Cons(ev.car, ev.cdr);
      }
    }
    break;
  default:
    {
      object_t ev = (object_t)*e;
      result = atomic_compare_exchange_strong_explicit(&SG_ATOMIC_REF_OBJECT(o),
						       &ev, (object_t)v,
						       success, failure);
      if (!result) {
	*e = SG_OBJ(ev);
      }
    }
    break;
  }
  return result;
}

int Sg_AtomicFlagTestAndSet(volatile SgAtomic *o, SgMemoryOrder order)
{
  if (!SG_ATOMIC_FLAG_P(o)) {
    Sg_Error(UC("atomic_flag is required but got %A"), o);
  }
  return atomic_flag_test_and_set_explicit(&SG_ATOMIC_REF_FLAG(o), order);
}
void Sg_AtomicFlagClear(volatile SgAtomic *o, SgMemoryOrder order)
{
  if (!SG_ATOMIC_FLAG_P(o)) {
    Sg_Error(UC("atomic_flag is required but got %A"), o);
  }
  atomic_flag_clear_explicit(&SG_ATOMIC_REF_FLAG(o), order);
}

void Sg_AtomicThreadFence(SgMemoryOrder order)
{
  atomic_thread_fence(order);
}

extern void Sg__Init_atomic(SgLibrary *lib);

SG_EXTENSION_ENTRY void CDECL Sg_Init_sagittarius__atomic()
{
  SgObject lib = Sg_FindLibrary(SG_INTERN("(sagittarius atomic)"), TRUE);
  SG_INIT_EXTENSION(sagittarius__atomic);
  Sg__Init_atomic(SG_LIBRARY(lib));
  
#define insert_binding(name, value)					\
  Sg_MakeBinding(SG_LIBRARY(lib), SG_INTERN(#name), MEMORY_ORDER_TO_SCM(value), TRUE)

  insert_binding(*memory-order:relaxed*, memory_order_relaxed);
  insert_binding(*memory-order:consume*, memory_order_consume);
  insert_binding(*memory-order:acquire*, memory_order_acquire);
  insert_binding(*memory-order:release*, memory_order_release);
  insert_binding(*memory-order:acq-rel*, memory_order_acq_rel);
  insert_binding(*memory-order:seq-cst*, memory_order_seq_cst);

}
