/*
 * Copyright 2023 Philipp Salvisberg <philipp.salvisberg@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

lexer grammar IslandSqlScopeLexer;

options {
    superClass=IslandSqlLexerBase;
    caseInsensitive = true;
}

/*----------------------------------------------------------------------------*/
// Fragments to name expressions and reduce code duplication
/*----------------------------------------------------------------------------*/

fragment SINGLE_NL: '\r'? '\n';
fragment COMMENT_OR_WS: ML_COMMENT|(SL_COMMENT SINGLE_NL)|WS;
fragment SQL_TEXT: COMMENT_OR_WS|STRING|~';';
fragment SQL_TEXT_WITH_PLSQL: COMMENT_OR_WS|STRING|.;
fragment SLASH_END: '/' {isBeginOfCommand("/")}? [ \t]* (EOF|SINGLE_NL);
fragment PLSQL_DECLARATION_END: ';'? [ \t]* (EOF|SLASH_END);
fragment SQL_END:
      EOF
    | ';' [ \t]* SINGLE_NL?
    | SLASH_END
;
fragment CONTINUE_LINE: '-' [ \t]* SINGLE_NL;
fragment SQLPLUS_TEXT: (~[\r\n]|CONTINUE_LINE);
fragment SQLPLUS_END: EOF|SINGLE_NL;
fragment DOLLAR_QUOTE: '$' ID? '$';
fragment PLPGSQL_END: DOLLAR_QUOTE ~[;]* SQL_END;
fragment ANY_EXCEPT_FOR_AND_SEMI:
    (
          'f' 'o' ~[r;]
        | 'f' ~[o;]
        | ~[f;]
    )+;
fragment ANY_EXCEPT_AS_WS:
    (
          'a' 's' ~[ \t\r\n]
        | 'a' ~'s'
        | ~'a'
    )+
;

/*----------------------------------------------------------------------------*/
// Whitespace and comments
/*----------------------------------------------------------------------------*/

WS: [ \t\r\n]+ -> channel(HIDDEN);
ML_COMMENT: '/*' ~'*'* ({!isText("*/")}? .)* '*/' -> channel(HIDDEN);
SL_COMMENT: '--' ~[\r\n]* -> channel(HIDDEN);

/*----------------------------------------------------------------------------*/
// SQL*Plus commands (as single tokens, similar to comments)
/*----------------------------------------------------------------------------*/

REMARK_COMMAND:
    'rem' {isBeginOfCommand("rem")}? ('a' ('r' 'k'?)?)?
        ([ \t]+ SQLPLUS_TEXT*)? SQLPLUS_END -> channel(HIDDEN)
;

PROMPT_COMMAND:
    'pro' {isBeginOfCommand("pro")}? ('m' ('p' 't'?)?)?
       ([ \t]+ SQLPLUS_TEXT*)? SQLPLUS_END -> channel(HIDDEN)
;

/*----------------------------------------------------------------------------*/
// Conditional compilation directives
/*----------------------------------------------------------------------------*/

CONDITIONAL_COMPILATION_DIRECTIVE: '$if' .*? '$end' -> channel(HIDDEN);

/*----------------------------------------------------------------------------*/
// SQL*Plus commands with keywords conflicting with islands of interest
/*----------------------------------------------------------------------------*/

// hide keyword: insert, select
COPY_COMMAND:
    'copy' {isBeginOfCommand("copy")}?
        ([ \t]+ SQLPLUS_TEXT*)? SQLPLUS_END -> channel(HIDDEN)
;

/*----------------------------------------------------------------------------*/
// SQL statements with keywords conflicting with islands of interest
/*----------------------------------------------------------------------------*/

// hide keyword: with
ADMINISTER_KEY_MANAGEMENT:
    'administer' {isBeginOfStatement("administer")}? COMMENT_OR_WS+
        'key' COMMENT_OR_WS+ 'management' COMMENT_OR_WS+ SQL_TEXT+? SQL_END -> channel(HIDDEN)
;

// hide keyword: select, insert, update, delete
ALTER_AUDIT_POLICY:
    'alter' {isBeginOfStatement("alter")}? COMMENT_OR_WS+
        'audit' COMMENT_OR_WS+ 'policy' COMMENT_OR_WS+ SQL_TEXT+? SQL_END -> channel(HIDDEN)
;

// hide keywords: select, insert, update, delete
CREATE_AUDIT_POLICY:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+
        'audit' COMMENT_OR_WS+ 'policy' COMMENT_OR_WS+ SQL_TEXT+? SQL_END -> channel(HIDDEN)
;

// hide keywords: with
CREATE_DATABASE:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+
        'database' COMMENT_OR_WS+ SQL_TEXT+? SQL_END -> channel(HIDDEN)
;

