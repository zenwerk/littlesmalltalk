/*
    Little Smalltalk Class method syntax

        differs from smalltalk-80 slightly

            class heading is different
            vertical bar must appear between methods
            syntax for primitives is different

*/

/*      literals        */
%token LITNUM LITFNUM LITCHAR LITSTR LITSYM 

/*      basic objects   */
%token CLASS ASSIGN BINARY PRIMITIVE NAMEDPRIM

/*      types of variables */
%token PSEUDO UPPERCASEVAR LOWERCASEVAR COLONVAR KEYWORD

/*      one character symbols */
%token LP RP LB RB PERIOD BAR MBAR SEMI UPARROW PS MINUS PE
/*     (  )  [  ]  .      |   ^|   ;    ^       #  -     > */

%{
#include <stdlib.h>
#include <string.h>
#include "env.h"
#include "drive.h"
#include "parser.h"
%}

%union {
    struct litlist       *a;
    struct blockstruct   *b;
    char                 *c;
    struct exprstruct    *e;
    int                   i;
    struct keylist       *k;
    struct classstruct   *l;
    struct methodstruct  *m;
    struct objstruct     *o;
    enum pseuvars         p;
    struct primlist      *r;
    struct statestruct   *s;
    struct litstruct     *t;
    struct primstruct    *u;
}

%{
extern struct blockstruct  *mkblock();
extern struct classstruct  *mkclass();
extern struct varstruct    *mkvar(), *addvlist(), *invlist();
extern struct methodstruct *mkmethod();
extern struct exprstruct   *mkexpr(), *mkkey();
extern struct keylist      *mkklist();
extern struct statestruct  *mkstate();
extern struct objstruct    *mkobj();
extern struct primstruct   *mkprim();
extern struct primlist     *addprim();
extern struct litstruct    *mklit();
extern struct litlist      *addlit();
extern char                *bincat();

struct varstruct *instvars;
struct varstruct *contextvars;

int bytetop = 0;
uchar bytearray[1000];
extern char* yytext;

YYSTYPE e;
int errorcount = 0;
%}

%type <a> litarray
%type <b> block
%type <c> CLASS KEYWORD LOWERCASEVAR UPPERCASEVAR COLONVAR LITSYM LITSTR
%type <c> BINARY BAR MINUS UPARROW PE
%type <c> classname binarysym binarychar
%type <c> LITFNUM fliteral
%type <e> pattern expression cexpression binary unary
%type <e> kcontinuation bcontinuation ucontinuation
%type <i> LITCHAR LITNUM PRIMITIVE NAMEDPRIM
%type <i> tempvars cvarlist namelist barglist nliteral
%type <k> keypattern keywordlist
%type <l> super classheading
%type <m> method methodlist
%type <o> primary
%type <p> PSEUDO
%type <r> objlist
%type <s> statelist statement sexpression opmessagelist
%type <s> bstatelist bstatement bexpression
%type <t> literal iliteral aliteral
%type <u> primitive


%start file

%%
file         : classdef
             | file classdef
             ;

classdef     : classheading lb methodlist ']' {if (errorcount == 0) genclass($1, $3);}
             ;

lb           : '['
             | error   {
                 if ((yytext[0] == ':') || isalpha(yytext[0])) expect(":SuperClass");
                 else expect("open brace [");
             }
             ;

classheading : class super instancevars {$$ = $2;}
             ;

class        : 'Class'
             | error {expect("keyword Class");}
             ;

super        : classname           {$$ = mkclass($1, (char *) 0);}
             | classname COLONVAR  {$$ = mkclass($1, $2);}
             | error               {expect("Classname :Superclass");
                                    $$ = mkclass("Error", (char *) 0);}
             ;

classname    : UPPERCASEVAR
             | 'Class'
             ;

instancevars : /* empty */
             | bar instvarlist bar
             ;

instvarlist  : LOWERCASEVAR             {addinst($1);}
             | instvarlist LOWERCASEVAR {addinst($2);}
             | error                    {expect("instance variable");}
             ;

methodlist   : method
             | methodlist '^|' method {$3->nextmethod = $1; $$ = $3;}
             ;

method       : pattern tempvars statelist op {deltemps($2); $$ = mkmethod($1, $2, $3);}
             ;

pattern      : keypattern {
                   $$ = mkkey((struct exprstruct *) 0, $1);
               }
             | binarysym argvariable {
                   $$ = mkexpr((struct exprstruct *) 0, bincmd, $1, (struct exprstruct *) 0);
               }
             | LOWERCASEVAR {
                   $$ = mkexpr((struct exprstruct *) 0, uncmd, $1, (struct exprstruct *) 0);
               }
             | error {
                   expect("method pattern");
                   $$ = mkexpr((struct exprstruct *) 0, uncmd, "", (struct exprstruct *) 0);
               }
             ;

keypattern   : KEYWORD argvariable {
                   $$ = mkklist((struct keylist *) 0, $1, (struct exprstruct *) 0);
               }
             | keypattern KEYWORD argvariable {
                   $$ = mkklist($1, $2, (struct exprstruct *) 0);
               }
             ;

