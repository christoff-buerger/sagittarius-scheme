/* compare.h                                       -*- mode:c; coding:utf-8; -*-
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
#ifndef SAGITTARIUS_COMPARE_H_
#define SAGITTARIUS_COMPARE_H_

#include "sagittariusdefs.h"

enum {
    SG_CMP_EQ,
    SG_CMP_EQV,
    SG_CMP_EQUAL
};

#define SG_EQ(x, y) ((x) == (y))

SG_CDECL_BEGIN

SG_EXTERN int Sg_EqP(SgObject x, SgObject y);
SG_EXTERN int Sg_EqvP(SgObject x, SgObject y);
SG_EXTERN int Sg_EqualP(SgObject x, SgObject y);
SG_EXTERN int SG_EqualM(SgObject x, SgObject y, int mode);

SG_CDECL_END

#endif /* SAGITTARIUS_COMPARE_H_ */

/*
  end of file
  Local Variables:
  coding: utf-8-unix
  End
*/
