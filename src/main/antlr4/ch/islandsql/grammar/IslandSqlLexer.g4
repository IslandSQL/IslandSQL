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
fragment CONTINUE_LINE: '-' [ \t]* SINGLE_NL;
fragment SQLPLUS_TEXT: (~[\r\n]|CONTINUE_LINE);
fragment SQLPLUS_END: EOF|SINGLE_NL;
fragment INT: [0-9]+ (LOWBAR [0-9]+)*; // PostgreSQL allows underscores for visual grouping

/*----------------------------------------------------------------------------*/
// Whitespace, comments and hints
/*----------------------------------------------------------------------------*/

WS: [ \t\r\n]+ -> channel(HIDDEN);
ML_HINT: '/*+' .*? '*/' -> channel(HIDDEN);
ML_COMMENT: '/*' .*? '*/' -> channel(HIDDEN);
SL_HINT: '--+' ~[\r\n]* -> channel(HIDDEN);
SL_COMMENT: '--' ~[\r\n]* -> channel(HIDDEN);

/*----------------------------------------------------------------------------*/
// SQL*Plus commands (similar to comments)
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
// Conditional compilation directives (to be ignored by the parser)
/*----------------------------------------------------------------------------*/

CONDITIONAL_COMPILATION_DIRECTIVE: '$if' .*? '$end' -> channel(HIDDEN);

/*----------------------------------------------------------------------------*/
// Keywords
/*----------------------------------------------------------------------------*/

