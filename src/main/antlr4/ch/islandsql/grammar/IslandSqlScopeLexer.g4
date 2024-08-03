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
fragment SQL_TEXT: COMMENT_OR_WS|STRING|NAME|~[;\\];
fragment HSPACE: [ \t]+;
fragment SLASH_END: '/' {isBeginOfCommand("/")}? HSPACE? (EOF|SINGLE_NL);
fragment NAME: ID|QUOTED_ID;
fragment LABEL: '<<' WS? NAME WS? '>>';
fragment PSQL_EXEC: (WS|ML_COMMENT)* '\\g' ~[\n]* SINGLE_NL?;
fragment OR_REPLACE: ('or' COMMENT_OR_WS+ 'replace' COMMENT_OR_WS+)?;
fragment NON_EDITIONABLE: (('editionable' | 'noneditionable') COMMENT_OR_WS+)?;
fragment TO_SQLPLUS_END: ((HSPACE|CONTINUE_LINE) SQLPLUS_TEXT*)? SQLPLUS_END;
fragment MORE_TO_SQL_END: COMMENT_OR_WS+ SQL_TEXT+? SQL_END;
fragment TO_SQL_END: (COMMENT_OR_WS+ SQL_TEXT*?)? SQL_END;
fragment SQL_END:
      EOF
    | '\\'? ';' HSPACE? SINGLE_NL?
    | SLASH_END
    | PSQL_EXEC
