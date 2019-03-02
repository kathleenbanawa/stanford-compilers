/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
    if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
        YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

int comment_refcnt;
bool has_null;

%}

%x block_comment
%x comment
%x str

INT_CONST [0-9]+
TYPEID    [A-Z][[:alnum:]_]*
OBJECTID  [a-z][[:alnum:]_]*
SPECIAL   [\@\.\*\+\-\(\)\;\{\}\:\<\,\=\/\~]

%%

(?i:class)    { return CLASS; }
(?i:else)     { return ELSE; }
(?i:fi)       { return FI; }
(?i:if)       { return IF; }
(?i:in)       { return IN; }
(?i:inherits) { return INHERITS; }
(?i:isvoid)   { return ISVOID; }
(?i:let)      { return LET; }
(?i:loop)     { return LOOP; }
(?i:pool)     { return POOL; }
(?i:then)     { return THEN; }
(?i:while)    { return WHILE; }
(?i:case)     { return CASE; }
(?i:esac)     { return ESAC; }
(?i:new)      { return NEW; }
(?i:not)      { return NOT; }
(?i:of)       { return OF; }

f(?i:alse) {
    cool_yylval.boolean = 0;
    return BOOL_CONST;
}
t(?i:rue) {
    cool_yylval.boolean = 1;
    return BOOL_CONST;
}

"=>"      { return DARROW; }
"<="      { return LE; }
"<-"      { return ASSIGN; }
{SPECIAL} { return yytext[0]; }

<block_comment><<EOF>> {
    BEGIN(INITIAL);
    cool_yylval.error_msg = "EOF in comment";
    return ERROR;
}

<block_comment>\n { curr_lineno++; }

<block_comment>.

<block_comment>"(*" {
    comment_refcnt++;
}

<block_comment>"*)" {
    comment_refcnt--;
    if (comment_refcnt == 0) {
        BEGIN(INITIAL);
    }
}

"(*" {
    BEGIN(block_comment);
    comment_refcnt++;
}

"*)" {
    cool_yylval.error_msg = "Unmatched *)";
    return ERROR;
}

<comment><<EOF>> {
    return 0;
}

<comment>\n {
    BEGIN(INITIAL);
    curr_lineno++;
}

<comment>.

"--" {
    BEGIN(comment);
}

<str><<EOF>> {
    BEGIN(INITIAL);
    cool_yylval.error_msg = "EOF in string constant";
    return ERROR;
}

<str>\n {
    BEGIN(INITIAL);
    curr_lineno++;
    cool_yylval.error_msg = "Unterminated string constant";
    return ERROR;
}

<str>\" {
    BEGIN(INITIAL);
    *string_buf_ptr = '\0';
    if (strlen(string_buf) >= MAX_STR_CONST) {
        cool_yylval.error_msg = "String constant too long";
        return ERROR;
    }
    if (has_null) {
        cool_yylval.error_msg = "String contains null character";
        return ERROR;
    }
    cool_yylval.symbol = stringtable.add_string(string_buf);
    return STR_CONST;
}

<str>\0      { has_null = true; }
<str>\\      { *string_buf_ptr++ = '\n'; }
<str>\\b     { *string_buf_ptr++ = '\b'; }
<str>\\t     { *string_buf_ptr++ = '\t'; }
<str>\\n     { *string_buf_ptr++ = '\n'; }
<str>\\f     { *string_buf_ptr++ = '\f'; }
<str>\\[^\0] { *string_buf_ptr++ = yytext[1]; }

<str>[^\\\"\0\n]+ {
    char *c = yytext;
    while (*c) {
        *string_buf_ptr++ = *c++;
    }
}

\" {
    string_buf_ptr = string_buf;
    BEGIN(str);
}

{INT_CONST} {
    cool_yylval.symbol = inttable.add_string(yytext);
    return INT_CONST;
}

{TYPEID} {
    cool_yylval.symbol = idtable.add_string(yytext);
    return TYPEID;
}

{OBJECTID} {
    cool_yylval.symbol = stringtable.add_string(yytext);
    return OBJECTID;
}

\n { curr_lineno++; }

[ \t\v\r\f]+

. {
    cool_yylval.error_msg = yytext;
    return ERROR;
}

%%
