/* bytevector.c                                    -*- mode:c; coding:utf-8; -*-
 *
 *   Copyright (c) 2010-2021  Takashi Kato <ktakashi@ymail.com>
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
#include <math.h>
#define LIBSAGITTARIUS_BODY
/* for warning */
#define NO_NTZ
#include "sagittarius/private/sagittariusdefs.h"
#include "sagittarius/private/arith.h"
#include "sagittarius/private/bytevector.h"
#include "sagittarius/private/bignum.h"
#include "sagittarius/private/bits.h"
#include "sagittarius/private/collection.h"
#include "sagittarius/private/number.h"
#include "sagittarius/private/pair.h"
#include "sagittarius/private/port.h"
#include "sagittarius/private/string.h"
#include "sagittarius/private/error.h"
#include "sagittarius/private/symbol.h"
#include "sagittarius/private/vm.h"

static void bvector_print(SgObject obj, SgPort *port, SgWriteContext *ctx)
{
  SgByteVector *b = SG_BVECTOR(obj);
  size_t i, size = b->size;
  uint8_t *u8 = b->elements;
  char buf[32];
  
  if (SG_VM_IS_SET_FLAG(Sg_VM(), SG_R7RS_MODE)) {
    Sg_PutuzUnsafe(port, UC("#u8("));
  } else {
    Sg_PutuzUnsafe(port, UC("#vu8("));
  }
  if (size != 0) {
    for (i = 0; i < size - 1; i++) {
      snprintf(buf, array_sizeof(buf), "%u", u8[i]);
      Sg_PutzUnsafe(port, buf);
      Sg_PutcUnsafe(port, ' ');
    }
    snprintf(buf, array_sizeof(buf), "%u", u8[i]);
    Sg_PutzUnsafe(port, buf);
  }
  Sg_PutcUnsafe(port, ')');
}

SG_DEFINE_BUILTIN_CLASS(Sg_ByteVectorClass, bvector_print, NULL, NULL, NULL,
			SG_CLASS_SEQUENCE_CPL);

static SgByteVector* make_bytevector_rec()
{
  SgByteVector *z = SG_NEW(SgByteVector);
  SG_SET_CLASS(z, SG_CLASS_BVECTOR);
  z->literalp = FALSE;
  return z;
}

static SgByteVector* make_bytevector(long size)
{
  SgByteVector *z = make_bytevector_rec();
  z->size = size;
  z->elements = SG_NEW_ATOMIC2(uint8_t *, size);
  return z;
}

SgObject Sg_MakeByteVector(long size, int fill)
{
  SgByteVector *b;
  long i;
  if (!(SG_IS_BYTE(fill) || SG_IS_OCTET(fill))) {
    /* out of range */
    Sg_Error(UC("fill must be between -128 and 255, but got %d"), fill);
  }
  b = make_bytevector(size);
  for (i = 0; i < size; i++) {
    b->elements[i] = fill;
  }
  return SG_OBJ(b);
}

SgObject Sg_MakeByteVectorFromU8Array(const uint8_t *buf, long size)
{
  SgByteVector *z = make_bytevector_rec();
  z->size = size;
  z->elements = (uint8_t *)buf;
  return SG_OBJ(z);
}

int Sg_ByteVectorCmp(SgByteVector *bv1, SgByteVector *bv2)
{
  long bv1_len = SG_BVECTOR_SIZE(bv1);
  long bv2_len = SG_BVECTOR_SIZE(bv2);
  long len = (bv1_len > bv2_len)? bv2_len : bv1_len;
  int r = memcmp(SG_BVECTOR_ELEMENTS(bv1), SG_BVECTOR_ELEMENTS(bv2), len);
  if (r == 0) {
    if (bv1_len == bv2_len) return 0;
    else if (bv1_len >bv2_len) return 1;
    else return -1;
  }
  return r;
}

int Sg_ByteVectorEqP(SgByteVector *bv1, SgByteVector *bv2)
{
  return Sg_ByteVectorCmp(bv1, bv2) == 0;
}

SgObject Sg_ByteVectorCopy(SgByteVector *src, long start, long end)
{
  SgByteVector *dst;
  long len = SG_BVECTOR_SIZE(src);
  SG_CHECK_START_END(start, end, len);

  dst = make_bytevector(end - start);
  memcpy(SG_BVECTOR_ELEMENTS(dst), SG_BVECTOR_ELEMENTS(src) + start,
	 (end-start) * sizeof(uint8_t));
  return SG_OBJ(dst);
}

void Sg_ByteVectorCopyX(SgByteVector *src, long srcStart,
			SgByteVector *dst, long dstStart,
			long k)
{
  long srcLen = SG_BVECTOR_SIZE(src);
  long dstLen = SG_BVECTOR_SIZE(dst);
  if ((srcStart <= srcStart + k) &&
      (srcStart + k <= srcLen) &&
      (0 <= dstStart) &&
      (dstStart <= dstStart + k) &&
      (dstStart + k <= dstLen)) {
    memmove(SG_BVECTOR_ELEMENTS(dst) + dstStart,
	    SG_BVECTOR_ELEMENTS(src) + srcStart,
	    k);
  } else {
    Sg_Error(UC("bytevector-copy!: invalid range (src %d) (dst %d) (size %d)"),
	     srcStart, dstStart, k);
  }
}

SgObject Sg_ByteVectorReverseX(SgByteVector *bv, long start, long end)
{
  long i, n = SG_BVECTOR_SIZE(bv), e, c;
  SG_CHECK_START_END(start, end, n);

  n = (end-start)/2;

  for (i = start, e = end-1, c = 0; c < n; i++, c++, e--) {
    uint8_t t = SG_BVECTOR_ELEMENT(bv, i);
    SG_BVECTOR_ELEMENT(bv, i) = SG_BVECTOR_ELEMENT(bv, e);
    SG_BVECTOR_ELEMENT(bv, e) = t;
  }
  return bv;
}

