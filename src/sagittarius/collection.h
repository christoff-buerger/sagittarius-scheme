/* collection.h                                           -*- coding: utf-8; -*-
 *
 *   Copyright (c) 2010-2014  Takashi Kato <ktakashi@ymail.com>
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
#ifndef SAGITTARIUS_COLLECTION_H_
#define SAGITTARIUS_COLLECTION_H_

/* definition of collections */
#include "sagittariusdefs.h"
#include "clos.h"

SG_CLASS_DECL(Sg_CollectionClass);
SG_CLASS_DECL(Sg_SequenceClass);
SG_CLASS_DECL(Sg_DictionaryClass);
SG_CLASS_DECL(Sg_OrderedDictionaryClass);

#define SG_CLASS_COLLECTION 	    (&Sg_CollectionClass)
#define SG_CLASS_SEQUENCE   	    (&Sg_SequenceClass)
#define SG_CLASS_DICTIONARY 	    (&Sg_DictionaryClass)
#define SG_CLASS_ORDERED_DICTIONARY (&Sg_OrderedDictionaryClass)

extern SgClass *Sg__OrderedDictionaryCPL[];
extern SgClass *Sg__SequenceCPL[];

#define SG_CLASS_COLLECTION_CPL 	(Sg__SequenceCPL+1)
#define SG_CLASS_SEQUENCE_CPL   	(Sg__SequenceCPL)
#define SG_CLASS_DICTIONARY_CPL 	(Sg__OrderedDictionaryCPL+2)
#define SG_CLASS_ORDERED_DICTIONARY_CPL (Sg__OrderedDictionaryCPL)


#endif /* SAGITTARIUS_COLLECTION_H_ */
