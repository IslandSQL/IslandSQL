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
fragment HSPACE: [ \t]+;
fragment SLASH_END: '/' {isBeginOfCommand("/")}? HSPACE? (EOF|SINGLE_NL);
fragment NAME: ID|QUOTED_ID;
fragment LABEL: '<<' WS? NAME WS? '>>';
fragment PSQL_EXEC: SINGLE_NL (WS|ML_COMMENT)* '\\g' ~[\n]+;
fragment UNIT_DEFINITION_START: ('function'|'procedure') COMMENT_OR_WS+ SQL_TEXT+? ('is'|'as') COMMENT_OR_WS+;
fragment TO_SQLPLUS_END: ((HSPACE|CONTINUE_LINE) SQLPLUS_TEXT*)? SQLPLUS_END;
fragment TO_SQL_END: COMMENT_OR_WS+ SQL_TEXT+? SQL_END;
fragment SQL_END:
      EOF
    | ';' HSPACE? SINGLE_NL?
    | SLASH_END
    | PSQL_EXEC
;
fragment CONTINUE_LINE: '-' HSPACE? SINGLE_NL?;
fragment SQLPLUS_TEXT: (~[\r\n]|CONTINUE_LINE);
fragment SQLPLUS_END: EOF|SINGLE_NL;
fragment ANY_EXCEPT_AS_WS:
    (
          'a' 's' ~[ \t\r\n]
        | 'a' ~'s'
        | ~'a'
    )
;
fragment ANY_EXCEPT_LOG:
    (
          'l' 'o' ~'g'
        | 'l' ~'o'
        | ~'l'
    )
;
fragment ANY_EXCEPT_BODY:
    (
          'b' 'o' 'd' ~'y'
        | 'b' 'o' ~'d'
        | 'b' ~'o'
        | ~'b'
    )
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
QUOTED_ID: '"' .*? '"' ('"' .*? '"')* -> channel(HIDDEN);

/*----------------------------------------------------------------------------*/
// Comments
/*----------------------------------------------------------------------------*/

ML_COMMENT: '/*' ~'*'* ({!isText("*/")}? .)* '*/' -> channel(HIDDEN);
SL_COMMENT: '--' ~[\r\n]* -> channel(HIDDEN);

/*----------------------------------------------------------------------------*/
// SQL*Plus commands (as single tokens, similar to comments)
/*----------------------------------------------------------------------------*/

REMARK_COMMAND:
    'rem' {isBeginOfCommand("rem")}? ('a' ('r' 'k'?)?)? TO_SQLPLUS_END -> channel(HIDDEN)
;

PROMPT_COMMAND:
    'pro' {isBeginOfCommand("pro")}? ('m' ('p' 't'?)?)? TO_SQLPLUS_END -> channel(HIDDEN)
;

/*----------------------------------------------------------------------------*/
// SQL*Plus commands with keywords conflicting with islands of interest
/*----------------------------------------------------------------------------*/

// hide keyword: insert, select
COPY_COMMAND:
    'copy' {isBeginOfCommand("copy")}? TO_SQLPLUS_END -> channel(HIDDEN)
;

/*----------------------------------------------------------------------------*/
// SQL statements with keywords conflicting with islands of interest
/*----------------------------------------------------------------------------*/

// hide keyword: with
ADMINISTER_KEY_MANAGEMENT:
    'administer' {isBeginOfStatement("administer")}? COMMENT_OR_WS+
        'key' COMMENT_OR_WS+ 'management' TO_SQL_END -> channel(HIDDEN)
;

// hide keyword: select, insert, update, delete
ALTER_AUDIT_POLICY:
    'alter' {isBeginOfStatement("alter")}? COMMENT_OR_WS+
        'audit' COMMENT_OR_WS+ 'policy' TO_SQL_END -> channel(HIDDEN)
;

// hide keyword: merge
ALTER_TABLE:
    'alter' {isBeginOfStatement("alter")}? COMMENT_OR_WS+
        'table' TO_SQL_END -> channel(HIDDEN)
;

// hide keyword: begin
ALTER_TABLESPACE:
    'alter' {isBeginOfStatement("alter")}? COMMENT_OR_WS+
        'tablespace' TO_SQL_END -> channel(HIDDEN)
;

// hide keywords: select, insert, update, delete
CREATE_AUDIT_POLICY:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+
        'audit' COMMENT_OR_WS+ 'policy' TO_SQL_END -> channel(HIDDEN)
