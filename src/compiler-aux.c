/* This file is automatically generated. DO NOT EDIT!*/
#define LIBSAGITTARIUS_BODY
#include "sagittarius.h"
#define WORD(x)       SG_WORD(x)
#define SYMBOL(x)     Sg_Intern(Sg_MakeString(UC(x), SG_LITERAL_STRING))
#define SYMBOLW(x)    WORD(SYMBOL(x))
#define STRING(x)     Sg_MakeString(UC(x), SG_LITERAL_STRING)
#define STRINGW(x)    WORD(STRING(x))
#define KEYWORD(x)    Sg_MakeKeyword(STRING(x))
#define KEYWORDW(x)    WORD(KEYWORD(x))
#define IDENT(x, lib) WORD(Sg_MakeIdentifier(SYMBOL(x), SG_NIL, (lib)))
static struct sg__wcRec {
  SgCodeBuilder cb[4];
  SgWord        w[167];
} sg__wc = {
  { /* code builder */
    SG_STATIC_CODE_BUILDER(&sg__wc.w[87], NULL, 1, FALSE, 0, 9, 24), /* ensure-library-name */
    SG_STATIC_CODE_BUILDER(&sg__wc.w[111], NULL, 1, FALSE, 0, 7, 19), /* parse-type */
    SG_STATIC_CODE_BUILDER(&sg__wc.w[130], NULL, 1, FALSE, 0, 12, 37), /* parse-args */
  },
  { /* compiled code */
  /*     0 */        0x0000002A           /* 0      (CLOSURE) */,
  /*     1 */        WORD(SG_UNDEF)  /* <code-builder> */,
  /*     2 */        0x00000037           /* 2      (DEFINE) */,
  /*     3 */        WORD(SG_UNDEF)  /* identifier#ensure-library-name */,
  /*     4 */        0x0000002A           /* 4      (CLOSURE) */,
  /*     5 */        WORD(SG_UNDEF)  /* <code-builder> */,
  /*     6 */        0x00000037           /* 6      (DEFINE) */,
  /*     7 */        WORD(SG_UNDEF)  /* identifier#parse-type */,
  /*     8 */        0x0000002A           /* 8      (CLOSURE) */,
  /*     9 */        WORD(SG_UNDEF)  /* <code-builder> */,
  /*    10 */        0x00000037           /* 10     (DEFINE) */,
  /*    11 */        WORD(SG_UNDEF)  /* identifier#parse-args */,
  /*    12 */        0x00000002           /* 12     (UNDEF) */,
  /*    13 */        0x00000003           /* 13     (CONST) */,
  /*    14 */        WORD(SG_UNDEF), /* (($UNDEF . 0) ($DEFINE . 1) ($LREF . 2) ($LSET . 3) ($GREF . 4) ($GSET . 5) ($CONST . 6) ($IF . 7) ($LET . 8) ($LAMBDA . 9) ($RECEIVE . 10) ($LABEL . 11) ($SEQ . 12) ($CALL . 13) ($ASM . 14) ($IT . 15) ($LIST . 16)) */
  /*    15 */        0x00000137           /* 15     (DEFINE) */,
  /*    16 */        WORD(SG_UNDEF)  /* identifier#|.intermediate-tags.| */,
  /*    17 */        0x00000003           /* 17     (CONST) */,
  /*    18 */        WORD(SG_MAKE_INT(0)),
  /*    19 */        0x00000137           /* 19     (DEFINE) */,
  /*    20 */        WORD(SG_UNDEF)  /* identifier#$UNDEF */,
  /*    21 */        0x00000003           /* 21     (CONST) */,
  /*    22 */        WORD(SG_MAKE_INT(1)),
  /*    23 */        0x00000137           /* 23     (DEFINE) */,
  /*    24 */        WORD(SG_UNDEF)  /* identifier#$DEFINE */,
  /*    25 */        0x00000003           /* 25     (CONST) */,
  /*    26 */        WORD(SG_MAKE_INT(2)),
  /*    27 */        0x00000137           /* 27     (DEFINE) */,
  /*    28 */        WORD(SG_UNDEF)  /* identifier#$LREF */,
  /*    29 */        0x00000003           /* 29     (CONST) */,
  /*    30 */        WORD(SG_MAKE_INT(3)),
  /*    31 */        0x00000137           /* 31     (DEFINE) */,
  /*    32 */        WORD(SG_UNDEF)  /* identifier#$LSET */,
  /*    33 */        0x00000003           /* 33     (CONST) */,
  /*    34 */        WORD(SG_MAKE_INT(4)),
  /*    35 */        0x00000137           /* 35     (DEFINE) */,
  /*    36 */        WORD(SG_UNDEF)  /* identifier#$GREF */,
  /*    37 */        0x00000003           /* 37     (CONST) */,
  /*    38 */        WORD(SG_MAKE_INT(5)),
  /*    39 */        0x00000137           /* 39     (DEFINE) */,
  /*    40 */        WORD(SG_UNDEF)  /* identifier#$GSET */,
  /*    41 */        0x00000003           /* 41     (CONST) */,
  /*    42 */        WORD(SG_MAKE_INT(6)),
  /*    43 */        0x00000137           /* 43     (DEFINE) */,
  /*    44 */        WORD(SG_UNDEF)  /* identifier#$CONST */,
  /*    45 */        0x00000003           /* 45     (CONST) */,
  /*    46 */        WORD(SG_MAKE_INT(7)),
  /*    47 */        0x00000137           /* 47     (DEFINE) */,
  /*    48 */        WORD(SG_UNDEF)  /* identifier#$IF */,
  /*    49 */        0x00000003           /* 49     (CONST) */,
  /*    50 */        WORD(SG_MAKE_INT(8)),
  /*    51 */        0x00000137           /* 51     (DEFINE) */,
  /*    52 */        WORD(SG_UNDEF)  /* identifier#$LET */,
  /*    53 */        0x00000003           /* 53     (CONST) */,
  /*    54 */        WORD(SG_MAKE_INT(9)),
  /*    55 */        0x00000137           /* 55     (DEFINE) */,
  /*    56 */        WORD(SG_UNDEF)  /* identifier#$LAMBDA */,
  /*    57 */        0x00000003           /* 57     (CONST) */,
  /*    58 */        WORD(SG_MAKE_INT(10)),
  /*    59 */        0x00000137           /* 59     (DEFINE) */,
  /*    60 */        WORD(SG_UNDEF)  /* identifier#$RECEIVE */,
  /*    61 */        0x00000003           /* 61     (CONST) */,
  /*    62 */        WORD(SG_MAKE_INT(11)),
  /*    63 */        0x00000137           /* 63     (DEFINE) */,
  /*    64 */        WORD(SG_UNDEF)  /* identifier#$LABEL */,
  /*    65 */        0x00000003           /* 65     (CONST) */,
  /*    66 */        WORD(SG_MAKE_INT(12)),
  /*    67 */        0x00000137           /* 67     (DEFINE) */,
  /*    68 */        WORD(SG_UNDEF)  /* identifier#$SEQ */,
  /*    69 */        0x00000003           /* 69     (CONST) */,
  /*    70 */        WORD(SG_MAKE_INT(13)),
  /*    71 */        0x00000137           /* 71     (DEFINE) */,
  /*    72 */        WORD(SG_UNDEF)  /* identifier#$CALL */,
  /*    73 */        0x00000003           /* 73     (CONST) */,
  /*    74 */        WORD(SG_MAKE_INT(14)),
  /*    75 */        0x00000137           /* 75     (DEFINE) */,
  /*    76 */        WORD(SG_UNDEF)  /* identifier#$ASM */,
  /*    77 */        0x00000003           /* 77     (CONST) */,
  /*    78 */        WORD(SG_MAKE_INT(15)),
  /*    79 */        0x00000137           /* 79     (DEFINE) */,
  /*    80 */        WORD(SG_UNDEF)  /* identifier#$IT */,
  /*    81 */        0x00000003           /* 81     (CONST) */,
  /*    82 */        WORD(SG_MAKE_INT(16)),
  /*    83 */        0x00000137           /* 83     (DEFINE) */,
  /*    84 */        WORD(SG_UNDEF)  /* identifier#$LIST */,
  /*    85 */        0x00000002           /* 85     (UNDEF) */,
  /*    86 */        0x00000001           /* 86     (HALT) */,
  /*    87 */        0x0000004A           /* 0      (CONST_PUSH) */,
  /*    88 */        WORD(SG_UNDEF)  /* <keyrowd :null> */,
  /*    89 */        0x00000005           /* 2      (LREF) */,
  /*    90 */        0x00000021           /* 3      (BNEQV) */,
  /*    91 */        WORD(SG_MAKE_INT(5)),
  /*    92 */        0x00000003           /* 5      (CONST) */,
  /*    93 */        WORD(SG_UNDEF), /* null */
  /*    94 */        0x00000018           /* 7      (JUMP) */,
  /*    95 */        WORD(SG_MAKE_INT(15)),
  /*    96 */        0x0000004A           /* 9      (CONST_PUSH) */,
  /*    97 */        WORD(SG_UNDEF)  /* <keyrowd :sagittarius> */,
  /*    98 */        0x00000005           /* 11     (LREF) */,
  /*    99 */        0x00000021           /* 12     (BNEQV) */,
  /*   100 */        WORD(SG_MAKE_INT(5)),
  /*   101 */        0x00000003           /* 14     (CONST) */,
  /*   102 */        WORD(SG_UNDEF), /* (sagittarius) */
  /*   103 */        0x00000018           /* 16     (JUMP) */,
  /*   104 */        WORD(SG_MAKE_INT(6)),
  /*   105 */        0x0000004A           /* 18     (CONST_PUSH) */,
  /*   106 */        WORD(SG_UNDEF), /* "invalid library tag:" */
  /*   107 */        0x00000047           /* 20     (LREF_PUSH) */,
  /*   108 */        0x0000024D           /* 21     (GREF_TAIL_CALL) */,
  /*   109 */        WORD(SG_UNDEF)  /* identifier#error */,
  /*   110 */        0x00000030           /* 23     (RET) */,
  /*   111 */        0x00000005           /* 0      (LREF) */,
  /*   112 */        0x00000040           /* 1      (PAIRP) */,
  /*   113 */        0x00000017           /* 2      (TEST) */,
  /*   114 */        WORD(SG_MAKE_INT(10)),
  /*   115 */        0x00000031           /* 4      (FRAME) */,
  /*   116 */        WORD(SG_MAKE_INT(4)),
  /*   117 */        0x00000047           /* 6      (LREF_PUSH) */,
  /*   118 */        0x0000014C           /* 7      (GREF_CALL) */,
  /*   119 */        WORD(SG_UNDEF)  /* identifier#length */,
  /*   120 */        0x0000000B           /* 9      (PUSH) */,
  /*   121 */        0x00000003           /* 10     (CONST) */,
  /*   122 */        WORD(SG_MAKE_INT(2)),
  /*   123 */        0x00000024           /* 12     (NUM_EQ) */,
  /*   124 */        0x00000017           /* 13     (TEST) */,
  /*   125 */        WORD(SG_MAKE_INT(4)),
  /*   126 */        0x00000047           /* 15     (LREF_PUSH) */,
  /*   127 */        0x0000014D           /* 16     (GREF_TAIL_CALL) */,
  /*   128 */        WORD(SG_UNDEF)  /* identifier#cadr */,
  /*   129 */        0x00000030           /* 18     (RET) */,
  /*   130 */        0x00000332           /* 0      (LET_FRAME) */,
  /*   131 */        0x00000047           /* 1      (LREF_PUSH) */,
  /*   132 */        0x00000134           /* 2      (DISPLAY) */,
  /*   133 */        0x00000047           /* 3      (LREF_PUSH) */,
  /*   134 */        0x0000004A           /* 4      (CONST_PUSH) */,
  /*   135 */        WORD(SG_MAKE_INT(0)),
  /*   136 */        0x00000233           /* 6      (POP_LET_FRAME) */,
  /*   137 */        0x0000001A           /* 7      (MARK) */,
  /*   138 */        0x00000005           /* 8      (LREF) */,
  /*   139 */        0x00000022           /* 9      (BNNULL) */,
  /*   140 */        WORD(SG_MAKE_INT(7)),
  /*   141 */        0x00000147           /* 11     (LREF_PUSH) */,
  /*   142 */        0x00000003           /* 12     (CONST) */,
  /*   143 */        WORD(SG_MAKE_BOOL(FALSE)),
  /*   144 */        0x0000023C           /* 14     (VALUES) */,
  /*   145 */        0x00000018           /* 15     (JUMP) */,
  /*   146 */        WORD(SG_MAKE_INT(20)),
  /*   147 */        0x00000005           /* 17     (LREF) */,
  /*   148 */        0x00000040           /* 18     (PAIRP) */,
  /*   149 */        0x00000017           /* 19     (TEST) */,
  /*   150 */        WORD(SG_MAKE_INT(12)),
  /*   151 */        0x00000005           /* 21     (LREF) */,
  /*   152 */        0x00000039           /* 22     (CDR) */,
  /*   153 */        0x0000000B           /* 23     (PUSH) */,
  /*   154 */        0x00000105           /* 24     (LREF) */,
  /*   155 */        0x0000010F           /* 25     (ADDI) */,
  /*   156 */        0x0000000B           /* 26     (PUSH) */,
  /*   157 */        0x00000219           /* 27     (SHIFTJ) */,
  /*   158 */        0x00000018           /* 28     (JUMP) */,
  /*   159 */        WORD(SG_MAKE_INT(-21)),
  /*   160 */        0x00000018           /* 30     (JUMP) */,
  /*   161 */        WORD(SG_MAKE_INT(5)),
  /*   162 */        0x00000147           /* 32     (LREF_PUSH) */,
  /*   163 */        0x00000003           /* 33     (CONST) */,
  /*   164 */        WORD(SG_MAKE_BOOL(TRUE)),
  /*   165 */        0x0000023C           /* 35     (VALUES) */,
  /*   166 */        0x00000030           /* 36     (RET) */,
  }
};