SgObject Sg_NativeEndianness()
{
#if WORDS_BIGENDIAN
  return SG_INTERN("big");
#else
  return SG_INTERN("little");
#endif
}

static inline int is_valid_value(long value, size_t bitCount, int signP)
{
  /* TODO 64 bit... */
  /* cf) bitCount = 8, max = 256 */
  unsigned long unsigned_max = (1 << bitCount) - 1;
  long signed_max = (1 << (bitCount - 1)) - 1; /* cf) bitCount = 8, max = 127 */
  intptr_t min = -(1 << (bitCount - 1)); /* cf) bitCount = 8, max = -128 */
  if ((size_t)nbits(value) > bitCount) {
    return FALSE;
  }
  /* check max and min value */
  if (signP) {
    return min <= value && value <= signed_max;
  } else {
    /* unsigned min is always 0 */
    return 0 <= value && (unsigned long)value <= unsigned_max;
  }
}

/* FIXME not so nice implemantation */
static inline int bytevector_set(SgByteVector *bv, long index, intptr_t value,
				 int bitCount, int signP)
{
  /* im too lazy to repeat this */
#define SIGN_SWITCH(prefix, suffix)					\
  if (signP) {								\
    SG_CPP_CAT3(Sg_ByteVectorS, prefix, suffix)				\
      (bv, index,							\
       (SG_CPP_CAT3(int, prefix, _t))value);				\
  } else {								\
    SG_CPP_CAT3(Sg_ByteVectorU, prefix, suffix)				\
      (bv, index,							\
       (SG_CPP_CAT3(uint, prefix, _t))value);				\
  }

  switch (bitCount) {
  case 8:
    SIGN_SWITCH(8, Set);
    break;
  case 16:
    SIGN_SWITCH(16, NativeSet);
    break;
  case 32:
    SIGN_SWITCH(32, NativeSet);
    break;
  case 64:
    SIGN_SWITCH(64, NativeSet);
    break;
  }
  return bitCount >> 3;
#undef SIGN_SWITCH
}

SgObject Sg_ListToByteVector(SgObject lst, int bitCount, int signP)
{
  SgByteVector *bv;
  SgObject cp;
  long len = 0, i;
  SG_FOR_EACH(cp, lst) {
    SgObject num = SG_CAR(cp);
    if (SG_INTP(num) &&
	is_valid_value(SG_INT_VALUE(num), bitCount, signP)) {
      len++;
      continue;
    } else {
      Sg_WrongTypeOfArgumentViolation(SG_INTERN("list->bytevector"),
				      signP
				      ? SG_MAKE_STRING("unsigned integer list")
				      : SG_MAKE_STRING("integer list"),
				      num, lst);
      return SG_UNDEF;
    }
  }
  if (!SG_NULLP(cp)) {
    Sg_WrongTypeOfArgumentViolation(SG_INTERN("list->bytevector"),
				    SG_MAKE_STRING("proper list"),
				    lst, lst);
  }
  bv = make_bytevector(len);
  /* again... */
  i = 0;
  SG_FOR_EACH(cp, lst) {
    SgObject num = SG_CAR(cp);
    i += bytevector_set(bv, i, SG_INT_VALUE(num), bitCount, signP);
  }
  return SG_OBJ(bv);
}

static inline SgObject bytevector_ref(SgByteVector *bv, long index,
				      int bitCount, int signP)
{
  /* im too lazy to repeat this */
#define Sg_MakeIntegerS    Sg_MakeInteger
#define Sg_MakeBignum64S   Sg_MakeBignumFromS64
#define Sg_MakeBignum64U   Sg_MakeBignumFromU64

#define SIGN_SWITCH(prefix, suffix, gene)				\
  if (signP) {								\
    value = SG_CPP_CAT3(Sg_ByteVectorS, prefix, suffix)(bv, index);	\
    ret = (SG_CPP_CAT(gene, S))(value);					\
  } else {								\
    value = SG_CPP_CAT3(Sg_ByteVectorU, prefix, suffix)(bv, index);	\
    ret = (SG_CPP_CAT(gene, U))(value);					\
  }
  
  SgObject ret = SG_UNDEF;
  switch (bitCount) {
  case 8: {
    unsigned long value;
    SIGN_SWITCH(8, Ref, Sg_MakeInteger);
    break;
  }
  case 16: {
    unsigned long value;
    SIGN_SWITCH(16, NativeRef, Sg_MakeInteger);
    break;
  }
  case 32: {
    unsigned long value;
    SIGN_SWITCH(32, NativeRef, Sg_MakeInteger);
    break;
  }
  case 64: {
    uint64_t value;
    SIGN_SWITCH(64, NativeRef, Sg_MakeBignum64);
    break;
  }
  }
  return ret;
#undef SIGN_SWITCH
#undef Sg_MakeIntegerS
#undef Sg_MakeBignum64S
#undef Sg_MakeBignum64U
}

SgObject Sg_ByteVectorToList(SgByteVector *bv, int bitCount, int signP)
{
  SgObject ret = SG_NIL;
  long i, len = SG_BVECTOR_SIZE(bv);
  for (i = 0; i < len;) {
    SgObject ref = bytevector_ref(bv, i, bitCount, signP);
    ret = Sg_Cons(ref, ret);
    i += (bitCount >> 3);
  }
  ret = Sg_ReverseX(ret);
  return ret;
}