;

// hide keywords: with
CREATE_DATABASE:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+
        'database' TO_SQL_END -> channel(HIDDEN)
;

// hide keyword: with
CREATE_MATERIALIZED_VIEW_LOG:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ 'materialized'
        COMMENT_OR_WS+ 'view' COMMENT_OR_WS+ 'log' TO_SQL_END -> channel(HIDDEN)
;

// hide keyword: with
CREATE_OPERATOR:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ ('or'
        COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)? 'operator' TO_SQL_END -> channel(HIDDEN)
;

// hide keywords: select, insert, update, delete (hides first command only)
CREATE_RULE:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ ('or'
        COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)? 'rule' TO_SQL_END -> channel(HIDDEN)
;

// hide keywords: select, insert, update, delete
CREATE_SCHEMA:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ 'schema'
        TO_SQL_END -> channel(HIDDEN)
;

// hide keyword: with
CREATE_TABLE:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ SQL_TEXT*? 'table'
        TO_SQL_END -> channel(HIDDEN);

// hide keyword: with
CREATE_USER:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ 'user'
        TO_SQL_END -> channel(HIDDEN)
;

// hide keyword: with (everything up to the as keyword)
// TODO: remove with https://github.com/IslandSQL/IslandSQL/issues/35
CREATE_VIEW:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ SQL_TEXT*? 'view'
        COMMENT_OR_WS+ ANY_EXCEPT_LOG ANY_EXCEPT_AS_WS+ -> channel(HIDDEN)
;

// hide keywords: select, insert, update, delete
GRANT:
    'grant' {isBeginOfStatement("grant")}? TO_SQL_END -> channel(HIDDEN)
;

// hide keywords: select, insert, update, delete
REVOKE:
    'revoke' {isBeginOfStatement("revoke")}? TO_SQL_END -> channel(HIDDEN)
;

/*----------------------------------------------------------------------------*/
// Islands of interest on DEFAULT_CHANNEL
/*----------------------------------------------------------------------------*/

CALL:
    'call' {isBeginOfStatement("call")}? TO_SQL_END
;

COMMIT:
    'commit' {isBeginOfStatement("commit")}? TO_SQL_END
;

// handles also functions with unquoted sql_body
CREATE_FUNCTION_POSTGRESQL:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ ('or'
    COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)? 'function' COMMENT_OR_WS+ SQL_TEXT+?
    'returns' TO_SQL_END
;

CREATE_FUNCTION:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ ('or'
    COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)?
    (('editionable' | 'noneditionable') COMMENT_OR_WS+)?
    'function' COMMENT_OR_WS+ -> pushMode(UNIT_MODE)
;

// handles also package body
CREATE_PACKAGE:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ ('or'
    COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)?
    (('editionable' | 'noneditionable') COMMENT_OR_WS+)?
    'package' COMMENT_OR_WS+ -> pushMode(CODE_BLOCK_MODE)
;

CREATE_PROCEDURE:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ ('or'
    COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)?
    (('editionable' | 'noneditionable') COMMENT_OR_WS+)?
    'procedure' COMMENT_OR_WS+ -> pushMode(UNIT_MODE)
;

CREATE_TRIGGER_POSTGRESQL:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ ('or'
    COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)?
    ('constraint' COMMENT_OR_WS+)?
    'trigger' COMMENT_OR_WS+ SQL_TEXT+?
    'execute' COMMENT_OR_WS+ ('function' | 'procedure') TO_SQL_END
;

CREATE_TRIGGER:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ ('or'
    COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)?
    (('editionable' | 'noneditionable') COMMENT_OR_WS+)?
    'trigger' COMMENT_OR_WS+ -> pushMode(DECLARE_SECTION_MODE)
;

// OracleDB and PostgreSQL type specifications
CREATE_TYPE:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ ('or'
    COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)?
    (('editionable' | 'noneditionable') COMMENT_OR_WS+)?
    'type' COMMENT_OR_WS+ ANY_EXCEPT_BODY SQL_TEXT+? SQL_END
;

CREATE_TYPE_BODY:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ ('or'
    COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)?
    (('editionable' | 'noneditionable') COMMENT_OR_WS+)?
    'type' COMMENT_OR_WS+ 'body' COMMENT_OR_WS+ -> pushMode(CODE_BLOCK_MODE)
