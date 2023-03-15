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

lexer grammar IslandSqlLexer;

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
fragment INT: [0-9]+;

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
// Other hidden tokens
/*----------------------------------------------------------------------------*/

WS: [ \t\r\n]+ -> channel(HIDDEN);
ML_COMMENT: '/*' .*? '*/' -> channel(HIDDEN);
SL_COMMENT: '--' ~[\r\n]* -> channel(HIDDEN);
CONDITIONAL_COMPILATION_DIRECTIVE: '$if' .*? '$end' -> channel(HIDDEN);

/*----------------------------------------------------------------------------*/
// Keywords
/*----------------------------------------------------------------------------*/

K_ALL: 'all';
K_AND: 'and';
K_ANY: 'any';
K_ASC: 'asc';
K_BETWEEN: 'between';
K_BY: 'by';
K_CASE: 'case';
K_COLLATE: 'collate';
K_CONNECT_BY_ROOT: 'connect_by_root';
K_CURRENT: 'current';
K_DATE: 'date';
K_DAY: 'day';
K_DESC: 'desc';
K_DETERMINISTIC: 'deterministic';
K_DISTINCT: 'distinct';
K_ELSE: 'else';
K_END: 'end';
K_EXCLUDE: 'exclude';
K_EXCLUSIVE: 'exclusive';
K_FIRST: 'first';
K_FOLLOWING: 'following';
K_FOR: 'for';
K_GROUP: 'group';
K_GROUPS: 'groups';
K_HOUR: 'hour';
K_IN: 'in';
K_INTERVAL: 'interval';
K_LAST: 'last';
K_LOCK: 'lock';
K_MINUTE: 'minute';
K_MODE: 'mode';
K_MONTH: 'month';
K_NO: 'no';
K_NOWAIT: 'nowait';
K_NULLS: 'nulls';
K_ORDER: 'order';
K_OTHERS: 'others';
K_OVER: 'over';
K_PARTITION: 'partition';
K_PRECEDING: 'preceding';
K_PRIOR: 'prior';
K_RANGE: 'range';
K_ROW: 'row';
K_ROWS: 'rows';
K_SECOND: 'second';
K_SHARE: 'share';
K_SIBLINGS: 'siblings';
K_SOME: 'some';
K_SUBPARTITION: 'subpartition';
K_TABLE: 'table';
K_THEN: 'then';
K_TIES: 'ties';
K_TIMESTAMP: 'timestamp';
K_TO: 'to';
K_UNBOUNDED: 'unbounded';
K_UNIQUE: 'unique';
K_UPDATE: 'update';
K_WAIT: 'wait';
K_WHEN: 'when';
K_WITHIN: 'within';
K_YEAR: 'year';

/*----------------------------------------------------------------------------*/
// Special characters - naming according HTML entity name
/*----------------------------------------------------------------------------*/

// see https://html.spec.whatwg.org/multipage/named-characters.html#named-character-references
// or https://oinam.github.io/entities/

AST: '*';
AMP: '&';
COMMAT: '@';
COMMA: ',';
EQUALS: '=';
EXCL: '!';
GT: '>';
HAT: '^';
LPAR: '(';
LT: '<';
MINUS: '-';
PERIOD: '.';
PLUS: '+';
RPAR: ')';
SEMI: ';';
SOL: '/';
TILDE: '~';
VERBAR: '|';

/*----------------------------------------------------------------------------*/
// Data types
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
    )
;

NUMBER:
    (
          INT (PERIOD {!isCharAt(".", getCharIndex())}? INT?)?
        | PERIOD {!isCharAt(".", getCharIndex()-2)}? INT
    )
    ('e' ('+'|'-')? INT)?
    ('f'|'d')?
;

/*----------------------------------------------------------------------------*/
// Identifier
/*----------------------------------------------------------------------------*/

QUOTED_ID: '"' .*? '"' ('"' .*? '"')*;
ID: [\p{Alpha}] [_$#0-9\p{Alpha}]*;

/*----------------------------------------------------------------------------*/
// Cursor for loop
// TODO: remove with https://github.com/IslandSQL/IslandSQL/issues/29
/*----------------------------------------------------------------------------*/

CURSOR_FOR_LOOP_START:
    'for' COMMENT_OR_WS+ ~[\t\r\n ]+ COMMENT_OR_WS+ 'in' COMMENT_OR_WS* {isText("(")}?
    -> channel(HIDDEN), pushMode(CURSOR_FOR_LOOP)
;

/*----------------------------------------------------------------------------*/
// Islands of interest as single tokens
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

MERGE:
    'merge' {isBeginOfStatement("merge")}? COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

SELECT:
    (
        ('with' {isBeginOfStatement("with")}? COMMENT_OR_WS+ ('function'|'procedure') SQL_TEXT+? PLSQL_DECLARATION_END)
      | ('with' {isBeginOfStatement("with")}? COMMENT_OR_WS+ SQL_TEXT+? SQL_END)
      | ('select' {isBeginOfStatement("select")}? COMMENT_OR_WS+ SQL_TEXT+? SQL_END)
      | ('(' {isBeginOfStatement("(")}? COMMENT_OR_WS? ('(' COMMENT_OR_WS*)* 'select' COMMENT_OR_WS+ SQL_TEXT+? SQL_END)
    )
;

UPDATE:
    'update' {isBeginOfStatement("update")}? COMMENT_OR_WS+ SQL_TEXT+? 'set' COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

/*----------------------------------------------------------------------------*/
// Any other token
/*----------------------------------------------------------------------------*/

ANY_OTHER: .;

/*----------------------------------------------------------------------------*/
// Cursor for loop mode to identify select statement
// TODO: remove with https://github.com/IslandSQL/IslandSQL/issues/29
/*----------------------------------------------------------------------------*/

mode CURSOR_FOR_LOOP;

fragment CFL_SINGLE_NL: '\r'? '\n';
fragment CFL_COMMENT_OR_WS: CFL_ML_COMMENT|CFL_SL_COMMENT|CFL_WS;
CFL_ML_COMMENT: '/*' .*? '*/' -> channel(HIDDEN), type(ML_COMMENT);
CFL_SL_COMMENT: '--' .*? (EOF|CFL_SINGLE_NL) -> channel(HIDDEN), type(SL_COMMENT);
CFL_WS: [ \t\r\n]+ -> channel(HIDDEN), type(WS);
CFL_ANY_OTHER: . -> channel(HIDDEN), type(ANY_OTHER);

CFL_SELECT:
    ('(' CFL_COMMENT_OR_WS*)+
    ('select'|'with') .*? (')' CFL_COMMENT_OR_WS*)+ {isText("loop")}? -> type(SELECT)
;

CFL_END_OF_SELECT:
    'loop' -> channel(HIDDEN), popMode
;
