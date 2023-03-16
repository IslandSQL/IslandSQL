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

K_ACCESS: 'access';
K_ADD: 'add';
K_AFTER: 'after';
K_AGGREGATE: 'aggregate';
K_ALL: 'all';
K_ANALYTIC: 'analytic';
K_AND: 'and';
K_ANY: 'any';
K_APPLY: 'apply';
K_AS: 'as';
K_ASC: 'asc';
K_AUTOMATIC: 'automatic';
K_BADFILE: 'badfile';
K_BETWEEN: 'between';
K_BLOCK: 'block';
K_BREADTH: 'breadth';
K_BULK: 'bulk';
K_BY: 'by';
K_CASE: 'case';
K_CHECK: 'check';
K_CLOB: 'clob';
K_COLLATE: 'collate';
K_COLLECT: 'collect';
K_CONNECT: 'connect';
K_CONNECT_BY_ROOT: 'connect_by_root';
K_CONSTRAINT: 'constraint';
K_CROSS: 'cross';
K_CURRENT: 'current';
K_CYCLE: 'cycle';
K_DATE: 'date';
K_DAY: 'day';
K_DECREMENT: 'decrement';
K_DEFAULT: 'default';
K_DEFINE: 'define';
K_DEPTH: 'depth';
K_DESC: 'desc';
K_DETERMINISTIC: 'deterministic';
K_DIMENSION: 'dimension';
K_DIRECTORY: 'directory';
K_DISCARD: 'discard';
K_DISTINCT: 'distinct';
K_ELSE: 'else';
K_END: 'end';
K_EXCEPT: 'except';
K_EXCLUDE: 'exclude';
K_EXCLUSIVE: 'exclusive';
K_EXTERNAL: 'external';
K_FACT: 'fact';
K_FETCH: 'fetch';
K_FILTER: 'filter';
K_FINAL: 'final';
K_FIRST: 'first';
K_FOLLOWING: 'following';
K_FOR: 'for';
K_FROM: 'from';
K_FULL: 'full';
K_FUNCTION: 'function';
K_GROUP: 'group';
K_GROUPING: 'grouping';
K_GROUPS: 'groups';
K_HAVING: 'having';
K_HIERARCHIES: 'hierarchies';
K_HOUR: 'hour';
K_IGNORE: 'ignore';
K_IN: 'in';
K_INCLUDE: 'include';
K_INCREMENT: 'increment';
K_INFINITE: 'infinite';
K_INNER: 'inner';
K_INTERSECT: 'intersect';
K_INTERVAL: 'interval';
K_INTO: 'into';
K_INVISIBLE: 'invisible';
K_IS: 'is';
K_ITERATE: 'iterate';
K_JOIN: 'join';
K_KEEP: 'keep';
K_LAST: 'last';
K_LATERAL: 'lateral';
K_LEFT: 'left';
K_LIKE: 'like';
K_LIMIT: 'limit';
K_LOCATION: 'location';
K_LOCK: 'lock';
K_LOCKED: 'locked';
K_LOGFILE: 'logfile';
K_MAIN: 'main';
K_MATCH: 'match';
K_MATCH_RECOGNIZE: 'match_recognize';
K_MEASURE: 'measure';
K_MEASURES: 'measures';
K_MINUS: 'minus';
K_MINUTE: 'minute';
K_MODE: 'mode';
K_MODEL: 'model';
K_MODIFY: 'modify';
K_MONTH: 'month';
K_NAN: 'nan';
K_NATURAL: 'natural';
K_NAV: 'nav';
K_NEXT: 'next';
K_NO: 'no';
K_NOCYCLE: 'nocycle';
K_NOT: 'not';
K_NOWAIT: 'nowait';
K_NULL: 'null';
K_NULLS: 'nulls';
K_OF: 'of';
K_OFFSET: 'offset';
K_ON: 'on';
K_ONE: 'one';
K_ONLY: 'only';
K_OPTION: 'option';
K_OR: 'or';
K_ORDER: 'order';
K_OTHERS: 'others';
K_OUTER: 'outer';
K_OVER: 'over';
K_PARAMETERS: 'parameters';
K_PARTITION: 'partition';
K_PAST: 'past';
K_PATTERN: 'pattern';
K_PER: 'per';
K_PERCENT: 'percent';
K_PERIOD: 'period';
K_PERMUTE: 'permute';
K_PIVOT: 'pivot';
K_PRECEDING: 'preceding';
K_PRESENT: 'present';
K_PRIOR: 'prior';
K_PROCEDURE: 'procedure';
K_RANGE: 'range';
K_READ: 'read';
K_REFERENCE: 'reference';
K_REJECT: 'reject';
K_RETURN: 'return';
K_RIGHT: 'right';
K_ROW: 'row';
K_ROWS: 'rows';
K_RULES: 'rules';
K_RUNNING: 'running';
K_SAMPLE: 'sample';
K_SCN: 'scn';
K_SEARCH: 'search';
K_SECOND: 'second';
K_SEED: 'seed';
K_SELECT: 'select';
K_SEQUENTIAL: 'sequential';
K_SET: 'set';
K_SETS: 'sets';
K_SHARE: 'share';
K_SIBLINGS: 'siblings';
K_SINGLE: 'single';
K_SKIP: 'skip';
K_SOME: 'some';
K_SORT: 'sort';
K_START: 'start';
K_SUBPARTITION: 'subpartition';
K_SUBSET: 'subset';
K_TABLE: 'table';
K_THEN: 'then';
K_TIES: 'ties';
K_TIMESTAMP: 'timestamp';
K_TO: 'to';
K_TYPE: 'type';
K_UNBOUNDED: 'unbounded';
K_UNION: 'union';
K_UNIQUE: 'unique';
K_UNPIVOT: 'unpivot';
K_UNTIL: 'until';
K_UPDATE: 'update';
K_UPDATED: 'updated';
K_UPSERT: 'upsert';
K_USING: 'using';
K_VERSIONS: 'versions';
K_VIEW: 'view';
K_VISIBLE: 'visible';
K_WAIT: 'wait';
K_WHEN: 'when';
K_WHERE: 'where';
K_WINDOW: 'window';
K_WITH: 'with';
K_WITHIN: 'within';
K_XML: 'xml';
K_YEAR: 'year';

/*----------------------------------------------------------------------------*/
// Special characters - naming according HTML entity name
/*----------------------------------------------------------------------------*/

// see https://html.spec.whatwg.org/multipage/named-characters.html#named-character-references
// or https://oinam.github.io/entities/

AMP: '&';
AST: '*';
COLON: ':';
COMMA: ',';
COMMAT: '@';
DOLLAR: '$';
EQUALS: '=';
EXCL: '!';
GT: '>';
HAT: '^';
LCUB: '{';
LPAR: '(';
LSQB: '[';
LT: '<';
MINUS: '-';
PERIOD: '.';
PLUS: '+';
QUEST: '?';
RCUB: '}';
RPAR: ')';
RSQB: ']';
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

UPDATE:
    'update' {isBeginOfStatement("update")}? COMMENT_OR_WS+ SQL_TEXT+? 'set' COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

/*----------------------------------------------------------------------------*/
// Any other token
/*----------------------------------------------------------------------------*/

ANY_OTHER: .;