;

DELETE:
    'delete' {isBeginOfStatement("delete")}? TO_SQL_END
;

EXPLAIN_PLAN:
    'explain' {isBeginOfStatement("explain")}? TO_SQL_END
;

INSERT:
    'insert' {isBeginOfStatement("insert")}? TO_SQL_END
;

LOCK_TABLE:
    'lock' {isBeginOfStatement("lock")}? TO_SQL_END
;

MERGE:
    'merge' {isBeginOfStatement("merge")}? TO_SQL_END
;

PLSQL_BLOCK_DECLARE:
    (LABEL COMMENT_OR_WS*)* 'declare' {isBeginOfStatement("declare")}? COMMENT_OR_WS+ -> pushMode(DECLARE_SECTION_MODE)
;

PLSQL_BLOCK_BEGIN:
    (LABEL COMMENT_OR_WS*)* 'begin' {isBeginOfStatement("begin")}? COMMENT_OR_WS+ -> pushMode(CODE_BLOCK_MODE)
;

ROLLBACK:
    'rollback' {isBeginOfStatement("rollback")}? TO_SQL_END
;

SAVEPOINT:
    'savepoint' {isBeginOfStatement("savepoint")}? TO_SQL_END
;

SET_CONSTRAINTS:
    'set' {isBeginOfStatement("set")}? COMMENT_OR_WS+ ('constraint' | 'contstraints') TO_SQL_END
;

// TODO: enforce select in parenthesis at begin of statement to to avoid identifying out-of-scope subqueries after implementing:
// - https://github.com/IslandSQL/IslandSQL/issues/35
SELECT:
    (
        'select' {isBeginOfStatement("select")}? TO_SQL_END
      | ('(' COMMENT_OR_WS*)+ 'select' TO_SQL_END
    )
;

UPDATE:
    'update' {isBeginOfStatement("update")}? COMMENT_OR_WS+ SQL_TEXT+? 'set' (COMMENT_OR_WS|'(')+ SQL_TEXT+? SQL_END
;

// part of select (OracleDB, PostgreSQL) and insert, update, delete (PostgreSQL)
WITH:
    'with' {isBeginOfStatement("with")}? COMMENT_OR_WS+ -> pushMode(WITH_CLAUSE_MODE)
;

/*----------------------------------------------------------------------------*/
// Any other token
/*----------------------------------------------------------------------------*/

ANY_OTHER: . -> channel(HIDDEN);

/*----------------------------------------------------------------------------*/
// Unit Mode (standalone function and procedure)
/*----------------------------------------------------------------------------*/

mode UNIT_MODE;

// variants ending on semicolon
UNIT_JAVA: ('is'|'as') COMMENT_OR_WS+ 'language' COMMENT_OR_WS+ 'java' COMMENT_OR_WS+ 'name' TO_SQL_END -> popMode;
UNIT_MLE: ('is'|'as') COMMENT_OR_WS+ 'mle' COMMENT_OR_WS+ ('module'|'language') TO_SQL_END -> popMode;
UNIT_C: ('is'|'as') COMMENT_OR_WS+ ('language' COMMENT_OR_WS+ 'c'|'external') TO_SQL_END -> popMode;
UNIT_PG: 'as' COMMENT_OR_WS+ STRING SQL_TEXT*? SQL_END -> popMode;
UNIT: SQL_END -> popMode;

// variants ending with a code block
UNIT_ORCL: ('is'|'as') -> more, mode(DECLARE_SECTION_MODE);

UNIT_ML_COMMENT: ML_COMMENT -> more;
UNIT_SL_COMMENT: SL_COMMENT -> more;
UNIT_WS: WS -> more;
UNIT_STRING: STRING -> more;
UNIT_ID: ID -> more;
UNIT_QUOTED_ID: QUOTED_ID -> more;
UNIT_ANY_OTHER: . -> more;

/*----------------------------------------------------------------------------*/
// Declare Section Mode
/*----------------------------------------------------------------------------*/

mode DECLARE_SECTION_MODE;

DS_COMPOUND_TRIGGER: 'compound' -> more, mode(CODE_BLOCK_MODE);
DS_UNIT_DEFINITION: UNIT_DEFINITION_START -> more, pushMode(DECLARE_SECTION_MODE);
DS_BEGIN: 'begin' COMMENT_OR_WS+ -> more, mode(CODE_BLOCK_MODE);