// hide keywords: select, insert, update, delete
CREATE_SCHEMA:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+
        'schema' COMMENT_OR_WS+ 'authorization' COMMENT_OR_WS+ SQL_TEXT+? SQL_END -> channel(HIDDEN)
;

// hide keyword: with
CREATE_MATERIALIZED_VIEW_LOG:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ 'materialized'
        COMMENT_OR_WS+ 'view' COMMENT_OR_WS+ 'log' COMMENT_OR_WS+ SQL_TEXT+? SQL_END -> channel(HIDDEN)
;

// hide keyword: with
CREATE_OPERATOR:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ ('or'
        COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)? 'operator' COMMENT_OR_WS+ SQL_TEXT+? SQL_END -> channel(HIDDEN)
;

// hide keyword: with
CREATE_TABLE:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ ('or'
        COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)? 'table' COMMENT_OR_WS+ SQL_TEXT+? SQL_END -> channel(HIDDEN);

// hide keyword: insert, update, delete (everything up to the first semicolon)
CREATE_TRIGGER:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ ('or'
        COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)? 'trigger'
        COMMENT_OR_WS+ SQL_TEXT+? SQL_END -> channel(HIDDEN)
;

// hide keyword: with (everything up to the as keyword)
CREATE_VIEW:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ ('or'
        COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)? ('materialized' COMMENT_OR_WS+)? 'view'
        ANY_EXCEPT_AS_WS -> channel(HIDDEN)
;

// hide keywords: select, insert, update, delete
GRANT:
    'grant' {isBeginOfStatement("grant")}? COMMENT_OR_WS+ SQL_TEXT+? SQL_END -> channel(HIDDEN)
;

// hide keywords: select, insert, update, delete
REVOKE:
    'revoke' {isBeginOfStatement("revoke")}? COMMENT_OR_WS+ SQL_TEXT+? SQL_END -> channel(HIDDEN)
;

/*----------------------------------------------------------------------------*/
// Data types
/*----------------------------------------------------------------------------*/

