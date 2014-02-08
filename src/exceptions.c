/* exceptions.c                                    -*- mode:c; coding:utf-8; -*-
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
#define LIBSAGITTARIUS_BODY
#include "sagittarius/exceptions.h"
#include "sagittarius/subr.h"
#include "sagittarius/pair.h"
#include "sagittarius/symbol.h"
#include "sagittarius/writer.h"
#include "sagittarius/port.h"
#include "sagittarius/string.h"
#include "sagittarius/vm.h"
#include "sagittarius/vector.h"
#include "sagittarius/record.h"
#include "sagittarius/error.h"
#include "sagittarius/library.h"
#include "sagittarius/keyword.h"
#include "sagittarius/string.h"

static SgClass *Sg_ConditionCPL[] = {
  SG_CLASS_CONSITION,
  SG_CLASS_TOP,
  NULL
};

static void compound_printer(SgObject o, SgPort *p, SgWriteContext *ctx)
{
  SgObject components = SG_COMPOUND_CONDITION(o)->components, cp;
  Sg_Putuz(p, UC("#<condition\n"));
  SG_FOR_EACH(cp, components) {
    Sg_Putc(p, ' ');
    Sg_Write(SG_CAR(cp), p, SG_WRITE_WRITE);
    Sg_Putc(p, '\n');
  }
  Sg_Putc(p, '>');
}


static SgObject allocate_compound_condition(SgClass *klass, SgObject initargs)
{
  SgObject cond = SG_ALLOCATE(SgCompoundCondition, klass);
  SG_SET_CLASS(cond, klass);
  SG_COMPOUND_CONDITION(cond)->components = SG_NIL;
  return cond;
}

static SgObject cc_components(SgCompoundCondition *c)
{
  if (!SG_COMPOUND_CONDITIONP(c)) {
    Sg_Error(UC("&compound-condition required but got %S"), c);
  }
  return c->components;
}
static void cc_components_set(SgCompoundCondition *c, SgObject comps)
{
  c->components = comps;
}
static SgSlotAccessor cc_slots[] = {
  SG_CLASS_SLOT_SPEC("components", 0, cc_components, cc_components_set),
  { { NULL } }
};

SG_DEFINE_BASE_CLASS(Sg_CompoundConditionClass, SgCompoundCondition,
		     compound_printer, NULL, NULL, allocate_compound_condition,
		     Sg_ConditionCPL);

SgObject Sg_Condition(SgObject components)
{
  SgObject h = SG_NIL, t = SG_NIL, component;
  SgObject cond;
  SG_FOR_EACH(component, components) {
    SgObject c = SG_CAR(component);
    if (!Sg_ConditionP(c)) {
      Sg_AssertionViolation(SG_INTERN("condition"),
			    Sg_Sprintf(UC("expected condition, but got %S"), c),
			    components);
    }
    if (SG_COMPOUND_CONDITIONP(c)) {
      SG_APPEND(h, t, SG_COMPOUND_CONDITION(c)->components);
    } else {
      SG_APPEND1(h, t, c);
    }
  }
  cond = allocate_compound_condition(SG_CLASS_COMPOUND_CONDITION, SG_NIL);
  SG_COMPOUND_CONDITION(cond)->components = h;
  return cond;
}

SgObject Sg_SimpleConditions(SgObject obj)
{
  if (Sg_SimpleConditionP(obj)) {
    return SG_LIST1(obj);
  } else if (Sg_CompoundConditionP(obj)) {
    return Sg_CompoundConditionComponent(obj);
  }
  return SG_UNDEF;		/* dummy */
}

SgObject Sg_CompoundConditionComponent(SgObject obj)
{
  if (!SG_COMPOUND_CONDITIONP(obj)) {
    Sg_Error(UC("compound-condition required but got %S"), obj);
  }
  return SG_COMPOUND_CONDITION(obj)->components;
}

int Sg_CompoundConditionP(SgObject obj)
{
  return SG_COMPOUND_CONDITIONP(obj);
}

int Sg_SimpleConditionP(SgObject obj)
{
  return SG_SIMPLE_CONDITIONP(obj);
}

int Sg_ConditionP(SgObject obj)
{
  return SG_CONDITIONP(obj);
}

/* classes */
static SgClass *base_cpl[] = {
  SG_CLASS_TOP,
  NULL
};
SG_DEFINE_ABSTRACT_CLASS(Sg_ConditionClass, base_cpl);

static SgObject condition_allocate(SgClass *klass, SgObject initargs)
{
  SgCondition *c = SG_ALLOCATE(SgCondition, klass);
  SG_SET_CLASS(c, klass);
  return SG_OBJ(c);
}

static void condition0_printer(SgObject o, SgPort *p, SgWriteContext *ctx)
{
  Sg_Printf(p, UC("#<%A>"), SG_CLASS(Sg_ClassOf(o))->name);
}

SG_DEFINE_BASE_CLASS(Sg_WarningClass, SgCondition,
		     condition0_printer, NULL, NULL, condition_allocate,
		     Sg_ConditionCPL);
