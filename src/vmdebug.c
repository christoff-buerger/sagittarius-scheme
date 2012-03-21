/*Generated by genstub. Do not edit.*/

#line 11 "vmdebug.stub"

#define LIBSAGITTARIUS_BODY


#line 12 "vmdebug.stub"
#include <sagittarius.h>

static struct sg__rcRec {
  SgObject d428[3];
} sg__rc = {
  {  /* SgObject d428 */
    SG_UNBOUND,
    SG_UNBOUND,
    SG_UNBOUND,
  },
};
static SgObject vmdebug_vm_dump_code(SgObject *SG_FP, int SG_ARGC, void *data_)
{
  SgObject cb_scm;
  SgCodeBuilder* cb;
  SG_ENTER_SUBR("vm-dump-code");
  if (SG_ARGC != 1)
    Sg_WrongNumberOfArgumentsViolation(
     SG_INTERN("vm-dump-code"), 1, SG_ARGC, SG_NIL);
  cb_scm = SG_ARGREF(0);
  if (!SG_CODE_BUILDERP(cb_scm))
    Sg_WrongTypeOfArgumentViolation(
       sg__rc.d428[0], SG_MAKE_STRING("code-builder"), cb_scm, SG_NIL);
  cb = SG_CODE_BUILDER(cb_scm);
  {
{
SgObject SG_RESULT = (SgObject)NULL;
{
#line 15 "vmdebug.stub"
Sg_VMDumpCode(cb);}
{
#line 16 "vmdebug.stub"
SG_RESULT=(SG_UNDEF);}
SG_RETURN(SG_OBJ_SAFE(SG_RESULT));
}
  }
}
static SG_DEFINE_SUBR(vmdebug_vm_dump_code__STUB, 1, 0,vmdebug_vm_dump_code, SG_FALSE, NULL);

static SgObject vmdebug_source_info(SgObject *SG_FP, int SG_ARGC, void *data_)
{
  SgObject o_scm;
  SgObject o;
  SG_ENTER_SUBR("source-info");
  if (SG_ARGC != 1)
    Sg_WrongNumberOfArgumentsViolation(
     SG_INTERN("source-info"), 1, SG_ARGC, SG_NIL);
  o_scm = SG_ARGREF(0);
  o = (o_scm);
  {
{
SgObject SG_RESULT = (SgObject)NULL;
{
#line 19 "vmdebug.stub"
if (SG_PTRP(o)){
SG_RESULT=(Sg_WeakHashTableRef(
SG_WEAK_HASHTABLE((Sg_VM())->sourceInfos),o,SG_FALSE));} else {
SG_RESULT=(SG_FALSE);}}
SG_RETURN(SG_OBJ_SAFE(SG_RESULT));
}
  }
}
static SG_DEFINE_SUBR(vmdebug_source_info__STUB, 1, 0,vmdebug_source_info, SG_FALSE, NULL);

static SgObject vmdebug_source_info_setX(SgObject *SG_FP, int SG_ARGC, void *data_)
{
  SgObject o_scm;
  SgObject o;
  SgObject i_scm;
  SgObject i;
  SG_ENTER_SUBR("source-info-set!");
  if (SG_ARGC != 2)
    Sg_WrongNumberOfArgumentsViolation(
     SG_INTERN("source-info-set!"), 2, SG_ARGC, SG_NIL);
  o_scm = SG_ARGREF(0);
  o = (o_scm);
  i_scm = SG_ARGREF(1);
  i = (i_scm);
  {
{
SgObject SG_RESULT = (SgObject)NULL;
{
#line 25 "vmdebug.stub"
if (SG_PTRP(o)){{
{SgVM* vm=Sg_VM();
if ((!(SG_VM_IS_SET_FLAG(vm,SG_NO_DEBUG_INFO)))){{
Sg_WeakHashTableSet(SG_WEAK_HASHTABLE((vm)->sourceInfos),o,i,0);}}}}}}
{
#line 30 "vmdebug.stub"
SG_RESULT=(o);}
SG_RETURN(SG_OBJ_SAFE(SG_RESULT));
}
  }
}
static SG_DEFINE_SUBR(vmdebug_source_info_setX__STUB, 2, 0,vmdebug_source_info_setX, SG_FALSE, NULL);

void Sg__Init_sagittarius_vm_debug () {
  SgLibrary *lib = SG_LIBRARY(Sg_FindLibrary(SG_INTERN("(sagittarius vm debug)"), TRUE));
  sg__rc.d428[0] = SG_MAKE_STRING("vm-dump-code");
  Sg_InsertBinding(lib, Sg_Intern(sg__rc.d428[0]), &vmdebug_vm_dump_code__STUB);
  SG_PROCEDURE_NAME(&vmdebug_vm_dump_code__STUB) = sg__rc.d428[0];
  sg__rc.d428[1] = SG_MAKE_STRING("source-info");
  Sg_InsertBinding(lib, Sg_Intern(sg__rc.d428[1]), &vmdebug_source_info__STUB);
  SG_PROCEDURE_NAME(&vmdebug_source_info__STUB) = sg__rc.d428[1];
  sg__rc.d428[2] = SG_MAKE_STRING("source-info-set!");
  Sg_InsertBinding(lib, Sg_Intern(sg__rc.d428[2]), &vmdebug_source_info_setX__STUB);
  SG_PROCEDURE_NAME(&vmdebug_source_info_setX__STUB) = sg__rc.d428[2];
}