void Sg_ByteVectorFill(SgByteVector *bv, int value, long start, long end)
{
  long len;
  if (!(SG_IS_BYTE(value) || SG_IS_OCTET(value))) {
    /* out of range */
    Sg_Error(UC("fill must be between -128 and 255, but got %d"), value);
  }
  len = SG_BVECTOR_SIZE(bv);
  SG_CHECK_START_END(start, end, len);
  memset(SG_BVECTOR_ELEMENTS(bv)+start, value, end-start);
}

SgObject Sg_ByteVectorToString(SgByteVector *bv, SgTranscoder *transcoder,
			       long start, long end)
{
#define BUF_SIZ 256
  SgPort *accum, *bin, *tin;
  SgBytePort bp;
  SgStringPort ap;
  SgTranscodedPort tp;
  SgObject r;
  SgChar buf[BUF_SIZ];
  long size = SG_BVECTOR_SIZE(bv);
  long read_size = BUF_SIZ;
  int64_t total_size = 0;
  int64_t len;

  SG_CHECK_START_END(start, end, size);

  size = end - start;
  if (size < read_size) read_size = size;

  bin = Sg_InitByteArrayInputPort(&bp, SG_BVECTOR_ELEMENTS(bv), start, end);
  tin = Sg_InitTranscodedPort(&tp, bin, transcoder, SG_INPUT_PORT);
  accum = Sg_InitStringOutputPort(&ap, size);
  
  for (;;) {
    int rest;
    len = Sg_ReadsUnsafe(tin, buf, read_size);
    if (len < read_size) break;
    Sg_WritesUnsafe(accum, buf, len);
    total_size += len;
    rest = (int)(size - total_size);
    len = 0;
    if (rest <= 0) break;
    if (rest < read_size) read_size = rest;
  }
  if (len != 0) {
    Sg_WritesUnsafe(accum, buf, len);
  }
  r = Sg_GetStringFromStringPort(&ap);
  SG_CLEAN_BYTE_PORT(&bp);
  SG_CLEAN_TRANSCODED_PORT(&tp);
  SG_CLEAN_STRING_PORT(&ap);
  return r;
}

SgObject Sg_StringToByteVector(SgString *s, SgTranscoder *transcoder,
			       long start, long end)
{
  SgPort *accum, *out;
  SgBytePort bp;
  SgTranscodedPort tp;
  SgObject r;
  long len = SG_STRING_SIZE(s);
  SG_CHECK_START_END(start, end, len);

  accum = Sg_InitByteArrayOutputPort(&bp, end);
  out = Sg_InitTranscodedPort(&tp, accum, transcoder, SG_OUTPUT_PORT);

  Sg_WritesUnsafe(out, SG_STRING_VALUE(s) + start, end - start);

  r = Sg_GetByteVectorFromBinaryPort(&bp);
  SG_CLEAN_BYTE_PORT(&bp);
  SG_CLEAN_TRANSCODED_PORT(&tp);

  return r;
}


/* u/s8 accessor */
uint8_t Sg_ByteVectorU8Ref(SgByteVector *bv, long index)
{
  return SG_BVECTOR_ELEMENT(bv, index);
}

void Sg_ByteVectorU8Set(SgByteVector *bv, long index, uint8_t value)
{
  SG_BVECTOR_ELEMENT(bv, index) = value;
}

int8_t Sg_ByteVectorS8Ref(SgByteVector *bv, long index)
{
  return (int8_t)SG_BVECTOR_ELEMENT(bv, index);
}

void Sg_ByteVectorS8Set(SgByteVector *bv, long index, int8_t value)
{
  SG_BVECTOR_ELEMENT(bv, index) = (uint8_t)value;
}

/* u/s16 accessor */
uint16_t Sg_ByteVectorU16NativeRef(SgByteVector *bv, long index)
{
  uint8_t *tmp = &SG_BVECTOR_ELEMENT(bv, index);
  return *(uint16_t*)tmp;
}

uint16_t Sg_ByteVectorU16LittleRef(SgByteVector *bv, long index)
{
  return (SG_BVECTOR_ELEMENT(bv, index + 1) << 8) |
          SG_BVECTOR_ELEMENT(bv, index);
}

uint16_t Sg_ByteVectorU16BigRef(SgByteVector *bv, long index)
{
  return (SG_BVECTOR_ELEMENT(bv, index) << 8) |
          SG_BVECTOR_ELEMENT(bv, index + 1);
}

void Sg_ByteVectorU16NativeSet(SgByteVector *bv, long index, uint16_t value)
{
  uint8_t *tmp = &SG_BVECTOR_ELEMENT(bv, index);
  *(uint16_t*)tmp = value;
}

void Sg_ByteVectorU16LittleSet(SgByteVector *bv, long index, uint16_t value)
{
  SG_BVECTOR_ELEMENT(bv, index) = value & 0xff;
  SG_BVECTOR_ELEMENT(bv, index + 1) = value >> 8;
}

void Sg_ByteVectorU16BigSet(SgByteVector *bv, long index, uint16_t value)
{
  SG_BVECTOR_ELEMENT(bv, index) = value >> 8;
  SG_BVECTOR_ELEMENT(bv, index + 1) = value & 0xff;
}

int16_t Sg_ByteVectorS16NativeRef(SgByteVector *bv, long index)
{
  uint8_t *tmp = &SG_BVECTOR_ELEMENT(bv, index);
  return *(int16_t*)tmp;
}

int16_t Sg_ByteVectorS16LittleRef(SgByteVector *bv, long index)
{
  return ((SG_BVECTOR_ELEMENT(bv, index + 1) << 8) |
	  SG_BVECTOR_ELEMENT(bv, index));
}

int16_t Sg_ByteVectorS16BigRef(SgByteVector *bv, long index)
{
  return ((SG_BVECTOR_ELEMENT(bv, index) << 8) |
	  SG_BVECTOR_ELEMENT(bv, index + 1));
}