SG_DEFINE_BASE_CLASS(Sg_SeriousClass, SgCondition,
		     condition0_printer, NULL, NULL, condition_allocate,
		     Sg_ConditionCPL);

static SgClass *serious_cpl[] = {
  SG_CLASS_SERIOUS,
  SG_CLASS_CONSITION,
  SG_CLASS_TOP,
  NULL
};
SG_DEFINE_BASE_CLASS(Sg_ErrorClass, SgCondition,
		     condition0_printer, NULL, NULL, condition_allocate,
		     serious_cpl);
SG_DEFINE_BASE_CLASS(Sg_ViolationClass, SgCondition,
		     condition0_printer, NULL, NULL, condition_allocate,
		     serious_cpl);
static SgClass *violation_cpl[] = {
  SG_CLASS_VIOLATION,
  SG_CLASS_SERIOUS,
  SG_CLASS_CONSITION,
  SG_CLASS_TOP,
  NULL
};
SG_DEFINE_BASE_CLASS(Sg_AssertionClass, SgCondition,
		     condition0_printer, NULL, NULL, condition_allocate,
		     violation_cpl);
SG_DEFINE_BASE_CLASS(Sg_NonContinuableClass, SgCondition,
		     condition0_printer, NULL, NULL, condition_allocate,
		     violation_cpl);
SG_DEFINE_BASE_CLASS(Sg_ImplementationRestrictionClass, SgCondition,
		     condition0_printer, NULL, NULL, condition_allocate,
		     violation_cpl);
SG_DEFINE_BASE_CLASS(Sg_LexicalConditionClass, SgCondition,
		     condition0_printer, NULL, NULL, condition_allocate,
		     violation_cpl);

static void syntax_printer(SgObject o, SgPort *p, SgWriteContext *ctx)
{
  Sg_Printf(p, UC("#<%A %S %S>"), SG_CLASS(Sg_ClassOf(o))->name,
	    SG_SYNTAX_CONDITION(o)->form,
	    SG_SYNTAX_CONDITION(o)->subform);
}
static SgObject syntax_allocate(SgClass *klass, SgObject initargs)
{
  SgSyntaxCondition *c = SG_ALLOCATE(SgSyntaxCondition, klass);
  SG_SET_CLASS(c, klass);
  return SG_OBJ(c);
}
static SgObject sc_form(SgSyntaxCondition *sc)
{
  if (!SG_SYNTAX_CONDITIONP(sc)) {
    Sg_Error(UC("&syntax required but got %S"), sc);
  }
  return sc->form;
}
static void sc_form_set(SgSyntaxCondition *sc, SgObject form)
{
  sc->form = form;
}
static SgObject sc_subform(SgSyntaxCondition *sc)
{
  if (!SG_SYNTAX_CONDITIONP(sc)) {
    Sg_Error(UC("&syntax required but got %S"), sc);
  }
  return sc->subform;
}
static void sc_subform_set(SgSyntaxCondition *sc, SgObject form)
{
  sc->subform = form;
}

static SgSlotAccessor sc_slots[] = {
  SG_CLASS_SLOT_SPEC("form",    0, sc_form, sc_form_set),
  SG_CLASS_SLOT_SPEC("subform", 1, sc_subform, sc_subform_set),
  { { NULL } }
};

SG_DEFINE_BASE_CLASS(Sg_SyntaxConditionClass, SgSyntaxCondition,
		     syntax_printer, NULL, NULL, syntax_allocate,
		     violation_cpl);

SG_DEFINE_BASE_CLASS(Sg_UndefinedConditionClass, SgCondition,
		     condition0_printer, NULL, NULL, condition_allocate,
		     violation_cpl);

static void message_printer(SgObject o, SgPort *p, SgWriteContext *ctx)
{
  Sg_Printf(p, UC("#<%A %A>"), SG_CLASS(Sg_ClassOf(o))->name,
	    SG_MESSAGE_CONDITION(o)->message);
}
static SgObject message_allocate(SgClass *klass, SgObject initargs)
{
  SgMessageCondition *c = SG_ALLOCATE(SgMessageCondition, klass);
  SG_SET_CLASS(c, klass);
  return SG_OBJ(c);
}
static SgObject msg_message(SgMessageCondition *mc)
{
  if (!SG_MESSAGE_CONDITIONP(mc)) {
    Sg_Error(UC("&message required but got %S"), mc);
  }
  return mc->message;
}
static void msg_message_set(SgMessageCondition *mc, SgObject msg)
{
  mc->message = msg;
}

static SgSlotAccessor msg_slots[] = {
  SG_CLASS_SLOT_SPEC("message", 0, msg_message, msg_message_set),
  { { NULL } }
};

SG_DEFINE_BASE_CLASS(Sg_MessageConditionClass, SgMessageCondition,
		     message_printer, NULL, NULL, message_allocate,
		     Sg_ConditionCPL);