argvariable  : LOWERCASEVAR {
                   addtemp($1, argvar);
               }
             | error {
                   expect("argument variable");
               }
             ;

tempvars     : /* empty */      {$$ = 0;}
             | bar namelist bar {$$ = $2;}
             ;

bar          : '|'
             | '^|'
             | error {expect("| (vertical bar)");}
             ;

namelist     : tvariable          {$$ = 1;}
             | namelist tvariable {$$ = $1 + 1;}
             ;

tvariable    : LOWERCASEVAR {addtemp($1, tempvar);}
             ;
 
/* 複文 */
statelist    : statement               {$$ = $1;}
             | statelist '.' statement {$3->nextstate = $1; $$ = $3;}
             ;

op           : /* empty - optional period */
             | '.'
             ;

/* 文 = ^式の開始 or 式の開始 */
statement    : '^' sexpression {
                 $$ = mkstate(upar, (char *) 0, $2);
               }
             | sexpression
             ;

/* 式の開始 = 代入式 or C式 */
sexpression  : LOWERCASEVAR ':=' sexpression {
                 $$ = mkstate(asgn, $1, $3);
               }
             | cexpression {
                 $$ = mkstate(expr, (char *) 0, (struct statestruct *) $1);
               }
             ;

/* 単項` > `2項` > `キーワード` の優先順位なので
   キーワード, 二項, 単項 の順にパースする */

/* C式 = 単式 or Keywordメッセージ */
cexpression  : expression
             | kcontinuation {$$ = mkexpr($1, semiend, 0, 0);}
             ;

/* Keywordメッセ = 二項メッセージ or 二項メッセ+キーワード */
kcontinuation: bcontinuation
             | bcontinuation keywordlist {$$ = mkkey($1, $2);}
             ;

/* 二項メッセ = 単項メッセ or 二項メッセ+二項シンボル+単項 */
bcontinuation: ucontinuation
             | bcontinuation binarysym unary {$$ = mkexpr($1, bincmd, $2, $3);}
             ;

/* 単項メッセ = C式';' or 単項メッセ+変数 */
ucontinuation: cexpression ';' {$$ = mkexpr($1, semistart, 0, 0);} /* さらなるメッセージへ */
             | ucontinuation LOWERCASEVAR {
                 $$ = mkexpr($1, uncmd, $2, (struct exprstruct *) 0);
               }
             ;

/* 単式 = 二項 or 二項+キーワードリスト */
expression   : binary             {$$ = $1;}
             | binary keywordlist {$$ = mkkey($1, $2);}
             ;

/* hoge: fuga hoge: piyo */
keywordlist  : KEYWORD binary             {$$ = mkklist((struct keylist *) 0, $1, $2);}
             | keywordlist KEYWORD binary {$$ = mkklist($1, $2, $3);}
             ;

/* 二項 = 単項 or 二項+二項シンボル+単項 */
binary       : unary                  {$$ = $1;}
             | binary binarysym unary {$$ = mkexpr($1, bincmd, $2, $3);}
             ;

binarysym    : binarychar            {$$ = $1;}
             | binarychar binarychar {$$ = bincat($1, $2);}
             ;

binarychar   : BINARY
             | '|'
             | '!'
             | '-'
             | '^'
             | '>'
             ;

/* 単項 */
unary        : primary {
                   $$ = mkexpr((struct exprstruct *) 0, reccmd, (char *) 0, (struct exprstruct *) $1);
               }
             | unary LOWERCASEVAR {
                   $$ = mkexpr($1, uncmd, $2, (struct exprstruct *) 0);
               }
             ;

/* プライマリ(Smalltalk世界でのプリミティブ) */
primary      : classname           {e.c = $1; $$ = mkobj(classobj, &e);}
             | LOWERCASEVAR        {e.c = $1; $$ = mkobj(varobj, &e);}
             | literal             {e.t = $1; $$ = mkobj(litobj, &e);}
             | PSEUDO              {e.p = $1; $$ = mkobj(pseuobj, &e);}
             | primitive           {e.u = $1; $$ = mkobj(primobj, &e);}
             | '(' sexpression ')' {e.s = $2; $$ = mkobj(exprobj, &e);}
             | block               {e.b = $1; $$ = mkobj(blockobj, &e);}
             ;

/* プリミティブ(C言語機能呼び出し) */
primitive    : PRIMITIVE LITNUM objlist '>' {$$ = mkprim($2, $3);}
             | NAMEDPRIM objlist '>'        {$$ = mkprim($1, $2);}
             ;

/* プライマリのリスト */
objlist      : /* empty */     {$$ = (struct primlist *) 0;}
             | objlist primary {$$ = addprim($1, $2);}
             ;

/* ブロック */
block        : '[' barglist opmessagelist ']' {
                    $$ = mkblock($2, $3);
                    deltemps($2);
               }
             ;

/* ブロックの引数リスト */
barglist     : /* empty */  {$$ = 0;}
             | cvarlist '|' {$$ = $1;}
             ;