static SgCodeBuilder toplevel_sagittarius_compiler_util = SG_STATIC_CODE_BUILDER(&sg__wc.w[0], NULL, 0, FALSE, 0, 0, 87);
void Sg__Init_sagittarius_compiler_util()
{
  SgLibrary *lib = Sg_FindLibrary(SYMBOL("(sagittarius compiler util)"), TRUE);
  sg__wc.w[20] = IDENT("$UNDEF", lib);
  sg__wc.w[97] = KEYWORDW("sagittarius");
  sg__wc.w[52] = IDENT("$LET", lib);
  sg__wc.w[32] = IDENT("$LSET", lib);
  sg__wc.w[28] = IDENT("$LREF", lib);
  sg__wc.w[68] = IDENT("$SEQ", lib);
  sg__wc.w[5] = WORD(&sg__wc.cb[1]);
sg__wc.cb[1].name = SYMBOL("parse-type");
  sg__wc.w[36] = IDENT("$GREF", lib);
  sg__wc.w[88] = KEYWORDW("null");
  sg__wc.w[24] = IDENT("$DEFINE", lib);
  sg__wc.w[119] = IDENT("length", lib);
  sg__wc.w[72] = IDENT("$CALL", lib);
  sg__wc.w[14] = WORD(Sg_Cons(Sg_Cons(SYMBOL("$UNDEF"), SG_MAKE_INT(0)), Sg_Cons(Sg_Cons(SYMBOL("$DEFINE"), SG_MAKE_INT(1)), Sg_Cons(Sg_Cons(SYMBOL("$LREF"), SG_MAKE_INT(2)), Sg_Cons(Sg_Cons(SYMBOL("$LSET"), SG_MAKE_INT(3)), Sg_Cons(Sg_Cons(SYMBOL("$GREF"), SG_MAKE_INT(4)), Sg_Cons(Sg_Cons(SYMBOL("$GSET"), SG_MAKE_INT(5)), Sg_Cons(Sg_Cons(SYMBOL("$CONST"), SG_MAKE_INT(6)), Sg_Cons(Sg_Cons(SYMBOL("$IF"), SG_MAKE_INT(7)), Sg_Cons(Sg_Cons(SYMBOL("$LET"), SG_MAKE_INT(8)), Sg_Cons(Sg_Cons(SYMBOL("$LAMBDA"), SG_MAKE_INT(9)), Sg_Cons(Sg_Cons(SYMBOL("$RECEIVE"), SG_MAKE_INT(10)), Sg_Cons(Sg_Cons(SYMBOL("$LABEL"), SG_MAKE_INT(11)), Sg_Cons(Sg_Cons(SYMBOL("$SEQ"), SG_MAKE_INT(12)), Sg_Cons(Sg_Cons(SYMBOL("$CALL"), SG_MAKE_INT(13)), Sg_Cons(Sg_Cons(SYMBOL("$ASM"), SG_MAKE_INT(14)), Sg_Cons(Sg_Cons(SYMBOL("$IT"), SG_MAKE_INT(15)), Sg_Cons(Sg_Cons(SYMBOL("$LIST"), SG_MAKE_INT(16)), SG_NIL))))))))))))))))));
  sg__wc.w[56] = IDENT("$LAMBDA", lib);
  sg__wc.w[9] = WORD(&sg__wc.cb[2]);
sg__wc.cb[2].name = SYMBOL("parse-args");
  sg__wc.w[40] = IDENT("$GSET", lib);
  sg__wc.w[7] = IDENT("parse-type", lib);
  sg__wc.w[3] = IDENT("ensure-library-name", lib);
  sg__wc.w[80] = IDENT("$IT", lib);
  sg__wc.w[60] = IDENT("$RECEIVE", lib);
  sg__wc.w[11] = IDENT("parse-args", lib);
  sg__wc.w[93] = SYMBOLW("null");
  sg__wc.w[76] = IDENT("$ASM", lib);
  sg__wc.w[102] = WORD(Sg_Cons(SYMBOL("sagittarius"), SG_NIL));
  sg__wc.w[128] = IDENT("cadr", lib);
  sg__wc.w[44] = IDENT("$CONST", lib);
  sg__wc.w[48] = IDENT("$IF", lib);
  sg__wc.w[106] = STRINGW("invalid library tag:");
  sg__wc.w[84] = IDENT("$LIST", lib);
  sg__wc.w[64] = IDENT("$LABEL", lib);
  sg__wc.w[16] = IDENT(".intermediate-tags.", lib);
  sg__wc.w[109] = IDENT("error", lib);
  sg__wc.w[1] = WORD(&sg__wc.cb[0]);
sg__wc.cb[0].name = SYMBOL("ensure-library-name");
  Sg_ImportLibrary(lib, SG_OBJ(SYMBOL("(sagittarius)")));
  Sg_ImportLibrary(lib, SG_OBJ(SYMBOL("(core base)")));
  Sg_ImportLibrary(lib, SG_OBJ(SYMBOL("null")));
  Sg_LibraryExportedSet(lib, Sg_Cons(Sg_Cons(SYMBOL("$UNDEF"), Sg_Cons(SYMBOL("$DEFINE"), Sg_Cons(SYMBOL("$LREF"), Sg_Cons(SYMBOL("$LSET"), Sg_Cons(SYMBOL("$GREF"), Sg_Cons(SYMBOL("$GSET"), Sg_Cons(SYMBOL("$CONST"), Sg_Cons(SYMBOL("$IF"), Sg_Cons(SYMBOL("$LET"), Sg_Cons(SYMBOL("$LAMBDA"), Sg_Cons(SYMBOL("$RECEIVE"), Sg_Cons(SYMBOL("$LABEL"), Sg_Cons(SYMBOL("$SEQ"), Sg_Cons(SYMBOL("$CALL"), Sg_Cons(SYMBOL("$ASM"), Sg_Cons(SYMBOL("$IT"), Sg_Cons(SYMBOL("$LIST"), Sg_Cons(SYMBOL(".intermediate-tags."), Sg_Cons(SYMBOL("define-simple-struct"), Sg_Cons(SYMBOL("define-enum"), Sg_Cons(SYMBOL("case/unquote"), Sg_Cons(SYMBOL("parse-args"), Sg_Cons(SYMBOL("parse-type"), Sg_Cons(SYMBOL("ensure-library-name"), SG_NIL)))))))))))))))))))))))), SG_NIL));
  Sg_VMExecute(SG_OBJ(&toplevel_sagittarius_compiler_util));
}
