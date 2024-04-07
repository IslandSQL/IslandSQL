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
fragment COMMENT_OR_WS: ML_COMMENT|(SL_COMMENT (SINGLE_NL|EOF))|WS;
fragment SQL_TEXT: COMMENT_OR_WS|STRING|~';';
fragment SQL_TEXT_WITH_PLSQL: COMMENT_OR_WS|STRING|.;
fragment SQL_PROCEDURE_BODY: 'begin' COMMENT_OR_WS 'atomic' ANY_EXCEPT_END 'end';
fragment SQL_TEXT_WITH_PGPLSQL: COMMENT_OR_WS|STRING|SQL_PROCEDURE_BODY|~';';
fragment SLASH_END: '/' {isBeginOfCommand("/")}? [ \t]* (EOF|SINGLE_NL);
fragment PLSQL_DECLARATION_END: ';'? [ \t]* (EOF|SLASH_END);
fragment LABEL: '<<' WS* ID WS* '>>';
fragment PLSQL_END: 'end' (COMMENT_OR_WS+ (ID|'"' ID '"'))? COMMENT_OR_WS* ';' COMMENT_OR_WS* (EOF|SLASH_END);
fragment PSQL_EXEC: SINGLE_NL (WS|ML_COMMENT)* '\\g' ~[\n]+;
fragment SQL_END:
      EOF
    | ';' [ \t]* SINGLE_NL?
    | SLASH_END
    | PSQL_EXEC
;
fragment CONTINUE_LINE: '-' [ \t]* SINGLE_NL;
fragment SQLPLUS_TEXT: (~[\r\n]|CONTINUE_LINE);
fragment SQLPLUS_END: EOF|SINGLE_NL;
fragment DOLLAR_QUOTE: '$' ID? '$';
fragment ANY_EXCEPT_DOLLAR_DOLLAR:
    (
          '$' ~'$'
        | ~'$'
    )+;
