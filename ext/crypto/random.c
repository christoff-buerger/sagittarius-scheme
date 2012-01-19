/* -*- C -*- */
/*
 * random.c
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
#include <sagittarius.h>
#define LIBSAGITTARIUS_BODY
#include <sagittarius/extend.h>
#include "math.h"

static void prng_printer(SgObject self, SgPort *port, SgWriteContext *ctx)
{
  Sg_Printf(port, UC("#<prng %A>"), SG_PRNG(self)->name);
}

SG_DEFINE_BUILTIN_CLASS_SIMPLE(Sg_PrngClass, prng_printer);

static SgPrng* make_prng(int type, SgString *name)
{
  SgPrng *prng = SG_NEW(SgPrng);
  SG_SET_CLASS(prng, SG_CLASS_PRNG);
  prng->type = type;
  prng->name = name;
  return prng;
}

static void finalize_prng(SgObject prng, void *data)
{
  prng_descriptor[SG_PRNG(prng)->impl.builtin.wprng]
    .done(&SG_PRNG(prng)->impl.builtin.prng);
}

SgObject Sg_MakePseudoRandom(SgString *name, SgObject seed)
{
  const char *cname = Sg_Utf32sToUtf8s(name);
  int wprng = find_prng(cname), err;
  SgPrng *prng;
  
  if (wprng == -1) {
    Sg_Error(UC("%A is not supported"), name);
    return SG_UNDEF;
  }

  prng = make_prng(SG_BUILTIN_PRNG, name);
  SG_PRNG(prng)->impl.builtin.wprng = wprng;
  err = prng_descriptor[wprng].start(&SG_PRNG(prng)->impl.builtin.prng);
  if (err != CRYPT_OK) goto err;

  err = prng_descriptor[wprng].ready(&SG_PRNG(prng)->impl.builtin.prng);
  if (err != CRYPT_OK) goto err;

  if (!SG_FALSEP(seed)) {
    if (SG_BVECTORP(seed)) {
      err = prng_descriptor[wprng]
	.add_entropy(SG_BVECTOR_ELEMENTS(seed),
		     SG_BVECTOR_SIZE(seed),
		     &SG_PRNG(prng)->impl.builtin.prng);
      if (err != CRYPT_OK) goto err;
    } else { goto err; }
  }

  Sg_RegisterFinalizer(prng, finalize_prng, NULL);
  return SG_OBJ(prng);
 err:
  Sg_Error(UC("Failed to initialize pseudo random: %A"),
	   Sg_MakeStringC(error_to_string(err)));
  return SG_UNDEF;
}

void Sg_SetSeed(SgPrng *prng, SgByteVector *seed)
{
  int err;
  if (prng->type != SG_BUILTIN_PRNG ||
      prng->type != SG_SECURE_PRNG) return;
  err = prng_descriptor[SG_PRNG(prng)->impl.builtin.wprng]
    .add_entropy(SG_BVECTOR_ELEMENTS(seed),
		 SG_BVECTOR_SIZE(seed),
		 &SG_PRNG(prng)->impl.builtin.prng);
  if (err != CRYPT_OK) {
    Sg_Error(UC("Failed to set seed. %A"), seed);
  }
}

SgObject Sg_MakeSecureRandom(SgString *name, int bits)
{
  const char *cname = Sg_Utf32sToUtf8s(name);
  int wprng = find_prng(cname), err;
  SgPrng *prng;
  
  if (wprng == -1) {
    Sg_Error(UC("%A is not supported"), name);
    return SG_UNDEF;
  }

  prng = make_prng(SG_SECURE_PRNG, name);
  SG_PRNG(prng)->impl.builtin.wprng = wprng;

  err = rng_make_prng(bits, wprng, &SG_PRNG(prng)->impl.builtin.prng, NULL);
  if (err != CRYPT_OK) {
    Sg_Error(UC("Failed to initialize secure random: %A"),
	     Sg_MakeStringC(error_to_string(err)));
    return SG_UNDEF;
  }
  Sg_RegisterFinalizer(prng, finalize_prng, NULL);
  return SG_OBJ(prng);
}


SgObject Sg_ReadRandomBytes(SgPrng *prng, int size)
{
  SgByteVector *buf = SG_BVECTOR(Sg_MakeByteVector(size, 0));
  switch (prng->type) {
  case SG_BUILTIN_PRNG:
  case SG_SECURE_PRNG:
    if (prng_descriptor[SG_PRNG(prng)->impl.builtin.wprng]
	  .read(SG_BVECTOR_ELEMENTS(buf), size,
		&SG_PRNG(prng)->impl.builtin.prng) != size) {
      Sg_Error(UC("read random error"));
      return SG_UNDEF;
    }
    break;
  case SG_CUSTOM_PRNG:
    Sg_Apply2(prng->impl.readRandom, buf, Sg_MakeInteger(size));
    break;
  }
  return SG_OBJ(buf);
}

SgObject Sg_MakeCustomPrng(SgString *name, SgObject readRandom)
{
  SgPrng *prng = make_prng(SG_CUSTOM_PRNG, name);
  prng->impl.readRandom = readRandom;
  return SG_OBJ(prng);
}