DS_ML_COMMENT: ML_COMMENT -> more;
DS_SL_COMMENT: SL_COMMENT -> more;
DS_WS: WS -> more;
DS_STRING: STRING -> more;
DS_ID: ID -> more;
DS_QUOTED_ID: QUOTED_ID -> more;
DS_ANY_OTHER: . -> more;

/*----------------------------------------------------------------------------*/
// With Clause Mode
/*----------------------------------------------------------------------------*/

mode WITH_CLAUSE_MODE;

WC: SQL_END -> popMode;

WC_UNIT_DEFINITION: UNIT_DEFINITION_START -> more, pushMode(DECLARE_SECTION_MODE);
WC_UNIT_BEGIN: 'begin' COMMENT_OR_WS+ -> more, pushMode(CODE_BLOCK_MODE);

WC_ML_COMMENT: ML_COMMENT -> more;
WC_SL_COMMENT: SL_COMMENT -> more;
WC_WS: WS -> more;
WC_STRING: STRING -> more;
WC_ID: ID -> more;
WC_QUOTED_ID: QUOTED_ID -> more;
WC_ANY_OTHER: . -> more;

/*----------------------------------------------------------------------------*/
// PL/SQL and PL/pgsql Code Block Mode
/*----------------------------------------------------------------------------*/

mode CODE_BLOCK_MODE;

CB_LOOP: 'end' COMMENT_OR_WS+ 'loop' (COMMENT_OR_WS+ NAME)? COMMENT_OR_WS* ';' -> popMode;
CB_CASE_STMT: 'end' COMMENT_OR_WS+ 'case' (COMMENT_OR_WS+ NAME)? COMMENT_OR_WS* ';' -> popMode;
CB_COMPOUND_TRIGGER:
    (
          'end' COMMENT_OR_WS+ ('before'|'after') COMMENT_OR_WS+ 'statement' COMMENT_OR_WS* ';'
        | 'end' COMMENT_OR_WS+ ('before'|'after') COMMENT_OR_WS+ 'each' COMMENT_OR_WS+ 'row' COMMENT_OR_WS* ';'
        | 'end' COMMENT_OR_WS+ 'instead' COMMENT_OR_WS+ 'of' COMMENT_OR_WS+ 'each' COMMENT_OR_WS+ 'row' COMMENT_OR_WS* ';'
    ) -> popMode;
CB_STMT: 'end' (COMMENT_OR_WS+ NAME)? COMMENT_OR_WS* ';' -> popMode;
CB_EXPR: 'end' (COMMENT_OR_WS+ NAME)? -> popMode; // including PostgreSQL atomic block

CB_SELECTION_DIRECTIVE_START: '$if' -> more, pushMode(CONDITIONAL_COMPILATION_MODE);

// handle everything that has end keyword as nested code block
CB_BEGIN_START: 'begin' -> more, pushMode(CODE_BLOCK_MODE);
CB_LOOP_START: 'loop' -> more, pushMode(CODE_BLOCK_MODE);
CB_IF_START: 'if' -> more, pushMode(CODE_BLOCK_MODE);
CB_CASE_START: 'case' -> more, pushMode(CODE_BLOCK_MODE);

CB_POSITION_FROM_END: 'position' COMMENT_OR_WS+ 'from' COMMENT_OR_WS+ 'end' -> more; // lead_lag_clause, av_level_ref
CB_ML_COMMENT: ML_COMMENT -> more;
CB_SL_COMMENT: SL_COMMENT -> more;
CB_WS: WS -> more;
CB_STRING: STRING -> more;
CB_ID: ID -> more;
CB_QUOTED_ID: QUOTED_ID -> more;
CB_ANY_OTHER: . -> more;

/*----------------------------------------------------------------------------*/
// Conditional Compilation Directive Mode
/*----------------------------------------------------------------------------*/

mode CONDITIONAL_COMPILATION_MODE;

// always part of CB
CC: '$end' -> more, popMode;

// error directive has an $end keyword, treat as a nested conditional compilation directive
CC_ERROR_START: '$error' -> more, pushMode(CONDITIONAL_COMPILATION_MODE);

CC_WS: WS -> more;
CC_ID: ID -> more;
CC_QUOTED_ID: QUOTED_ID -> more;
CC_ANY_OTHER: . -> more;