fragment ANY_EXCEPT_END:
    (
          'e' 'n' ~'d'
        | 'e' ~'n'
        | ~'e'
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

/*----------------------------------------------------------------------------*/
// String
/*----------------------------------------------------------------------------*/

STRING:
    (
          'e' (['] ~[']* ['])                                   // PostgreSQL string constant with C-style escapes
        | 'b' (['] ~[']* ['])                                   // PostgreSQL bit-string constant
        | 'u&' ['] ~[']* [']                                    // PostgreSQL string constant with unicode escapes
        | '$$' ANY_EXCEPT_DOLLAR_DOLLAR? '$$'                   // PostgreSQL dollar-quoted string constant
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
// Comments
/*----------------------------------------------------------------------------*/

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

// hide keyword: merge
ALTER_TABLE:
    'alter' {isBeginOfStatement("alter")}? COMMENT_OR_WS+
        'table' COMMENT_OR_WS+ SQL_TEXT+? SQL_END -> channel(HIDDEN)
;

// hide keyword: begin
ALTER_TABLESPACE:
    'alter' {isBeginOfStatement("alter")}? COMMENT_OR_WS+
        'tablespace' COMMENT_OR_WS+ SQL_TEXT+? SQL_END -> channel(HIDDEN)
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

// hide keywords: select, insert, update, delete (hides first command only)
CREATE_RULE:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ ('or'
        COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)? 'rule' COMMENT_OR_WS+ SQL_TEXT+? SQL_END -> channel(HIDDEN)
;

// hide keywords: select, insert, update, delete
CREATE_SCHEMA:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+
        'schema' COMMENT_OR_WS+ 'authorization' COMMENT_OR_WS+ SQL_TEXT+? SQL_END -> channel(HIDDEN)
;

// hide keyword: with
CREATE_TABLE:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ ('or'
        COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)? 'table' COMMENT_OR_WS+ SQL_TEXT+? SQL_END -> channel(HIDDEN);

// hide keyword: with
CREATE_USER:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ 'user'
        COMMENT_OR_WS+ SQL_TEXT+? SQL_END -> channel(HIDDEN)
;

// hide keyword: with (everything up to the as keyword)
// TODO: remove with https://github.com/IslandSQL/IslandSQL/issues/35
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
// Islands of interest on DEFAULT_CHANNEL
/*----------------------------------------------------------------------------*/

CALL:
    'call' {isBeginOfStatement("call")}? COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

COMMIT:
    'commit' {isBeginOfStatement("commit")}? COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

// handles also functions with unquoted sql_body
CREATE_FUNCTION_POSTGRESQL:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ ('or'
    COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)? 'function' COMMENT_OR_WS+ SQL_TEXT+?
    'returns' COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

CREATE_FUNCTION:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ ('or'
    COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)?
    (('editionable' | 'noneditionable') COMMENT_OR_WS+)?
    'function' COMMENT_OR_WS+ SQL_TEXT_WITH_PLSQL+? PLSQL_END
;

// handles also package body
CREATE_PACKAGE:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ ('or'
    COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)?
    (('editionable' | 'noneditionable') COMMENT_OR_WS+)?
    'package' COMMENT_OR_WS+ SQL_TEXT_WITH_PLSQL+? PLSQL_END
;

// handles also procedures with unquoted sql_body
CREATE_PROCEDURE_POSTGRESQL:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ ('or'
    COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)? 'procedure' COMMENT_OR_WS+ SQL_TEXT_WITH_PGPLSQL+ SQL_END
;

CREATE_PROCEDURE:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ ('or'
    COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)?
    (('editionable' | 'noneditionable') COMMENT_OR_WS+)?
    'procedure' COMMENT_OR_WS+ SQL_TEXT_WITH_PLSQL+? PLSQL_END
;

CREATE_TRIGGER_POSTGRESQL:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ ('or'
    COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)?
    ('constraint' COMMENT_OR_WS+)?
    'trigger' COMMENT_OR_WS+ SQL_TEXT+?
    'execute' COMMENT_OR_WS+ ('function' | 'procedure') COMMENT_OR_WS+
    SQL_TEXT+? SQL_END
;

CREATE_TRIGGER:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ ('or'
    COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)?
    (('editionable' | 'noneditionable') COMMENT_OR_WS+)?
    'trigger' COMMENT_OR_WS+ SQL_TEXT_WITH_PLSQL+? PLSQL_END
;

// OracleDB and PostgreSQL type specifications
CREATE_TYPE:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ ('or'
    COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)?
    (('editionable' | 'noneditionable') COMMENT_OR_WS+)?
    'type' COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

CREATE_TYPE_BODY:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ ('or'
    COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)?
    (('editionable' | 'noneditionable') COMMENT_OR_WS+)?
    'type' COMMENT_OR_WS+ 'body' COMMENT_OR_WS+ SQL_TEXT_WITH_PLSQL+? PLSQL_END
;

DELETE:
    'delete' {isBeginOfStatement("delete")}? COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

EXPLAIN_PLAN:
    'explain' {isBeginOfStatement("explain")}? COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

INSERT:
    'insert' {isBeginOfStatement("insert")}? COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

LOCK_TABLE:
    'lock' {isBeginOfStatement("lock")}? COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

MERGE:
    'merge' {isBeginOfStatement("merge")}? COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

PLSQL_BLOCK:
      (LABEL COMMENT_OR_WS*)* 'begin' {isBeginOfStatement("begin")}? COMMENT_OR_WS+ SQL_TEXT_WITH_PLSQL+? PLSQL_END
    | (LABEL COMMENT_OR_WS*)* 'declare' {isBeginOfStatement("declare")}? COMMENT_OR_WS+ SQL_TEXT_WITH_PLSQL+? PLSQL_END
;

ROLLBACK:
    'rollback' {isBeginOfStatement("rollback")}? COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

SAVEPOINT:
    'savepoint' {isBeginOfStatement("savepoint")}? COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

SET_CONSTRAINTS:
    'set' {isBeginOfStatement("set")}? COMMENT_OR_WS+ ('constraint' | 'contstraints') COMMENT_OR_WS+ SQL_TEXT+? SQL_END
;

// TODO: enforce select in parenthesis at begin of statement to to avoid identifying out-of-scope subqueries after implementing:
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