static void irr_printer(SgObject o, SgPort *p, SgWriteContext *ctx)
{
  Sg_Printf(p, UC("#<%A %A>"), SG_CLASS(Sg_ClassOf(o))->name,
	    SG_IRRITATNS_CONDITION(o)->irritants);
}
static SgObject irr_allocate(SgClass *klass, SgObject initargs)
{
  SgIrritantsCondition *c = SG_ALLOCATE(SgIrritantsCondition, klass);
  SG_SET_CLASS(c, klass);
  return SG_OBJ(c);
}
static SgObject irr_irritants(SgIrritantsCondition *ic)
{
  if (!SG_IRRITATNS_CONDITIONP(ic)) {
    Sg_Error(UC("&irritants required but got %S"), ic);
  }
  return ic->irritants;
}
static void irr_irritants_set(SgIrritantsCondition *ic, SgObject irr)
{
  ic->irritants = irr;
}
static SgSlotAccessor irr_slots[] = {
  SG_CLASS_SLOT_SPEC("irritants", 0, irr_irritants, irr_irritants_set),
  { { NULL } }
};
SG_DEFINE_BASE_CLASS(Sg_IrritantsConditionClass, SgIrritantsCondition,
		     irr_printer, NULL, NULL, irr_allocate,
		     Sg_ConditionCPL);

static void who_printer(SgObject o, SgPort *p, SgWriteContext *ctx)
{
  Sg_Printf(p, UC("#<%A %A>"), SG_CLASS(Sg_ClassOf(o))->name,
	    SG_WHO_CONDITION(o)->who);
}
static SgObject who_allocate(SgClass *klass, SgObject initargs)
{
  SgWhoCondition *c = SG_ALLOCATE(SgWhoCondition, klass);
  SG_SET_CLASS(c, klass);
  return SG_OBJ(c);
}
static SgObject who_who(SgWhoCondition *wc)
{
  if (!SG_WHO_CONDITIONP(wc)) {
    Sg_Error(UC("&who required but got %S"), wc);
  }
  return wc->who;
}
static void who_who_set(SgWhoCondition *wc, SgObject who)
{
  wc->who = who;
}
static SgSlotAccessor who_slots[] = {
  SG_CLASS_SLOT_SPEC("who", 0, who_who, who_who_set),
  { { NULL } }
};
SG_DEFINE_BASE_CLASS(Sg_WhoConditionClass, SgWhoCondition,
		     who_printer, NULL, NULL, who_allocate,
		     Sg_ConditionCPL);

/* i/o */
static SgClass *error_cpl[] = {
  SG_CLASS_ERROR,
  SG_CLASS_SERIOUS,
  SG_CLASS_CONSITION,
  SG_CLASS_TOP,
  NULL
};
SG_DEFINE_BASE_CLASS(Sg_IOErrorClass, SgCondition,
		     condition0_printer, NULL, NULL, condition_allocate,
		     error_cpl);
static SgClass *io_cpl[] = {
  SG_CLASS_IO_ERROR,
  SG_CLASS_ERROR,
  SG_CLASS_SERIOUS,
  SG_CLASS_CONSITION,
  SG_CLASS_TOP,
  NULL
};
SG_DEFINE_BASE_CLASS(Sg_IOReadErrorClass, SgCondition,
		     condition0_printer, NULL, NULL, condition_allocate,
		     io_cpl);
SG_DEFINE_BASE_CLASS(Sg_IOWriteErrorClass, SgCondition,
		     condition0_printer, NULL, NULL, condition_allocate,
		     io_cpl);

static void port_printer(SgObject o, SgPort *p, SgWriteContext *ctx)
{
  Sg_Printf(p, UC("#<%A %A>"), SG_CLASS(Sg_ClassOf(o))->name,
	    SG_IO_PORT_ERROR(o)->port);
}
static SgObject port_allocate(SgClass *klass, SgObject initargs)
{
  SgIOPortError *c = SG_ALLOCATE(SgIOPortError, klass);
  SG_SET_CLASS(c, klass);
  return SG_OBJ(c);
}
static SgObject port_port(SgIOPortError *port)
{
  if (!SG_IO_PORT_ERRORP(port)) {
    Sg_Error(UC("&i/o-port required but got %S"), port);
  }
  return port->port;
}
static void port_port_set(SgIOPortError *port, SgObject src)
{
  port->port = src;
}
static SgSlotAccessor port_slots[] = {
  SG_CLASS_SLOT_SPEC("port", 0, port_port, port_port_set),
  { { NULL } }
};
SG_DEFINE_BASE_CLASS(Sg_IOPortErrorClass, SgIOPortError,
		     port_printer, NULL, NULL, port_allocate,
		     io_cpl);

