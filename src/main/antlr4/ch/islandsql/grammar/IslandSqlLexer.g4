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
fragment HSPACE: [ \t]+;
fragment CONTINUE_LINE: '-' HSPACE? SINGLE_NL?;
fragment SQLPLUS_TEXT: (~[\r\n]|CONTINUE_LINE);
fragment SQLPLUS_END: EOF|SINGLE_NL;
fragment TO_SQLPLUS_END: ((HSPACE|CONTINUE_LINE) SQLPLUS_TEXT*)? SQLPLUS_END;
fragment INT: [0-9]+ (LOWBAR [0-9]+)*; // PostgreSQL allows underscores for visual grouping
fragment IN_AND_NESTED_COMMENT: ('/'*? ML_COMMENT | ('/'* | '*'*) ~[/*])*? '*'*?;
fragment STRING_WITH_ESCAPE_CHARS: (['] ('\\'? .)*? ['])+;
fragment COMMENT_OR_WS: ML_HINT|ML_COMMENT|SL_HINT|SL_COMMENT|WS;

/*----------------------------------------------------------------------------*/
// Whitespace, comments and hints
/*----------------------------------------------------------------------------*/

WS: [ \t\r\n]+ -> channel(HIDDEN);
ML_HINT: '/*+' IN_AND_NESTED_COMMENT '*/' -> channel(HIDDEN);
ML_COMMENT: '/*' IN_AND_NESTED_COMMENT '*/' -> channel(HIDDEN);
SL_HINT: '--+' ~[\r\n]* -> channel(HIDDEN);
SL_COMMENT: '--' ~[\r\n]* -> channel(HIDDEN);

/*----------------------------------------------------------------------------*/
// SQL*Plus commands (similar to comments)
/*----------------------------------------------------------------------------*/

REMARK_COMMAND:
    'rem' {isBeginOfCommand("rem")}? ('a' ('r' 'k'?)?)? TO_SQLPLUS_END -> channel(HIDDEN)
;

PROMPT_COMMAND:
    'pro' {isBeginOfCommand("pro")}? ('m' ('p' 't'?)?)? TO_SQLPLUS_END -> channel(HIDDEN)
;

/*----------------------------------------------------------------------------*/
// Keywords
/*----------------------------------------------------------------------------*/

K_A: 'a';
K_ABORT: 'abort';
K_ABS: 'abs';
K_ABSENT: 'absent';
K_ABSOLUTE: 'absolute';
K_ACCESS: 'access';
K_ACCESSIBLE: 'accessible';
K_ACCURACY: 'accuracy';
K_ACROSS: 'across';
K_ACTION: 'action';
K_ADD: 'add';
K_AFTER: 'after';
K_AGENT: 'agent';
K_AGGREGATE: 'aggregate';
K_ALIAS: 'alias';
K_ALL: 'all';
K_ALLOW: 'allow';
K_ALTER: 'alter';
K_ALWAYS: 'always';
K_ANALYTIC: 'analytic';
K_ANALYZE: 'analyze';
K_ANCESTOR: 'ancestor';
K_AND: 'and';
K_ANNOTATIONS: 'annotations';
K_ANY: 'any';
K_ANYSCHEMA: 'anyschema';
K_APPEND: 'append';
K_APPLY: 'apply';
K_APPROX: 'approx';
K_APPROXIMATE: 'approximate';
K_ARRAY: 'array';
K_AS: 'as';
K_ASC: 'asc';
K_ASCII: 'ascii';
K_ASENSITIVE: 'asensitive';
K_ASSERT: 'assert';
K_ASSOCIATE: 'associate';
K_AT: 'at';
K_ATOMIC: 'atomic';
K_AUDIT: 'audit';
K_AUTHID: 'authid';
K_AUTO: 'auto';
K_AUTOMATIC: 'automatic';
K_AUTONOMOUS_TRANSACTION: 'autonomous_transaction';
K_AVERAGE_RANK: 'average_rank';
K_BACKWARD: 'backward';
K_BADFILE: 'badfile';
K_BATCH: 'batch';
K_BEFORE: 'before';
K_BEGIN: 'begin';
K_BEGINNING: 'beginning';
K_BEQUEATH: 'bequeath';
K_BETWEEN: 'between';
K_BFILE: 'bfile';
K_BIGINT: 'bigint';
K_BIGRAM: 'bigram';
K_BIGSERIAL: 'bigserial';
K_BINARY: 'binary';
K_BINARY_DOUBLE: 'binary_double';
K_BINARY_FLOAT: 'binary_float';
K_BIT: 'bit';
K_BLANKLINE: 'blankline';
K_BLOB: 'blob';
K_BLOCK: 'block';
K_BLOCKCHAIN: 'blockchain';
K_BODY: 'body';
K_BOOL: 'bool';
K_BOOLEAN: 'boolean';
K_BOTH: 'both';
K_BOX: 'box';
K_BREADTH: 'breadth';
K_BUFFERS: 'buffers';
K_BUILD: 'build';
K_BULK: 'bulk';
K_BY: 'by';
K_BYTE: 'byte';
K_BYTEA: 'bytea';
K_C: 'c';
K_CACHE: 'cache';
K_CALL: 'call';
K_CALLED: 'called';
K_CASCADE: 'cascade';
K_CASCADED: 'cascaded';
K_CASE: 'case';
K_CASE_SENSITIVE: ('case_sensitive'|'case-sensitive'); // original implementation was based on kebab-case, see https://mobile.twitter.com/phsalvisberg/status/1351990195109974018
K_CAST: 'cast';
K_CHAIN: 'chain';
K_CHAR: 'char';
K_CHARACTER: 'character';
K_CHARACTERISTICS: 'characteristics';
K_CHARACTERS: 'characters';
K_CHARS: 'chars';
K_CHARSETFORM: 'charsetform';
K_CHARSETID: 'charsetid';
K_CHAR_CS: 'char_cs';
K_CHECK: 'check';
K_CHECKPOINT: 'checkpoint';
K_CIDR: 'cidr';
K_CIRCLE: 'circle';
K_CLOB: 'clob';
K_CLONE: 'clone';
K_CLOSE: 'close';
K_CLUSTER: 'cluster';
K_COLLATE: 'collate';
K_COLLATION: 'collation';
K_COLLECT: 'collect';
K_COLUMN: 'column';
K_COLUMNS: 'columns';
K_COLUMN_NAME: 'column_name';
K_COMMENT: 'comment';
K_COMMENTS: 'comments';
K_COMMIT: 'commit';
K_COMMITTED: 'committed';
K_COMPLETE: 'complete';
K_COMPOUND: 'compound';
K_COMPRESSION: 'compression';
K_COMPUTATION: 'computation';
K_CONCURRENT: 'concurrent';
K_CONDITIONAL: 'conditional';
K_CONFLICT: 'conflict';
K_CONNECT: 'connect';
K_CONNECT_BY_ROOT: 'connect_by_root';
K_CONSTANT: 'constant';
K_CONSTRAINT: 'constraint';
K_CONSTRAINTS: 'constraints';
K_CONSTRAINT_NAME: 'constraint_name';
K_CONSTRUCTOR: 'constructor';
K_CONTAINER: 'container';
K_CONTAINERS_DEFAULT: 'containers_default';
K_CONTAINER_MAP: 'container_map';
K_CONTENT: 'content';
K_CONTEXT: 'context';
K_CONTINUE: 'continue';
K_CONVERSION: 'conversion';
K_COPY: 'copy';
K_CORRUPT_XID: 'corrupt_xid';
K_CORRUPT_XID_ALL: 'corrupt_xid_all';
K_COST: 'cost';
K_COSTS: 'costs';
K_COUNT: 'count';
K_COVERAGE: 'coverage';
K_CREATE: 'create';
K_CREATION: 'creation';
K_CROSS: 'cross';
K_CROSSEDITION: 'crossedition';
K_CURRENT: 'current';
K_CURRENT_USER: 'current_user';
K_CURSOR: 'cursor';
K_CUSTOM: 'custom';
K_CYCLE: 'cycle';
K_DAMERAU_LEVENSHTEIN: 'damerau_levenshtein';
K_DANGLING: 'dangling';
K_DATA: 'data';
K_DATABASE: 'database';
K_DATATYPE: 'datatype';
K_DATE: 'date';
K_DAY: 'day';
K_DBTIMEZONE: 'dbtimezone';
K_DB_ROLE_CHANGE: 'db_role_change';
K_DDL: 'ddl';
K_DEALLOCATE: 'deallocate';
K_DEBUG: 'debug';
K_DEC: 'dec';
K_DECIMAL: 'decimal';
K_DECLARE: 'declare';
K_DECREMENT: 'decrement';
K_DEFAULT: 'default';
K_DEFAULTS: 'defaults';
K_DEFERRABLE: 'deferrable';
K_DEFERRED: 'deferred';
K_DEFINE: 'define';
K_DEFINER: 'definer';
K_DELETE: 'delete';
K_DEMAND: 'demand';
K_DENSE_RANK: 'dense_rank';
K_DEPRECATE: 'deprecate';
K_DEPTH: 'depth';
K_DESC: 'desc';
K_DESTINATION: 'destination';
K_DETAIL: 'detail';
K_DETERMINISTIC: 'deterministic';
K_DIAGNOSTICS: 'diagnostics';
K_DIMENSION: 'dimension';
K_DIRECTORY: 'directory';
K_DISABLE: 'disable';
K_DISALLOW: 'disallow';
K_DISASSOCIATE: 'disassociate';
K_DISCARD: 'discard';
K_DISTINCT: 'distinct';
K_DO: 'do';
K_DOCUMENT: 'document';
K_DOMAIN: 'domain';
K_DOUBLE: 'double';
K_DROP: 'drop';
K_DUALITY: 'duality';
K_DUPLICATED: 'duplicated';
K_DURATION: 'duration';
K_EACH: 'each';
K_EDITION: 'edition';
K_EDITIONABLE: 'editionable';
K_EDITIONING: 'editioning';
K_EDIT_TOLERANCE: 'edit_tolerance';
K_EFSEARCH: 'efsearch';
K_ELEMENT: 'element';
K_ELSE: 'else';
K_ELSEIF: 'elseif';
K_ELSIF: 'elsif';
K_EMPTY: 'empty';
K_ENABLE: 'enable';
K_ENCODING: 'encoding';
K_ENCRYPT: 'encrypt';
K_END: 'end';
K_ENFORCED: 'enforced';
K_ENTITYESCAPING: 'entityescaping';
K_ENUM: 'enum';
K_ENV: 'env';
K_ERRCODE: 'errcode';
K_ERROR: 'error';
K_ERRORS: 'errors';
K_ESCAPE: 'escape';
K_ETAG: 'etag';
K_EVALNAME: 'evalname';
K_EVALUATE: 'evaluate';
K_EXACT: 'exact';
K_EXCEPT: 'except';
K_EXCEPTION: 'exception';
K_EXCEPTIONS: 'exceptions';
K_EXCEPTION_INIT: 'exception_init';
K_EXCHANGE: 'exchange';
K_EXCLUDE: 'exclude';
K_EXCLUDING: 'excluding';
K_EXCLUSIVE: 'exclusive';
K_EXECUTE: 'execute';
K_EXISTING: 'existing';
K_EXISTS: 'exists';
K_EXIT: 'exit';
K_EXPLAIN: 'explain';
K_EXTENDED: 'extended';
K_EXTERNAL: 'external';
K_EXTRA: 'extra';
K_EXTRACT: 'extract';
K_EXTSCHEMA: 'extschema';
K_FACT: 'fact';
K_FALSE: 'false';
K_FAST: 'fast';
K_FEATURE_COMPARE: 'feature_compare';
K_FETCH: 'fetch';
K_FILESYSTEM_LIKE_LOGGING: 'filesystem_like_logging';
K_FILTER: 'filter';
K_FINAL: 'final';
K_FIRST: 'first';
K_FLEX: 'flex';
K_FLOAT4: 'float4';
K_FLOAT8: 'float8';
K_FLOAT: 'float';
K_FOLLOWING: 'following';
K_FOLLOWS: 'follows';
K_FOR: 'for';
K_FORALL: 'forall';
K_FORCE: 'force';
K_FOREACH: 'foreach';
K_FOREIGN: 'foreign';
K_FORMAT: 'format';
K_FORWARD: 'forward';
K_FROM: 'from';
K_FROM_VECTOR: 'from_vector';
K_FULL: 'full';
K_FUNCTION: 'function';
K_FUZZY_MATCH: 'fuzzy_match';
K_GENERATED: 'generated';
K_GENERIC_PLAN: 'generic_plan';
K_GET: 'get';
K_GLOBAL: 'global';
K_GOTO: 'goto';
K_GRANT: 'grant';
K_GRAPH_TABLE: 'graph_table';
K_GROUP: 'group';
K_GROUPING: 'grouping';
K_GROUPS: 'groups';
K_HASH: 'hash';
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
K_HINT: 'hint';
K_HOLD: 'hold';
K_HOUR: 'hour';
K_ID: 'id';
K_IDENTIFIED: 'identified';
K_IDENTIFIER: 'identifier';
K_IDENTITY: 'identity';
K_IF: 'if';
K_IGNORE: 'ignore';
K_ILIKE: 'ilike';
K_IMMEDIATE: 'immediate';
K_IMMUTABLE: 'immutable';
K_IMPORT: 'import';
K_IN: 'in';
K_INCLUDE: 'include';
K_INCLUDING: 'including';
K_INCREMENT: 'increment';
K_INDENT: 'indent';
K_INDEX: 'index';
K_INDEXES: 'indexes';
K_INDICATOR: 'indicator';
K_INDICES: 'indices';
K_INET: 'inet';
K_INFINITE: 'infinite';
K_INFO: 'info';
K_INHERIT: 'inherit';
K_INITIALLY: 'initially';
K_INITRANS: 'initrans';
K_INLINE: 'inline';
K_INNER: 'inner';
K_INOUT: 'inout';
K_INPUT: 'input';
K_INSENSITIVE: 'insensitive';
K_INSERT: 'insert';
K_INSTANTIABLE: 'instantiable';
K_INSTEAD: 'instead';
K_INT2: 'int2';
K_INT4: 'int4';
K_INT8: 'int8';
K_INT: 'int';
K_INTEGER: 'integer';
K_INTERSECT: 'intersect';
K_INTERVAL: 'interval';
K_INTO: 'into';
K_INVISIBLE: 'invisible';
K_INVOKER: 'invoker';
K_IS: 'is';
K_ISNULL: 'isnull';
K_ISOLATION: 'isolation';
K_ITERATE: 'iterate';
K_JARO_WINKLER: 'jaro_winkler';
K_JAVA: 'java';
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
K_LANGUAGE: 'language';
K_LAST: 'last';
K_LATERAL: 'lateral';
K_LAX: 'lax';
K_LEAD: 'lead';
K_LEADING: 'leading';
K_LEAD_DIFF: 'lead_diff';
K_LEAD_DIFF_PERCENT: 'lead_diff_percent';
K_LEAKPROOF: 'leakproof';
K_LEFT: 'left';
K_LENGTH: 'length';
K_LEVEL: 'level';
K_LEVENSHTEIN: 'levenshtein';
K_LIBRARY: 'library';
K_LIKE2: 'like2';
K_LIKE4: 'like4';
K_LIKE: 'like';
K_LIKEC: 'likec';
K_LIMIT: 'limit';
K_LINE: 'line';
K_LISTAGG: 'listagg';
K_LISTEN: 'listen';
K_LOAD: 'load';
K_LOB: 'lob';
K_LOBS: 'lobs';
K_LOCAL: 'local';
K_LOCATION: 'location';
K_LOCK: 'lock';
K_LOCKED: 'locked';
K_LOG: 'log';
K_LOGFILE: 'logfile';
K_LOGGING: 'logging';
K_LOGOFF: 'logoff';
K_LOGON: 'logon';
K_LONG: 'long';
K_LONGEST_COMMON_SUBSTRING: 'longest_common_substring';
K_LOOP: 'loop';
K_LSEG: 'lseg';
K_MACADDR8: 'macaddr8';
K_MACADDR: 'macaddr';
K_MAIN: 'main';
K_MAP: 'map';
K_MAPPING: 'mapping';
K_MASTER: 'master';
K_MATCH: 'match';
K_MATCHED: 'matched';
K_MATCHES: 'matches';
K_MATCH_RECOGNIZE: 'match_recognize';
K_MATERIALIZED: 'materialized';
K_MAX: 'max';
K_MAXLEN: 'maxlen';
K_MAXVALUE: 'maxvalue';
K_MEASURES: 'measures';
K_MEMBER: 'member';
K_MEMOPTIMIZED: 'memoptimized';
K_MERGE: 'merge';
K_MESSAGE: 'message';
K_MESSAGE_TEXT: 'message_text';
K_METADATA: 'metadata';
K_MINUS: 'minus';
K_MINUTE: 'minute';
K_MINVALUE: 'minvalue';
K_MISMATCH: 'mismatch';
K_MISSING: 'missing';
K_MLE: 'mle';
K_MOD: 'mod';
K_MODE: 'mode';
K_MODEL: 'model';
K_MODIFY: 'modify';
K_MODULE: 'module';
K_MONEY: 'money';
K_MONTH: 'month';
K_MOVE: 'move';
K_MULTISET: 'multiset';
K_MUTABLE: 'mutable';
K_NAME: 'name';
K_NAN: 'nan';
K_NATIONAL: 'national';
K_NATURAL: 'natural';
K_NAV: 'nav';
K_NCHAR: 'nchar';
K_NCHAR_CS: 'nchar_cs';
K_NCLOB: 'nclob';
K_NEIGHBOR: 'neighbor';
K_NESTED: 'nested';
K_NEVER: 'never';
K_NEW: 'new';
K_NEWLINE: 'newline';
K_NEXT: 'next';
K_NO: 'no';
K_NOAUDIT: 'noaudit';
K_NOCACHE: 'nocache';
K_NOCHECK: 'nocheck';
K_NOCOPY: 'nocopy';
K_NOCYCLE: 'nocycle';
K_NODELETE: 'nodelete';
K_NOENTITYESCAPING: 'noentityescaping';
K_NOINSERT: 'noinsert';
K_NOLOGGING: 'nologging';
K_NOMAXVALUE: 'nomaxvalue';
K_NOMINVALUE: 'nominvalue';
K_NONE: 'none';
K_NONEDITIONABLE: 'noneditionable';
K_NONSCHEMA: 'nonschema';
K_NOORDER: 'noorder';
K_NOPARALLEL: 'noparallel';
K_NOPRECHECK: 'noprecheck';
K_NORELY: 'norely';
K_NORMALIZE: 'normalize';
K_NORMALIZED: 'normalized';
K_NOSCHEMACHECK: 'noschemacheck';
K_NOT: 'not';
K_NOTHING: 'nothing';
K_NOTICE: 'notice';
K_NOTIFY: 'notify';
K_NOTNULL: 'notnull';
K_NOUPDATE: 'noupdate';
K_NOVALIDATE: 'novalidate';
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
K_OID: 'oid';
K_OLD: 'old';
K_OMIT: 'omit';
K_ON: 'on';
K_ONE: 'one';
K_ONLY: 'only';
K_OPEN: 'open';
K_OPERATOR: 'operator';
K_OPTION: 'option';
K_OR: 'or';
K_ORDER: 'order';
K_ORDERED: 'ordered';
K_ORDINALITY: 'ordinality';
K_ORGANIZATION: 'organization';
K_OTHERS: 'others';
K_OUT: 'out';
K_OUTER: 'outer';
K_OVER: 'over';
K_OVERFLOW: 'overflow';
K_OVERLAP: 'overlap';
K_OVERLAPS: 'overlaps';
K_OVERLAY: 'overlay';
K_OVERRIDING: 'overriding';
K_PACKAGE: 'package';
K_PAIRS: 'pairs';
K_PARALLEL: 'parallel';
K_PARALLEL_ENABLE: 'parallel_enable';
K_PARAMETERS: 'parameters';
K_PARENT: 'parent';
K_PARTIAL: 'partial';
K_PARTITION: 'partition';
K_PARTITIONS: 'partitions';
K_PARTITIONSET: 'partitionset';
K_PASSING: 'passing';
K_PAST: 'past';
K_PATH: 'path';
K_PATTERN: 'pattern';
K_PCTFREE: 'pctfree';
K_PCTUSED: 'pctused';
K_PER: 'per';
K_PERCENT: 'percent';
K_PERFORM: 'perform';
K_PERIOD: 'period';
K_PERMUTE: 'permute';
K_PERSISTABLE: 'persistable';
K_PG_CONTEXT: 'pg_context';
K_PG_DATATYPE_NAME: 'pg_datatype_name';
K_PG_EXCEPTION_CONTEXT: 'pg_exception_context';
K_PG_EXCEPTION_DETAIL: 'pg_exception_detail';
K_PG_EXCEPTION_HINT: 'pg_exception_hint';
K_PG_LSN: 'pg_lsn';
K_PG_ROUTINE_OID: 'pg_routine_oid';
K_PG_SNAPSHOT: 'pg_snapshot';
K_PIPE: 'pipe';
K_PIPELINED: 'pipelined';
K_PIVOT: 'pivot';
K_PLACING: 'placing';
K_PLAIN: 'plain';
K_PLAN: 'plan';
K_PLUGGABLE: 'pluggable';
K_POINT: 'point';
K_POLYGON: 'polygon';
K_POLYMORPHIC: 'polymorphic';
K_POSITION: 'position';
K_PRAGMA: 'pragma';
K_PREBUILT: 'prebuilt';
K_PRECEDES: 'precedes';
K_PRECEDING: 'preceding';
K_PRECHECK: 'precheck';
K_PRECISION: 'precision';
K_PREDICTION: 'prediction';
K_PREDICTION_COST: 'prediction_cost';
K_PREDICTION_DETAILS: 'prediction_details';
K_PREPARE: 'prepare';
K_PREPARED: 'prepared';
K_PREPEND: 'prepend';
K_PRESENT: 'present';
K_PRESERVE: 'preserve';
K_PRETTY: 'pretty';
K_PRIMARY: 'primary';
K_PRIOR: 'prior';
K_PRIVATE: 'private';
K_PROBES: 'probes';
K_PROCEDURE: 'procedure';
K_PUNCTUATION: 'punctuation';
K_QUALIFY: 'qualify';
K_QUERY: 'query';
K_RAISE: 'raise';
K_RANGE: 'range';
K_RANK: 'rank';
K_RAW: 'raw';
K_READ: 'read';
K_REAL: 'real';
K_REASSIGN: 'reassign';
K_RECORD: 'record';
K_RECURSIVE: 'recursive';
K_RECURSIVELY: 'recursively';
K_REDUCED: 'reduced';
K_REF: 'ref';
K_REFERENCE: 'reference';
K_REFERENCES: 'references';
K_REFERENCING: 'referencing';
K_REFRESH: 'refresh';
K_REINDEX: 'reindex';
K_REJECT: 'reject';
K_RELATE_TO_SHORTER: 'relate_to_shorter';
K_RELATIONAL: 'relational';
K_RELATIVE: 'relative';
K_RELIES_ON: 'relies_on';
K_RELY: 'rely';
K_REMOVE: 'remove';
K_RENAME: 'rename';
K_REPEAT: 'repeat';
K_REPEATABLE: 'repeatable';
K_REPLACE: 'replace';
K_RESERVABLE: 'reservable';
K_RESET: 'reset';
K_RESPECT: 'respect';
K_RESTRICT: 'restrict';
K_RESTRICTED: 'restricted';
K_RESTRICT_REFERENCES: 'restrict_references';
K_RESULT: 'result';
K_RESULT_CACHE: 'result_cache';
K_RETURN: 'return';
K_RETURNED_SQLSTATE: 'returned_sqlstate';
K_RETURNING: 'returning';
K_RETURNS: 'returns';
K_REVERSE: 'reverse';
K_REVOKE: 'revoke';
K_REWRITE: 'rewrite';
K_RIGHT: 'right';
K_RNDS: 'rnds';
K_RNPS: 'rnps';
K_ROLLBACK: 'rollback';
K_ROW: 'row';
K_ROWID: 'rowid';
K_ROWS: 'rows';
K_ROWTYPE: 'rowtype';
K_ROW_COUNT: 'row_count';
K_ROW_NUMBER: 'row_number';
K_RULES: 'rules';
K_RUNNING: 'running';
K_SAFE: 'safe';
K_SALT: 'salt';
K_SAMPLE: 'sample';
K_SAVE: 'save';
K_SAVEPOINT: 'savepoint';
K_SCALAR: 'scalar';
K_SCALARS: 'scalars';
K_SCHEMA: 'schema';
K_SCHEMACHECK: 'schemacheck';
K_SCHEMA_NAME: 'schema_name';
K_SCN: 'scn';
K_SCOPE: 'scope';
K_SCROLL: 'scroll';
K_SDO_GEOMETRY: 'sdo_geometry';
K_SEARCH: 'search';
K_SECOND: 'second';
K_SECURITY: 'security';
K_SEED: 'seed';
K_SEGMENT: 'segment';
K_SELECT: 'select';
K_SELF: 'self';
K_SENTENCE: 'sentence';
K_SEQUENCE: 'sequence';
K_SEQUENTIAL: 'sequential';
K_SERIAL2: 'serial2';
K_SERIAL4: 'serial4';
K_SERIAL8: 'serial8';
K_SERIAL: 'serial';
K_SERIALIZABLE: 'serializable';
K_SERIALLY_REUSABLE: 'serially_reusable';
K_SERVERERROR: 'servererror';
K_SESSION: 'session';
K_SESSIONTIMEZONE: 'sessiontimezone';
K_SET: 'set';
K_SETOF: 'setof';
K_SETS: 'sets';
K_SHARDED: 'sharded';
K_SHARD_ENABLE: 'shard_enable';
K_SHARE: 'share';
K_SHARE_OF: 'share_of';
K_SHARING: 'sharing';
K_SHOW: 'show';
K_SHUTDOWN: 'shutdown';
K_SIBLINGS: 'siblings';
K_SIGNATURE: 'signature';
K_SIMILAR: 'similar';
K_SIMPLE: 'simple';
K_SINGLE: 'single';
K_SIZE: 'size';
K_SKIP: 'skip';
K_SLICE: 'slice';
K_SMALLINT: 'smallint';
K_SMALLSERIAL: 'smallserial';
K_SNAPSHOT: 'snapshot';
K_SOME: 'some';
K_SORT: 'sort';
K_SOURCE: 'source';
K_SPACE: 'space';
K_SPLIT: 'split';
K_SQL: 'sql';
K_SQLSTATE: 'sqlstate';
K_SQL_MACRO: 'sql_macro';
K_STABLE: 'stable';
K_STACKED: 'stacked';
K_STAGING: 'staging';
K_STANDALONE: 'standalone';
K_START: 'start';
K_STARTUP: 'startup';
K_STATEMENT: 'statement';
K_STATEMENT_ID: 'statement_id';
K_STATIC: 'static';
K_STATISTICS: 'statistics';
K_STORAGE: 'storage';
K_STORE: 'store';
K_STORED: 'stored';
K_STRICT: 'strict';
K_STRING: 'string';
K_STRUCT: 'struct';
K_SUBMULTISET: 'submultiset';
K_SUBPARTITION: 'subpartition';
K_SUBSET: 'subset';
K_SUBSTRING: 'substring';
K_SUBTYPE: 'subtype';
K_SUMMARY: 'summary';
K_SUPPLEMENTAL: 'supplemental';
K_SUPPORT: 'support';
K_SUPPRESSES_WARNING_6009: 'suppresses_warning_6009';
K_SUSPEND: 'suspend';
K_SYMMETRIC: 'symmetric';
K_SYNCHRONOUS: 'synchronous';
K_SYSTEM: 'system';
K_TABLE: 'table';
K_TABLES: 'tables';
K_TABLESAMPLE: 'tablesample';
K_TABLESPACE: 'tablespace';
K_TABLE_NAME: 'table_name';
K_TARGET: 'target';
K_TDO: 'tdo';
K_TEMP: 'temp';
K_TEMPORARY: 'temporary';
K_TEXT: 'text';
K_THE: 'the';
K_THEN: 'then';
K_TIES: 'ties';
K_TIME: 'time';
K_TIMESTAMP: 'timestamp';
K_TIMESTAMPTZ: 'timestamptz';
K_TIMETZ: 'timetz';
K_TIMEZONE: 'timezone';
K_TIMING: 'timing';
K_TO: 'to';
K_TRAILING: 'trailing';
K_TRANSACTION: 'transaction';
K_TRANSFORM: 'transform';
K_TREAT: 'treat';
K_TRIGGER: 'trigger';
K_TRIGRAM: 'trigram';
K_TRIM: 'trim';
K_TRUE: 'true';
K_TRUNCATE: 'truncate';
K_TRUST: 'trust';
K_TRUSTED: 'trusted';
K_TSQUERY: 'tsquery';
K_TSVECTOR: 'tsvector';
K_TXID_SNAPSHOT: 'txid_snapshot';
K_TYPE: 'type';
K_TYPENAME: 'typename';
K_UDF: 'udf';
K_UESCAPE: 'uescape';
K_UNBOUNDED: 'unbounded';
K_UNCOMMITTED: 'uncommitted';
K_UNCONDITIONAL: 'unconditional';
K_UNDER: 'under';
K_UNION: 'union';
K_UNIQUE: 'unique';
K_UNKNOWN: 'unknown';
K_UNLIMITED: 'unlimited';
K_UNLISTEN: 'unlisten';
K_UNLOGGED: 'unlogged';
K_UNMATCHED: 'unmatched';
K_UNNEST: 'unnest';
K_UNPIVOT: 'unpivot';
K_UNPLUG: 'unplug';
K_UNSAFE: 'unsafe';
K_UNSCALED: 'unscaled';
K_UNTIL: 'until';
K_UNUSABLE: 'unusable';
K_UPDATE: 'update';
K_UPDATED: 'updated';
K_UPSERT: 'upsert';
K_UROWID: 'urowid';
K_USE: 'use';
K_USER: 'user';
K_USING: 'using';
K_UUID: 'uuid';
K_VACUUM: 'vacuum';
K_VALIDATE: 'validate';
K_VALIDATE_CONVERSION: 'validate_conversion';
K_VALUE: 'value';
K_VALUES: 'values';
K_VARBIT: 'varbit';
K_VARCHAR2: 'varchar2';
K_VARCHAR: 'varchar';
K_VARIADIC: 'variadic';
K_VARRAY: 'varray';
K_VARRAYS: 'varrays';
K_VARYING: 'varying';
K_VECTOR: 'vector';
K_VECTOR_CHUNKS: 'vector_chunks';
K_VECTOR_SERIALIZE: 'vector_serialize';
K_VERBOSE: 'verbose';
K_VERSION: 'version';
K_VERSIONS: 'versions';
K_VIEW: 'view';
K_VIRTUAL: 'virtual';
K_VISIBLE: 'visible';
K_VOCABULARY: 'vocabulary';
K_VOLATILE: 'volatile';
K_WAIT: 'wait';
K_WAL: 'wal';
K_WARNING: 'warning';
K_WELLFORMED: 'wellformed';
K_WHEN: 'when';
K_WHERE: 'where';
K_WHILE: 'while';
K_WHITESPACE: 'whitespace';
K_WHOLE_WORD_MATCH: 'whole_word_match';
K_WIDECHAR: 'widechar';
K_WINDOW: 'window';
K_WITH: 'with';
K_WITHIN: 'within';
K_WITHOUT: 'without';
K_WNDS: 'wnds';
K_WNPS: 'wnps';
K_WORDS: 'words';
K_WORK: 'work';
K_WRAPPER: 'wrapper';
K_WRITE: 'write';
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
K_XMLSCHEMA: 'xmlschema';
K_XMLSERIALIZE: 'xmlserialize';
K_XMLTABLE: 'xmltable';
K_XMLTYPE: 'xmltype';
K_YAML: 'yaml';
K_YEAR: 'year';
K_YES: 'yes';
K_ZONE: 'zone';

/*----------------------------------------------------------------------------*/
// Special characters - naming according HTML entity name
/*----------------------------------------------------------------------------*/

// see https://html.spec.whatwg.org/multipage/named-characters.html#named-character-references
// or https://oinam.github.io/entities/

AMP: '&';
AMP_AMP: '&&';
AST: '*';
AST_AST: '**';
AST_QUEST: '*?';
BSOL: '\\';
COLON: ':';
COLON_EQUALS: ':=';    // no WS allowed between chars in field_definition of OracleDB
COLON_COLON: '::';     // no WS allowed between COLONs in PostgreSQL
COMMA: ',';
COMMAT: '@';
DOLLAR: '$';
DOLLAR_END: '$end';
DOLLAR_ELSE: '$else';
DOLLAR_ELSIF: '$elsif';
DOLLAR_ERROR: '$error';
DOLLAR_IF: '$if';
DOLLAR_THEN: '$then';
EQUALS: '=';
EQUALS_GT: '=>';
EXCL: '!';
EXCL_EQUALS: '!=';
EXCL_TILDE: '!~';
GT: '>';
GT_EQUALS: '>=';
GT_GT: '>>';
HAT: '^';
HAT_EQUALS: '^=';
LCUB: '{';
LOWBAR: '_';
LPAR: '(';
LSQB: '[';
LT: '<';
LT_EQUALS: '<=';
LT_GT: '<>';
LT_LT: '<<';
LT_MINUS_GT: '<->';
MINUS: '-';
MINUS_GT: '->';
NUM: '#';
PERCNT: '%';
PERIOD: '.';
PLUS: '+';
PLUS_QUEST: '+?';
QUEST: '?';
QUEST_QUEST: '??';
RCUB: '}';
RPAR: ')';
RSQB: ']';
SEMI: ';';
SOL: '/';
TILDE: '~';
TILDE_EQUALS: '~=';
VERBAR: '|';
VERBAR_VERBAR: '||';

/*----------------------------------------------------------------------------*/
// Generic operators used by various PostgreSQL extensions
/*----------------------------------------------------------------------------*/

// based on https://stackoverflow.com/questions/24194110/antlr4-negative-lookahead-in-lexer

// operator not ending on '+' nor '-'
POSTGRESQL_OPERATOR:
    (
          [<>=~!@#%^&|`?]
        | ('+'|'-' {_input.LA(1) != '-'}?)+ [<>=~!@#%^&|`?] // start single-line comment not allowed
        | '/' {_input.LA(1) != '*'}? // start of multiline comment not allowed
        | '*' {_input.LA(1) != '/'}? // end of multiline comment not allowed
    )+
;
// operator can end on '+' or '-' if it contains one of these characters: [~!@#%^&|`?]
POSTGRESQL_OPERATOR_ENDING_ON_PLUS_OR_MINUS:
    (
          [<>=+]
        | '-' {_input.LA(1) != '-'}? // start single-line comment not allowed
        | '/' {_input.LA(1) != '*'}? // start of multiline comment not allowed
        | '*' {_input.LA(1) != '/'}? // end of multiline comment not allowed
    )*
    [~!@#%^&|`?]
    POSTGRESQL_OPERATOR?
    ('+'|'-' {_input.LA(1) != '-'}?)+ // start single-line comment not allowed
    -> type(POSTGRESQL_OPERATOR)
;

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
    'e' STRING_WITH_ESCAPE_CHARS (COMMENT_OR_WS* STRING_WITH_ESCAPE_CHARS)*
;

B_STRING:
    'b' STRING
;

X_STRING:
    'x' STRING
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
    '$$' .*? '$$' {!isInquiryDirective()}?
;

DOLLAR_ID_STRING:
    '$' ID '$' {saveDollarIdentifier1()}? .*? '$' ID '$' {checkDollarIdentifier2()}?
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
PLSQL_INQUIRY_DIRECTIVE: '$$' ID;
POSITIONAL_PARAMETER: '$'[0-9]+;

/*----------------------------------------------------------------------------*/
// psql exec query command
/*----------------------------------------------------------------------------*/

PSQL_EXEC: (WS|ML_COMMENT|ML_HINT)* ('\\g'|'\\crosstabview') ~[\n]* (EOF|SINGLE_NL);

/*----------------------------------------------------------------------------*/
// Any other token
/*----------------------------------------------------------------------------*/

ANY_OTHER: .;
