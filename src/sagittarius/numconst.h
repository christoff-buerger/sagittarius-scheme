/* numconst.h                                      -*- mode:c; coding:utf-8; -*-
 *
 *   Copyright (c) 2010-2015  Takashi Kato <ktakashi@ymail.com>
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
#ifndef SAGITTARIUS_NUMCONST_H_
#define SAGITTARIUS_NUMCONST_H_

#include "sagittariusdefs.h"

SG_CDECL_BEGIN
SG_EXTERN SgObject Sg__ConstObjes[]; /* initialized in number.c */
SG_CDECL_END

#define SG_2_52               (Sg__ConstObjes[0]) /* 2^52 */
#define SG_2_53               (Sg__ConstObjes[1]) /* 2^53 */
#define SG_POSITIVE_INFINITY  (Sg__ConstObjes[2]) /* #i1/0 */
#define SG_NEGATIVE_INFINITY  (Sg__ConstObjes[3]) /* #i-1/0 */
#define SG_NAN                (Sg__ConstObjes[4]) /* #<nan> */
#define SG_FL_POSITIVE_ZERO   (Sg__ConstObjes[5]) /* 0.0 */
#define SG_FL_NEGATIVE_ZERO   (Sg__ConstObjes[6]) /* -0.0 */
#define SG_NUM_CONST_OBJS 7

#endif /* SAGITTARIUS_NUMCONST_H_ */

/*
  end of file
  Local Variables:
  coding: utf-8-unix
  End
*/