void Sg_ByteVectorS16NativeSet(SgByteVector *bv, long index, int16_t value)
{
  uint8_t *tmp = &SG_BVECTOR_ELEMENT(bv, index);
  *(int16_t*)tmp = value;
}

void Sg_ByteVectorS16LittleSet(SgByteVector *bv, long index, int16_t value)
{
  SG_BVECTOR_ELEMENT(bv, index) = value & 0xff;
  SG_BVECTOR_ELEMENT(bv, index + 1) = value >> 8;
}

void Sg_ByteVectorS16BigSet(SgByteVector *bv, long index, int16_t value)
{
  SG_BVECTOR_ELEMENT(bv, index) = value >> 8;
  SG_BVECTOR_ELEMENT(bv, index + 1) = value & 0xff;
}

/* u/s32 accessor */
uint32_t Sg_ByteVectorU32NativeRef(SgByteVector *bv, long index)
{
  uint8_t *tmp = &SG_BVECTOR_ELEMENT(bv, index);
  return *(uint32_t*)tmp;
}

uint32_t Sg_ByteVectorU32LittleRef(SgByteVector *bv, long index)
{
  return ((SG_BVECTOR_ELEMENT(bv, index + 3) << 24) |
	  (SG_BVECTOR_ELEMENT(bv, index + 2) << 16) |
	  (SG_BVECTOR_ELEMENT(bv, index + 1) << 8)  |
	  (SG_BVECTOR_ELEMENT(bv, index + 0)));
}

uint32_t Sg_ByteVectorU32BigRef(SgByteVector *bv, long index)
{
  return ((SG_BVECTOR_ELEMENT(bv, index + 0) << 24) |
	  (SG_BVECTOR_ELEMENT(bv, index + 1) << 16) |
	  (SG_BVECTOR_ELEMENT(bv, index + 2) << 8)  |
	  (SG_BVECTOR_ELEMENT(bv, index + 3)));
}

void Sg_ByteVectorU32NativeSet(SgByteVector *bv, long index, uint32_t value)
{
  uint8_t *tmp = &SG_BVECTOR_ELEMENT(bv, index);
  *(uint32_t*)tmp = value;
}

void Sg_ByteVectorU32LittleSet(SgByteVector *bv, long index, uint32_t value)
{
  SG_BVECTOR_ELEMENT(bv, index + 3) = value >> 24;
  SG_BVECTOR_ELEMENT(bv, index + 2) = value >> 16;
  SG_BVECTOR_ELEMENT(bv, index + 1) = value >> 8;
  SG_BVECTOR_ELEMENT(bv, index + 0) = value;
}

void Sg_ByteVectorU32BigSet(SgByteVector *bv, long index, uint32_t value)
{
  SG_BVECTOR_ELEMENT(bv, index + 0) = value >> 24;
  SG_BVECTOR_ELEMENT(bv, index + 1) = value >> 16;
  SG_BVECTOR_ELEMENT(bv, index + 2) = value >> 8;
  SG_BVECTOR_ELEMENT(bv, index + 3) = value;
}

int32_t Sg_ByteVectorS32NativeRef(SgByteVector *bv, long index)
{
  uint8_t *tmp = &SG_BVECTOR_ELEMENT(bv, index);
  return *(int32_t*)tmp;
}

int32_t Sg_ByteVectorS32LittleRef(SgByteVector *bv, long index)
{
  return ((SG_BVECTOR_ELEMENT(bv, index + 3) << 24) |
	  (SG_BVECTOR_ELEMENT(bv, index + 2) << 16) |
	  (SG_BVECTOR_ELEMENT(bv, index + 1) << 8)  |
	  (SG_BVECTOR_ELEMENT(bv, index + 0)));
}

int32_t Sg_ByteVectorS32BigRef(SgByteVector *bv, long index)
{
  return ((SG_BVECTOR_ELEMENT(bv, index + 0) << 24) |
	  (SG_BVECTOR_ELEMENT(bv, index + 1) << 16) |
	  (SG_BVECTOR_ELEMENT(bv, index + 2) << 8)  |
	  (SG_BVECTOR_ELEMENT(bv, index + 3)));
}

void Sg_ByteVectorS32NativeSet(SgByteVector *bv, long index, int32_t value)
{
  uint8_t *tmp = &SG_BVECTOR_ELEMENT(bv, index);
  *(int32_t*)tmp = value;
}

void Sg_ByteVectorS32LittleSet(SgByteVector *bv, long index, int32_t value)
{
  SG_BVECTOR_ELEMENT(bv, index + 3) = value >> 24;
  SG_BVECTOR_ELEMENT(bv, index + 2) = value >> 16;
  SG_BVECTOR_ELEMENT(bv, index + 1) = value >> 8;
  SG_BVECTOR_ELEMENT(bv, index + 0) = value & 0xff;
}

void Sg_ByteVectorS32BigSet(SgByteVector *bv, long index, int32_t value)
{
  SG_BVECTOR_ELEMENT(bv, index + 0) = value >> 24;
  SG_BVECTOR_ELEMENT(bv, index + 1) = value >> 16;
  SG_BVECTOR_ELEMENT(bv, index + 2) = value >> 8;
  SG_BVECTOR_ELEMENT(bv, index + 3) = value & 0xff;
}

/* u/s64 accessor */
uint64_t Sg_ByteVectorU64NativeRef(SgByteVector *bv, long index)
{
  uint8_t *tmp = &SG_BVECTOR_ELEMENT(bv, index);
  return *(uint64_t*)tmp;
}

