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
fragment SQL_TEXT: COMMENT_OR_WS|STRING|.;
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

/*----------------------------------------------------------------------------*/
// Whitespace, comments and hints
/*----------------------------------------------------------------------------*/

WS: [ \t\r\n]+ -> channel(HIDDEN);
ML_HINT: '/*+' .*? '*/' -> channel(HIDDEN);
ML_COMMENT: '/*' ~'*'* ({!isText("*/")}? .)* '*/' -> channel(HIDDEN);
SL_HINT: '--+' ~[\r\n]* -> channel(HIDDEN);
SL_COMMENT: '--' ~[\r\n]* -> channel(HIDDEN);

/*----------------------------------------------------------------------------*/
// Hidden SQL*Plus commands
/*----------------------------------------------------------------------------*/

REMARK_COMMAND:
    'rem' {isBeginOfCommand("rem")}? ('a' ('r' 'k'?)?)?
        (WS SQLPLUS_TEXT*)? SQLPLUS_END -> channel(HIDDEN)
;

PROMPT_COMMAND:
    'pro' {isBeginOfCommand("pro")}? ('m' ('p' 't'?)?)?
       (WS SQLPLUS_TEXT*)? SQLPLUS_END -> channel(HIDDEN)
;

/*----------------------------------------------------------------------------*/
// Conditional compilation directives
/*----------------------------------------------------------------------------*/

CONDITIONAL_COMPILATION_DIRECTIVE: '$if' .*? '$end' -> channel(HIDDEN);

/*----------------------------------------------------------------------------*/
// Other hidden tokens to be ignored
/*----------------------------------------------------------------------------*/

STRING:
    'n'?
    (
          (['] .*? ['])+
        | ('q' ['] '[' .*? ']' ['])
        | ('q' ['] '(' .*? ')' ['])
        | ('q' ['] '{' .*? '}' ['])
        | ('q' ['] '<' .*? '>' ['])
        | ('q' ['] . {saveQuoteDelimiter1()}? .+? . ['] {checkQuoteDelimiter2()}?)
    ) -> channel(HIDDEN)
;

ID: [\p{Alpha}] [_$#0-9\p{Alpha}]* -> channel(HIDDEN);

LABEL: '<<' WS* ID WS* '>>' -> channel(HIDDEN);

GRANT:
    'grant' {isBeginOfStatement("grant")}? COMMENT_OR_WS+ SQL_TEXT+? SQL_END -> channel(HIDDEN)
;

REVOKE:
    'revoke' {isBeginOfStatement("revoke")}? COMMENT_OR_WS+ SQL_TEXT+? SQL_END -> channel(HIDDEN)
;

CREATE_AUDIT_POLICY:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+
        'audit' COMMENT_OR_WS+ 'policy' COMMENT_OR_WS+ SQL_TEXT+? SQL_END -> channel(HIDDEN)
;

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
    'cursor' {isBeginOfStatement("cursor")}? COMMENT_OR_WS+ ~[\t\r\n ]+ COMMENT_OR_WS+ 'is' COMMENT_OR_WS*
    -> channel(HIDDEN)
;

/*----------------------------------------------------------------------------*/
// Open cursor for
// TODO: remove with https://github.com/IslandSQL/IslandSQL/issues/29
/*----------------------------------------------------------------------------*/

OPEN_CURSOR_FOR_START:
    'open' {isBeginOfStatement("open")}? ~[;]+ COMMENT_OR_WS+ 'for' (COMMENT_OR_WS+|{isText("(")}?)
    -> channel(HIDDEN)
;

/*----------------------------------------------------------------------------*/
// Forall statement
// TODO: remove with https://github.com/IslandSQL/IslandSQL/issues/29
/*----------------------------------------------------------------------------*/

FORALL_START:
    'forall' {isBeginOfStatement("forall")}? COMMENT_OR_WS+ .+?
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

// TODO: remove select in parenthesis with https://github.com/IslandSQL/IslandSQL/issues/29 to avoid identifying out-of-scope subqueries
SELECT:
    (
        ('with' {isBeginOfStatement("with")}? COMMENT_OR_WS+ ('function'|'procedure') SQL_TEXT+? PLSQL_DECLARATION_END)
      | ('with' {isBeginOfStatement("with")}? COMMENT_OR_WS+ SQL_TEXT+? SQL_END)
      | ('select' {isBeginOfStatement("select")}? COMMENT_OR_WS+ SQL_TEXT+? SQL_END)
      | ('(' COMMENT_OR_WS? ('(' COMMENT_OR_WS*)* 'select' COMMENT_OR_WS+ SQL_TEXT+? ')' COMMENT_OR_WS* SQL_END)
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

fragment CFL_SINGLE_NL: '\r'? '\n';
fragment CFL_COMMENT_OR_WS: CFL_ML_COMMENT|(CFL_SL_COMMENT CFL_SINGLE_NL)|CFL_WS;
CFL_ML_COMMENT: '/*' ~'*'* ({!isText("*/")}? .)* '*/' -> channel(HIDDEN), type(ML_COMMENT);
CFL_SL_COMMENT: '--' ~[\r\n]* -> channel(HIDDEN), type(SL_COMMENT);
CFL_WS: [ \t\r\n]+ -> channel(HIDDEN), type(WS);
CFL_ANY_OTHER: . -> channel(HIDDEN), type(ANY_OTHER);

CFL_SELECT:
    ('(' CFL_COMMENT_OR_WS*)+
    ('select'|'with') .*? (')' CFL_COMMENT_OR_WS*)+ {isText("loop")}? -> type(SELECT)
;

CFL_END_OF_SELECT:
    'loop' -> type(ID), channel(HIDDEN), popMode
;