STRING:
    (
          'e' (['] ~[']* ['])                                   // PostgreSQL string constant with C-style escapes
        | 'b' (['] ~[']* ['])                                   // PostgreSQL bit-string constant
        | 'u&' ['] ~[']* [']                                    // PostgreSQL string constant with unicode escapes
        | '$$' .*? '$$'                                         // PostgreSQL dollar-quoted string constant
        | '$' ID '$' {saveDollarIdentifier1()}? .+? '$' ID '$' {checkDollarIdentifier2()}?
        | 'n'? ['] ~[']* ['] (COMMENT_OR_WS* ['] ~[']* ['])*    // simple string, PostgreSQL, MySQL string constant
        | 'n'? 'q' ['] '[' .*? ']' [']
        | 'n'? 'q' ['] '(' .*? ')' [']
        | 'n'? 'q' ['] '{' .*? '}' [']
        | 'n'? 'q' ['] '<' .*? '>' [']
        | 'n'? 'q' ['] . {saveQuoteDelimiter1()}? .+? . ['] {checkQuoteDelimiter2()}?
    ) -> channel(HIDDEN)
;

/*----------------------------------------------------------------------------*/
// Identifier
/*----------------------------------------------------------------------------*/

ID: [_\p{Alpha}] [_$#0-9\p{Alpha}]* -> channel(HIDDEN);

/*----------------------------------------------------------------------------*/
// Label statement
// TODO: remove with https://github.com/IslandSQL/IslandSQL/issues/29
/*----------------------------------------------------------------------------*/

LABEL: '<<' WS* ID WS* '>>' -> channel(HIDDEN);

/*----------------------------------------------------------------------------*/
// Cursor for loop
// TODO: remove with https://github.com/IslandSQL/IslandSQL/issues/29
/*----------------------------------------------------------------------------*/

CURSOR_FOR_LOOP_START:
    'for' {isBeginOfStatement("for")}? COMMENT_OR_WS+ ~[\t\r\n ]+ COMMENT_OR_WS+ 'in' COMMENT_OR_WS* {isText("(")}?
    -> channel(HIDDEN), pushMode(CURSOR_FOR_LOOP)
;

/*----------------------------------------------------------------------------*/
// Cursor definition
// TODO: remove with https://github.com/IslandSQL/IslandSQL/issues/29
/*----------------------------------------------------------------------------*/

CURSOR_START:
    'cursor' {isBeginOfStatement("cursor")}? COMMENT_OR_WS+ SQL_TEXT+? (COMMENT_OR_WS|')')+ 'is' COMMENT_OR_WS*
    -> channel(HIDDEN), pushMode(SUBQUERY)
;

/*----------------------------------------------------------------------------*/
// Open cursor for
// TODO: remove with https://github.com/IslandSQL/IslandSQL/issues/29
/*----------------------------------------------------------------------------*/

OPEN_CURSOR_FOR_START:
    'open' {isBeginOfStatement("open")}? COMMENT_OR_WS+
    ANY_EXCEPT_FOR_AND_SEMI 'for' (COMMENT_OR_WS+|{isText("(")}?)
    -> channel(HIDDEN), pushMode(SUBQUERY)
;

/*----------------------------------------------------------------------------*/
// Forall statement
// TODO: remove with https://github.com/IslandSQL/IslandSQL/issues/29
/*----------------------------------------------------------------------------*/

FORALL_IGNORE:
    'forall' {isBeginOfStatement("forall")}? COMMENT_OR_WS+ WS
        'execute' WS 'immediate' .+? SQL_END -> channel(HIDDEN);

FORALL_START:
    'forall' {isBeginOfStatement("forall")}? COMMENT_OR_WS+ SQL_TEXT+? WS
    (
          {isText("insert")}?
        | {isText("update")}?
        | {isText("delete")}?
        | {isText("merge")}?
    )
    -> channel(HIDDEN)
;

/*----------------------------------------------------------------------------*/
// Islands of interest on DEFAULT_CHANNEL
/*----------------------------------------------------------------------------*/

CALL:
    'call' {isBeginOfStatement("call")}? COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

DELETE:
    'delete' {isBeginOfStatement("delete")}? COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

EXPLAIN_PLAN:
    'explain' {isBeginOfStatement("explain")}? COMMENT_OR_WS+ 'plan' COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

INSERT:
    'insert' {isBeginOfStatement("insert")}? COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

LOCK_TABLE:
    'lock' {isBeginOfStatement("lock")}? COMMENT_OR_WS+ 'table' COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

MERGE:
    'merge' {isBeginOfStatement("merge")}? COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

// TODO: enforce select in parenthesis at begin of statement to to avoid identifying out-of-scope subqueries after implementing:
// - https://github.com/IslandSQL/IslandSQL/issues/29
// - https://github.com/IslandSQL/IslandSQL/issues/35
SELECT:
    (
        ('with' {isBeginOfStatement("with")}? COMMENT_OR_WS+ ('function'|'procedure') SQL_TEXT_WITH_PLSQL+? PLSQL_DECLARATION_END)
      | ('with' {isBeginOfStatement("with")}? COMMENT_OR_WS+ SQL_TEXT+? SQL_END)
      | ('select' {isBeginOfStatement("select")}? COMMENT_OR_WS+ SQL_TEXT+? SQL_END)
      | (('(' COMMENT_OR_WS*)+ 'select' COMMENT_OR_WS+ SQL_TEXT+? SQL_END)
    )
;

UPDATE:
    'update' {isBeginOfStatement("update")}? COMMENT_OR_WS+ SQL_TEXT+? 'set' (COMMENT_OR_WS|'(')+ SQL_TEXT+? SQL_END
;

/*----------------------------------------------------------------------------*/
// Any other token
/*----------------------------------------------------------------------------*/

ANY_OTHER: . -> channel(HIDDEN);

/*----------------------------------------------------------------------------*/
// Cursor for loop mode to identify select statement
// TODO: remove with https://github.com/IslandSQL/IslandSQL/issues/29
/*----------------------------------------------------------------------------*/

mode CURSOR_FOR_LOOP;

CFL_ML_COMMENT: ML_COMMENT -> channel(HIDDEN), type(ML_COMMENT);
CFL_SL_COMMENT: SL_COMMENT -> channel(HIDDEN), type(SL_COMMENT);
CFL_WS: WS -> channel(HIDDEN), type(WS);
CFL_ANY_OTHER: . -> channel(HIDDEN), type(ANY_OTHER);

CFL_SELECT:
    ('(' COMMENT_OR_WS*)+
    ('select'|'with') .*? (')' COMMENT_OR_WS*)+ {isText("loop")}? -> type(SELECT)
;

CFL_END_OF_SELECT:
    'loop' -> type(ID), channel(HIDDEN), popMode
;

/*----------------------------------------------------------------------------*/
// Subquery mode to identify select statement
// TODO: remove with https://github.com/IslandSQL/IslandSQL/issues/29
/*----------------------------------------------------------------------------*/

mode SUBQUERY;

SQ_END: ';' -> channel(HIDDEN), type(ANY_OTHER), popMode;
SQ_ID: ID -> channel(HIDDEN), type(ID);
SQ_STRING: STRING  -> channel(HIDDEN), type(STRING);
SQ_ANY_OTHER: . -> channel(HIDDEN), type(ANY_OTHER);

SQ_SELECT:
    ('('|COMMENT_OR_WS)*
    ('select'|'with') COMMENT_OR_WS+ SQL_TEXT+? ';' SINGLE_NL? -> type(SELECT), popMode
;