uint64_t Sg_ByteVectorU64LittleRef(SgByteVector *bv, long index)
{
  return (((uint64_t)(SG_BVECTOR_ELEMENT(bv, index + 7)) << 56) |
	  ((uint64_t)(SG_BVECTOR_ELEMENT(bv, index + 6)) << 48) |
	  ((uint64_t)(SG_BVECTOR_ELEMENT(bv, index + 5)) << 40) |
	  ((uint64_t)(SG_BVECTOR_ELEMENT(bv, index + 4)) << 32) |
	  ((uint64_t)(SG_BVECTOR_ELEMENT(bv, index + 3)) << 24) |
	  ((uint64_t)(SG_BVECTOR_ELEMENT(bv, index + 2)) << 16) |
	  ((uint64_t)(SG_BVECTOR_ELEMENT(bv, index + 1)) << 8) |
	  ((uint64_t)(SG_BVECTOR_ELEMENT(bv, index + 0))));
}

uint64_t Sg_ByteVectorU64BigRef(SgByteVector *bv, long index)
{
  return (((uint64_t)(SG_BVECTOR_ELEMENT(bv, index + 0)) << 56) |
	  ((uint64_t)(SG_BVECTOR_ELEMENT(bv, index + 1)) << 48) |
	  ((uint64_t)(SG_BVECTOR_ELEMENT(bv, index + 2)) << 40) |
	  ((uint64_t)(SG_BVECTOR_ELEMENT(bv, index + 3)) << 32) |
	  ((uint64_t)(SG_BVECTOR_ELEMENT(bv, index + 4)) << 24) |
	  ((uint64_t)(SG_BVECTOR_ELEMENT(bv, index + 5)) << 16) |
	  ((uint64_t)(SG_BVECTOR_ELEMENT(bv, index + 6)) << 8) |
	  ((uint64_t)(SG_BVECTOR_ELEMENT(bv, index + 7))));
}

void Sg_ByteVectorU64NativeSet(SgByteVector *bv, long index, uint64_t value)
{
  uint8_t *tmp = &SG_BVECTOR_ELEMENT(bv, index);
  *(uint64_t*)tmp = value;
}

void Sg_ByteVectorU64LittleSet(SgByteVector *bv, long index, uint64_t value)
{
  SG_BVECTOR_ELEMENT(bv, index + 7) = (uint8_t)(value >> 56);
  SG_BVECTOR_ELEMENT(bv, index + 6) = (uint8_t)(value >> 48);
  SG_BVECTOR_ELEMENT(bv, index + 5) = (uint8_t)(value >> 40);
  SG_BVECTOR_ELEMENT(bv, index + 4) = (uint8_t)(value >> 32);
  SG_BVECTOR_ELEMENT(bv, index + 3) = (uint8_t)(value >> 24);
  SG_BVECTOR_ELEMENT(bv, index + 2) = (uint8_t)(value >> 16);
  SG_BVECTOR_ELEMENT(bv, index + 1) = (uint8_t)(value >> 8);
  SG_BVECTOR_ELEMENT(bv, index + 0) = (uint8_t)(value & 0xff);
}

void Sg_ByteVectorU64BigSet(SgByteVector *bv, long index, uint64_t value)
{
  SG_BVECTOR_ELEMENT(bv, index + 0) = (uint8_t)(value >> 56);
  SG_BVECTOR_ELEMENT(bv, index + 1) = (uint8_t)(value >> 48);
  SG_BVECTOR_ELEMENT(bv, index + 2) = (uint8_t)(value >> 40);
  SG_BVECTOR_ELEMENT(bv, index + 3) = (uint8_t)(value >> 32);
  SG_BVECTOR_ELEMENT(bv, index + 4) = (uint8_t)(value >> 24);
  SG_BVECTOR_ELEMENT(bv, index + 5) = (uint8_t)(value >> 16);
  SG_BVECTOR_ELEMENT(bv, index + 6) = (uint8_t)(value >> 8);
  SG_BVECTOR_ELEMENT(bv, index + 7) = (uint8_t)(value & 0xff);
}

int64_t Sg_ByteVectorS64NativeRef(SgByteVector *bv, long index)
{
  uint8_t *tmp = &SG_BVECTOR_ELEMENT(bv, index);
  return *(int64_t*)tmp;
}

int64_t Sg_ByteVectorS64LittleRef(SgByteVector *bv, long index)
{
  return (((int64_t)(SG_BVECTOR_ELEMENT(bv, index + 7)) << 56) |
	  ((int64_t)(SG_BVECTOR_ELEMENT(bv, index + 6)) << 48) |
	  ((int64_t)(SG_BVECTOR_ELEMENT(bv, index + 5)) << 40) |
	  ((int64_t)(SG_BVECTOR_ELEMENT(bv, index + 4)) << 32) |
	  ((int64_t)(SG_BVECTOR_ELEMENT(bv, index + 3)) << 24) |
	  ((int64_t)(SG_BVECTOR_ELEMENT(bv, index + 2)) << 16) |
	  ((int64_t)(SG_BVECTOR_ELEMENT(bv, index + 1)) << 8) |
	  ((int64_t)(SG_BVECTOR_ELEMENT(bv, index + 0))));
}

int64_t Sg_ByteVectorS64BigRef(SgByteVector *bv, long index)
{
  return (((int64_t)(SG_BVECTOR_ELEMENT(bv, index + 0)) << 56) |
	  ((int64_t)(SG_BVECTOR_ELEMENT(bv, index + 1)) << 48) |
	  ((int64_t)(SG_BVECTOR_ELEMENT(bv, index + 2)) << 40) |
	  ((int64_t)(SG_BVECTOR_ELEMENT(bv, index + 3)) << 32) |
	  ((int64_t)(SG_BVECTOR_ELEMENT(bv, index + 4)) << 24) |
	  ((int64_t)(SG_BVECTOR_ELEMENT(bv, index + 5)) << 16) |
	  ((int64_t)(SG_BVECTOR_ELEMENT(bv, index + 6)) << 8) |
	  ((int64_t)(SG_BVECTOR_ELEMENT(bv, index + 7))));
}