static void enc_printer(SgObject o, SgPort *p, SgWriteContext *ctx)
{
  Sg_Printf(p, UC("#<%A %A:%S>"), SG_CLASS(Sg_ClassOf(o))->name,
	    SG_IO_ENCODING_ERROR(o)->port,
	    SG_IO_ENCODING_ERROR(o)->char_);
}
static SgObject enc_allocate(SgClass *klass, SgObject initargs)
{
  SgIOEncodingError *c = SG_ALLOCATE(SgIOEncodingError, klass);
  SG_SET_CLASS(c, klass);
  return SG_OBJ(c);
}
static SgObject enc_char(SgIOEncodingError *port)
{
  if (!SG_IO_ENCODING_ERRORP(port)) {
    Sg_Error(UC("&i/o-encoding required but got %S"), port);
  }
  return port->char_;
}
static void enc_char_set(SgIOEncodingError *port, SgObject src)
{
  port->port = src;
}
static SgSlotAccessor enc_slots[] = {
  SG_CLASS_SLOT_SPEC("port", 0, port_port, port_port_set),
  SG_CLASS_SLOT_SPEC("char", 1, enc_char, enc_char_set),
  { { NULL } }
};
static SgClass *port_cpl[] = {
  SG_CLASS_IO_PORT_ERROR,
  SG_CLASS_IO_ERROR,
  SG_CLASS_ERROR,
  SG_CLASS_SERIOUS,
  SG_CLASS_CONSITION,
  SG_CLASS_TOP,
  NULL
};
SG_DEFINE_BASE_CLASS(Sg_IOEncodingErrorClass, SgIOEncodingError,
		     enc_printer, NULL, NULL, enc_allocate,
		     port_cpl);
SG_DEFINE_BASE_CLASS(Sg_IODecodingErrorClass, SgIOPortError,
		     port_printer, NULL, NULL, port_allocate,
		     port_cpl);
/* position */
static void pos_printer(SgObject o, SgPort *p, SgWriteContext *ctx)
{
  Sg_Printf(p, UC("#<%A %A>"), SG_CLASS(Sg_ClassOf(o))->name,
	    SG_IO_INVALID_POSITION(o)->position);
}
static SgObject pos_allocate(SgClass *klass, SgObject initargs)
{
  SgIOInvalidPosition *c = SG_ALLOCATE(SgIOInvalidPosition, klass);
  SG_SET_CLASS(c, klass);
  return SG_OBJ(c);
}
static SgObject pos_position(SgIOInvalidPosition *ip)
{
  if (!SG_IO_INVALID_POSITIONP(ip)) {
    Sg_Error(UC("&i/o-invalid-position required but got %S"), ip);
  }
  return ip->position;
}
static void pos_position_set(SgIOInvalidPosition *ip, SgObject pos)
{
  ip->position = pos;
}
static SgSlotAccessor ip_slots[] = {
  SG_CLASS_SLOT_SPEC("position", 0, pos_position, pos_position_set),
  { { NULL } }
};
SG_DEFINE_BASE_CLASS(Sg_IOInvalidPositionClass, SgIOInvalidPosition,
		     pos_printer, NULL, NULL, pos_allocate,
		     io_cpl);
/* filename */
static void fn_printer(SgObject o, SgPort *p, SgWriteContext *ctx)
{
  Sg_Printf(p, UC("#<%A %A>"), SG_CLASS(Sg_ClassOf(o))->name,
	    SG_IO_FILENAME(o)->filename);
}
static SgObject fn_allocate(SgClass *klass, SgObject initargs)
{
  SgIOFilename *c = SG_ALLOCATE(SgIOFilename, klass);
  SG_SET_CLASS(c, klass);
  return SG_OBJ(c);
}
static SgObject fn_filename(SgIOFilename *fn)
{
  if (!SG_IO_FILENAMEP(fn)) {
    Sg_Error(UC("&i/o-filename required but got %S"), fn);
  }
  return fn->filename;
}
static void fn_filename_set(SgIOFilename *fn, SgObject name)
{
  fn->filename = name;
}
static SgSlotAccessor fn_slots[] = {
  SG_CLASS_SLOT_SPEC("filename", 0, fn_filename, fn_filename_set),
  { { NULL } }
};
SG_DEFINE_BASE_CLASS(Sg_IOFilenameClass, SgIOFilename,
		     fn_printer, NULL, NULL, fn_allocate,
		     io_cpl);
static SgClass *fn_cpl[] = {
  SG_CLASS_IO_FILENAME,
  SG_CLASS_IO_ERROR,
  SG_CLASS_ERROR,
  SG_CLASS_SERIOUS,
  SG_CLASS_CONSITION,
  SG_CLASS_TOP,
  NULL
};
SG_DEFINE_BASE_CLASS(Sg_IOFileProtectionClass, SgIOFilename,
		     fn_printer, NULL, NULL, fn_allocate,
		     fn_cpl);
static SgClass *fnp_cpl[] = {
  SG_CLASS_IO_FILE_PROTECTION,
  SG_CLASS_IO_FILENAME,
  SG_CLASS_IO_ERROR,
  SG_CLASS_ERROR,
  SG_CLASS_SERIOUS,
  SG_CLASS_CONSITION,
  SG_CLASS_TOP,
  NULL
};
SG_DEFINE_BASE_CLASS(Sg_IOFileIsReadOnlyClass, SgIOFilename,
		     fn_printer, NULL, NULL, fn_allocate,
		     fnp_cpl);
