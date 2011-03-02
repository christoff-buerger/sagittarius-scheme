/* This file is automatically generated by builtin-symbols.scm. DO NOT EDIT! */
#define LIBSAGITTARIUS_BODY
#include <sagittarius.h>
SgSymbol Sg_BuiltinSymbols[] = {
#define ENTRY() {MAKE_HDR_VALUE(TC_SYMBOL), NULL, TRUE}
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
  ENTRY(),
#undef ENTRY
};
static void init_builtin_symbols()
{
#define STRING(s)    Sg_MakeString(UC(s), SG_LITERAL_STRING)
#define INTERN(s, i) \
  Sg_BuiltinSymbols[i].name = STRING(s); \
  Sg_HashTableSet(obtable, Sg_BuiltinSymbols[i].name, SG_OBJ(&Sg_BuiltinSymbols[i]), 0)
  INTERN("quote", 0);
  INTERN("quasiquote", 1);
  INTERN("unquote", 2);
  INTERN("unquote-splicing", 3);
  INTERN("syntax", 4);
  INTERN("quasisyntax", 5);
  INTERN("unsyntax", 6);
  INTERN("unsyntax-splicing", 7);
  INTERN("define", 8);
  INTERN("define-constant", 9);
  INTERN("let", 10);
  INTERN("let*", 11);
  INTERN("letrec", 12);
  INTERN("letrec*", 13);
  INTERN("set!", 14);
  INTERN("begin", 15);
  INTERN(".", 16);
  INTERN("(", 17);
  INTERN(")", 18);
  INTERN("[", 19);
  INTERN("]", 20);
  INTERN("if", 21);
  INTERN("and", 22);
  INTERN("or", 23);
  INTERN("cond", 24);
  INTERN("=>", 25);
  INTERN("do", 26);
  INTERN("while", 27);
  INTERN("unless", 28);
  INTERN("when", 29);
  INTERN("receive", 30);
  INTERN("library", 31);
  INTERN("import", 32);
  INTERN("export", 33);
  INTERN("for", 34);
  INTERN("only", 35);
  INTERN("rename", 36);
  INTERN("prefix", 37);
  INTERN("expand", 38);
  INTERN("run", 39);
  INTERN("define-syntax", 40);
  INTERN("let-syntax", 41);
  INTERN("letrec-syntax", 42);
  INTERN("syntax-rules", 43);
  INTERN("er-macro-transformer", 44);
  INTERN("...", 45);
  INTERN("%macroexpand-1", 46);
  INTERN("%macroexpand", 47);
  INTERN("file-options", 48);
#undef INTERN
}
