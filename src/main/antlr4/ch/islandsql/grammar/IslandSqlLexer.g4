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
fragment INT: [0-9]+;

/*----------------------------------------------------------------------------*/
// Hidden tokens
/*----------------------------------------------------------------------------*/

WS: [ \t\r\n]+ -> channel(HIDDEN);
ML_COMMENT: '/*' .*? '*/' -> channel(HIDDEN);
SL_COMMENT: '--' .*? (EOF|SINGLE_NL) -> channel(HIDDEN);
CONDITIONAL_COMPILATION_DIRECTIVE: '$if' .*? '$end' -> channel(HIDDEN);

/*----------------------------------------------------------------------------*/
// Keywords
/*----------------------------------------------------------------------------*/

K_ALL: 'all';
K_ANY: 'any';
K_CASE: 'case';
K_COLLATE: 'collate';
K_ELSE: 'else';
K_END: 'end';
K_EXCLUSIVE: 'exclusive';
K_FOR: 'for';
K_IN: 'in';
K_LOCK: 'lock';
K_MODE: 'mode';
K_NOWAIT: 'nowait';
K_PARTITION: 'partition';
K_PRIOR: 'prior';
K_ROW: 'row';
K_SHARE: 'share';
K_SOME: 'some';
K_SUBPARTITION: 'subpartition';
K_TABLE: 'table';
K_THEN: 'then';
K_UPDATE: 'update';
K_WAIT: 'wait';
K_WHEN: 'when';

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
    ('+'|'-')?
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
// Islands of interest as single tokens
/*----------------------------------------------------------------------------*/

CALL:
    'call' COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

DELETE:
    'delete' COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

EXPLAIN_PLAN:
    'explain' COMMENT_OR_WS+ 'plan' COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

INSERT:
    'insert' COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

MERGE:
    'merge' COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

UPDATE:
    'update' COMMENT_OR_WS+ SQL_TEXT+? 'set' COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

SELECT:
    (
          ('with' COMMENT_OR_WS+ ('function'|'procedure') SQL_TEXT+? PLSQL_DECLARATION_END)
        | ('with' COMMENT_OR_WS+ SQL_TEXT+? SQL_END)
        | (('(' COMMENT_OR_WS*)* 'select' COMMENT_OR_WS SQL_TEXT+? SQL_END)
    )
;

/*----------------------------------------------------------------------------*/
// Any other token
/*----------------------------------------------------------------------------*/

ANY_OTHER: .;