void Sg_ByteVectorS64NativeSet(SgByteVector *bv, long index, int64_t value)
{
  uint8_t *tmp = &SG_BVECTOR_ELEMENT(bv, index);
  *(int64_t*)tmp = value;
}

void Sg_ByteVectorS64LittleSet(SgByteVector *bv, long index, int64_t value)
{
  SG_BVECTOR_ELEMENT(bv, index + 7) = (uint8_t)(value >> 56);
  SG_BVECTOR_ELEMENT(bv, index + 6) = (uint8_t)(value >> 48);
  SG_BVECTOR_ELEMENT(bv, index + 5) = (uint8_t)(value >> 40);
  SG_BVECTOR_ELEMENT(bv, index + 4) = (uint8_t)(value >> 32);
  SG_BVECTOR_ELEMENT(bv, index + 3) = (uint8_t)(value >> 24);
  SG_BVECTOR_ELEMENT(bv, index + 2) = (uint8_t)(value >> 16);
  SG_BVECTOR_ELEMENT(bv, index + 1) = (uint8_t)(value >> 8);
  SG_BVECTOR_ELEMENT(bv, index + 0) = (uint8_t)(value & 0xff);
}

void Sg_ByteVectorS64BigSet(SgByteVector *bv, long index, int64_t value)
{
  SG_BVECTOR_ELEMENT(bv, index + 0) = (uint8_t)(value >> 56);
  SG_BVECTOR_ELEMENT(bv, index + 1) = (uint8_t)(value >> 48);
  SG_BVECTOR_ELEMENT(bv, index + 2) = (uint8_t)(value >> 40);
  SG_BVECTOR_ELEMENT(bv, index + 3) = (uint8_t)(value >> 32);
  SG_BVECTOR_ELEMENT(bv, index + 4) = (uint8_t)(value >> 24);
  SG_BVECTOR_ELEMENT(bv, index + 5) = (uint8_t)(value >> 16);
  SG_BVECTOR_ELEMENT(bv, index + 6) = (uint8_t)(value >> 8);
  SG_BVECTOR_ELEMENT(bv, index + 7) = (uint8_t)(value & 0xff);
}

/* float accessor */
float Sg_ByteVectorIEEESingleNativeRef(SgByteVector *bv, long index)
{
  union {
    float fvalue;
    uint8_t data[sizeof(float)];
  } n;
  memcpy(n.data, SG_BVECTOR_ELEMENTS(bv) + index, sizeof(float));
  return n.fvalue;
}

float Sg_ByteVectorIEEESingleLittleRef(SgByteVector *bv, long index)
{
#if WORDS_BIGENDIAN
  size_t i;
  union {
    float fvalue;
    uint8_t data[sizeof(float)];
  } n;
  for (i = 0; i < sizeof(float); i++) {
    n.data[i] = SG_BVECTOR_ELEMENT(bv, index + sizeof(float) - i - 1);
  }
  return n.fvalue;
#else
  return Sg_ByteVectorIEEESingleNativeRef(bv, index);
#endif
}

float Sg_ByteVectorIEEESingleBigRef(SgByteVector *bv, long index)
{
#if WORDS_BIGENDIAN
  return Sg_ByteVectorIEEESingleNativeRef(bv, index);
#else
  size_t i;
  union {
    float fvalue;
    uint8_t data[sizeof(float)];
  } n;
  for (i = 0; i < sizeof(float); i++) {
    n.data[i] = SG_BVECTOR_ELEMENT(bv, index + sizeof(float) - i - 1);
  }
  return n.fvalue;
#endif
}

void Sg_ByteVectorIEEESingleNativeSet(SgByteVector *bv, long index, float value)
{
  union {
    float fvalue;
    uint8_t data[sizeof(float)];
  } n;
  n.fvalue = value;
  memcpy(SG_BVECTOR_ELEMENTS(bv) + index, n.data, sizeof(float));
}

void Sg_ByteVectorIEEESingleLittleSet(SgByteVector *bv, long index, float value)
{
#if WORDS_BIGENDIAN
  size_t i;
  union {
    float fvalue;
    uint8_t data[sizeof(float)];
  } n;
  n.fvalue = value;
  for (i = 0; i < sizeof(float); i++) {
    SG_BVECTOR_ELEMENT(bv, index + sizeof(float) - i - 1) = n.data[i]; 
  }
#else
  Sg_ByteVectorIEEESingleNativeSet(bv, index, value);
#endif
}

void Sg_ByteVectorIEEESingleBigSet(SgByteVector *bv, long index, float value)
{
#if WORDS_BIGENDIAN
  return Sg_ByteVectorIEEESingleNativeSet(bv, index, value);
#else
  size_t i;
  union {
    float fvalue;
    uint8_t data[sizeof(float)];
  } n;
  n.fvalue = value;
  for (i = 0; i < sizeof(float); i++) {
    SG_BVECTOR_ELEMENT(bv, index + sizeof(float) - i - 1) = n.data[i]; 
  }
#endif
}

/* double accessor */
double Sg_ByteVectorIEEEDoubleNativeRef(SgByteVector *bv, long index)
{
  union {
    double fvalue;
    uint8_t data[sizeof(double)];
  } n;
  memcpy(n.data, SG_BVECTOR_ELEMENTS(bv) + index, sizeof(double));
  return n.fvalue;
}

double Sg_ByteVectorIEEEDoubleLittleRef(SgByteVector *bv, long index)
{
#if WORDS_BIGENDIAN
  size_t i;
  union {
    double fvalue;
    uint8_t data[sizeof(double)];
  } n;
  for (i = 0; i < sizeof(double); i++) {
    n.data[i] = SG_BVECTOR_ELEMENT(bv, index + sizeof(double) - i - 1);
  }
  return n.fvalue;
#else
  return Sg_ByteVectorIEEEDoubleNativeRef(bv, index);
#endif
}