;
fragment CONTINUE_LINE: '-' HSPACE? SINGLE_NL?;
fragment SQLPLUS_TEXT: (~[\r\n]|CONTINUE_LINE);
fragment SQLPLUS_END: EOF|SINGLE_NL;
fragment IN_AND_NESTED_COMMENT: ('/'*? ML_COMMENT | ('/'* | '*'*) ~[/*])*? '*'*?;
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
          'e' (['] ('\\'? .)*? ['])+ (COMMENT_OR_WS* ['] ('\\'? .)*? ['])*  // PostgreSQL string constant with C-style escapes
        | 'b' ['] ~[']* [']                                     // PostgreSQL bit-string constant
        | 'u&' ['] ~[']* [']                                    // PostgreSQL string constant with unicode escapes
        | '$$' .*? '$$' {!isInquiryDirective()}?                // PostgreSQL dollar-quoted string constant
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

ML_COMMENT: '/*' IN_AND_NESTED_COMMENT '*/' -> channel(HIDDEN);
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
        'key' COMMENT_OR_WS+ 'management' MORE_TO_SQL_END -> channel(HIDDEN)
;

// hide keyword: select, insert, update, delete
ALTER_AUDIT_POLICY:
    'alter' {isBeginOfStatement("alter")}? COMMENT_OR_WS+
        'audit' COMMENT_OR_WS+ 'policy' MORE_TO_SQL_END -> channel(HIDDEN)
;

// hide keyword: merge
ALTER_TABLE:
    'alter' {isBeginOfStatement("alter")}? COMMENT_OR_WS+
        'table' MORE_TO_SQL_END -> channel(HIDDEN)
;

// hide keyword: begin
ALTER_TABLESPACE:
    'alter' {isBeginOfStatement("alter")}? COMMENT_OR_WS+
        'tablespace' MORE_TO_SQL_END -> channel(HIDDEN)
;

// hide keywords: select, insert, update, delete
CREATE_AUDIT_POLICY:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+
        'audit' COMMENT_OR_WS+ 'policy' MORE_TO_SQL_END -> channel(HIDDEN)
;

// hide keywords: with
CREATE_CAST:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+
        'cast' MORE_TO_SQL_END -> channel(HIDDEN)
;

// hide keywords: with
CREATE_DATABASE:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+
        'database' MORE_TO_SQL_END -> channel(HIDDEN)
;

// hide keywords: with
CREATE_INDEX:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ (('unique'|'bitmap'|'multivalue') COMMENT_OR_WS+)?
        'index' MORE_TO_SQL_END -> channel(HIDDEN)
;

// hide keyword: with
CREATE_MATERIALIZED_VIEW_LOG:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ 'materialized'
        COMMENT_OR_WS+ 'view' COMMENT_OR_WS+ 'log' MORE_TO_SQL_END -> channel(HIDDEN)
;

// hide statements and keywords after "as" (e.g. JavaScript code)
CREATE_MLE_MODULE:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ OR_REPLACE 'mle' COMMENT_OR_WS+
        'module' COMMENT_OR_WS+ .+? SLASH_END -> channel(HIDDEN)
;

// hide keyword: with
CREATE_OPERATOR:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ OR_REPLACE
        'operator' MORE_TO_SQL_END -> channel(HIDDEN)
;

// hide keywords: select, insert, update, delete (hides first command only)
CREATE_RULE:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ OR_REPLACE
        'rule' MORE_TO_SQL_END -> channel(HIDDEN)
;

// hide keywords: select, insert, update, delete
CREATE_SCHEMA:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ 'schema'
        MORE_TO_SQL_END -> channel(HIDDEN)
;

// hide keyword: with
CREATE_USER:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ 'user'
        MORE_TO_SQL_END -> channel(HIDDEN)
;

// hide keywords: select, insert, update, delete
GRANT:
    'grant' {isBeginOfStatement("grant")}? MORE_TO_SQL_END -> channel(HIDDEN)
;

// hide keywords: select, insert, update, delete
REVOKE:
    'revoke' {isBeginOfStatement("revoke")}? MORE_TO_SQL_END -> channel(HIDDEN)
;

/*----------------------------------------------------------------------------*/
// Islands of interest on DEFAULT_CHANNEL
/*----------------------------------------------------------------------------*/

BEGIN:
    'begin' {isBeginOfStatement("begin")}?
    (
          COMMENT_OR_WS* SQL_END
        | COMMENT_OR_WS+ ('work'|'transaction') TO_SQL_END
        | COMMENT_OR_WS+ ('isolation'|'read'|'not'|'deferrable') TO_SQL_END
    )
;

CALL:
    'call' {isBeginOfStatement("call")}? MORE_TO_SQL_END
;

COMMIT:
    'commit' {isBeginOfStatement("commit")}? TO_SQL_END
;

CREATE_FUNCTION:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ OR_REPLACE NON_EDITIONABLE
    'function' COMMENT_OR_WS+ -> pushMode(UNIT_MODE)
;

CREATE_JSON_RELATIONAL_DUALITY_VIEW:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ OR_REPLACE
    (('no' COMMENT_OR_WS+)? 'force' COMMENT_OR_WS+)? NON_EDITIONABLE
    'json' COMMENT_OR_WS+ ('relational' COMMENT_OR_WS+)?
    'duality' COMMENT_OR_WS+ 'view' COMMENT_OR_WS+ -> pushMode(WITH_CLAUSE_MODE)
;

CREATE_MATERIALIZED_VIEW:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+
    'materialized' COMMENT_OR_WS+ 'view' COMMENT_OR_WS+
    ANY_EXCEPT_LOG -> pushMode(WITH_CLAUSE_MODE)
;

// handles also package body
CREATE_PACKAGE:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ OR_REPLACE NON_EDITIONABLE
    'package' COMMENT_OR_WS+ -> pushMode(PACKAGE_MODE)
;

CREATE_PROCEDURE:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ OR_REPLACE NON_EDITIONABLE
    'procedure' COMMENT_OR_WS+ -> pushMode(UNIT_MODE)
;

CREATE_TABLE:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+
    (
          'global' COMMENT_OR_WS+ ('temp' 'orary'?) COMMENT_OR_WS+
        | ('private'|'local') COMMENT_OR_WS+ ('temp' 'orary'?) COMMENT_OR_WS+
        | ('temp' 'orary'?) COMMENT_OR_WS+
        | 'unlogged' COMMENT_OR_WS+
        | 'sharded' COMMENT_OR_WS+
        | 'duplicated' COMMENT_OR_WS+
        | ('immutable' COMMENT_OR_WS+)? 'blockchain' COMMENT_OR_WS+
        | 'immutable' COMMENT_OR_WS+
    )?
    'table' COMMENT_OR_WS+ -> pushMode(WITH_CLAUSE_MODE)
;

CREATE_TRIGGER_POSTGRESQL:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ OR_REPLACE
    ('constraint' COMMENT_OR_WS+)?
    'trigger' COMMENT_OR_WS+ SQL_TEXT+?
    'execute' COMMENT_OR_WS+ ('function' | 'procedure') MORE_TO_SQL_END
;

CREATE_TRIGGER:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ OR_REPLACE NON_EDITIONABLE
    'trigger' COMMENT_OR_WS+ -> pushMode(DECLARE_SECTION_MODE)
;

// OracleDB and PostgreSQL type specifications
CREATE_TYPE:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ OR_REPLACE NON_EDITIONABLE
    'type' COMMENT_OR_WS+ ANY_EXCEPT_BODY SQL_TEXT+? SQL_END
;

CREATE_TYPE_BODY:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ OR_REPLACE NON_EDITIONABLE
    'type' COMMENT_OR_WS+ 'body' COMMENT_OR_WS+ -> pushMode(CODE_BLOCK_MODE)
;

CREATE_VIEW:
    'create' {isBeginOfStatement("create")}? COMMENT_OR_WS+ OR_REPLACE
    (
         (('temp' 'orary'?) COMMENT_OR_WS+)? ('recursive' COMMENT_OR_WS+)?
       | (('no' COMMENT_OR_WS+)? 'force' COMMENT_OR_WS+)?
             (
                 (
                       'editioning'
                     | 'editionable'
                     | ('editionable' COMMENT_OR_WS+ 'editioning')
                     | 'noneditionable'
                 ) COMMENT_OR_WS+
             )?
    )
    'view' COMMENT_OR_WS+ -> pushMode(WITH_CLAUSE_MODE)
;

DECLARE:
    'declare' {isBeginOfStatement("declare") && getDialect() != IslandSqlDialect.ORACLEDB}? COMMENT_OR_WS+ NAME COMMENT_OR_WS+
    ('binary' COMMENT_OR_WS+)?
    (('asensitive' | 'insensitive') COMMENT_OR_WS+)?
    (('no' COMMENT_OR_WS+)? 'scroll' COMMENT_OR_WS+)?
    'cursor' COMMENT_OR_WS+
    (('with' | 'without') COMMENT_OR_WS+ 'hold' COMMENT_OR_WS+)?
    'for' MORE_TO_SQL_END
;

DELETE:
    'delete' {isBeginOfStatement("delete")}? MORE_TO_SQL_END
;

DO:
    'do' {isBeginOfStatement("do")}? MORE_TO_SQL_END
;

EXPLAIN_PLAN:
    'explain' {isBeginOfStatement("explain")}? MORE_TO_SQL_END
;

INSERT:
    'insert' {isBeginOfStatement("insert")}? MORE_TO_SQL_END
;

LOCK_TABLE:
    'lock' {isBeginOfStatement("lock")}? MORE_TO_SQL_END
;

MERGE:
    'merge' {isBeginOfStatement("merge")}? MORE_TO_SQL_END
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
    'savepoint' {isBeginOfStatement("savepoint")}? MORE_TO_SQL_END
;

SET_CONSTRAINTS:
    'set' {isBeginOfStatement("set")}? COMMENT_OR_WS+ 'constraint' 's'? MORE_TO_SQL_END
;

SET_TRANSACTION:
    'set' {isBeginOfStatement("set")}? COMMENT_OR_WS+ 'transaction' MORE_TO_SQL_END
;

SELECT:
    (
        'select' {isBeginOfStatement("select")}? MORE_TO_SQL_END
      | '(' {isBeginOfStatement("(")}? COMMENT_OR_WS* ('(' COMMENT_OR_WS*)* 'select' MORE_TO_SQL_END
    )
;

UPDATE:
    'update' {isBeginOfStatement("update")}? COMMENT_OR_WS+ SQL_TEXT+? COMMENT_OR_WS+ 'set' (COMMENT_OR_WS|'(')+ SQL_TEXT+? SQL_END
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
// Unit Mode for standalone function and procedure (UNIT)
/*----------------------------------------------------------------------------*/

mode UNIT_MODE;

// fail-safe, process tokens that are waiting to be assigned after "more"
UNIT_EOF: EOF -> popMode;

// variants ending on semicolon
UNIT_JAVA: ('is'|'as') COMMENT_OR_WS+ 'language' COMMENT_OR_WS+ 'java' COMMENT_OR_WS+ 'name' MORE_TO_SQL_END -> popMode;
UNIT_MLE: ('is'|'as') COMMENT_OR_WS+ 'mle' COMMENT_OR_WS+ ('module'|'language') MORE_TO_SQL_END -> popMode;
UNIT_C: ('is'|'as') COMMENT_OR_WS+ ('language' COMMENT_OR_WS+ 'c'|'external') MORE_TO_SQL_END -> popMode;
UNIT_PG: 'as' COMMENT_OR_WS+ ':'? STRING SQL_TEXT*? SQL_END -> popMode;
UNIT: SQL_END -> popMode;

// variants ending with a code block
UNIT_ORCL: ('is'|'as') -> more, mode(DECLARE_SECTION_MODE);
UNIT_PG_BLOCK: 'begin' COMMENT_OR_WS+ 'atomic' -> more, mode(CODE_BLOCK_MODE);

UNIT_ML_COMMENT: ML_COMMENT -> more;
UNIT_SL_COMMENT: SL_COMMENT -> more;
UNIT_WS: WS -> more;
UNIT_STRING: STRING -> more;
UNIT_ID: ID -> more;
UNIT_QUOTED_ID: QUOTED_ID -> more;
UNIT_ANY_OTHER: . -> more;

/*----------------------------------------------------------------------------*/
// Declare Section Mode (DS)
/*----------------------------------------------------------------------------*/

mode DECLARE_SECTION_MODE;

// fail-safe, process tokens that are waiting to be assigned after "more"
DS_EOF: EOF -> popMode;

DS_COMPOUND_TRIGGER: 'compound' -> more, mode(CODE_BLOCK_MODE);
DS_FUNCTION: 'function' -> more, pushMode(UNIT_MODE);
DS_PROCEDURE: 'procedure' -> more, pushMode(UNIT_MODE);
DS_BEGIN: 'begin' COMMENT_OR_WS+ -> more, mode(CODE_BLOCK_MODE);

DS_ML_COMMENT: ML_COMMENT -> more;
DS_SL_COMMENT: SL_COMMENT -> more;
DS_WS: WS -> more;
DS_STRING: STRING -> more;
DS_ID: ID -> more;
DS_QUOTED_ID: QUOTED_ID -> more;
DS_ANY_OTHER: . -> more;

/*----------------------------------------------------------------------------*/
// With Clause Mode (WC)
/*----------------------------------------------------------------------------*/

mode WITH_CLAUSE_MODE;

// fail-safe, process tokens that are waiting to be assigned after "more"
WC_EOF: EOF -> popMode;

WC: SQL_END -> popMode;

WC_FUNCTION: 'function' -> more, pushMode(UNIT_MODE);
WC_PROCEDURE: 'procedure' -> more, pushMode(UNIT_MODE);

WC_ML_COMMENT: ML_COMMENT -> more;
WC_SL_COMMENT: SL_COMMENT -> more;
WC_WS: WS -> more;
WC_STRING: STRING -> more;
WC_ID: ID -> more;
WC_QUOTED_ID: QUOTED_ID -> more;
WC_ANY_OTHER: . -> more;

/*----------------------------------------------------------------------------*/
// PL/SQL Package Mode (PKG)
/*----------------------------------------------------------------------------*/

mode PACKAGE_MODE;

// fail-safe, process tokens that are waiting to be assigned after "more"
PKG_EOF: EOF -> popMode;

PKG_STMT: 'end' (COMMENT_OR_WS+ NAME)? COMMENT_OR_WS* ';' -> popMode;

PKG_SELECTION_DIRECTIVE_START: '$if' -> more, pushMode(CONDITIONAL_COMPILATION_MODE);
PKG_FUNCTION: 'function' -> more, pushMode(UNIT_MODE);
PKG_PROCEDURE: 'procedure' -> more, pushMode(UNIT_MODE);
PKG_INITIALIZE_SECTION_START: 'begin' -> more, mode(CODE_BLOCK_MODE);

PKG_ML_COMMENT: ML_COMMENT -> more;
PKG_SL_COMMENT: SL_COMMENT -> more;
PKG_WS: WS -> more;
PKG_STRING: STRING -> more;
PKG_ID: ID -> more;
PKG_QUOTED_ID: QUOTED_ID -> more;
PKG_ANY_OTHER: . -> more;

/*----------------------------------------------------------------------------*/
// PL/SQL Code Block Mode (CB)
/*----------------------------------------------------------------------------*/

mode CODE_BLOCK_MODE;

// fail-safe, process tokens that are waiting to be assigned after "more"
CB_EOF: EOF -> popMode;

// detects end of code block when initialize section is used in a package body
CB_SLASH: SLASH_END -> popMode;

CB_LOOP: 'end' COMMENT_OR_WS+ 'loop' (COMMENT_OR_WS+ NAME)? COMMENT_OR_WS* ';' -> popMode;
CB_CASE_STMT: 'end' COMMENT_OR_WS+ 'case' (COMMENT_OR_WS+ NAME)? COMMENT_OR_WS* ';' -> popMode;
CB_COMPOUND_TRIGGER:
    (
          'end' COMMENT_OR_WS+ ('before'|'after') COMMENT_OR_WS+ 'statement' COMMENT_OR_WS* ';'
        | 'end' COMMENT_OR_WS+ ('before'|'after') COMMENT_OR_WS+ 'each' COMMENT_OR_WS+ 'row' COMMENT_OR_WS* ';'
        | 'end' COMMENT_OR_WS+ 'instead' COMMENT_OR_WS+ 'of' COMMENT_OR_WS+ 'each' COMMENT_OR_WS+ 'row' COMMENT_OR_WS* ';'
    ) -> popMode;
CB_STMT: 'end' (COMMENT_OR_WS+ NAME)? COMMENT_OR_WS* ';' -> popMode;
// stay in current mode when 'end' seems to be an identifier
CB_CASE_EXPR: 'end' {_modeStack.size() > 2}? -> popMode;

CB_SELECTION_DIRECTIVE_START: '$if' -> more, pushMode(CONDITIONAL_COMPILATION_MODE);

// handle everything that has end keyword as nested code block
CB_FUNCTION: 'function' -> more, pushMode(UNIT_MODE);
CB_PROCEDURE: 'procedure' -> more, pushMode(UNIT_MODE);
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
// Conditional Compilation Directive Mode (CC)
/*----------------------------------------------------------------------------*/

mode CONDITIONAL_COMPILATION_MODE;

// fail-safe, process tokens that are waiting to be assigned after "more"
CC_EOF: EOF -> popMode;

// always part of CB
CC: '$end' -> more, popMode;

// error directive has an $end keyword, treat as a nested conditional compilation directive
CC_ERROR_START: '$error' -> more, pushMode(CONDITIONAL_COMPILATION_MODE);

CC_WS: WS -> more;
CC_ID: ID -> more;
CC_QUOTED_ID: QUOTED_ID -> more;
CC_ANY_OTHER: . -> more;
