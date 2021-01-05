/* identifier.c                                    -*- mode:c; coding:utf-8; -*-
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
#define LIBSAGITTARIUS_BODY
#include "sagittarius/private/identifier.h"
#include "sagittarius/private/symbol.h"
#include "sagittarius/private/library.h"
#include "sagittarius/private/pair.h"
#include "sagittarius/private/vector.h"
#include "sagittarius/private/hashtable.h"
#include "sagittarius/private/writer.h"
#include "sagittarius/private/port.h"
#include "sagittarius/private/reader.h"
#include "sagittarius/private/vm.h"

static void id_print(SgObject obj, SgPort *port, SgWriteContext *ctx)
{
  SgIdentifier *id = SG_IDENTIFIER(obj);
  Sg_Putuz(port, UC("#<identifier "));
  Sg_Write(id->name, port, ctx->mode);
  Sg_Putc(port, '#');
  if (SG_LIBRARYP(id->library)) {
    Sg_Write(id->library->name, port, SG_WRITE_DISPLAY);
  }
#if 1
  if (SG_WRITE_MODE(ctx) == SG_WRITE_WRITE ||
      SG_WRITE_MODE(ctx) == SG_WRITE_SHARED) {
    char buf[50];
    Sg_Putc(port, ' ');
    Sg_Write(SG_IDENTIFIER_IDENTITY(id), port, SG_WRITE_WRITE);
    snprintf(buf, sizeof(buf), " (%p):%d", id, SG_IDENTIFIER_PENDING(id));
    Sg_Putz(port, buf);
  }
  /* Sg_Write(id->envs, port, SG_WRITE_SHARED); */
#endif
  Sg_Putc(port, '>');
}

SG_DEFINE_BUILTIN_CLASS_SIMPLE(Sg_IdentifierClass, id_print);

SgObject Sg_MakeRawIdentifier(SgObject name, SgObject envs, SgObject identity,
			      SgLibrary *library, int pendingP)
{
  SgIdentifier *id = SG_NEW(SgIdentifier);
  SG_SET_CLASS(id, SG_CLASS_IDENTIFIER);
  SG_INIT_IDENTIFIER(id, name, envs, identity, library, pendingP);
  return SG_OBJ(id);
}

/* 
   this is used from builtin libraries and the envs must be '() 
*/
SgObject Sg_MakeGlobalIdentifier(SgObject name, SgLibrary *library)
{
  return Sg_MakeRawIdentifier(name, SG_NIL, SG_FALSE, library, FALSE);
}

void Sg__InitIdentifier()
{
  /* For future we might want to make identifier <object> to use slot-ref
     but for now.*/
  SgLibrary *clib = Sg_FindLibrary(SG_INTERN("(sagittarius clos)"), TRUE);
  Sg_InitStaticClass(SG_CLASS_IDENTIFIER, UC("<identifier>"), clib, NULL, 0);
}
/*
  end of file
  Local Variables:
  coding: utf-8-unix
  End:
*/