double Sg_ByteVectorIEEEDoubleBigRef(SgByteVector *bv, long index)
{
#if WORDS_BIGENDIAN
  return Sg_ByteVectorIEEEDoubleNativeRef(bv, index);
#else
  size_t i;
  union {
    double fvalue;
    uint8_t data[sizeof(double)];
  } n;
  for (i = 0; i < sizeof(double); i++) {
    n.data[i] = SG_BVECTOR_ELEMENT(bv, index + sizeof(double) - i - 1);
  }
  return n.fvalue;
#endif
}

void Sg_ByteVectorIEEEDoubleNativeSet(SgByteVector *bv,
				      long index, double value)
{
  union {
    double fvalue;
    uint8_t data[sizeof(double)];
  } n;
  n.fvalue = value;
  memcpy(SG_BVECTOR_ELEMENTS(bv) + index, n.data, sizeof(double));
}

void Sg_ByteVectorIEEEDoubleLittleSet(SgByteVector *bv,
				      long index, double value)
{
#if WORDS_BIGENDIAN
  size_t i;
  union {
    double fvalue;
    uint8_t data[sizeof(double)];
  } n;
  n.fvalue = value;
  for (i = 0; i < sizeof(double); i++) {
    SG_BVECTOR_ELEMENT(bv, index + sizeof(double) - i - 1) = n.data[i];
  }
#else
  Sg_ByteVectorIEEEDoubleNativeSet(bv, index, value);
#endif
}

void Sg_ByteVectorIEEEDoubleBigSet(SgByteVector *bv, long index, double value)
{
#if WORDS_BIGENDIAN
  Sg_ByteVectorIEEEDoubleNativeSet(bv, index, value);
#else
  size_t i;
  union {
    double fvalue;
    uint8_t data[sizeof(double)];
  } n;
  n.fvalue = value;
  for (i = 0; i < sizeof(double); i++) {
    SG_BVECTOR_ELEMENT(bv, index + sizeof(double) - i - 1) = n.data[i];
  }
#endif
}

static unsigned long fill_bits(unsigned long x, long bytes)
{
  unsigned long mask = ~((1UL << (bytes<<3))-1);
  return x | mask;
}

static SgObject bytevector2integer(SgByteVector *bv, long start, long end,
				   int sign)
{
  long len = SG_BVECTOR_SIZE(bv), i;
  SgObject ans = SG_MAKE_INT(0);
  SG_CHECK_START_END(start, end, len);
  /*
    We can make bignum directly if we see the given bytevector's size.
   */
  if (len > SIZEOF_LONG ||
      (len == SIZEOF_LONG && SG_BVECTOR_ELEMENT(bv, 0) > 0x1F)) {
    /* bignum
       the bignum's elements is reversed order, so if given bytevector is
       #vu(#x1F #xFF #xFF #xFF #x01) then the elements must be like this
       e[0] = 0xFFFFFF01
       e[1] = 0x1F.
     */
    int bignum_size = (int)ceil((double)len/SIZEOF_LONG);
    long i, pos;
    ans = Sg_MakeBignumWithSize(bignum_size, 0);
    for (i = 0, pos = end-1; i < bignum_size; i++, pos -= SIZEOF_LONG) {
      /* resolve bytevector with reverse order */
      unsigned long e = 0;
      int j;
      for (j = 0; j < SIZEOF_LONG; j++) {
	if (pos-j < start) break;
	e += (unsigned long)SG_BVECTOR_ELEMENT(bv, pos-j) << (j<<3);
      }
      SG_BIGNUM(ans)->elements[i] = e;
    }
    ans = Sg_NormalizeBignum(SG_BIGNUM(ans));
    /* if the sign flag is set and the very first byte's 8th bit is set
       then it's negative.*/
    if (sign && ((SG_BVECTOR_ELEMENT(bv, start) & 0x80) == 0x80)){
      /* in this case the ans still remains as bignum so we don't need to
	 check. */
      int bytes = end % SIZEOF_LONG;
      if (bytes) {
	unsigned long last = SG_BIGNUM(ans)->elements[bignum_size-1];
	last = fill_bits(last, bytes);
	SG_BIGNUM(ans)->elements[bignum_size-1] = last;
      }
      ans = Sg_BignumComplement(ans);
      SG_BIGNUM_SET_SIGN(ans, -1);
      ans = Sg_NormalizeBignum(ans);
    }

  } else {
    /* the result will be fixnum. */
    unsigned long lans = 0;
    for (i = end; start < i; i--) {
      lans += (unsigned long)SG_BVECTOR_ELEMENT(bv, i-1) << ((end-i)<<3);
    }
    if (sign && ((SG_BVECTOR_ELEMENT(bv, start) & 0x80) == 0x80)) {
      lans = fill_bits(lans, end);
      ans = Sg_MakeInteger(lans);
    } else {
      ans = Sg_MakeIntegerU(lans);
    }
  }
  return ans;
}

SgObject Sg_ByteVectorToIntegerSBig(SgByteVector *bv, long start, long end)
{
  return bytevector2integer(bv, start, end, TRUE);
}

SgObject Sg_ByteVectorToIntegerBig(SgByteVector *bv, long start, long end)
{
  return bytevector2integer(bv, start, end, FALSE);
}