SG_DEFINE_BASE_CLASS(Sg_IOFileAlreadyExistsClass, SgIOFilename,
		     fn_printer, NULL, NULL, fn_allocate,
		     fn_cpl);
SG_DEFINE_BASE_CLASS(Sg_IOFileDoesNotExistClass, SgIOFilename,
		     fn_printer, NULL, NULL, fn_allocate,
		     fn_cpl);

/* compile */
static void comp_printer(SgObject o, SgPort *p, SgWriteContext *ctx)
{
  Sg_Printf(p, UC("#<%A %A %S>"), SG_CLASS(Sg_ClassOf(o))->name,
	    SG_COMPILE_CONDITION(o)->source,
	    SG_COMPILE_CONDITION(o)->program);
}
static SgObject comp_allocate(SgClass *klass, SgObject initargs)
{
  SgCompileCondition *c = SG_ALLOCATE(SgCompileCondition, klass);
  SG_SET_CLASS(c, klass);
  return SG_OBJ(c);
}
static SgObject comp_source(SgCompileCondition *c)
{
  return c->source;
}
static void comp_source_set(SgCompileCondition *c, SgObject s)
{
  c->source = s;
}
static SgObject comp_prog(SgCompileCondition *c)
{
  if (!SG_COMPILE_CONDITIONP(c)) {
    Sg_Error(UC("&compile required but got %S"), c);
  }
  return c->program;
}
static void comp_prog_set(SgCompileCondition *c, SgObject p)
{
  if (!SG_COMPILE_CONDITIONP(c)) {
    Sg_Error(UC("&compile required but got %S"), c);
  }
  c->program = p;
}
static SgSlotAccessor cmp_slots[] = {
  SG_CLASS_SLOT_SPEC("source",  0, comp_source, comp_source_set),
  SG_CLASS_SLOT_SPEC("program", 1, comp_prog, comp_prog_set),
  { { NULL } }
};
SG_DEFINE_BASE_CLASS(Sg_CompileConditionClass, SgCompileCondition,
		     comp_printer, NULL, NULL, comp_allocate,
		     error_cpl);

static void imp_printer(SgObject o, SgPort *p, SgWriteContext *ctx)
{
  Sg_Printf(p, UC("#<%A %A>"), SG_CLASS(Sg_ClassOf(o))->name,
	    SG_IMPORT_CONDITION(o)->library);
}
static SgObject imp_allocate(SgClass *klass, SgObject initargs)
{
  SgImportCondition *c = SG_ALLOCATE(SgImportCondition, klass);
  SG_SET_CLASS(c, klass);
  return SG_OBJ(c);
}
static SgObject imp_lib(SgImportCondition *c)
{
  if (!SG_IMPORT_CONDITIONP(c)) {
    Sg_Error(UC("&import required but got %S"), c);
  }
  return c->library;
}
static void imp_lib_set(SgImportCondition *c, SgObject p)
{
  c->library = p;
}
static SgSlotAccessor imp_slots[] = {
  SG_CLASS_SLOT_SPEC("library",  0, imp_lib, imp_lib_set),
  { { NULL } }
};
SG_DEFINE_BASE_CLASS(Sg_ImportConditionClass, SgImportCondition,
		     imp_printer, NULL, NULL, imp_allocate,
		     error_cpl);


SgObject Sg_MakeNonContinuableViolation()
{
  return condition_allocate(SG_CLASS_NON_CONTINUABLE, SG_NIL);
}

SgObject Sg_MakeAssertionViolation()
{
  return condition_allocate(SG_CLASS_ASSERTION, SG_NIL);
}

SgObject Sg_MakeUndefinedViolation()
{
  return condition_allocate(SG_CLASS_UNDEFINED_CONDITION, SG_NIL);
}

SgObject Sg_MakeImplementationRestrictionViolation()
{
  return condition_allocate(SG_CLASS_IMPLEMENTATION_RESTRICTION, SG_NIL);
}

SgObject Sg_MakeWhoCondition(SgObject who)
{
  SgObject c = who_allocate(SG_CLASS_WHO_CONDITION, SG_NIL);
  SG_WHO_CONDITION(c)->who = who;
  return SG_OBJ(c);
}

SgObject Sg_MakeMessageCondition(SgObject msg)
{
  SgObject c = message_allocate(SG_CLASS_MESSAGE_CONDITION, SG_NIL);
  SG_MESSAGE_CONDITION(c)->message = msg;
  return SG_OBJ(c);
}

SgObject Sg_MakeIrritantsCondition(SgObject irritants)
{
  SgObject c = message_allocate(SG_CLASS_IRRITANTS_CONDITION, SG_NIL);
  SG_IRRITATNS_CONDITION(c)->irritants = irritants;
  return SG_OBJ(c);
}

SgObject Sg_MakeWarning()
{
  return condition_allocate(SG_CLASS_WARNING, SG_NIL);
}