/* コロン変数のリスト */
cvarlist     : COLONVAR          {addtemp($1, argvar); $$ = 1;}
             | cvarlist COLONVAR {addtemp($2, argvar); $$ = $1 + 1;}
             ;

/* メッセージリスト */
opmessagelist: bstatelist bstatement {$2->nextstate = $1; $$ = $2;}
             | bstatement            {$$ = $1;}
             ;

/* ブロック内の文のリスト */
bstatelist   : sexpression '.'            {$$ = $1;}
             | bstatelist sexpression '.' {$2->nextstate = $1; $$ = $2;}
             ;

/* ブロック内の文 = '^'+式の開始 or ブロック内式 */
bstatement   : '^' sexpression {$$ = mkstate(blkupar, (char *) 0, $2);}
             | bexpression     {$$ = mkstate(upar, (char *) 0, $1);}
             ;

/* ブロック内の式 = 空 or 式の開始 */
bexpression  : /* empty */ {
                     e.p = nilvar;
                     $$ = mkstate(expr, (char *) 0, (struct statestruct *) mkexpr((struct exprstruct *) 0, reccmd, (char *) 0, (struct exprstruct *) mkobj(pseuobj, &e)));
               }
             | sexpression {$$ = $1;}
             ;

/* リテラル */
literal      : iliteral               {$$ = $1;}
             | '#(' litarray ')' {e.a = $2; $$ = mklit(arlit, &e);}
             ;

iliteral     : fliteral           {e.c = $1; $$ = mklit(fnumlit, &e);}
             | nliteral           {e.i = $1; $$ = mklit(numlit, &e);}
             | LITCHAR            {e.i = $1; $$ = mklit(charlit, &e);}
             | LITSTR             {e.c = $1; $$ = mklit(strlit, &e);}
             | LITSYM             {e.c = $1; $$ = mklit(symlit, &e);}
             | '#[' bytearray ']' {bytearray[bytetop] = '\0'; $$ = mklit(bytelit, &e);}
             ;

fliteral     : LITFNUM     {$$ = $1;}
             | '-' LITFNUM {$$ = bincat("-", $2);}
             ;

nliteral     : LITNUM     {$$ = $1;}
             | '-' LITNUM {$$ = - $2;}
             ;

aliteral     : iliteral         {$$ = $1;}
             | LOWERCASEVAR     {e.c = $1; $$ = mklit(symlit, &e);}
             | UPPERCASEVAR     {e.c = $1; $$ = mklit(symlit, &e);}
             | KEYWORD          {e.c = $1; $$ = mklit(symlit, &e);}
             | COLONVAR         {e.c = $1; $$ = mklit(symlit, &e);}
             | CLASS            {e.c = $1; $$ = mklit(symlit, &e);}
             | binarysym        {e.c = $1; $$ = mklit(symlit, &e);}
             | ias litarray ')' {e.a = $2; $$ = mklit(arlit, &e);}
             ;

ias          : '#('
             | '(' 
             ;

litarray     : /* empty */       {$$ = (struct litlist *) 0;}
             | litarray aliteral {$$ = addlit($1, $2);}
             ;

bytearray    : LITNUM           {bytetop = 0; bytearray[bytetop++] = itouc($1);}
             | bytearray LITNUM {bytearray[bytetop++] = itouc($2);}
             ;
%%
# include <stdio.h>

char *filename;
FILE *fp;
FILE *ofd;

# include "lex.yy.c"

main(argc, argv)
int argc;
char **argv;
{
    if (argc != 2) quiter("parser: wrong number of arguments");
    filename = argv[1];
    fp = fopen(filename, "r");
    if (fp == NULL) {
        yerr("cannot open input file %s", filename);
        quiter("parser quits");
        }
    ofd = stdout;
    return(yyparse());
}

quiter(s) char *s; {fprintf(stderr,"%s\n", s); exit(1);}

yywarn(s, v) char *s, *v; {
   fprintf(stderr, "%s: line %d: Warning ", filename, linenum);
   fprintf(stderr, s, v);
   fprintf(stderr,"\n");
}

yyerror(s) char *s; {yerr(s, "");}

yerr(s, v)
char *s, *v;
{
   fprintf(stderr, "%s: line %d: ", filename, linenum);
   fprintf(stderr, s, v);
   fprintf(stderr,"\n");
   if (errorcount++ > 10) quiter("too many errors, goodby");
}

expect(str) char *str;
{  char buffer[100];

   sprintf(buffer,"Expected %%s found %s", yytext);
   yerr(buffer, str);
}

int yywrap() { return(1);}

char *alloc(size) int size;      /* allocate a block of storage */
{  char *p;

   p = (char *)malloc( (unsigned) size);
   if (p == (char *) 0) yyerror("out of free space");
   return(p);
}

char *bincat(s1, s2)
char *s1, *s2;
{    char *p;

    p = alloc(strlen(s1) + strlen(s2) + 1);
    strcpy(p, s1);
    strcat(p, s2);
    return(p);
}