static SgObject integer2bytevector(SgObject num, long size, int sign)
{
  int fill = 0;
  long bitlen, len;
  SgByteVector *bv;
  unsigned long left;
  
  /* calculate size without 2 complement */
  bitlen = Sg_BitSize(num);
  len = (bitlen>>3) + ((bitlen & 7) == 0 ? 0 : 1);
  /* if num == 0, then we need to add one */
  if (len == 0) len++;
  
  /* check if it's negative */
  if (sign) {
#define ROUNDUP8(v) (((v)+7)&(~7))
    if (SG_INTP(num)) {
      long v = SG_INT_VALUE(num);
      left = (unsigned long)v;
      if (v < 0) {
	fill = 0xFF;
      }
    } else {
      if (SG_BIGNUM_GET_SIGN(num) < 0) {
	num = Sg_BignumComplement(SG_BIGNUM(num));
	left = SG_BIGNUM(num)->elements[SG_BIGNUM(num)->size-1];
	bitlen = WORD_BITS - nlz(left);
	fill = 0xFF;
      } else {
	left = SG_BIGNUM(num)->elements[SG_BIGNUM(num)->size-1];
	bitlen = WORD_BITS - nlz(left);
      }
    }
    /* get left most byte */
    left = ((unsigned long)left >> (ROUNDUP8(bitlen) - 8)) & 0xFF;
    if (fill) {
      /* negative */
      /* up to 0x7F */
      if (left <= 0x7F) len++;
    } else {
      /* positive */
      /* 0x80 needs padding */
      if (left > 0x7F) len++;
    }
  }
  /* accept zero */
  if (size >= 0) {
    len = size;
  }
  bv = make_bytevector(len);
  memset(SG_BVECTOR_ELEMENTS(bv), fill, len);
  if (SG_BIGNUMP(num)) {
    /* the structure of bignum is commented above. this case we simply put
       the value from the bottom. */
    long pos, i;
    size_t bignum_size = SG_BIGNUM(num)->size;
    for (i = 0, pos = len-1; i < bignum_size; i++, pos -= SIZEOF_LONG) {
      unsigned long v = SG_BIGNUM(num)->elements[i];
      int j;
      for (j = 0; j < SIZEOF_LONG; j++) {
	if (pos-j < 0) break;
	SG_BVECTOR_ELEMENT(bv, pos-j) = (uint8_t)(v&0xFF);
	v >>= 8;
      }
    }    
  } else {
    long i;
    long v = SG_INT_VALUE(num);
    for (i = len - 1; 0 <= i; i--) {
      SG_BVECTOR_ELEMENT(bv, i) = (uint8_t)(v&0xFF);
      v >>= 8;
    }
  }

  return bv;
}

SgObject Sg_SIntegerToByteVectorBig(SgObject num, long size)
{
  if (!SG_EXACT_INTP(num)) {
    Sg_WrongTypeOfArgumentViolation(SG_INTERN("sinteger->bytevector"),
				    SG_MAKE_STRING("exact integer"),
				    num, num);
  }
  return integer2bytevector(num, size, TRUE);
}

SgObject Sg_IntegerToByteVectorBig(SgObject num, long size)
{
  /* we don't allow negative value for this */
  if (!SG_EXACT_INTP(num) || Sg_NegativeP(num)) {
    Sg_WrongTypeOfArgumentViolation(SG_INTERN("integer->bytevector"),
				    SG_MAKE_STRING("exact non negative integer"),
				    num, num);
  }
  return integer2bytevector(num, size, FALSE);
}

/* For now we just revert the given bv and pass to big */
/* FIXME implement seriously*/
/* FIXME at least reduce stack usage */
#define copy_to_tmp(tmp, bv)						\
  do {									\
    SG_ALLOC_TEMP_BVECTOR((tmp), SG_BVECTOR_SIZE(bv));			\
    Sg_ByteVectorCopyX(bv, 0, (tmp), 0, SG_BVECTOR_SIZE(bv));		\
    Sg_ByteVectorReverseX((tmp), 0, SG_BVECTOR_SIZE(bv));		\
  } while (0)
SgObject Sg_ByteVectorToIntegerLittle(SgByteVector *bv, long start, long end)
{
  SgByteVector *tmp;
  copy_to_tmp(tmp, bv);
  return Sg_ByteVectorToIntegerBig(tmp, start, end);
}
SgObject Sg_ByteVectorToIntegerSLittle(SgByteVector *bv, long start, long end)
{
  SgByteVector *tmp;
  copy_to_tmp(tmp, bv);
  return Sg_ByteVectorToIntegerSBig(tmp, start, end);
}
SgObject Sg_IntegerToByteVectorLittle(SgObject num, long size)
{
  SgObject bv = Sg_IntegerToByteVectorBig(num, size);
  return Sg_ByteVectorReverseX(bv, 0, SG_BVECTOR_SIZE(bv));
}
SgObject Sg_SIntegerToByteVectorLittle(SgObject num, long size)
{
  SgObject bv = Sg_SIntegerToByteVectorBig(num, size);
  return Sg_ByteVectorReverseX(bv, 0, SG_BVECTOR_SIZE(bv));
}

SgObject Sg_ByteVectorConcatenate(SgObject bvList)
{
  SgObject r, cp;
  long size = 0, i;
  SG_FOR_EACH(cp, bvList) {
    if (!SG_BVECTORP(SG_CAR(cp))) {
      Sg_WrongTypeOfArgumentViolation(SG_INTERN("bytevector-concatenate"),
				      SG_INTERN("bytevector"), 
				      SG_CAR(cp), bvList);
    }
    size += SG_BVECTOR_SIZE(SG_CAR(cp));
  }
  r = make_bytevector(size);
  if (size == 0) return r;
  i = 0;
  SG_FOR_EACH(cp, bvList) {
    long j;
    for (j = 0; j < SG_BVECTOR_SIZE(SG_CAR(cp)); j++, i++) {
      SG_BVECTOR_ELEMENT(r, i) = SG_BVECTOR_ELEMENT(SG_CAR(cp), j);
    }
  }
  return r;
}