SgObject Sg_MakeReaderCondition(SgObject msg)
{
  SgObject l = condition_allocate(SG_CLASS_LEXICAL_CONDITION, SG_NIL);
  SgObject r = condition_allocate(SG_CLASS_IO_READ_ERROR, SG_NIL);
  return Sg_Condition(SG_LIST3(l, r,
			       Sg_MakeMessageCondition(msg)));
}

SgObject Sg_MakeError(SgObject msg)
{
  return Sg_Condition(SG_LIST2(condition_allocate(SG_CLASS_ERROR, SG_NIL),
			       Sg_MakeMessageCondition(msg)));
}

SgObject Sg_MakeSyntaxError(SgObject msg, SgObject form)
{
  SgObject subform = SG_FALSE;
  SgObject s = syntax_allocate(SG_CLASS_SYNTAX_CONDITION, SG_NIL);
  if (SG_PAIRP(form) && SG_PAIRP(SG_CAR(form))) {
    subform = SG_CDR(form);
    form = SG_CAR(form);
  }
  SG_SYNTAX_CONDITION(s)->form = form;
  SG_SYNTAX_CONDITION(s)->subform = subform;
  return Sg_Condition(SG_LIST2(s, Sg_MakeMessageCondition(msg)));
}

static void describe_simple(SgPort *out, SgObject con)
{
  SgClass *klass = Sg_ClassOf(con);
  SgSlotAccessor **acc = klass->gettersNSetters;
  int count = klass->nfields;
  Sg_Write(klass->name, out, SG_WRITE_WRITE);
  for (; acc && *acc; acc++) {
    SgObject v = Sg_SlotRefUsingAccessor(con, (*acc));
    if (count == 1) {
      if (SG_STRINGP(v)) {
	Sg_Printf(out, UC(" %A"), v);
      } else {
	Sg_Printf(out, UC(" %S"), v);
      }
    } else {
      if (SG_STRINGP(v)) {
	Sg_Printf(out, UC("\n    %A: %A"), (*acc)->name, v);
      } else {
	Sg_Printf(out, UC("\n    %A: %S"), (*acc)->name, v);
      }
    }
  }
}

SgObject Sg_DescribeCondition(SgObject con)
{
  if (Sg_ConditionP(con)) {
    SgPort out;
    SgTextualPort tp;
    SgObject cp;
    Sg_InitStringOutputPort(&out, &tp, 512);
    Sg_PutzUnsafe(&out, "#<condition\n");
    if (SG_SIMPLE_CONDITIONP(con)) {
      Sg_PutzUnsafe(&out, "  ");
      describe_simple(&out, con);
    } else {
      SgObject comp;
      SG_FOR_EACH(comp, SG_COMPOUND_CONDITION(con)->components) {
	Sg_PutzUnsafe(&out, "  ");
	describe_simple(&out, SG_CAR(comp));
	Sg_PutcUnsafe(&out, '\n');
      }
    }
    Sg_PutzUnsafe(&out, "\n>");
    cp = Sg_GetStringFromStringPort(&out);
    SG_CLEAN_TEXTUAL_PORT(&tp);
    return cp;
  } else {
    return con;
  }
}

static void append_immutable(SgClass *klass)
{
  /* add :mutable #f, well it's useless but in case
     somebody make with (make &message) or so... */
  SgObject cp;
  SgObject immutable = SG_LIST2(Sg_MakeKeyword(SG_MAKE_STRING("mutable")),
				SG_FALSE);
  SG_FOR_EACH(cp, klass->directSlots) {
    Sg_Append2X(SG_CAR(cp), immutable);
  }
}

static SgObject predicate(SgObject *args, int argc, void *user_data)
{
  return Sg_VMIsA(args[0], SG_CLASS(user_data));
}
static SgObject accessor(SgObject *args, int argc, void *user_data)
{
  return ((SgObject(*)(SgObject))user_data)(args[0]);
}
/* 0 argument can be very easy :)  */
static SgObject invoke0(SgObject *args, int argc, void *user_data)
{
  return condition_allocate((SgClass *)user_data, SG_NIL);
}
/* call allocator directly and use slot accessor directly...*/
static SgObject invoken(SgObject *args, int argc, void *user_data)
{
  SgClass *klass = SG_CLASS(user_data);
  SgObject c = klass->allocate(klass, SG_NIL);
  SgSlotAccessor **accs = klass->gettersNSetters;
  int i;
  for (i = 0;accs && *accs; accs++, i++) {
    if (i == argc) break;	/* in case */
    Sg_SlotSetUsingAccessor(c, *accs, args[i]);
  }
  return SG_OBJ(c);
}