K_A: 'a';
K_ABS: 'abs';
K_ABSENT: 'absent';
K_ACCESS: 'access';
K_ACROSS: 'across';
K_ADD: 'add';
K_AFTER: 'after';
K_AGGREGATE: 'aggregate';
K_ALL: 'all';
K_ALLOW: 'allow';
K_ANALYTIC: 'analytic';
K_ANCESTOR: 'ancestor';
K_AND: 'and';
K_ANY: 'any';
K_APPEND: 'append';
K_APPLY: 'apply';
K_ARRAY: 'array';
K_AS: 'as';
K_ASC: 'asc';
K_ASCII: 'ascii';
K_AT: 'at';
K_AUTO: 'auto';
K_AUTOMATIC: 'automatic';
K_AVERAGE_RANK: 'average_rank';
K_BADFILE: 'badfile';
K_BEGINNING: 'beginning';
K_BETWEEN: 'between';
K_BFILE: 'bfile';
K_BIGINT: 'bigint';
K_BIGRAM: 'bigram';
K_BIGSERIAL: 'bigserial';
K_BINARY_DOUBLE: 'binary_double';
K_BINARY_FLOAT: 'binary_float';
K_BIT: 'bit';
K_BLOB: 'blob';
K_BLOCK: 'block';
K_BOOL: 'bool';
K_BOOLEAN: 'boolean';
K_BOTH: 'both';
K_BOX: 'box';
K_BREADTH: 'breadth';
K_BULK: 'bulk';
K_BY: 'by';
K_BYTE: 'byte';
K_BYTEA: 'bytea';
K_CALL: 'call';
K_CASE: 'case';
K_CASE_SENSITIVE: ('case_sensitive'|'case-sensitive'); // original implementation was based on kebab-case, see https://mobile.twitter.com/phsalvisberg/status/1351990195109974018
K_CAST: 'cast';
K_CHAR: 'char';
K_CHARACTER: 'character';
K_CHAR_CS: 'char_cs';
K_CHECK: 'check';
K_CIDR: 'cidr';
K_CIRCLE: 'circle';
K_CLOB: 'clob';
K_COLLATE: 'collate';
K_COLLECT: 'collect';
K_COLUMNS: 'columns';
K_CONDITIONAL: 'conditional';
K_CONNECT: 'connect';
K_CONNECT_BY_ROOT: 'connect_by_root';
K_CONSTRAINT: 'constraint';
K_CONTAINERS_DEFAULT: 'containers_default';
K_CONTAINER_MAP: 'container_map';
K_CONTENT: 'content';
K_CONVERSION: 'conversion';
K_COPY: 'copy';
K_COST: 'cost';
K_COUNT: 'count';
K_CREATE: 'create';
K_CROSS: 'cross';
K_CURRENT: 'current';
K_CURSOR: 'cursor';
K_CYCLE: 'cycle';
K_DAMERAU_LEVENSHTEIN: 'damerau_levenshtein';
K_DANGLING: 'dangling';
K_DATA: 'data';
K_DATE: 'date';
K_DAY: 'day';
K_DBTIMEZONE: 'dbtimezone';
K_DEC: 'dec';
K_DECIMAL: 'decimal';
K_DECREMENT: 'decrement';
K_DEFAULT: 'default';
K_DEFAULTS: 'defaults';
K_DEFINE: 'define';
K_DELETE: 'delete';
K_DENSE_RANK: 'dense_rank';
K_DEPTH: 'depth';
K_DESC: 'desc';
K_DETERMINISTIC: 'deterministic';
K_DIMENSION: 'dimension';
K_DIRECTORY: 'directory';
K_DISALLOW: 'disallow';
K_DISCARD: 'discard';
K_DISTINCT: 'distinct';
K_DOCUMENT: 'document';
K_DOMAIN: 'domain';
K_DOUBLE: 'double';
K_EDIT_TOLERANCE: 'edit_tolerance';
K_ELSE: 'else';
K_EMPTY: 'empty';
K_ENCODING: 'encoding';
K_END: 'end';
K_ENTITYESCAPING: 'entityescaping';
K_ERROR: 'error';
K_ERRORS: 'errors';
K_ESCAPE: 'escape';
K_EVALNAME: 'evalname';
K_EXCEPT: 'except';
K_EXCLUDE: 'exclude';
K_EXCLUSIVE: 'exclusive';
K_EXISTING: 'existing';
K_EXISTS: 'exists';
K_EXPLAIN: 'explain';
K_EXTERNAL: 'external';
K_EXTRA: 'extra';
K_EXTRACT: 'extract';
K_FACT: 'fact';
K_FALSE: 'false';
K_FEATURE_COMPARE: 'feature_compare';
K_FETCH: 'fetch';
K_FILTER: 'filter';
K_FINAL: 'final';
K_FIRST: 'first';
K_FLOAT8: 'float8';
K_FLOAT: 'float';
K_FOLLOWING: 'following';
K_FOR: 'for';
K_FORMAT: 'format';
K_FROM: 'from';
K_FULL: 'full';
K_FUNCTION: 'function';
K_FUZZY_MATCH: 'fuzzy_match';
K_GRAPH_TABLE: 'graph_table';
K_GROUP: 'group';
K_GROUPING: 'grouping';
K_GROUPS: 'groups';
K_HAVING: 'having';
K_HIDE: 'hide';
K_HIERARCHIES: 'hierarchies';
K_HIERARCHY: 'hierarchy';
K_HIER_ANCESTOR: 'hier_ancestor';
K_HIER_CAPTION: 'hier_caption';
K_HIER_CHILD_COUNT: 'hier_child_count';
K_HIER_DEPTH: 'hier_depth';
K_HIER_DESCRIPTION: 'hier_description';
K_HIER_LAG: 'hier_lag';
K_HIER_LEAD: 'hier_lead';
K_HIER_LEVEL: 'hier_level';
K_HIER_MEMBER_NAME: 'hier_member_name';
K_HIER_MEMBER_UNIQUE_NAME: 'hier_member_unique_name';
K_HIER_PARENT: 'hier_parent';
K_HIER_PARENT_LEVEL: 'hier_parent_level';
K_HIER_PARENT_UNIQUE_NAME: 'hier_parent_unique_name';
K_HOUR: 'hour';
K_IGNORE: 'ignore';
K_IN: 'in';
K_INCLUDE: 'include';
K_INCREMENT: 'increment';
K_INDENT: 'indent';
K_INDICATOR: 'indicator';
K_INET: 'inet';
K_INFINITE: 'infinite';
K_INNER: 'inner';
K_INSERT: 'insert';
K_INT4: 'int4';
K_INT8: 'int8';
K_INT: 'int';
K_INTEGER: 'integer';
K_INTERSECT: 'intersect';
K_INTERVAL: 'interval';
K_INTO: 'into';
K_INVISIBLE: 'invisible';
K_IS: 'is';
K_ITERATE: 'iterate';
K_JARO_WINKLER: 'jaro_winkler';
K_JOIN: 'join';
K_JSON: 'json';
K_JSONB: 'jsonb';
K_JSON_ARRAY: 'json_array';
K_JSON_ARRAYAGG: 'json_arrayagg';
K_JSON_EQUAL: 'json_equal';
K_JSON_EXISTS: 'json_exists';
K_JSON_MERGEPATCH: 'json_mergepatch';
K_JSON_OBJECT: 'json_object';
K_JSON_OBJECTAGG: 'json_objectagg';
K_JSON_QUERY: 'json_query';
K_JSON_SCALAR: 'json_scalar';
K_JSON_SERIALIZE: 'json_serialize';
K_JSON_TABLE: 'json_table';
K_JSON_TRANSFORM: 'json_transform';
K_JSON_VALUE: 'json_value';
K_KEEP: 'keep';
K_KEY: 'key';
K_KEYS: 'keys';
K_LAG: 'lag';
K_LAG_DIFF: 'lag_diff';
K_LAG_DIFF_PERCENT: 'lag_diff_percent';
K_LAST: 'last';
K_LATERAL: 'lateral';
K_LAX: 'lax';
K_LEAD: 'lead';
K_LEADING: 'leading';
K_LEAD_DIFF: 'lead_diff';
K_LEAD_DIFF_PERCENT: 'lead_diff_percent';
K_LEFT: 'left';
K_LEVEL: 'level';
K_LEVENSHTEIN: 'levenshtein';
K_LIKE2: 'like2';
K_LIKE4: 'like4';
K_LIKE: 'like';
K_LIKEC: 'likec';
K_LIMIT: 'limit';
K_LINE: 'line';
K_LISTAGG: 'listagg';
K_LOCAL: 'local';
K_LOCATION: 'location';
K_LOCK: 'lock';
K_LOCKED: 'locked';
K_LOG: 'log';
K_LOGFILE: 'logfile';
K_LONG: 'long';
K_LONGEST_COMMON_SUBSTRING: 'longest_common_substring';
K_LSEG: 'lseg';
K_MACADDR8: 'macaddr8';
K_MACADDR: 'macaddr';
K_MAIN: 'main';
K_MAPPING: 'mapping';
K_MATCH: 'match';
K_MATCHED: 'matched';
K_MATCHES: 'matches';
K_MATCH_RECOGNIZE: 'match_recognize';
K_MEASURES: 'measures';
K_MEMBER: 'member';
K_MERGE: 'merge';
K_MINUS: 'minus';
K_MINUTE: 'minute';
K_MISMATCH: 'mismatch';
K_MISSING: 'missing';
K_MODE: 'mode';
K_MODEL: 'model';
K_MODIFY: 'modify';
K_MONEY: 'money';
K_MONTH: 'month';
K_MULTISET: 'multiset';
K_NAME: 'name';
K_NAN: 'nan';
K_NATIONAL: 'national';
K_NATURAL: 'natural';
K_NAV: 'nav';
K_NCHAR: 'nchar';
K_NCHAR_CS: 'nchar_cs';
K_NCLOB: 'nclob';
K_NESTED: 'nested';
K_NEW: 'new';
K_NEXT: 'next';
K_NO: 'no';
K_NOCYCLE: 'nocycle';
K_NOENTITYESCAPING: 'noentityescaping';
K_NOSCHEMACHECK: 'noschemacheck';
K_NOT: 'not';
K_NOWAIT: 'nowait';
K_NTH_VALUE: 'nth_value';
K_NULL: 'null';
K_NULLS: 'nulls';
K_NUMBER: 'number';
K_NUMERIC: 'numeric';
K_NVARCHAR2: 'nvarchar2';
K_OBJECT: 'object';
K_OF: 'of';
K_OFFSET: 'offset';
K_OLD: 'old';
K_OMIT: 'omit';
K_ON: 'on';
K_ONE: 'one';
K_ONLY: 'only';
K_OPTION: 'option';
K_OR: 'or';
K_ORDER: 'order';
K_ORDERED: 'ordered';
K_ORDINALITY: 'ordinality';
K_OTHERS: 'others';
K_OUTER: 'outer';
K_OVER: 'over';
K_OVERFLOW: 'overflow';
K_PARAMETERS: 'parameters';
K_PARENT: 'parent';
K_PARTITION: 'partition';
K_PASSING: 'passing';
K_PAST: 'past';
K_PATH: 'path';
K_PATTERN: 'pattern';
K_PER: 'per';
K_PERCENT: 'percent';
K_PERIOD: 'period';
K_PERMUTE: 'permute';
K_PG_LSN: 'pg_lsn';
K_PG_SNAPSHOT: 'pg_snapshot';
K_PIVOT: 'pivot';
K_PLAN: 'plan';
K_POINT: 'point';
K_POSITION: 'position';
K_PRECEDING: 'preceding';
K_PRECISION: 'precision';
K_PREDICTION: 'prediction';
K_PREDICTION_COST: 'prediction_cost';
K_PREDICTION_DETAILS: 'prediction_details';
K_PREPEND: 'prepend';
K_PRESENT: 'present';
K_PRESERVE: 'preserve';
K_PRETTY: 'pretty';
K_PRIOR: 'prior';
K_PROCEDURE: 'procedure';
K_QUALIFY: 'qualify';
K_RANGE: 'range';
K_RANK: 'rank';
K_RAW: 'raw';
K_READ: 'read';
K_REAL: 'real';
K_REF: 'ref';
K_REFERENCE: 'reference';
K_REJECT: 'reject';
K_RELATE_TO_SHORTER: 'relate_to_shorter';
K_REMOVE: 'remove';
K_RENAME: 'rename';
K_REPLACE: 'replace';
K_RESERVABLE: 'reservable';
K_RESPECT: 'respect';
K_RETURN: 'return';
K_RETURNING: 'returning';
K_RIGHT: 'right';
K_ROW: 'row';
K_ROWID: 'rowid';
K_ROWS: 'rows';
K_ROW_NUMBER: 'row_number';
K_RULES: 'rules';
K_RUNNING: 'running';
K_SAMPLE: 'sample';
K_SCALARS: 'scalars';
K_SCHEMACHECK: 'schemacheck';
K_SCN: 'scn';
K_SDO_GEOMETRY: 'sdo_geometry';
K_SEARCH: 'search';
K_SECOND: 'second';
K_SEED: 'seed';
K_SELECT: 'select';
K_SEQUENCE: 'sequence';
K_SEQUENTIAL: 'sequential';
K_SERIAL8: 'serial8';
K_SESSIONTIMEZONE: 'sessiontimezone';
K_SET: 'set';
K_SETS: 'sets';
K_SHARE: 'share';
K_SHARE_OF: 'share_of';
K_SHOW: 'show';
K_SIBLINGS: 'siblings';
K_SINGLE: 'single';
K_SIZE: 'size';
K_SKIP: 'skip';
K_SMALLINT: 'smallint';
K_SOME: 'some';
K_SORT: 'sort';
K_SQL: 'sql';
K_STANDALONE: 'standalone';
K_START: 'start';
K_STATEMENT_ID: 'statement_id';
K_STRICT: 'strict';
K_SUBMULTISET: 'submultiset';
K_SUBPARTITION: 'subpartition';
K_SUBSET: 'subset';
K_TABLE: 'table';
K_THE: 'the';
K_THEN: 'then';
K_TIES: 'ties';
K_TIME: 'time';
K_TIMESTAMP: 'timestamp';
K_TIMEZONE: 'timezone';
K_TO: 'to';
K_TRAILING: 'trailing';
K_TREAT: 'treat';
K_TRIGRAM: 'trigram';
K_TRIM: 'trim';
K_TRUE: 'true';
K_TRUNCATE: 'truncate';
K_TYPE: 'type';
K_TYPENAME: 'typename';
K_UESCAPE: 'uescape';
K_UNBOUNDED: 'unbounded';
K_UNCONDITIONAL: 'unconditional';
K_UNION: 'union';
K_UNIQUE: 'unique';
K_UNLIMITED: 'unlimited';
K_UNMATCHED: 'unmatched';
K_UNPIVOT: 'unpivot';
K_UNSCALED: 'unscaled';
K_UNTIL: 'until';
K_UPDATE: 'update';
K_UPDATED: 'updated';
K_UPSERT: 'upsert';
K_UROWID: 'urowid';
K_USING: 'using';
K_VALIDATE: 'validate';
K_VALIDATE_CONVERSION: 'validate_conversion';
K_VALUE: 'value';
K_VALUES: 'values';
K_VARBIT: 'varbit';
K_VARCHAR2: 'varchar2';
K_VARCHAR: 'varchar';
K_VARYING: 'varying';
K_VERSION: 'version';
K_VERSIONS: 'versions';
K_VIEW: 'view';
K_VISIBLE: 'visible';
K_WAIT: 'wait';
K_WELLFORMED: 'wellformed';
K_WHEN: 'when';
K_WHERE: 'where';
K_WHOLE_WORD_MATCH: 'whole_word_match';
K_WINDOW: 'window';
K_WITH: 'with';
K_WITHIN: 'within';
K_WITHOUT: 'without';
K_WRAPPER: 'wrapper';
K_XML: 'xml';
K_XMLATTRIBUTES: 'xmlattributes';
K_XMLCAST: 'xmlcast';
K_XMLCOLATTVAL: 'xmlcolattval';
K_XMLELEMENT: 'xmlelement';
K_XMLEXISTS: 'xmlexists';
K_XMLFOREST: 'xmlforest';
K_XMLNAMESPACES: 'xmlnamespaces';
K_XMLPARSE: 'xmlparse';
K_XMLPI: 'xmlpi';
K_XMLQUERY: 'xmlquery';
K_XMLROOT: 'xmlroot';
K_XMLSERIALIZE: 'xmlserialize';
K_XMLTABLE: 'xmltable';
K_XMLTYPE: 'xmltype';
K_YEAR: 'year';
K_YES: 'yes';
K_ZONE: 'zone';

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
DOUBLE_COLON: '::';     // no WS allowed between COLONs in PostgreSQL
EQUALS: '=';
EXCL: '!';
GT: '>';
HAT: '^';
LCUB: '{';
LOWBAR: '_';
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
    (['] ~[']* ['])+
;

N_STRING:
    'n' STRING
;

E_STRING:
    'e' STRING
;

B_STRING:
    'b' STRING
;

U_AMP_STRING:
    'u&' STRING
;

Q_STRING:
    'q' (
          ['] '[' .*? ']' [']
        | ['] '(' .*? ')' [']
        | ['] '{' .*? '}' [']
        | ['] '<' .*? '>' [']
        | ['] . {saveQuoteDelimiter1()}? .+? . ['] {checkQuoteDelimiter2()}?
    )
;

NQ_STRING:
    'n' Q_STRING
;

DOLLAR_STRING:
    '$$' .*? '$$'
;

DOLLAR_ID_STRING:
    '$' ID '$' {saveDollarIdentifier1()}? .+? '$' ID '$' {checkDollarIdentifier2()}?
;

NUMBER:
      (
        (
              INT (PERIOD {!isCharAt(".", getCharIndex())}? INT?)?
            | PERIOD {!isCharAt(".", getCharIndex()-2)}? INT
        )
        ('e' ('+'|'-')? INT)?
        ('f'|'d')?
      )
    | '0x' ('_'? [0123456789abcdef]+)+  // PostgreSQL hexidecimal integer
    | '0o' ('_'? [01234567]+)+          // PostgreSQL octal integer
    | '0b' ('_'? [01]+)+                // PostgreSQL binary integer
;

/*----------------------------------------------------------------------------*/
// Identifier
/*----------------------------------------------------------------------------*/

UQUOTED_ID: ('u&') '"' ~["]* '"';
QUOTED_ID: '"' .*? '"' ('"' .*? '"')*;
ID: [_\p{Alpha}] [_$#0-9\p{Alpha}]*;

/*----------------------------------------------------------------------------*/
// Any other token
/*----------------------------------------------------------------------------*/

ANY_OTHER: .;
