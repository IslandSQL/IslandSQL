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
fragment COMMENT_OR_WS: ML_COMMENT|SL_COMMENT|WS;
fragment SQL_TEXT: ML_COMMENT|SL_COMMENT|STRING|.;
fragment SLASH_END: SINGLE_NL WS* '/' [ \t]* (EOF|SINGLE_NL);
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
// Comments and alike to be ignored
/*----------------------------------------------------------------------------*/

ML_COMMENT: '/*' .*? '*/' -> channel(HIDDEN);
SL_COMMENT: '--' .*? (EOF|SINGLE_NL) -> channel(HIDDEN);

REMARK_COMMAND:
    {isBeginOfCommand()}? 'rem' ('a' ('r' 'k'?)?)?
        (WS SQLPLUS_TEXT*)? SQLPLUS_END -> channel(HIDDEN)
;

PROMPT_COMMAND:
    {isBeginOfCommand()}? 'pro' ('m' ('p' 't'?)?)?
       (WS SQLPLUS_TEXT*)? SQLPLUS_END -> channel(HIDDEN)
;

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

CONDITIONAL_COMPILATION_DIRECTIVE: '$if' .*? '$end' -> channel(HIDDEN);

GRANT:
    {isBeginOfStatement()}? 'grant' COMMENT_OR_WS+ SQL_TEXT+? SQL_END -> channel(HIDDEN)
;

REVOKE:
    {isBeginOfStatement()}? 'revoke' COMMENT_OR_WS+ SQL_TEXT+? SQL_END -> channel(HIDDEN)
;

/*----------------------------------------------------------------------------*/
// Cursor for loop
// TODO: remove with https://github.com/IslandSQL/IslandSQL/issues/29
/*----------------------------------------------------------------------------*/

CURSOR_FOR_LOOP_START:
    'for' COMMENT_OR_WS+ SQL_TEXT+? 'in' COMMENT_OR_WS* -> channel(HIDDEN)
;

/*----------------------------------------------------------------------------*/
// Islands of interest on DEFAULT_CHANNEL
/*----------------------------------------------------------------------------*/

CALL:
    {isBeginOfStatement()}? 'call' COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

DELETE:
    {isBeginOfStatement()}? 'delete' COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

EXPLAIN_PLAN:
    {isBeginOfStatement()}? 'explain' COMMENT_OR_WS+ 'plan' COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

INSERT:
    {isBeginOfStatement()}? 'insert' COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

LOCK_TABLE:
    {isBeginOfStatement()}? 'lock' COMMENT_OR_WS+ 'table' COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

MERGE:
    {isBeginOfStatement()}? 'merge' COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

SELECT:
      (
          // TODO: remove alternative with https://github.com/IslandSQL/IslandSQL/issues/29
          {getLastTokenType() == CURSOR_FOR_LOOP_START}? '(' COMMENT_OR_WS*
          ('select'|'with') COMMENT_OR_WS+ SQL_TEXT+? ')' {isLoop()}?
      )
    | (
          {isBeginOfStatement()}?
          (
                ('with' COMMENT_OR_WS+ ('function'|'procedure') SQL_TEXT+? PLSQL_DECLARATION_END)
              | ('with' COMMENT_OR_WS+ SQL_TEXT+? SQL_END)
              | (('(' COMMENT_OR_WS*)* 'select' COMMENT_OR_WS+ SQL_TEXT+? SQL_END)
          )
      )
;

UPDATE:
    {isBeginOfStatement()}? 'update' COMMENT_OR_WS+ SQL_TEXT+? 'set' COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

/*----------------------------------------------------------------------------*/
// Whitespace
/*----------------------------------------------------------------------------*/

WS: [ \t\r\n]+ -> channel(HIDDEN);

/*----------------------------------------------------------------------------*/
// Any other token
/*----------------------------------------------------------------------------*/

ANY_OTHER: . -> channel(HIDDEN);