void Sg__InitConsitions()
{
  SgObject lib = Sg_FindLibrary(SG_INTERN("(core)"), FALSE);

  /* TODO think about how to initialise... */
  /* need record metaclass */
#define INIT_CONDITION(cl, nam, slots)					\
  do {									\
    SgObject m = Sg_AllocateRecordTypeMeta(SG_CLASS_RECORD_TYPE_META,	\
					   SG_NIL);			\
    Sg_InitStaticClassWithMeta(cl, UC(nam), lib, SG_CLASS(m),		\
			       SG_NIL,  slots, 0);			\
    append_immutable(cl);						\
  } while (0)

  INIT_CONDITION(SG_CLASS_CONSITION, "&condition", NULL);
  INIT_CONDITION(SG_CLASS_WARNING, "&warning", NULL);
  INIT_CONDITION(SG_CLASS_SERIOUS, "&serious", NULL);
  INIT_CONDITION(SG_CLASS_ERROR,   "&error", NULL);
  INIT_CONDITION(SG_CLASS_VIOLATION, "&violation", NULL);
  INIT_CONDITION(SG_CLASS_ASSERTION, "&assertion", NULL);
  INIT_CONDITION(SG_CLASS_NON_CONTINUABLE, "&non-continuable", NULL);
  INIT_CONDITION(SG_CLASS_IMPLEMENTATION_RESTRICTION, 
		 "&implementation-restriction", NULL);
  INIT_CONDITION(SG_CLASS_LEXICAL_CONDITION, "&lexical", NULL);
  INIT_CONDITION(SG_CLASS_SYNTAX_CONDITION, "&syntax", sc_slots);
  INIT_CONDITION(SG_CLASS_UNDEFINED_CONDITION, "&undefined", NULL);
  INIT_CONDITION(SG_CLASS_MESSAGE_CONDITION, "&message", msg_slots);
  INIT_CONDITION(SG_CLASS_IRRITANTS_CONDITION, "&irritants", irr_slots);
  INIT_CONDITION(SG_CLASS_WHO_CONDITION, "&who", who_slots);
  /* i/o */
  INIT_CONDITION(SG_CLASS_IO_ERROR, "&i/o", NULL);
  INIT_CONDITION(SG_CLASS_IO_READ_ERROR, "&i/o-read", NULL);
  INIT_CONDITION(SG_CLASS_IO_WRITE_ERROR, "&i/o-write", NULL);
  INIT_CONDITION(SG_CLASS_IO_INVALID_POSITION, 
		 "&i/o-invalid-position", ip_slots);
  INIT_CONDITION(SG_CLASS_IO_FILENAME, "&i/o-filename", fn_slots);
  INIT_CONDITION(SG_CLASS_IO_FILE_PROTECTION, "&i/o-file-protection", NULL);
  INIT_CONDITION(SG_CLASS_IO_FILE_IS_READ_ONLY, "&i/o-file-is-read-only", NULL);
  INIT_CONDITION(SG_CLASS_IO_FILE_ALREADY_EXISTS,
		 "&i/o-file-already-exists", NULL);
  INIT_CONDITION(SG_CLASS_IO_FILE_DOES_NOT_EXIST,
		 "&i/o-file-does-not-exist", NULL);
  INIT_CONDITION(SG_CLASS_IO_PORT_ERROR, "&i/o-port", port_slots);
  INIT_CONDITION(SG_CLASS_IO_ENCODING_ERROR, "&i/o-encoding", enc_slots);
  INIT_CONDITION(SG_CLASS_IO_DECODING_ERROR, "&i/o-decoding", NULL);
  /* compile */
  INIT_CONDITION(SG_CLASS_COMPILE_CONDITION, "&compile", cmp_slots);
  INIT_CONDITION(SG_CLASS_IMPORT_CONDITION, "&import", imp_slots);
  /* compound */
  INIT_CONDITION(SG_CLASS_COMPOUND_CONDITION, "&compound-condition", cc_slots);

  /* ctr&pred */
#define INIT_PRED(cl, name)						\
  do {									\
    SgObject pred = Sg_MakeSubr(predicate, cl, 1, 0, SG_MAKE_STRING(name)); \
    Sg_InsertBinding(SG_LIBRARY(lib), SG_INTERN(name), pred);		\
  } while (0);
#define INIT_CTR0(cl, name, pred)					\
  do {									\
    SgObject proc = Sg_MakeSubr(invoke0, cl, 0, 0, SG_MAKE_STRING(name)); \
    Sg_InsertBinding(SG_LIBRARY(lib), SG_INTERN(name), proc);		\
    INIT_PRED(cl, pred);						\
  } while (0)
#define INIT_ACC(fn, name)						\
  do {									\
    SgObject acc = Sg_MakeSubr(accessor, fn, 1, 0, SG_MAKE_STRING(name)); \
    Sg_InsertBinding(SG_LIBRARY(lib), SG_INTERN(name), acc);		\
  } while (0);
#define INIT_CTR1(cl, name, pred, acc, accnm)				\
  do {									\
    SgObject proc = Sg_MakeSubr(invoken, cl, 1, 0, SG_MAKE_STRING(name)); \
    Sg_InsertBinding(SG_LIBRARY(lib), SG_INTERN(name), proc);		\
    INIT_PRED(cl, pred);						\
    INIT_ACC(acc, accnm);						\
  } while (0)
#define INIT_CTR2(cl, name, pred, acc, accnm, acc2, accnm2)		\
  do {									\
    SgObject proc = Sg_MakeSubr(invoken, cl, 2, 0, SG_MAKE_STRING(name)); \
    Sg_InsertBinding(SG_LIBRARY(lib), SG_INTERN(name), proc);		\
    INIT_PRED(cl, pred);						\
    INIT_ACC(acc, accnm);						\
    INIT_ACC(acc2, accnm2);						\
  } while (0)

  INIT_CTR0(SG_CLASS_WARNING, "make-warning", "warning?");
  INIT_CTR0(SG_CLASS_SERIOUS, "make-serious-condition", "serious-condition?");
  INIT_CTR0(SG_CLASS_ERROR,   "make-error", "error?");
  INIT_CTR0(SG_CLASS_VIOLATION, "make-violation", "violation?");
  INIT_CTR0(SG_CLASS_ASSERTION, "make-assertion-violation",
	    "assertion-violation?");
  INIT_CTR0(SG_CLASS_NON_CONTINUABLE, "make-non-continuable-violation",
	    "non-continuable-violation?");
  INIT_CTR0(SG_CLASS_IMPLEMENTATION_RESTRICTION, 
	    "make-implementation-restriction-violation",
	    "implementation-restriction-violation?");
  INIT_CTR0(SG_CLASS_LEXICAL_CONDITION, "make-lexical-violation", 
	    "lexical-violation?");
  INIT_CTR0(SG_CLASS_UNDEFINED_CONDITION, "make-undefined-violation",
	    "undefined-violation?");

  INIT_CTR2(SG_CLASS_SYNTAX_CONDITION,
	    "make-syntax-violation", "syntax-violation?",
	    sc_form, "&syntax-violation-form",
	    sc_subform, "&syntax-violation-subform");

  INIT_CTR1(SG_CLASS_MESSAGE_CONDITION, "make-message-condition",
	    "message-condition?", msg_message, "&message-message");
  INIT_CTR1(SG_CLASS_IRRITANTS_CONDITION, "make-irritants-condition",
	    "irritants-condition?", irr_irritants, "&irritants-irritants");
  INIT_CTR1(SG_CLASS_WHO_CONDITION, "make-who-condition", "who-condition?",
	    who_who, "&who-who");

  /* i/o */
  INIT_CTR0(SG_CLASS_IO_ERROR, "make-i/o-error", "i/o-error?");
  INIT_CTR0(SG_CLASS_IO_READ_ERROR, "make-i/o-read-error", "i/o-read-error?");
  INIT_CTR0(SG_CLASS_IO_WRITE_ERROR, "make-i/o-write-error", "i/o-write-error?");

  INIT_CTR1(SG_CLASS_IO_INVALID_POSITION,
	    "make-i/o-invalid-position-error", "i/o-invalid-position-error?",
	    pos_position, "&i/o-invalid-position-position");
  INIT_CTR1(SG_CLASS_IO_FILENAME, 
	    "make-i/o-filename-error", "i/o-filename-error?",
	    fn_filename, "&i/o-filename-filename");
  INIT_CTR0(SG_CLASS_IO_FILE_PROTECTION, "make-i/o-file-protection-error",
	    "i/o-file-protection-error?");
  INIT_CTR0(SG_CLASS_IO_FILE_IS_READ_ONLY, 
	    "make-i/o-file-is-read-only-error", "i/o-file-is-read-only-error?");
  INIT_CTR0(SG_CLASS_IO_FILE_ALREADY_EXISTS, 
	    "make-i/o-file-already-exists-error", 
	    "i/o-file-already-exists-error?");
  INIT_CTR0(SG_CLASS_IO_FILE_DOES_NOT_EXIST,
	    "make-i/o-file-does-not-exist-error", 
	    "i/o-file-does-not-exist-error?");
  INIT_CTR1(SG_CLASS_IO_PORT_ERROR, "make-i/o-port-error", "i/o-port-error?",
	    port_port, "&i/o-port-port");
  INIT_CTR0(SG_CLASS_IO_PORT_ERROR, "make-i/o-decoding-error", 
	    "i/o-decoding-error?");
  INIT_CTR1(SG_CLASS_IO_PORT_ERROR,
	    "make-i/o-encoding-error", "i/o-encoding-error?",
	    enc_char, "&i/o-encoding-char");
  /* compile */
  INIT_CTR2(SG_CLASS_COMPILE_CONDITION, "make-compile-error", "compile-error?",
	    comp_source, "&compile-error-source",
	    comp_prog, "&compile-error-program");
  INIT_CTR1(SG_CLASS_IMPORT_CONDITION, "make-import-error", "import-error?",
	    imp_lib, "&import-library");
  /* compound */
  INIT_CTR1(SG_CLASS_COMPOUND_CONDITION,
	    "make-compound-condition", "compound-condition?",
	    cc_components, "&compound-condition-components");
}
