/* kernal.c                                        -*- mode:c; coding:utf-8; -*-
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
 */
#define LIBSAGITTARIUS_BODY
#include "sagittarius/private/kernel.h"
#include "sagittarius/private/writer.h"
#include "sagittarius/private/vm.h"

static void kernel_print(SgObject obj, SgPort *port, SgWriteContext *ctx)
{
  Sg_Printf(port, UC("#<kernel 0x%x threads=%d>"), obj,
	    SG_KERNEL(obj)->nThreads);
}

SG_DEFINE_BUILTIN_CLASS_SIMPLE(Sg_KernelClass, kernel_print);

SgObject Sg_NewKernel(SgVM *rootVM)
{
  SgKernel *k = SG_NEW(SgKernel);
  SG_SET_CLASS(k, SG_CLASS_KERNEL);
  k->nThreads = 1;
  k->threads = SG_NEW(SgDLinkNode);
  k->threads->value = rootVM;
  k->threads->prev =  k->threads->next = NULL;
  rootVM->kernel = k;
  return SG_OBJ(k);
}
