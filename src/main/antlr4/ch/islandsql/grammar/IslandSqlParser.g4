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

parser grammar IslandSqlParser;

options {
    tokenVocab=IslandSqlLexer;
    superClass=IslandSqlParserBase;
}

/*----------------------------------------------------------------------------*/
// Start rule
/*----------------------------------------------------------------------------*/

file: statement* EOF;

/*----------------------------------------------------------------------------*/
// Statement
/*----------------------------------------------------------------------------*/

statement:
      ddlStatement
    | dmlStatement
    | emptyStatement
    | plsqlBlockStatement
    | tclStatement
;

/*----------------------------------------------------------------------------*/
// Data Definition Language
/*----------------------------------------------------------------------------*/

ddlStatement:
      createFunctionStatement
    | createPackageStatement
    | createPackageBodyStatement
;

/*----------------------------------------------------------------------------*/
// Create Function
/*----------------------------------------------------------------------------*/

createFunctionStatement:
      createFunction sqlEnd?
;

createFunction:
    K_CREATE (K_OR K_REPLACE)? (K_EDITIONABLE | K_NONEDITIONABLE)? K_FUNCTION
    (K_IF K_NOT K_EXISTS)? (plsqlFunctionSource | postgresFunctionSource)
;

plsqlFunctionSource:
    (schema=sqlName PERIOD)? functionName=sqlName
        (LPAR parameters+=parameterDeclaration (COMMA parameters+=parameterDeclaration)* RPAR)?
        K_RETURN returnType=plsqlDataType options+=plsqlFunctionOption*
        (K_IS | K_AS) (declareSection? body | callSpec SEMI)
;

plsqlFunctionOption:
      sharingClause
    | invokerRightsclause
    | accessibleByClause
    | defaultCollationClause
    | deterministicClause
    | shardEnableClause
    | parallelEnableClause
    | resultCacheClause
    | aggreagateClause
    | pipelinedClause
    | sqlMacroClause
;

sharingClause:
    K_SHARING EQUALS (K_METADATA | K_NONE)
;

shardEnableClause:
    K_SHARD_ENABLE
;

aggreagateClause:
    K_AGGREGATE K_USING (schema=sqlName PERIOD)? implementationtype=sqlName
;

// space is not allowed between '=>'
sqlMacroClause:
    K_SQL_MACRO (LPAR (K_TYPE EQUALS_GT)? (K_SCALAR | K_TABLE)  RPAR)?
;

postgresFunctionSource:
    (schema=sqlName PERIOD)? functionName=sqlName
        (LPAR parameters+=parameterDeclaration (COMMA parameters+=parameterDeclaration)* RPAR)?
        K_RETURNS
        (
              K_SETOF? (returnSchema=sqlName PERIOD)? returnType=plsqlDataType
            | K_TABLE LPAR columns+=postgresqlColumnDefinition (COMMA columns+=postgresqlColumnDefinition)* RPAR
        )
        postgresqlFunctionOption+
;

postgresqlFunctionOption:
      K_LANGUAGE languageName=sqlName
    | K_TRANSFORM transformItems+=transformItem (COMMA transformItems+=transformItem)
    | K_IMMUTABLE
    | K_STABLE
    | K_VOLATILE
    | K_NOT? K_LEAKPROOF
    | K_CALLED K_ON K_NULL K_INPUT
    | K_RETURNS K_NULL K_ON K_NULL K_INPUT
    | K_STRICT
    | K_EXTERNAL? K_SECURITY (K_INVOKER | K_DEFINER)
    | K_PARALLEL (K_UNSAFE | K_RESTRICTED | K_SAFE)
    | K_COST executionCost=expression
    | K_ROWS resultRows=expression
    | K_SUPPORT (supportSchema=sqlName PERIOD)? supportFunction=sqlName
    | K_SET parameterName=sqlName ((K_TO | EQUALS) values+=expression (COMMA values+=expression)* | K_FROM K_CURRENT)
    | K_AS definition=expression
    | K_AS objFile=expression COMMA linkSymbol=expression
    | sqlBody
;

transformItem:
    K_FOR K_TYPE (typeSchema=sqlName PERIOD)? typeName=dataType
;

sqlBody:
    K_RETURN expr=expression
;

/*----------------------------------------------------------------------------*/
// Create Package
/*----------------------------------------------------------------------------*/

createPackageStatement:
      createPackage sqlEnd?
;

createPackage:
    K_CREATE (K_OR K_REPLACE)? (K_EDITIONABLE | K_NONEDITIONABLE)? K_PACKAGE
    (K_IF K_NOT K_EXISTS)? plsqlPackageSource
    (K_IS | K_AS) items+=itemlistItem+ K_END name=sqlName? SEMI
;

plsqlPackageSource:
    (schema=sqlName PERIOD)? packageName=sqlName options+=plsqlPackageOption*
;

plsqlPackageOption:
      sharingClause
    | defaultCollationClause
    | invokerRightsclause
    | accessibleByClause
;

/*----------------------------------------------------------------------------*/
// Create Package Body
/*----------------------------------------------------------------------------*/

createPackageBodyStatement:
      createPackageBody sqlEnd?
;

createPackageBody:
    K_CREATE (K_OR K_REPLACE)? (K_EDITIONABLE | K_NONEDITIONABLE)? K_PACKAGE K_BODY
    (K_IF K_NOT K_EXISTS)? plsqlPackageBodySource
;

plsqlPackageBodySource:
    (schema=sqlName PERIOD)? packageName=sqlName sharingClause?
    (K_IS | K_AS) declareSection initializeSection? K_END name=sqlName? SEMI
;

initializeSection:
    K_BEGIN
    stmts+=plsqlStatement+
    (K_EXCEPTION exceptionHandlers+=exceptionHandler+)?
;

/*----------------------------------------------------------------------------*/
// Data Manipulation Language
/*----------------------------------------------------------------------------*/

dmlStatement:
      callStatement
    | deleteStatement
    | explainPlanStatement
    | insertStatement
    | lockTableStatement
    | mergeStatement
    | selectStatement
    | updateStatement
;

/*----------------------------------------------------------------------------*/
// Call
/*----------------------------------------------------------------------------*/

callStatement:
    call sqlEnd
;

// simplified:
// - treat routine_call and object_access_expression as an ordinary expression
// - use placeholder_expression as into target
call:
    K_CALL callable=expression (K_INTO placeholderExpression)?
;

/*----------------------------------------------------------------------------*/
// Delete
/*----------------------------------------------------------------------------*/

deleteStatement:
    delete sqlEnd
;

delete:
    withClause?                                             // PostgreSQL
    {unhideFirstHint();} K_DELETE hint? K_FROM?
    (
          K_ONLY? dmlTableExpressionClause AST?             // PostgreSQL: only, *
        | K_ONLY LPAR dmlTableExpressionClause RPAR
    ) K_AS? talias=sqlName?                                 // PostgreSQL: as
    fromUsingClause?
    whereClause?
    returningClause?
    errorLoggingClause?
;

// simplified, table_collection_expression treated as expression
dmlTableExpressionClause:
      (schema=sqlName PERIOD)? table=sqlName AST? (partitionExtensionClause | COMMAT dblink=qualifiedName)? // PostgreSQL: *
    | LPAR query=subquery RPAR
    | expr=expression
;

// introduced in OracleDB 23c, re-use grammar in select statement
// it's similar to the fromClause, the only difference is that you can use K_USING instead of K_FROM
fromUsingClause:
    (K_FROM | K_USING) items+=fromItem (COMMA items+=fromItem)*
;

returningClause:
    (K_RETURN | K_RETURNING) sourceItems+=sourceItem (COMMA sourceItems+=sourceItem)*
    (
        (K_BULK K_COLLECT)? // within PL/SQL
        K_INTO targetItems+=dataItem (COMMA targetItems+=dataItem)*
    )?  // required in OracleDB but not allowed in PostgreSQL
;

// OLD and NEW are introduced in OracleDB 23c
sourceItem:
    (K_OLD | K_NEW)? expr=expression (K_AS? alias=sqlName)? // PostgreSQL allows to define an alias
;

dataItem:
    expr=expression
;

// dblinks are really not supported: ORA-38919: remote table not supported for DML error logging
errorLoggingClause:
    K_LOG K_ERRORS
    (K_INTO (schema=sqlName PERIOD)? table=sqlName)?
    (LPAR statementTag=expression RPAR)?
    (K_REJECT K_LIMIT (unlimited=K_UNLIMITED | limit=expression))?
;

/*----------------------------------------------------------------------------*/
// Explain plan
/*----------------------------------------------------------------------------*/

explainPlanStatement:
    (
          explainPlan       // OracleDB
        | explain           // PostgreSQL
    )
    sqlEnd
;

// undocumented: equals is optional
explainPlan:
    K_EXPLAIN K_PLAN (K_SET K_STATEMENT_ID EQUALS? statementId=expression)?
    (K_INTO (schema=sqlName PERIOD)? table=sqlName (COMMAT dblink=qualifiedName)?)?
    K_FOR statementName=forExplainPlanStatement
;

forExplainPlanStatement:
      select
    | delete
    | insert
    | merge
    | update
    | otherStatement
;

// support other statements such as CREATE TABLE, CREATE INDEX, ALTER INDEX as list of tokens
otherStatement:
    ~SEMI* // optional since all tokens may be on the hidden channel
;

explain:
    K_EXPLAIN
        (
              LPAR options+=explainOption (COMMA options+=explainOption)* RPAR
            | K_ANALYZE K_VERBOSE?
            | K_VERBOSE
        )?
    statementName=forExplainPlanStatement
;

explainOption:
      K_ANALYZE bool=expression?
    | K_VERBOSE bool=expression?
    | K_COSTS bool=expression?
    | K_GENERIC_PLAN bool=expression?
    | K_BUFFERS bool=expression?
    | K_WAL bool=expression?
    | K_TIMING bool=expression?
    | K_SUMMARY bool=expression?
    | K_FORMAT (K_TEXT | K_XML | K_JSON | K_YAML)
;

/*----------------------------------------------------------------------------*/
// Insert
/*----------------------------------------------------------------------------*/

insertStatement:
    insert sqlEnd
;

insert:
    withClause? // PostgreSQL
    {unhideFirstHint();} K_INSERT hint?
    (
          singleTableInsert
        | multiTableInsert
    )
;

singleTableInsert:
    insertIntoClause
    postgresqlOverridingClause?
    (
          insertValuesClause
        | subquery
        | postgresqlDefaultValuesClause
    )
    postgresqlOnConflictClause?
    returningClause? // unlike OracleDB, PostgreSQL allows a returning_clause for a subquery
    errorLoggingClause?
;

insertIntoClause:
    K_INTO dmlTableExpressionClause K_AS? tAlias=sqlName? // as keyword is allowed in PostgreSQL
    (LPAR columns+=qualifiedName (COMMA columns+=qualifiedName)* RPAR)?
;

insertValuesClause:
    K_VALUES rows+=valuesRow (COMMA rows+=valuesRow)*
;

multiTableInsert:
    (
          unconditionalInsertClause
        | conditionalInsertClause
    ) subquery
;

unconditionalInsertClause:
    K_ALL intoClauses+=multiTableInsertClause+
;

multiTableInsertClause:
    insertIntoClause insertValuesClause? errorLoggingClause?
;

conditionalInsertClause:
    (K_ALL | K_FIRST)?
    whenClauses+=conditionalInsertWhenClause+
    (K_ELSE elseIntoClauses+=multiTableInsertClause+)?
;

conditionalInsertWhenClause:
    K_WHEN cond=condition K_THEN intoClauses+=multiTableInsertClause+
;

postgresqlOverridingClause:
    K_OVERRIDING (K_SYSTEM|K_USER) K_VALUE
;

postgresqlDefaultValuesClause:
   K_DEFAULT K_VALUES
;

postgresqlOnConflictClause:
    K_ON K_CONFLICT target=postgresqlOnConflictTarget? action=postgresqlOnConflictAction
;

postgresqlOnConflictTarget:
      LPAR items+=postgresqlOnConflictTargetItem (COMMA items+=postgresqlOnConflictTargetItem)* RPAR  (K_WHERE indexPredicate=condition)?
    | K_ON K_CONSTRAINT constraintName=sqlName
;

postgresqlOnConflictTargetItem:
    (indexColumnName=sqlName|LPAR indexExpression=expression RPAR)
    (K_COLLATE collate=sqlName)?
    (opclass=sqlName)?
;

postgresqlOnConflictAction:
      postgresqlOnConflictActionDoNothing
    | postgresqlOnConflictActionDoUpdate
;

postgresqlOnConflictActionDoNothing:
    K_DO K_NOTHING
;

postgresqlOnConflictActionDoUpdate:
    K_DO K_UPDATE K_SET
    (
          columns+=sqlName EQUALS exprs+=expression
        | LPAR columns+=sqlName (COMMA columns+=sqlName)* RPAR
            EQUALS K_ROW? LPAR exprs+=expression (COMMA exprs+=expression)* RPAR
    )
    (K_WHERE cond=condition)?
;


/*----------------------------------------------------------------------------*/
// Lock table
/*----------------------------------------------------------------------------*/

lockTableStatement:
    lockTable sqlEnd
;

lockTable:
    K_LOCK K_TABLE? K_ONLY? // PostgreSQL: optional table, only
        objects+=lockTableObject (COMMA objects+=lockTableObject)*
        K_IN lockMode K_MODE lockTableWaitOption?
;

lockTableObject:
    (schema=sqlName PERIOD)? table=sqlName AST? // PostgreSQL: optional *
    (partitionExtensionClause|COMMAT dblink=qualifiedName)?
;

partitionExtensionClause:
      K_PARTITION LPAR name=sqlName RPAR                    # partitionLock
    | K_PARTITION K_FOR LPAR
        keys+=expression (COMMA keys+=expression)* RPAR     # partitionLock
    | K_SUBPARTITION LPAR name=sqlName RPAR                 # subpartitionLock
    | K_SUBPARTITION K_FOR LPAR
        keys+=expression (COMMA keys+=expression)* RPAR     # subpartitionLock
;

lockMode:
      K_ROW K_SHARE                 # rowShareLockMode
    | K_ROW K_EXCLUSIVE             # rowExclusiveLockMode
    | K_SHARE K_UPDATE              # shareUpdateLockMode // OracleDB only
    | K_SHARE                       # shareLockMode
    | K_SHARE K_ROW K_EXCLUSIVE     # shareRowExclusiveLockMode
    | K_EXCLUSIVE                   # exclusiveLockMode
    | K_ACCESS K_SHARE              # accessShareMode // PostgreSQL
    | K_SHARE K_UPDATE K_EXCLUSIVE  # shareUpdateExclusiveMode // PostgreSQL
    | K_ACCESS K_EXCLUSIVE          # accessExclusiveMode // PostgreSQL
;

lockTableWaitOption:
      K_NOWAIT                      # nowaitLockOption
    | K_WAIT waitSeconds=expression # waitLockOption
;

/*----------------------------------------------------------------------------*/
// Merge
/*----------------------------------------------------------------------------*/

mergeStatement:
    merge sqlEnd
;

merge:
    withClause? // PostgreSQL
    {unhideFirstHint();} K_MERGE hint?
    mergeIntoClause
    mergeUsingClause
    K_ON (
          LPAR cond=condition RPAR  // OracleDB
        | cond=condition            // PostgreSQL
    )
    (
          mergeUpdateClause mergeInsertClause?  // OracleDB
        | mergeInsertClause                     // OracleDB
        | mergeWhenClause+                      // PostgreSQL
    )
    errorLoggingClause?
;

// artifical clause, undocumented: database link and subquery
// simplified using database link and subquery
mergeIntoClause:
    K_INTO K_ONLY? dmlTableExpressionClause K_AS? talias=sqlName? // PostgreSQL: only, as
;

// artifical clause, undocumented: database link, table function
// simplified using values_clause, subquery, database link, table function as query_table_expression
mergeUsingClause:
    K_USING K_ONLY? queryTableExpression K_AS? talias=sqlName? // PostgreSQL: only, as
;

mergeUpdateClause:
    K_WHEN K_MATCHED K_THEN K_UPDATE K_SET
    columns+=mergeUpdateColumn (COMMA columns+=mergeUpdateColumn)*
    updateWhere=whereClause?
    (K_DELETE deleteWhere=whereClause)?
;

// artifical clause
mergeUpdateColumn:
    column=qualifiedName EQUALS expr=expression
;

mergeInsertClause:
    K_WHEN K_NOT K_MATCHED K_THEN K_INSERT
    (LPAR columns+=qualifiedName (COMMA columns+=qualifiedName)* RPAR)?
    K_VALUES LPAR values+=expression (COMMA values+=expression)* RPAR whereClause?
;

// PostgreSQL
mergeWhenClause:
      K_WHEN K_MATCHED (K_AND cond=condition)? K_THEN (mergeUpdate | mergeDelete | K_DO K_NOTHING)
    | K_WHEN K_NOT K_MATCHED (K_AND cond=condition)? K_THEN (mergeInsert | K_DO K_NOTHING)
;

// PostgreSQL
mergeUpdate:
    K_UPDATE K_SET
    (
          columns+=qualifiedName EQUALS exprs+=expression
        | LPAR columns+=qualifiedName (COMMA columns+=qualifiedName)* RPAR
            EQUALS LPAR exprs+=expression (COMMA exprs+=expression)* RPAR
    )
;

// PostgreSQL
mergeDelete:
    K_DELETE
;

// PostgreSQL
mergeInsert:
    K_INSERT (LPAR columns+=qualifiedName (COMMA columns+=qualifiedName)* RPAR)?
    (K_OVERRIDING (K_SYSTEM | K_USER) K_VALUE)?
    (K_VALUES LPAR values+=expression (COMMA values+=expression)* RPAR | K_DEFAULT K_VALUES)
;

/*----------------------------------------------------------------------------*/
// Select
/*----------------------------------------------------------------------------*/

selectStatement:
      select sqlEnd
    | LPAR select RPAR // in cursor for loop - TODO: remove with PL/SQL block support, see https://github.com/IslandSQL/IslandSQL/issues/29
;

select:
    subquery
    subqueryRestrictionClause? (K_CONTAINER_MAP|K_CONTAINERS_DEFAULT)? // TODO: remove with create view support, see https://github.com/IslandSQL/IslandSQL/issues/35
    (K_WITH K_NO? K_DATA)? // PostgreSQL, TODO: remove with create view support, see see https://github.com/IslandSQL/IslandSQL/issues/35
;

// moved with_clause from query_block to support main query in parenthesis (works, undocumented)
// undocumented: for_update_clause can be used before order_by_clause (but not with row_limiting_clause)
// PostgreSQL allows to use the values_clause as subquery in the with_clause (e.g. with set_operator)
// PostgreSQL allows multiple forUpdateClauses scope is a table not a column as in OracleDB
subquery:
      withClause? queryBlock forUpdateClause+ orderByClause? rowLimitingClause?         # subqueryQueryBlock
    | withClause? queryBlock orderByClause? rowLimitingClause? forUpdateClause*         # subqueryQueryBlock
    | left=subquery setOperator right=subquery                                          # subquerySet
    | withClause? LPAR subquery RPAR forUpdateClause+ orderByClause? rowLimitingClause? # subqueryParen
    | withClause? LPAR subquery RPAR orderByClause? rowLimitingClause? forUpdateClause* # subqueryParen
    | valuesClause orderByClause? rowLimitingClause?                                    # subqueryValues
    | K_TABLE K_ONLY? tableName=qualifiedName AST?                                      # tableQueryBlock // PostgreSQL
;

queryBlock:
    {unhideFirstHint();} K_SELECT hint?
    queryBlockSetOperator?
    selectList? // PostgreSQL: select_list is optional, e.g. in subquery of exists condition
    (intoClause | bulkCollectIntoClause | postgresqlIntoClause)? // in PL/SQL only
    fromClause? // starting with OracleDB 23c the from clause is optional
    whereClause?
    hierarchicalQueryClause?
    groupByClause?
    modelClause?
    windowClause?
;

hint:
      SL_HINT
    | ML_HINT
;

withClause:
    K_WITH
    (
          (plsqlDeclarations)+
        | (plsqlDeclarations)* factoringClause (COMMA factoringClause)*
        | K_RECURSIVE factoringClause (COMMA factoringClause)*              // PostgreSQL
    )
;

// only definitions are allowed in plsql_declarations (no forward declarations)
// the name of the clause is misleading
plsqlDeclarations:
      functionDefinition
    | procedureDefinition
;

factoringClause:
      subqueryFactoringClause
    | subavFactoringClause
;

subqueryFactoringClause:
    queryName=sqlName (LPAR caliases+=sqlName (COMMA caliases+=sqlName)* RPAR)?
    K_AS
    (K_NOT? K_MATERIALIZED)? // PostgreSQL
    LPAR
        (
              subquery       // including values for OracleDB and PostgreSQL
            | insert         // PostgreSQL
            | update         // PostgreSQL
            | delete         // PostgreSQL
        )
    RPAR
    searchClause?
    cycleClause?
;

// Unlike OracleDB, PostgreSQL allows the values_clause without table/column alias in from_clause
// in this case the ANTLR identifies the required parenthesis as part of a scalar subquery
// Using the values_clause without table/column alias is primarily used in the with_clause
valuesClause:
      LPAR K_VALUES rows+=valuesRow (COMMA rows+=valuesRow)* RPAR
        K_AS? talias=sqlName LPAR caliases+=sqlName (COMMA caliases+=sqlName)* RPAR     # valuesClauseQualified
    | K_VALUES rows+=valuesRow (COMMA rows+=valuesRow)*                                 # valuesClauseDefault
;

// undocumented, first value in the first row does not need parentheses (in OracleDB only)
valuesRow:
      LPAR exprs+=expression (COMMA exprs+=expression)* RPAR
    | exprs+=expression
;

searchClause:
    K_SEARCH (K_DEPTH|K_BREADTH) K_FIRST K_BY
    columns+=searchColumn (COMMA columns+=searchColumn)* K_SET orderingColumn=sqlName
;

searchColumn:
    calias=sqlName (K_ASC|K_DESC)? (K_NULLS (K_FIRST|K_LAST))?
;

cycleClause:
    K_CYCLE caliases+=sqlName (COMMA caliases+=sqlName)*
    K_SET cycleMarkCalias=sqlName
    (K_TO cycleValue=expression K_DEFAULT noCycleValue=expression)? // Postgresql: optional
    (K_USING cyclePathColName=expression)? // OracleDB: not supported, Postgresql: mandatory
;

subavFactoringClause:
    subavName=sqlName K_ANALYTIC K_VIEW K_AS LPAR subAvClause RPAR
;

subAvClause:
    K_USING (schema=sqlName PERIOD)? baseAvName=sqlName
    hierarchiesClause?
    filterClauses?
    addMeasClause?
;

hierarchiesClause:
    K_HIERARCHIES LPAR (items+=hierarchyRef (COMMA items+=hierarchyRef)*)? RPAR
;

filterClauses:
    K_FILTER K_FACT LPAR filters+=filterClause (COMMA filters+=filterClause)* RPAR
;

// combinded filter_clause and hier_ids
filterClause:
    ids+=hierId (COMMA ids+=hierId)* K_TO predicate=condition
;

hierId:
      K_MEASURES    # hierIdMeasures
    | hierarchyRef  # hierIdDim
;

addMeasClause:
    K_ADD K_MEASURES LPAR measures+=cubeMeas (COMMA measures+=cubeMeas)* RPAR
;

// removed duplicate measName (defined in calcMeasClause, documentation bug)
cubeMeas:
      baseMeasClause
    | calcMeasClause
;

// added measName here (from cubeMeas)
// verified syntax in livesql.oracle.com with create analyitc view statements (documentation bug)
// clause is not applicable for an inline analytic view (addMeasClause) since it's based
// on an existing analytic view and facts cannot be added afterwards.
// see also https://forums.oracle.com/ords/apexds/post/inline-analytic-view-missing-example-for-base-meas-clause-9465
baseMeasClause:
    measName=sqlName (K_FACT baseMeas=sqlName)? measAggregateClause?
;

measAggregateClause:
    K_AGGREGATE K_BY aggrFunction=sqlName
;

calcMeasClause:
    measName=sqlName K_AS LPAR expr=expression RPAR
;

selectList:
    items+=selectItem (COMMA items+=selectItem)*
;

// all variants handled as expression
selectItem:
    expr=expression (K_AS? cAlias=sqlName)?
;

whereClause:
    K_WHERE cond=condition
;

hierarchicalQueryClause:
      K_CONNECT K_BY K_NOCYCLE? connectByCond=condition (K_START K_WITH startWithCond=condition)?
    | K_START K_WITH startWithCond=condition K_CONNECT K_BY K_NOCYCLE? connectByCond=condition
;

// PostgreSQL: all, distinct
groupByClause:
      K_GROUP K_BY (K_ALL|K_DISTINCT)? items+=groupByItem (COMMA items+=groupByItem)* (K_HAVING cond=condition)?
    | K_HAVING cond=condition (K_GROUP K_BY (K_ALL|K_DISTINCT)? items+=groupByItem (COMMA items+=groupByItem)*)? // undocumented, but allowed in OracleDB
;

// rollupCubeClause treated as expression
groupByItem:
      expression
    | groupingSetsClause
;

groupingSetsClause:
    K_GROUPING K_SETS LPAR groupingSets+=expression (COMMA groupingSets+=expression)* RPAR
;

modelClause:
    K_MODEL cellReferenceOptions? returnRowsClause? referenceModels+=referenceModel* mainModel
;

cellReferenceOptions:
      (K_IGNORE|K_KEEP) K_NAV K_UNIQUE (K_DIMENSION|K_SINGLE K_REFERENCE)
    | (K_IGNORE|K_KEEP) K_NAV
    | K_UNIQUE (K_DIMENSION|K_SINGLE K_REFERENCE)
;

returnRowsClause:
    K_RETURN (K_UPDATED|K_ALL) K_ROWS
;

referenceModel:
    K_REFERENCE referenceModelName=sqlName K_ON LPAR subquery RPAR
    modelColumnClauses cellReferenceOptions?
;

modelColumnClauses:
    (K_PARTITION K_BY LPAR partitionColumns+=modelColumn (COMMA partitionColumns+=modelColumn)* RPAR)?
    K_DIMENSION K_BY LPAR dimensionColumns+=modelColumn (COMMA dimensionColumns+=modelColumn)* RPAR
    K_MEASURES LPAR measuresColumns+=modelColumn (COMMA measursColumns+=modelColumn)* RPAR
;

modelColumn:
    expr=expression (K_AS? alias=sqlName)?
;

mainModel:
    (K_MAIN mainModelName=sqlName)?
    modelColumnClauses
    cellReferenceOptions?
    modelRuleClause?
;
modelRuleClause:
    K_RULES? (K_UPDATE|K_UPSERT K_ALL?)? ((K_AUTOMATIC|K_SEQUENTIAL) K_ORDER)? modelIterateClause?
    LPAR modelRules+=modelRule (COMMA modelRules+=modelRule)* RPAR
;

// undocumented: parenthesis around condition are documented, but not necessary
modelIterateClause:
    K_ITERATE LPAR iterate=expression RPAR (K_UNTIL cond=condition)?
;

modelRule:
    (K_UPDATE|K_UPSERT K_ALL?)? cellAssignment orderByClause? EQUALS expr=expression
;

cellAssignment:
    column=expression LSQB (cellAssignmentList|multiColumnForLoop) RSQB
;

cellAssignmentList:
    values+=callAssignmentListItem (COMMA values+=callAssignmentListItem)*
;

callAssignmentListItem:
      condition
    | singleColumnForLoop
;

singleColumnForLoop:
    K_FOR dimensionColumn=sqlName
    (
          K_IN LPAR literals+=singleColumnForLoopLiteral (COMMA literals+=singleColumnForLoopLiteral)* RPAR
        | K_IN LPAR subquery RPAR
        | (K_LIKE pattern=singleColumnForLoopPattern)?
            K_FROM fromLiteral=singleColumnForLoopLiteral
            K_TO toLiteral=singleColumnForLoopLiteral (K_INCREMENT|K_DECREMENT) incrementBy=expression
    )
;

singleColumnForLoopLiteral:
      string
    | NUMBER
    | sqlName
    | expression // undocumented
;

singleColumnForLoopPattern:
      string
    | sqlName
;

multiColumnForLoop:
    K_FOR LPAR dimensionColumns+=sqlName (COMMA dimensionColumns+=sqlName)* RPAR
    K_IN LPAR literals+=multiColumnForLoopLiteral (COMMA literals+=multiColumnForLoopLiteral)* RPAR
    K_IN LPAR subquery RPAR
;

multiColumnForLoopLiteral:
    LPAR literals+=singleColumnForLoopLiteral (COMMA literals+=singleColumnForLoopLiteral)* RPAR
;

windowClause:
    K_WINDOW selectWindows+=selectWindow (COMMA selectWindows+=selectWindow)*
;

// wrong documentation, missing required parentheses around windowSpecification
selectWindow:
    windowName=sqlName K_AS LPAR windowSpecification RPAR
;

windowSpecification:
    existingWindowName=sqlName?
    queryPartitionClause?
    orderByClause?
    windowingClause?
;

queryBlockSetOperator:
      K_DISTINCT                                                                # distinctQbOperator
    | K_DISTINCT K_ON LPAR exprs+=expression (COMMA exprs+=expression)* RPAR    # distinctOnQbOperator // PostgreSQL
    | K_UNIQUE                                                                  # distinctQbOperator
    | K_ALL                                                                     # allQbOperator
;

// PostreSQL allows the use of distinct
setOperator:
      K_UNION     (K_ALL|K_DISTINCT)?    # unionSetOperator
    | K_INTERSECT (K_ALL|K_DISTINCT)?    # intersectSetOperator
    | K_MINUS     (K_ALL|K_DISTINCT)?    # minusSetOperator         // OracleDB
    | K_EXCEPT    (K_ALL|K_DISTINCT)?    # minusSetOperator
;

// only in PL/SQL
intoClause:
    K_INTO variables+=expression (COMMA variables+=expression)*
;

// only in PL/SQL
bulkCollectIntoClause:
    K_BULK K_COLLECT K_INTO variables+=expression (COMMA variables+=expression)*
;

postgresqlIntoClause:
    K_INTO (K_TEMPORARY|K_TEMP|K_UNLOGGED)? K_TABLE tableName=qualifiedName
;

fromClause:
    K_FROM items+=fromItem (COMMA items+=fromItem)*
;

// handles table aliases for all from items, simplifies from items in parentheses
fromItem:
      tableReference tableAlias?        # tableReferenceFromItem
    | fromItem joins+=joinVariant+      # joinClause
    | inlineAnalyticView tableAlias?    # inlineAnalyticViewFromItem
    | LPAR fromItem RPAR tableAlias?    # parenFromItem
;

// PostgreSQL allows caliases
// Handle all kind of table alias, allows more cominatqion than the underlyinging DBMSs
tableAlias:
      K_AS? tAlias=sqlName (LPAR caliases+=sqlName (COMMA caliases+=sqlName)* RPAR)? // OracleDB, PostgreSQL
    | K_AS? talias=sqlName LPAR cdefs+=postgresqlColumnDefinition (COMMA cdfs+=postgresqlColumnDefinition)* RPAR // PostgreSQL (function)
    | K_AS LPAR cdefs+=postgresqlColumnDefinition (COMMA cdfs+=postgresqlColumnDefinition)* RPAR // PostgreSQL (function)
;

postgresqlColumnDefinition:
    columnName=sqlName dataType
;

// containers_clause and shards_clause handeled as queryTableExpression (functions named containers/shards)
// undocumented: use of optional AS in json_table (query_table_expression)
// undocumented: use of invalid t_alias before row_pattern_clause, see issue #74
tableReference:
      K_ONLY LPAR qte=queryTableExpression RPAR flashbackQueryClause?
        (invalidTalias=sqlName? (pivotClause|unpivotClause|rowPatternClause))?
    | K_ONLY? qte=queryTableExpression flashbackQueryClause? // Postgresql: only (allowed without parentheses)
         (invalidTalias=sqlName? (pivotClause|unpivotClause|rowPatternClause))?
;

// using table for query_name, table, view, mview, hierarchy
queryTableExpression:
      (schema=sqlName PERIOD)? table=sqlName
        (
              modifiedExternalTable
            | partitionExtensionClause
            | COMMAT dblink=qualifiedName
            | hierarchiesClause
            | AST // PostgreSQL
        )? sampleClause?
    | inlineExternalTable sampleClause?
    | expr=expression (LPAR PLUS RPAR)? // handle qualified function expressions, table_collection_expression
    | K_LATERAL? LPAR subquery subqueryRestrictionClause? RPAR
    | postgresqlTableExpression
    | values=valuesClause // handled here to simplifiy grammar, even if pivot_clause etc. are not applicable
;

// table/column aliases are part of from_item
// plain table function is handled in query_table_expression
postgresqlTableExpression:
       K_LATERAL (schema=sqlName PERIOD)? expr=functionExpression (K_WITH K_ORDINALITY)?
     | (schema=sqlName PERIOD)? expr=functionExpression K_WITH K_ORDINALITY
     | K_LATERAL? K_ROWS K_FROM LPAR exprs+=rowsFromFunction (COMMA exprs+=rowsFromFunction)* RPAR (K_WITH K_ORDINALITY)?
;

rowsFromFunction:
    expr=functionExpression (K_AS LPAR cdefs+=postgresqlColumnDefinition (COMMA cdfs+=postgresqlColumnDefinition)* RPAR)?
;

// grammar definition in SQL Language Reference 19c/21c/23c is wrong, added LPAR/RPAR
modifiedExternalTable:
    K_EXTERNAL K_MODIFY LPAR properties+=modifyExternalTableProperties+ RPAR
;

// implemented as alternatives, all are technically optional
// grammar definition in SQL Language Reference 19c/21c/23c is wrong regarding "access parameters"
// it the similar as in externalTableDataProps. We use it here with the same restrictions.
modifyExternalTableProperties:
      K_DEFAULT K_DIRECTORY dir=sqlName                     # defaultDirectoryModifyExternalTableProperty
    | K_LOCATION LPAR locations+=externalFileLocation
        (COMMA locations+=externalFileLocation)* RPAR       # locationModifyExternalTableProperty
    | K_ACCESS K_PARAMETERS
        (
              LPAR opaqueFormatSpec=expression RPAR // only as string and variable
            | LPAR nativeOpaqueFormatSpec RPAR // driver-specific grammar, cannot add to array field, accessible via children
        )                                                   # accessParameterModifyExternalTableProperty
    | K_REJECT K_LIMIT rejectLimit=expression               # rejectLimitModifyExternalTableProperty
;

externalFileLocation:
      directory=sqlName
    | (directory=sqlName COLON)? locationSpecifier=string
;

sampleClause:
      K_SAMPLE K_BLOCK? LPAR samplePercent=expression RPAR (K_SEED LPAR seedValue=expression RPAR)? // OracleDB
    | K_TABLESAMPLE samplingMethod=sqlName LPAR args+=expression (COMMA args+=expression)* RPAR (K_REPEATABLE LPAR seedValue=expression RPAR)? // PostgreSQL
;

inlineExternalTable:
    K_EXTERNAL LPAR
    LPAR columns+=columnDefinition (COMMA columns+=columnDefinition)* RPAR
    inlineExternalTableProperties RPAR
;

inlineExternalTableProperties:
    (K_TYPE accessDriverType=sqlName)? properties+=externalTableDataProps+
    (K_REJECT K_LIMIT limit=expression)?
;

externalTableDataProps:
      K_DEFAULT K_DIRECTORY directory=sqlName               # defaultDirectoryExternalTableDataProperty
    | K_ACCESS K_PARAMETERS
        (
              LPAR opaqueFormatSpec=expression RPAR // only as string and variable
            | LPAR nativeOpaqueFormatSpec RPAR // driver-specific grammar, cannot add to array field, accessible via children
            | K_USING K_CLOB subquery
        )                                                   # accessParameterExternalTableDataProperty
    | K_LOCATION LPAR locations+=externalFileLocation
        (COMMA locations+=externalFileLocation)* RPAR       # locationExternalTableDataProperty
;

// We do not fully parse the unquoted opaque_format_spec. The reason is that the grammar
// is driver specific, e.g. ORACLE_DATAPUMP, ORACLE_HDFS, ORACLE_HIVE. The grammer is
// only documented in Oracle Database Utilities. See
// https://docs.oracle.com/en/database/oracle/oracle-database/23/sutil/oracle-external-tables-concepts.html#GUID-07D30CE6-128D-426F-8B76-B13E1C53BD5A
// providing a list of tokens is considered the final solution.
nativeOpaqueFormatSpec:
    .+?
;

// minimal clause for use in inlineExternalTable; the following is missing:
// default clause, identity_clause, encryption_spec, inline_constraint, inline_ref_constraint
columnDefinition:
    column=sqlName typeName=datatypeDomain
    K_RESERVABLE? (K_COLLATE collate=sqlName)? K_SORT? (K_VISIBLE|K_INVISIBLE)?
;

// simplified, reservable and collate are part of column_definition
datatypeDomain:
      dataType (K_DOMAIN (domainOwner=sqlName PERIOD)?  domainName=sqlName)?
    | K_DOMAIN (domainOwner=sqlName PERIOD)? domainName=sqlName
;

subqueryRestrictionClause:
    K_WITH (K_READ K_ONLY | K_CHECK K_OPTION) (K_CONSTRAINT constraintName=sqlName)?
;

// handle MINVALUE and MAXVALUE as sqlName in expression
flashbackQueryClause:
      K_VERSIONS K_BETWEEN (K_SCN|K_TIMESTAMP)
        minExpr=expression K_AND maxExpr=expression                         # versionsFlashbackQueryClause
    | K_VERSIONS K_PERIOD K_FOR validTimeColumn=sqlName K_BETWEEN
        minExpr=expression K_AND maxExpr=expression                         # versionsFlashbackQueryClause
    | K_AS K_OF (K_SCN|K_TIMESTAMP) asOfExpr=expression                     # asOfFlashbackQueryClause
    | K_AS K_OF K_PERIOD K_FOR validTimeColumn=sqlName asOfExpr=expression  # asOfFlashbackQueryClause
;

pivotClause:
    K_PIVOT K_XML? LPAR
    aggregateFunctions+=pivotClauseAggregateFunction (COMMA aggregateFunctions+=pivotClauseAggregateFunction)*
    pivotForClause pivotInClause
    RPAR
;

pivotClauseAggregateFunction:
    aggregateFunction=sqlName LPAR expr=expression RPAR (K_AS? alias=sqlName)?
;

pivotForClause:
    K_FOR
    (
          columns+=sqlName
        | LPAR columns+=sqlName (COMMA columns+=sqlName)* RPAR
    )
;

pivotInClause:
    K_IN LPAR (query=subquery | (exprs+=pivotInClauseExpression (COMMA exprs+=pivotInClauseExpression)*)) RPAR
;

pivotInClauseExpression:
    expr=expression (K_AS? alias=sqlName)?
;

unpivotClause:
    K_UNPIVOT ((K_INCLUDE|K_EXCLUDE) K_NULLS)? LPAR
    (
          columns+=sqlName
        | LPAR columns+=sqlName (COMMA columns+=sqlName)* RPAR
    )
    pivotForClause unpivotInClause
    RPAR
;

unpivotInClause:
    K_IN LPAR columns+=unpivotInClauseColumn (COMMA columns+=unpivotInClauseColumn)* RPAR
;

unpivotInClauseColumn:
     column=expression (K_AS? literal=expression)?
;

rowPatternClause:
    K_MATCH_RECOGNIZE LPAR
        rowPatternPartitionBy?
        rowPatternOrderBy?
        rowPatternMeasures?
        rowPatternRowsPerMatch?
        rowPatternSkipTo?
        K_PATTERN LPAR rowPattern RPAR
        rowPatternSubsetClause?
        K_DEFINE rowPatternDefinitionList
    RPAR
;

rowPatternPartitionBy:
    K_PARTITION K_BY columns+=sqlName (COMMA columns+=sqlName)*
;

// undocumented: use of orderByItem
rowPatternOrderBy:
    K_ORDER K_BY columns+=orderByItem (COMMA columns+=orderByItem)*
;

rowPatternMeasures:
    K_MEASURES columns+=rowpatternMeasureColumn (COMMA columns+=rowpatternMeasureColumn)*
;

// undocumented: optionality of "as"
rowpatternMeasureColumn:
    expr=expression K_AS? cAlias=sqlName
;

rowPatternRowsPerMatch:
    (K_ONE K_ROW|K_ALL K_ROWS) K_PER K_MATCH rowPatternRowsPerMatchOption?
;

// undocumented artificial clause, see issue #75
rowPatternRowsPerMatchOption:
      K_SHOW K_EMPTY K_MATCHES  # rowPatternRowsPerMatchShowEmptyMatches
    | K_OMIT K_EMPTY K_MATCHES  # rowPatternRowsPerMatchOmitEmptyMatches
    | K_WITH K_UNMATCHED K_ROWS # rowPatternRowsPerMatchWithUnmatchedRows
;

rowPatternSkipTo:
    K_AFTER K_MATCH K_SKIP
    (
          (K_TO K_NEXT|K_PAST K_LAST) K_ROW
        | K_TO (K_FIRST|K_LAST)? variableName=sqlName
    )
;

rowPattern:
    rowPatterns+=rowPatternTerm+
;

// simplified, content of row_pattern, row_pattern_term, row_pattern_factor, row_pattern_primary
rowPatternTerm:
        variableName=sqlName rowPatternQuantifier?
      | DOLLAR rowPatternQuantifier?
      | HAT rowPatternQuantifier?
      | LPAR rowPattern? RPAR rowPatternQuantifier?
      | LCUB MINUS rowPattern MINUS RCUB rowPatternQuantifier?
      | left=rowPatternTerm VERBAR right=rowPatternTerm rowPatternQuantifier?
      | rowPatternPermute rowPatternQuantifier?
;

rowPatternPermute:
    K_PERMUTE LPAR rowPattern (COMMA rowPattern)* RPAR
;

rowPatternQuantifier:
      AST QUEST?                                        # zeroOrMoreRowPatternQuantifier
    | PLUS QUEST?                                       # oneOrMoreRowPatternQuantifier
    | QUEST QUEST?                                      # zeroOreOneRowPatternQuantifier
    | LCUB from=NUMBER? COMMA to=NUMBER? RCUB QUEST?    # rangeRowPatternQuantifier
    | LCUB count=NUMBER RCUB                            # exactRowPatternQuantifier
;

rowPatternSubsetClause:
    K_SUBSET items+=rowPatternSubsetItem (COMMA items+=rowPatternSubsetItem)*
;

rowPatternSubsetItem:
    variable=sqlName EQUALS LPAR variables+=sqlName (COMMA variables+=sqlName)* RPAR
;

rowPatternDefinitionList:
    definitions+=rowPatternDefinition (COMMA definitions+=rowPatternDefinition)*
;

rowPatternDefinition:
    variableName=sqlName K_AS cond=condition
;

joinVariant:
      innerCrossJoinClause
    | outerJoinClause
    | crossOuterApplyClause
    | nestedClause
;

// undocumented: forItem instead of tableReference
innerCrossJoinClause:
      K_INNER? K_JOIN fromItem
      (
            K_ON cond=condition
          | K_USING LPAR columns+=qualifiedName (COMMA columns+=qualifiedName)* RPAR (K_AS joinUsingAlias=sqlName)? // PostgreSQL: join_using_alias
      )
    | K_CROSS K_JOIN fromItem
    | K_NATURAL K_INNER? K_JOIN fromItem
;

// undocumented: forItem instead of tableReference
outerJoinClause:
    left=queryPartitionClause? K_NATURAL? outerJoinType K_JOIN
    fromItem right=queryPartitionClause?
    (
          K_ON cond=condition
        | K_USING LPAR columns+=qualifiedName (COMMA columns+=qualifiedName)* RPAR (K_AS joinUsingAlias=sqlName)? // PostgreSQL: join_using_alias
    )?
;

outerJoinType:
    (K_FULL|K_LEFT|K_RIGHT) K_OUTER?
;

crossOuterApplyClause:
    (K_CROSS|K_OUTER) K_APPLY fromItem
;

// "equivalent to a left-outer ANSI join with JSON_TABLE"
// table alias is not documnted
nestedClause:
    K_NESTED K_PATH? identifier=sqlName
        (
              (PERIOD keys+=jsonObjectKey)+
            | (COMMA jsonBasicPathExpression)
        )? jsonTableOnErrorClause? jsonTableOnEmptyClause? jsonColumnsClause talias=sqlName?
;

// parenthesis around sub_av_clause is not documented, but required
// as is documented, but does not work, keeping it since it is optional
inlineAnalyticView:
    K_ANALYTIC K_VIEW LPAR subAvClause RPAR (K_AS? alias=sqlName)?
;

// ensure that at least one alternative is not optional
// make row/rows optional in offset for PostgreSQL
rowLimitingClause:
      K_OFFSET offset=expression (K_ROW | K_ROWS)?
    | (K_OFFSET offset=expression (K_ROW | K_ROWS)?)?
      K_FETCH (K_FIRST | K_NEXT) (rowcount=expression | percent=expression K_PERCENT)?
      (K_ROW | K_ROWS) (K_ONLY | K_WITH K_TIES)
    | K_LIMIT (rowcount=expression|K_ALL) (K_OFFSET offset=expression (K_ROW | K_ROWS)?)? // PostgreSQL
    | (K_OFFSET offset=expression (K_ROW | K_ROWS)?) K_LIMIT (rowcount=expression|K_ALL)? // PostgreSQL
;

forUpdateClause:
    K_FOR
    (
          K_UPDATE              // OracleDB, PostgreSQL
        | K_NO K_KEY K_UPDATE   // PostgreSQL
        | K_SHARE               // PostgreSQL
        | K_KEY K_SHARE         // PostgreSQL
    )
    (K_OF columns+=forUpdateColumn (COMMA columns+=forUpdateColumn)*)? // PostgreSQL: tables instead of columns
    (
          K_NOWAIT
        | K_WAIT wait=expression
        | K_SKIP K_LOCKED
    )?
;

forUpdateColumn:
    ((schema=sqlName PERIOD)? table=sqlName PERIOD)? column=sqlName
;

/*----------------------------------------------------------------------------*/
// Update
/*----------------------------------------------------------------------------*/

updateStatement:
    update sqlEnd
;

update:
    withClause?                                         // PostgreSQL
    {unhideFirstHint();} K_UPDATE hint?
    (
          K_ONLY? dmlTableExpressionClause AST?         // PostgreSQL: only, *
        | K_ONLY LPAR dmlTableExpressionClause RPAR
    ) K_AS? talias=sqlName?                             // PostgreSQL: as
    updateSetClause
    fromUsingClause?
    whereClause?
    orderByClause?
    returningClause?
    errorLoggingClause?
;

// including update statement exentions in PL/SQL ("current of" is part of expression)
updateSetClause:
    K_SET
    (
          items+=updateSetClauseItem (COMMA items+=updateSetClauseItem)*
        | K_VALUE LPAR talias=sqlName RPAR EQUALS (expr=expression | LPAR query=subquery RPAR)
        | K_ROW EQUALS expr=expression
    )
;

updateSetClauseItem:
      LPAR columns+=qualifiedName (COMMA columns+=qualifiedName)* RPAR
        EQUALS LPAR query=subquery RPAR                                             # updateSetClauseItemColumnList
    | LPAR columns+=qualifiedName (COMMA columns+=qualifiedName)* RPAR
        EQUALS K_ROW? LPAR exprs+=expression (COMMA exprs+=expression)* RPAR        # updateSetClauseItemPostgresqlRow
    | LPAR columns+=qualifiedName RPAR
        EQUALS (expr=expression | LPAR query=subquery RPAR)                         # updateSetClauseItemColumn
    | columns+=qualifiedName EQUALS (expr=expression | LPAR query=subquery RPAR)    # updateSetClauseItemColumn
;

/*----------------------------------------------------------------------------*/
// Empty
/*----------------------------------------------------------------------------*/

// pseudo statement that is ignored in PostgreSQL
emptyStatement:
      SEMI
    | SOL
;

/*----------------------------------------------------------------------------*/
// PL/SQL Block Statement
/*----------------------------------------------------------------------------*/

// top level statement, expected to end on new line, slash
plsqlBlockStatement:
    labels+=label* plsqlBlock sqlEnd?
;

label:
    LT_LT labelName=sqlName GT_GT
;


// simplified grammar, do not distinguish between item_list_1 and item_list_2
declareSection:
    items+=itemlistItem+
;

// all items in item_list_1 and item_list_2 and package_item_list
itemlistItem:
      typeDefinition
    | cursorDeclaration
    | cursorDefinition
    | itemDeclaration
    | functionDeclaration
    | functionDefinition
    | procedureDeclaration
    | procedureDefinition
;

typeDefinition:
      collectionTypeDefinition
    | recordTypeDefinition
    | refCursorTypeDefinition
    | subtypeDefinition
;

collectionTypeDefinition:
    K_TYPE name=sqlName K_IS (
          assocArrayTypeDef
        | varrayTypeDef
        | nestedTableTypeDef
    ) SEMI
;

assocArrayTypeDef:
    K_TABLE K_OF type=plsqlDataType (K_NOT K_NULL)? K_INDEX K_BY indexType=dataType
;

plsqlDataType:
      K_REF dataType            # refPlsqlDataType
    | dataType PERCNT K_TYPE    # percentTypePlsqlDataType
    | dataType PERCNT K_ROWTYPE # percentRowtypePlsqlDataType
    | dataType                  # simplePlsqlDataType
;

varrayTypeDef:
    (K_VARRAY | K_VARYING K_ARRAY) LPAR size=expression RPAR K_OF type=plsqlDataType (K_NOT K_NULL)?
;

nestedTableTypeDef:
    K_TABLE K_OF type=plsqlDataType (K_NOT K_NULL)?
;

recordTypeDefinition:
    K_TYPE name=sqlName K_IS K_RECORD LPAR
        fieldDefinitions+=fieldDefinition (COMMA fieldDefinitions+=fieldDefinition)*
    LPAR SEMI
;

// no space allowed between ':' and '=' in OracleDB 23.3
fieldDefinition:
    field=sqlName type=dataType ((K_NOT K_NULL)? (COLON_EQUALS | K_DEFAULT) expr=expression)?
;

refCursorTypeDefinition:
    K_TYPE type=sqlName K_IS K_REF K_CURSOR (K_RETURN returnType=plsqlDataType)? SEMI
;

subtypeDefinition:
    K_SUBTYPE subtype=sqlName K_IS baseType=plsqlDataType
    (subtypeConstraint | K_CHARACTER K_SET characterSet=sqlName) SEMI
;

// precision, scaled are handled by plsqlDataType for baseType, require parentheses which is not documented anyway
// no space allowed between periods, however we allow it to avoid conflict with substitugion variable ending on period
subtypeConstraint:
    K_RANGE lowValue=expression PERIOD PERIOD highValue=expression
;

cursorDeclaration:
    K_CURSOR cursor=sqlName
        (LPAR parameters+=cursorParameterDec (COMMA parameters+=cursorParameterDec)* RPAR)?
        K_RETURN rowtype=plsqlDataType SEMI
;

cursorParameterDec:
    parameterName=sqlName K_IN? type=plsqlDataType ((COLON_EQUALS | K_DEFAULT) expr=expression)?
;

cursorDefinition:
    K_CURSOR cursor=sqlName
        (LPAR parameters+=cursorParameterDec (COMMA parameters+=cursorParameterDec)* RPAR)?
        (K_RETURN rowtype=plsqlDataType)? K_IS select SEMI
;

// simplified: collection_variable_decl, cursor_variable_declaration, record_variable_declaration
// and exception_declaration are handled as variable_declaration
itemDeclaration:
      constantDeclaration
    | variableDeclaration
;

constantDeclaration:
    constant=sqlName K_CONSTANT type=dataType (K_NOT K_NULL)? (COLON_EQUALS | K_DEFAULT) expr=expression SEMI
;

variableDeclaration:
    variable=sqlName type=plsqlDataType ((K_NOT K_NULL)? (COLON_EQUALS | K_DEFAULT) expr=expression)? SEMI
;

functionDeclaration:
    functionHeading options+=functionDeclarationOption* SEMI
;

// contains also options in package_function_declaration
functionDeclarationOption:
      accessibleByClause
    | deterministicClause
    | pipelinedClause
    | shardEnableClause
    | parallelEnableClause
    | resultCacheClause
;

deterministicClause:
    K_DETERMINISTIC
;

pipelinedClause:
    K_PIPELINED
        (
              K_USING (schema=sqlName PERIOD)? implementationType=sqlName
            | (K_ROW | K_TABLE) K_POLYMORPHIC (K_USING (schema=sqlName PERIOD)? implementationType=sqlName)?
        )?
;

parallelEnableClause:
    K_PARALLEL_ENABLE
        (
            LPAR K_PARTITION arg=sqlName K_BY
                (
                      K_ANY
                    | (K_HASH | K_RANGE) LPAR columns+=sqlName (COMMA columns+=sqlName)* streamingClause? RPAR
                    | K_VALUE LPAR columns+=sqlName RPAR
                )
            RPAR
        )?
;

streamingClause:
    (K_ORDER | K_CLUSTER) expr=expression K_BY LPAR columns+=sqlName (COMMA columns+=sqlName)* RPAR
;

resultCacheClause:
    K_RESULT_CACHE (K_RELIES_ON LPAR dataSources+=qualifiedName (COMMA dataSources+=qualifiedName)* RPAR)?
;

functionHeading:
    K_FUNCTION functionName=sqlName
        (LPAR parameters+=parameterDeclaration (COMMA parameters+=parameterDeclaration)* RPAR)?
        K_RETURN returnType=plsqlDataType
;

functionDefinition:
    functionHeading options+=functionDefinitionOption* (K_IS | K_AS) (declareSection? body | callSpec SEMI)
;

functionDefinitionOption:
      deterministicClause
    | pipelinedClause
    | parallelEnableClause
    | resultCacheClause
;

callSpec:
      javaDeclaration
    | javascriptDeclaration
    | cDeclaration
;

javaDeclaration:
    K_LANGUAGE K_JAVA K_NAME javaName=string
;

javascriptDeclaration:
    K_MLE
        (
              K_MODULE (schema=sqlName PERIOD)? moduleName=sqlName
                (K_ENV (envSchema=sqlName PERIOD)? envName=sqlName)? K_SIGNATURE signature=string
            | K_LANGUAGE languageName=sqlName code=string
        )
;

cDeclaration:
    (K_LANGUAGE K_C | K_EXTERNAL)
        (
              (K_NAME name=sqlName)? K_LIBRARY libName=sqlName
            | K_LIBRARY libName=sqlName (K_NAME name=sqlName)?
        )
        (K_AGENT K_IN LPAR args+=sqlName (COMMA args+=sqlName)* RPAR)?
        (K_WITH K_CONTEXT)?
        (K_PARAMETERS LPAR params+=externalParameter (COMMA params+=externalParameter) RPAR)?
;

externalParameter:
      K_CONTEXT
    | K_SELF (K_TDO | externalProperty)
    | (parameterName=sqlName | K_RETURN) externalProperty? (K_BY K_REFERENCE)? externalDataType=sqlName?
;

externalProperty:
      K_INDICATOR (K_STRUCT | K_TDO)?
    | K_LENGTH
    | K_DURATION
    | K_MAXLEN
    | K_CHARSETID
    | K_CHARSETFORM
;

parameterDeclaration:
    parameter=sqlName
    (
          K_IN? type=plsqlDataType ((COLON_EQUALS | K_DEFAULT) expr=expression)?
        | K_IN? K_OUT K_NOCOPY? type=plsqlDataType
    )?
;

procedureDeclaration:
    procedureHeading options+=procedureOption* SEMI
;

// contains also options in package_procedure_declaration
procedureOption:
      accessibleByClause
    | defaultCollationClause
    | invokerRightsclause
;

accessibleByClause:
    K_ACCESSIBLE K_BY LPAR accessors+=accessor RPAR
;

accessor:
    unitKind? (schema=sqlName PERIOD) unitName=sqlName
;

unitKind:
      K_FUNCTION
    | K_PROCEDURE
    | K_PACKAGE
    | K_TRIGGER
    | K_TYPE
;

// the only documented option is using_nls_comp
defaultCollationClause:
    K_DEFAULT K_COLLATION collationOption=sqlName
;

invokerRightsclause:
    K_AUTHID (K_CURRENT_USER | K_DEFINER)
;

procedureHeading:
    K_PROCEDURE procedure=sqlName (LPAR parameters+=parameterDeclaration (COMMA parameters+=parameterDeclaration)* RPAR)?
;

procedureDefinition:
    procedureHeading options+=procedureOption* (K_IS | K_AS) (declareSection? body | callSpec SEMI)
;

body:
    K_BEGIN
    stmts+=plsqlStatement+
    (K_EXCEPTION exceptionHandlers+=exceptionHandler+)?
    K_END name=sqlName? SEMI
;

// collection_method_call is handled in procedure_call
plsqlStatement:
    labels+=label* (
          assignmentStatement
        | basicLoopStatement
        | caseStatement
        | closeStatment
        | continueStatement
        | cursorForLoopStatement
        | executeImmediateStatement
        | exitStatement
        | fetchStatement
        | forLoopStatement
        | forallStatement
        | gotoStatement
        | ifStatement
        | nullStatement
        | openStatement
        | openForStatement
        | pipeRowStatement
        | plsqlBlock
        | procedureCall
        | raiseStatement
        | returnStatement
        | selectIntoStatement
        | sqlStatement
        | whileLoopStatement
    )
;

assignmentStatement:
    target=expression COLON_EQUALS value=expression SEMI
;

basicLoopStatement:
    K_LOOP stmts+=plsqlStatement+ K_END K_LOOP name=sqlName? SEMI
;

caseStatement:
      simpleCaseStatement
    | searchedCaseStatement
;

simpleCaseStatement:
    K_CASE selector=expression whens+=simpleCaseStatementWhenClause+
    (K_ELSE elseStmts+=plsqlStatement+)? K_END K_CASE name=sqlName SEMI
;

simpleCaseStatementWhenClause:
    K_WHEN values+=whenClauseValue (COMMA values+=whenClauseValue)* K_THEN stmts+=plsqlStatement+
;

searchedCaseStatement:
    K_CASE whens+=searchedCaseStatementWhenClause+
    (K_ELSE elseStmts+=plsqlStatement+)? K_END K_CASE name=sqlName SEMI
;

searchedCaseStatementWhenClause:
    K_WHEN cond=condition K_THEN stmts+=plsqlStatement+
;

closeStatment:
    K_CLOSE COLON? cursor=qualifiedName SEMI
;

continueStatement:
    K_CONTINUE toLabel=sqlName? (K_WHEN cond=condition)? SEMI
;

// wrong documentation in 23.3 regarding parentheses for cursor parameters
cursorForLoopStatement:
    K_FOR record=sqlName K_IN (
          K_CURSOR LPAR params+=cursorParameterDec (COMMA params+=cursorParameterDec)* RPAR
        | LPAR select RPAR
    ) K_LOOP stmts+=plsqlStatement+ K_END K_LOOP name=sqlName? SEMI
;

executeImmediateStatement:
    executeImmediate SEMI
;

// required variant without ending on semicolon, used in forall_statement
executeImmediate:
    K_EXECUTE K_IMMEDIATE dynamicSqlStmt=expression (
        (intoClause | bulkCollectIntoClause) usingClause?

    )?
;

// wrong documentation in 23.3 regarding comma in bind_argument and optionality
usingClause:
    K_USING args+=bindArgument (COMMA args+=bindArgument)*
;

bindArgument:
    (
          K_IN K_OUT?
        | K_OUT
    )? arg=expression
;

exitStatement:
    K_EXIT toLabel=sqlName? (K_WHEN expr=expression)? SEMI
;

fetchStatement:
    K_FETCH COLON? cursor=qualifiedName (
          intoClause
        | bulkCollectIntoClause (K_LIMIT limit=expression)?
    ) SEMI
;

forLoopStatement:
    K_FOR iterator K_LOOP stmts+=plsqlStatement+ K_END K_LOOP name=sqlName? SEMI
;

iterator:
    firstIterand=iterandDecl (COMMA secondIterand=iterandDecl)? K_IN ctlSeq=iterationCtlSeq
;

iterandDecl:
    identifier=sqlName (K_MUTABLE | K_IMMUTABLE)? dataType?
;

iterationCtlSeq:
    controls+=qualIterationCtl (COMMA controls+=qualIterationCtl)*
;

qualIterationCtl:
    K_REVERSE? iterationControl predClauseSeq
;

iterationControl:
      steppedControl
    | singleExpressionControl
    | valuesOfControl
    | indicesOfControl
    | pairsOfControl
    | cursorIterationControl
;

// TODO: check optionality
predClauseSeq:
    (K_WHILE whileExpr=expression)? (K_WHEN whenExpr=expression)?
;

steppedControl:
    lowerBound=expression PERIOD PERIOD upperBound=expression (K_BY step=expression)?
;

singleExpressionControl:
    K_REPEAT? expr=expression
;

valuesOfControl:
    K_VALUES K_OF expr=expression
;

indicesOfControl:
    K_INDICES K_OF expr=expression
;

pairsOfControl:
    K_PAIRS K_OF expr=expression
;

cursorIterationControl:
    LPAR expr=expression RPAR
;

forallStatement:
    K_FORALL index=expression K_IN boundsClause (K_SAVE K_EXCEPTIONS)? stmt=forallDmlStatement SEMI
;

boundsClause:
      lowerBound=expression PERIOD PERIOD upperBound=expression                                                 # simpleBoundClause
    | K_INDICES K_OF collection=qualifiedName (K_BETWEEN lowerBound=expression K_AND upperBound=expression)?    # indicesBoundClause
    | K_VALUES K_OF collection=qualifiedName                                                                    # valuesBoundClause
;

forallDmlStatement:
      insert
    | update
    | delete
    | merge
    | executeImmediate
;

gotoStatement:
    K_GOTO toLabel=sqlName SEMI
;

ifStatement:
    K_IF conditionToStmts+=conditionToStatements
    (K_ELSIF conditionToStmts+=conditionToStatements)*
    (K_ELSE elseStmts=plsqlStatement+)?
    K_END K_IF SEMI
;

// artificial clause
conditionToStatements:
    cond=condition K_THEN stmts+=plsqlStatement+
;

nullStatement:
    K_NULL SEMI
;

openStatement:
    K_OPEN cursor=qualifiedName (LPAR params+=functionParameter (COMMA params+=functionParameter)* RPAR)? SEMI
;

openForStatement:
    K_OPEN COLON? cursor=qualifiedName K_FOR (selectStmt=select | expr=expression) usingClause? SEMI
;

pipeRowStatement:
    K_PIPE K_ROW LPAR row=expression RPAR SEMI
;

plsqlBlock:
    (K_DECLARE declareSection)? body
;

// others is handled as normal exception name
exceptionHandler:
    K_WHEN exceptions+=sqlName (K_OR exceptions+=sqlName)* K_THEN stmts+=plsqlStatement+
;

procedureCall:
    expr=expression SEMI
;

raiseStatement:
    K_RAISE exceptionName=qualifiedName? SEMI
;

returnStatement:
    K_RETURN value=condition SEMI
;

selectIntoStatement:
    select SEMI
;

sqlStatement:
    (
          commit
        | delete
        | insert
        | lockTable
        | merge
        | rollback
        | savepoint
        | setTransaction
        | update
    ) SEMI
;

whileLoopStatement:
    K_WHILE cond=condition K_LOOP stmts+=plsqlStatement+ K_END K_LOOP name=sqlName? SEMI
;

/*----------------------------------------------------------------------------*/
// Transaction Control Language
/*----------------------------------------------------------------------------*/

tclStatement:
      beginStatement
    | commitStatement
    | rollbackStatement
    | savepointStatement
    | setConstraintsStatement
    | setTransactionStatement
;

/*----------------------------------------------------------------------------*/
// Begin (PostgreSQL)
/*----------------------------------------------------------------------------*/

beginStatement:
    begin sqlEnd
;

begin:
    K_BEGIN (K_WORK | K_TRANSACTION)? (modes+=transactionMode (COMMA modes+=transactionMode)*)?
;

/*----------------------------------------------------------------------------*/
// Commit
/*----------------------------------------------------------------------------*/

commitStatement:
    commit sqlEnd
;

// undocumented in 23c: write options can have any order, force options, force with comment
commit:
    K_COMMIT
    (
          K_WORK
        | K_TRANSACTION // PostgreSQL
        | K_PREPARED transactionId=expression // PostgreSQL
    )?
    (K_AND K_NO? K_CHAIN)?  // PostgreSQL
    (K_COMMENT commentValue=expression)?
    (K_WRITE
        (
              K_WAIT (K_IMMEDIATE | K_BATCH)?
            | K_NOWAIT (K_IMMEDIATE | K_BATCH)?
            | K_IMMEDIATE
            | K_BATCH
        )?
    )?
    (
        K_FORCE (
              transactionId=expression (COMMA scn=expression)?
            | K_CORRUPT_XID corruptXid=expression
            | K_CORRUPT_XID_ALL
        )
    )?
;

/*----------------------------------------------------------------------------*/
// Rollback
/*----------------------------------------------------------------------------*/

rollbackStatement:
    rollback sqlEnd
;

rollback:
    K_ROLLBACK
    (
          K_WORK
        | K_TRANSACTION // PostgreSQL
        | K_PREPARED transactionId=expression // PostgreSQL
    )?
    (K_AND K_NO? K_CHAIN)? // PostgreSQL
    (
          K_TO K_SAVEPOINT? savepointName=sqlName
        | K_FORCE transactionId=expression
    )?
;

/*----------------------------------------------------------------------------*/
// Savepoint
/*----------------------------------------------------------------------------*/

savepointStatement:
    savepoint sqlEnd
;

savepoint:
    K_SAVEPOINT savepointName=sqlName
;

/*----------------------------------------------------------------------------*/
// Set Constraint(s)
/*----------------------------------------------------------------------------*/

setConstraintsStatement:
    setConstraints sqlEnd
;

setConstraints:
    K_SET (K_CONSTRAINT | K_CONSTRAINTS)
    (
          K_ALL
        | constraints+=constraint (COMMA constraints+=constraint)*
    ) (K_IMMEDIATE | K_DEFERRED) SEMI
;

constraint:
    name=qualifiedName (K_AT dblink=qualifiedName)?
;

/*----------------------------------------------------------------------------*/
// Set Transaction
/*----------------------------------------------------------------------------*/

setTransactionStatement:
    setTransaction sqlEnd
;

setTransaction:
    K_SET
    (K_SESSION K_CHARACTERISTICS K_AS)? // PostgreSQL
    K_TRANSACTION
    (
          transactionMode (K_NAME name=expression)? // OracleDB: name
        | K_SNAPSHOT snapshotId=expression // PostgreSQL: accepted also for "set session characteristics as"
        | K_USE K_ROLLBACK K_SEGMENT rollbackSegment=sqlName (K_NAME name=expression)? // OracleDB
        | K_NAME name=expression // OracleDB
    )
;

// PostgreSQL modes, subset supported by OracleDB
transactionMode:
      K_ISOLATION K_LEVEL (K_SERIALIZABLE | K_REPEATABLE K_READ | K_READ K_COMMITTED | K_READ K_UNCOMMITTED)
    | K_READ K_WRITE
    | K_READ K_ONLY
    | K_NOT? K_DEFERRABLE
;

/*----------------------------------------------------------------------------*/
// Data types
/*----------------------------------------------------------------------------*/

dataType:
      oracleBuiltInDatatype
    | ansiSupportedDatatype
    | postgresqlDatatype
    | userDefinedType
    | posgresqlArrayDatatype=dataType (LSQB RSQB)+
;

oracleBuiltInDatatype:
      characterDatatype
    | numberDatatype
    | longAndRawDatatype
    | datetimeDatatype
    | largeObjectDatatype
    | rowidDatatype
    | jsonDatatype
    | booleanDatatype
;

characterDatatype:
      K_CHAR (LPAR size=expression (K_BYTE|K_CHAR)? RPAR)?
    | K_VARCHAR2 LPAR size=expression (K_BYTE|K_CHAR)? RPAR
    | K_NCHAR (LPAR size=expression RPAR)
    | K_NVARCHAR2 (LPAR size=expression RPAR)
;

numberDatatype:
      K_NUMBER (LPAR precision=expression (COMMA scale=expression)? RPAR)?
    | K_FLOAT (LPAR precision=expression LPAR)?
    | K_BINARY_FLOAT
    | K_BINARY_DOUBLE
;

longAndRawDatatype:
      K_LONG
    | K_LONG K_RAW
    | K_RAW LPAR size=expression RPAR
;

datetimeDatatype:
      K_DATE
    | K_TIMESTAMP (LPAR fractionalSecondsPrecision=expression RPAR)? (K_WITH K_LOCAL? K_TIME K_ZONE)?
    | K_INTERVAL K_YEAR (LPAR yearPrecision=expression RPAR)? K_TO K_MONTH
    | K_INTERVAL K_DAY (LPAR dayPrecision=expression RPAR)? K_TO K_SECOND (LPAR fractionalSecondsPrecision=expression RPAR)?
;

largeObjectDatatype:
      K_BLOB
    | K_CLOB
    | K_NCLOB
    | K_BFILE
;

rowidDatatype:
      K_ROWID
    | K_UROWID (LPAR size=expression RPAR)?
;

jsonDatatype:
    K_JSON
;

booleanDatatype:
    K_BOOLEAN
;

ansiSupportedDatatype:
      K_CHARACTER (K_VARYING? LPAR size=expression RPAR)?                       // optional size in PostgreSQL
    | (K_CHAR|K_NCHAR) (K_VARYING LPAR size=expression (K_BYTE|K_CHAR)? RPAR)?  // optional size in PostgreSQL
    | K_VARCHAR (LPAR size=expression (K_BYTE|K_CHAR)? RPAR)?                   // optional size in PostgreSQL
    | K_NATIONAL (K_CHARACTER|K_CHAR) K_VARYING? LPAR size=expression RPAR
    | (K_NUMERIC|K_DECIMAL|K_DEC) (LPAR precision=expression (COMMA scale=expression)? RPAR)?
    | (K_INTEGER|K_INT|K_SMALLINT)
    | K_FLOAT (LPAR size=expression RPAR)?
    | K_DOUBLE K_PRECISION
    | K_REAL
;

// only data types that are not handled in oracleBuiltInDatatype and ansiSupportedDatatype
postgresqlDatatype:
      K_BIGINT
    | K_INT8                                                        // alias for bigint
    | K_BIGSERIAL
    | K_SERIAL8                                                     // alias for bigserial
    | K_BIT (LPAR size=expression RPAR)?
    | K_BIT K_VARYING (LPAR size=expression RPAR)?
    | K_VARBIT (LPAR size=expression RPAR)?                         // alias for bit varying
    | K_BOOL                                                        // alias for boolean
    | K_BOX
    | K_BYTEA
    | K_CHARACTER K_VARYING                                         // no precision allowed
    | K_CIDR
    | K_CIRCLE
    | K_FLOAT8                                                      // alias for double precision
    | K_INT4                                                        // alias for int, integer
    | K_INET
    | K_INTERVAL intervalField? (LPAR precision=expression RPAR)?
    | K_JSONB
    | K_LINE
    | K_LSEG
    | K_MACADDR
    | K_MACADDR8
    | K_MONEY
    | K_PATH
    | K_PG_LSN
    | K_PG_SNAPSHOT
    | K_POINT
    | K_POLYGON
    | K_FLOAT4
    | K_INT2
    | K_SMALLSERIAL
    | K_SERIAL2
    | K_SERIAL
    | K_SERIAL4
    | K_TEXT
    | K_TIME (LPAR precision=expression RPAR)? (K_WITHOUT K_TIME K_ZONE)?
    | K_TIME (LPAR precision=expression RPAR)? K_WITH K_TIME K_ZONE
    | K_TIMETZ
    | K_TIMESTAMP (LPAR precision=expression RPAR)? K_WITHOUT K_TIME K_ZONE // variant not handled in OracleDB's datetimeDatatype
    | K_TIMESTAMPTZ
    | K_TSQUERY
    | K_TSVECTOR
    | K_TXID_SNAPSHOT
    | K_UUID
    | K_XML
;

intervalField:
      K_YEAR                    # yearIntervalField
    | K_MONTH                   # monthIntervalField
    | K_DAY                     # dayIntervalField
    | K_HOUR                    # hourIntervalField
    | K_MINUTE                  # minuteIntervalField
    | K_SECOND                  # secondIntervalField
    | K_YEAR K_TO K_MONTH       # yearToMonthIntervalField
    | K_DAY K_TO K_HOUR         # dayToHourIntervalField
    | K_DAY K_TO K_MINUTE       # dayToMinuteIntervalField
    | K_DAY K_TO K_SECOND       # dayToSecondIntervalField
    | K_HOUR K_TO K_MINUTE      # hourToMinuteIntervalField
    | K_HOUR K_TO K_SECOND      # hourToSecondIntervalField
    | K_MINUTE K_TO K_SECOND    # minuteToSecondIntervalField
;

// handles also Oracle_supplied_types, which are just a special type of user_defined_types
// handles also parametrized PostGIS data types such as geography
userDefinedType:
    name=qualifiedName (LPAR exprs+=expression (COMMA exprs+=expression)* RPAR)?
;

/*----------------------------------------------------------------------------*/
// Expression
/*----------------------------------------------------------------------------*/

expression:
      expr=string                                               # simpleExpressionStringLiteral
    | expr=NUMBER                                               # simpleExpressionNumberLiteral
    | K_DATE expr=string                                        # dateLiteral
    | K_TIMESTAMP expr=string                                   # timestampLiteral
    | expr=intervalExpression                                   # intervalExpressionParent
    | LPAR expr=subquery RPAR                                   # scalarSubqueryExpression
    | LPAR exprs+=expression (COMMA exprs+=expression)* RPAR    # expressionList                // also parenthesisCondition
    | K_CURSOR LPAR expr=subquery RPAR                          # cursorExpression
    | expr=caseExpression                                       # caseExpressionParent
    | expr=jsonObjectAccessExpression                           # jsonObjectAccessExpressionParent
    | operator=unaryOperator expr=expression                    # unaryExpression               // precedence 0, must be evaluated before functions
    | expr=specialFunctionExpression                            # specialFunctionExpressionParent
    | expr=functionExpression                                   # functionExpressionParent
    | expr=plsqlQualifiedExpression                             # plsqlQualifiedExpressionParent
    | expr=placeholderExpression                                # placeholderExpressionParent
    | expr=AST                                                  # allColumnWildcardExpression
    | type=dataType expr=string                                 # postgresqlStringCast
    | left=expression operator=PERIOD right=expression          # qualifiedExpression           // precedence 1
    | expr=expression operator=COLON_COLON type=dataType        # postgresqlHistoricalCast      // precedence 2
    | expr=expression
        LSQB (cellAssignmentList|multiColumnForLoop) RSQB       # modelExpression               // precedence 3, also PostgreSQL array element selection
    | expr=expression
        LSQB lower=expression COLON upper=expression RSQB       # postgresqlSubscript           // precedence 3, PostgreSQL subscripts are handeld as model_expression
    | expr=postgresqlArrayConstructor                           # postgresqlArrayConstructorParent // precedence 3
    | left=expression operator=K_COLLATE right=expression       # collateExpression             // precedence 5
    | left=expression operator=K_AT
        (
              K_LOCAL
            | K_TIME K_ZONE
                (
                     K_DBTIMEZONE
                   | K_SESSIONTIMEZONE
                   | right=expression
                )
        )                                                       # datetimeExpression            // precedence 6
    | left=expression operator=HAT right=expression             # exponentiationExpression      // precedence 7, PostgreSQL
    | left=expression operator=AST right=expression             # multiplicationExpression      // precedence 8
    | left=expression operator=SOL right=expression             # divisionExpression            // precedence 8
    | left=expression operator=PERCNT right=expression          # moduloExpression              // precedence 8, PostgreSQL
    | left=expression operator=PLUS right=expression            # additionExpression            // precedence 9
    | left=expression operator=MINUS right=expression           # substractionExpression        // precedence 9
    | left=expression
        (
              operator=VERBAR_VERBAR // OracleDB, PostgreSQL (no WS allowed)
            | operator=VERBAR VERBAR // OracleDB (WS, comment allowed)
        )
        right=expression                                        # concatenationExpression       // precedence 10
    | left=expression operator=binaryOperator right=expression  # binaryExpression              // precedence 10
    | left=expression K_MULTISET operator=K_EXCEPT
        (K_ALL|K_DISTINCT)? right=expression                    # multisetExpression
    | left=expression K_MULTISET operator=K_INTERSECT
        (K_ALL|K_DISTINCT)? right=expression                    # multisetExpression
    | left=expression K_MULTISET operator=K_UNION
        (K_ALL|K_DISTINCT)? right=expression                    # multisetExpression
    | expr=expression LPAR PLUS RPAR                            # outerJoinExpression
    | expr=sqlName                                              # simpleExpressionName
    // starting with 23c a condition is treated as a synonym to an expression
    | operator=K_NOT cond=expression                            # notCondition
    | left=expression operator=K_AND right=expression           # logicalCondition
    | left=expression operator=K_OR right=expression            # logicalCondition
    | left=expression
        operator=simpleComparisionOperator
        groupOperator=(K_ANY|K_SOME|K_ALL)
        right=expression                                        # groupComparisionCondition
    | left=expression
        operator=simpleComparisionOperator
        right=expression                                        # simpleComparisionCondition
    | expr=expression
        operator=K_IS K_NOT? (K_NAN|K_INFINITE)                 # floatingPointCondition
    | expr=expression operator=K_IS K_ANY                       # isAnyCondition            // "any" only is handled as sqlName
    | expr=expression operator=K_IS K_PRESENT                   # isPresentCondition
    | expr=expression operator=K_IS K_NOT? K_A K_SET            # isASetCondition
    | expr=expression operator=K_IS K_NOT? K_EMPTY              # isEmptyCondition
    | expr=expression operator=K_IS K_NOT? K_NULL               # isNullCondition
    | expr=expression operator=(K_NOTNULL|K_ISNULL)             # postgresqlNullCondition   // PostgreSQL
    | expr=expression operator=K_IS K_NOT? K_TRUE               # isTrueCondition
    | expr=expression operator=K_IS K_NOT? K_FALSE              # isFalseCondition
    | expr=expression operator=K_IS K_NOT? K_DANGLING           # isDanglingCondition
    | expr=expression operator=K_IS K_NOT? K_UNKNOWN            # isUnknownCondition        // PostgreSQL
    | expr=expression operator=K_IS K_NOT? K_DOCUMENT           # isDocumentCondition       // PostgreSQL
    | expr=expression
        operator=K_IS K_NOT? K_JSON formatClause?
        (
            LPAR (options+=jsonConditionOption+) RPAR
          | options+=jsonConditionOption*
        )                                                       # isJsonCondition
    | left=expression operator=K_IS K_NOT?
        K_DISTINCT K_FROM right=expression                      # isDistinctFromCondition   // PostgreSQL
    | left=expression K_NOT? operator=K_MEMBER
        K_OF? right=expression                                  # memberCondition
    | left=expression K_NOT? operator=K_SUBMULTISET
        K_OF? right=expression                                  # submultisetCondition
    | left=expression K_NOT?
        operator=(K_LIKE|K_LIKEC|K_LIKE2|K_LIKE4)
        right=expression
        (K_ESCAPE escChar=expression)?                          # likeCondition
    | left=expression K_NOT?
        operator=K_SIMILAR K_TO
        right=expression
        (K_ESCAPE escChar=expression)?                          # similarCondition          // PostgreSQL
    | expr1=expression K_NOT? operator=K_BETWEEN K_SYMMETRIC?
        expr2=expression K_AND expr3=expression                 # betweenCondition          // PostgreSQL: symmetric
    | K_EXISTS LPAR subquery RPAR                               # existsCondition
    | left=expression K_NOT? operator=K_IN
        right=expression                                        # inCondition
    | expr=expression K_IS K_NOT? K_OF K_TYPE?
        LPAR types+=isOfTypeConditionItem
        (COMMA types+=isOfTypeConditionItem)* RPAR              # isOfTypeCondition
;

intervalExpression:
      intervalLiteralYearToMonth
    | intervalLiteralDayToSecond
    | intervalExpressionYearToMonth
    | intervalExpressionDayToSecond
;

intervalLiteralYearToMonth:
    K_INTERVAL expr=string
        from=(K_YEAR|K_MONTH) (LPAR precision=NUMBER RPAR)? (K_TO to=(K_YEAR|K_MONTH))?
;

intervalLiteralDayToSecond:
    K_INTERVAL expr=string
        (
              from=(K_DAY|K_HOUR|K_MINUTE) (LPAR precision=NUMBER RPAR)?
            | from=K_SECOND (LPAR leadingPrecision=NUMBER (COMMA fromFractionalSecondPrecision=NUMBER)? RPAR)?
        )
        (
            K_TO
            (
                  to=(K_DAY|K_HOUR|K_MINUTE)
                | to=K_SECOND (LPAR toFractionalSecondsPercision=NUMBER RPAR)?
            )
        )?
;

intervalExpressionYearToMonth:
    LPAR expr1=expression MINUS expr2=expression RPAR
        K_YEAR (LPAR leadingFieldPrecision=expression RPAR)? K_TO K_MONTH
;

intervalExpressionDayToSecond:
    LPAR expr1=expression MINUS expr2=expression RPAR
        K_DAY (LPAR leadingFieldPrecision=expression RPAR)?
        K_TO K_SECOND (LPAR fractionalSecondPrecision=expression RPAR)?
;

caseExpression:
    K_CASE
        (
              simpleCaseExpression
            | searchedCaseExpression
        )
        elseClause?
    K_END
;

// recognized only with array step, qualified names are recognized as binaryExpression with PERIOD operator
jsonObjectAccessExpression:
    talias=sqlName PERIOD jsonColumn=sqlName (PERIOD keys+=jsonObjectKey)+
;

jsonObjectKey:
    key=sqlName arraySteps+=jsonArrayStep+
;

jsonArrayStep:
    LSQB values+=jsonArrayStepValue (COMMA values+=jsonArrayStepValue)* RSQB
;

jsonArrayStepValue:
      expr=expression
    | from=expression K_TO to=expression
;

simpleCaseExpression:
    expr=expression whens+=simpleCaseExpressionWhenClause+
;

simpleCaseExpressionWhenClause:
    K_WHEN values+=whenClauseValue (COMMA values+=whenClauseValue)* K_THEN expr=expression
;

whenClauseValue:
      expression            # selectorValue
    | danglingCondition     # danglingPredicate
;

searchedCaseExpression:
    whens+=searchedCaseExpressionWhenClause+
;
searchedCaseExpressionWhenClause:
    K_WHEN cond=condition K_THEN expr=expression
;

elseClause:
    K_ELSE expr=expression
;

// Functions and function-like conditions that have a syntax that
// cannot be handled by the generic functionExpression.
specialFunctionExpression:
      avExpression
    | cast
    | extract
    | featureCompare
    | fuzzyMatch
    | graphTable
    | jsonArray
    | jsonArrayagg
    | jsonMergepatch
    | jsonObject
    | jsonObjectagg
    | jsonQuery
    | jsonScalar
    | jsonSerialize
    | jsonTable
    | jsonTransform
    | jsonValue
    | jsonEqualCondition
    | jsonExistsCondition
    | listagg
    | nthValue
    | overlay
    | substring
    | tableFunction
    | treat
    | trim
    | validateConversion
    | xmlcast
    | xmlcolattval
    | xmlelement
    | xmlexists
    | xmlforest
    | xmlparse
    | xmlpi
    | xmlquery
    | xmlroot
    | xmlserialize
    | xmltable
;

avExpression:
      avMeasExpression
    | avHierExpression
;

avMeasExpression:
      leadLagExpression
    | avWindowExpression
    | rankExpression
    | shareOfExpression
    | qdrExpression
;

leadLagExpression:
    leadLagFunctionName LPAR expr=expression RPAR K_OVER LPAR leadLagClause RPAR
;

leadLagFunctionName:
      K_LAG
    | K_LAG_DIFF
    | K_LAG_DIFF_PERCENT
    | K_LEAD
    | K_LEAD_DIFF
    | K_LEAD_DIFF_PERCENT
;

leadLagClause:
    K_HIERARCHY hierarchyRef K_OFFSET offset=expression
    (
          K_WITHIN (K_LEVEL|K_PARENT)
        | K_ACROSS K_ANCESTOR K_AT K_LEVEL levelRef=sqlName (K_POSITION K_FROM (K_BEGINNING|K_END))?
    )?
;

avWindowExpression:
    aggregateFunction=sqlName K_OVER LPAR avWindowClause RPAR
;

avWindowClause:
    K_HIERARCHY hierarchyRef K_BETWEEN (precedingBoundary|followingBoundary) (K_WITHIN avLevelRef)?
;

// artifical clause to reduce reduncancy
avLevelRef:
      K_LEVEL levelRef=sqlName?                             # avLevelRefLevel
    | K_PARENT                                              # avLevelRefParent
    | K_ACROSS? K_ANCESTOR K_AT K_LEVEL levelRef=sqlName
       (K_POSITION K_FROM (K_BEGINNING|K_END)?)?            # avLevelRefAncestor
    | K_MEMBER expr=memberExpression                        # avLevelRefMember
;

precedingBoundary:
    (
        fromUnboundedPreceding=K_UNBOUNDED K_PRECEDING
      | fromOffsetPreceding=expression K_PRECEDING
    )
    K_AND
    (
        toCurrentMember=K_CURRENT K_MEMBER
      | toOffsetPreceding=expression K_PRECEDING
      | toOffsetFollowing=expression K_FOLLOWING
      | toUnboundedFollowing=K_UNBOUNDED K_FOLLOWING
    )
;

followingBoundary:
    (
        fromCurrentMember=K_CURRENT K_MEMBER
      | fromOffsetFollowing=expression K_FOLLOWING
    )
    K_AND
    (
        toOffsetFollowing=expression K_FOLLOWING
      | toUnboundedFollowing=K_UNBOUNDED K_FOLLOWING
    )
;

hierarchyRef:
    (dimAlias=sqlName PERIOD)? hierAlias=sqlName
;

rankExpression:
    functionName=rankFunctionName LPAR RPAR K_OVER LPAR rankClause RPAR
;

rankFunctionName:
      K_RANK
    | K_DENSE_RANK
    | K_AVERAGE_RANK
    | K_ROW_NUMBER
;

// real orderByClause is just a subset, simplified gammar
rankClause:
    K_HIERARCHY hierarchyRef orderByClause (K_WITHIN avLevelRef)?
;

shareOfExpression:
    K_SHARE_OF LPAR expr=expression shareClause RPAR
;

shareClause:
    K_HIERARCHY hierarchyRef avLevelRef
;

qdrExpression:
    K_QUALIFY LPAR expr=expression COMMA qualifier RPAR
;

qualifier:
    hierarchyRef EQUALS memberExpression
;

memberExpression:
      levelMemberLiteral            # memberExprLevelMember
    | hierNavigationExpression      # memberExprHierNavigation
    | K_CURRENT K_MEMBER            # memberExprCurrentMember
    | K_NULL                        # memberExprNull
    | K_ALL                         # memberExprAll
;

levelMemberLiteral:
    levelRef=sqlName (posMemberKeys|namedMemberKeys)
;

posMemberKeys:
    LSQB keys+=expression (COMMA keys+=expression)* RSQB
;

namedMemberKeys:
    LSQB keys+=namedMemberKeysItem (COMMA keys+=namedMemberKeysItem)* RSQB
;

namedMemberKeysItem:
    attrName=sqlName EQUALS key=expression
;

hierNavigationExpression:
      hierAncestorExpression    # hierNavigationExprAncestor
    | hierParentExpression      # hierNavigationExprParent
    | hierLeadLagExpression     # hierNavigationExprLeadLag
;

hierAncestorExpression:
    K_HIER_ANCESTOR LPAR expr=expression K_AT (K_LEVEL levelRef=sqlName|K_DEPTH depthExpr=expression) RPAR
;

hierParentExpression:
    K_HIER_PARENT LPAR expr=expression RPAR
;

hierLeadLagExpression:
    (K_HIER_LEAD|K_HIER_LAG) LPAR hierLeadLagClause RPAR
;

hierLeadLagClause:
    memberExpr=memberExpression K_OFFSET offsetExpr=expression (K_WITHIN avLevelRef)?
;

avHierExpression:
    functionName=hierFunctionName
        LPAR memberExpr=memberExpression K_WITHIN K_HIERARCHY hierarchyRef RPAR
;

hierFunctionName:
      K_HIER_CAPTION
    | K_HIER_DEPTH
    | K_HIER_DESCRIPTION
    | K_HIER_LEVEL
    | K_HIER_MEMBER_NAME
    | K_HIER_MEMBER_UNIQUE_NAME
    | K_HIER_PARENT_LEVEL
    | K_HIER_PARENT_UNIQUE_NAME
    | K_HIER_CHILD_COUNT
;

cast:
    K_CAST LPAR
        (
              expr=expression
            | K_MULTISET LPAR subquery RPAR
        )
        K_AS K_DOMAIN? typeName=dataType domainValidateClause?
        defaultOnConversionError?
        (COMMA fmt=expression (COMMA nlsparam=expression)?)?
    RPAR
;

domainValidateClause:
      K_VALIDATE
    | K_NOVALIDATE
;

defaultOnConversionError:
    K_DEFAULT returnValue=expression K_ON K_CONVERSION K_ERROR
;

extract:
    K_EXTRACT LPAR what=sqlName K_FROM expr=expression RPAR
;

featureCompare:
    K_FEATURE_COMPARE LPAR (schema=sqlName PERIOD)? model=sqlName
    miningAttributeClause1=miningAttributeClause K_AND miningAttributeClause2=miningAttributeClause RPAR
;

respectIgnoreNullsClause:
    (K_RESPECT | K_IGNORE) K_NULLS
;

fuzzyMatch:
    K_FUZZY_MATCH LPAR
        algorithm=(
            K_LEVENSHTEIN
          | K_DAMERAU_LEVENSHTEIN
          | K_JARO_WINKLER
          | K_BIGRAM
          | K_TRIGRAM
          | K_WHOLE_WORD_MATCH
          | K_LONGEST_COMMON_SUBSTRING
        )
        COMMA str1=expression
        COMMA str2=expression
        (COMMA option=(K_UNSCALED|K_RELATE_TO_SHORTER|K_EDIT_TOLERANCE) tolerance=expression?)?
    RPAR
;

// simplified, includes: graph_reference, graph_name, graph_pattern, path_pattern_list, graph_pattern_where_clause,
// graph_table_shape, graph_table_columns_clause
graphTable:
    K_GRAPH_TABLE LPAR
    (schema=sqlName PERIOD)?
    graph=sqlName K_MATCH patterns+=pathTerm (COMMA patterns+=pathTerm)*
    (K_WHERE cond=condition)?
    K_COLUMNS LPAR columns+=graphTableColumnDefinition (COMMA columns+=graphTableColumnDefinition)* RPAR
    RPAR
;

graphTableColumnDefinition:
    expr=expression (K_AS column=sqlName)?
;

// simplified, includes path_pattern, path_pattern_expression, path_concatenation (to handle left-recursion)
pathTerm:
      pathFactor+
;

pathFactor:
      pathPrimary
    | quantifiedPathPrimary
;

pathPrimary:
      elementPattern
    | parenthesizedPathPatternExpression
;

quantifiedPathPrimary:
    pathPrimary graphPatternQuantifier
;

graphPatternQuantifier:
      fixedQuantifier
    | generalQuantifier
;

fixedQuantifier:
    LCUB value=expression RCUB
;

// simplified, includes lower_bound, upper_bound
generalQuantifier:
    LCUB lowerBound=expression? COMMA upperBound=expression RCUB
;

elementPattern:
      vertexPattern
    | edgePattern
;

// simplified, includes parenthesized_path_pattern_where_clause
parenthesizedPathPatternExpression:
    LPAR expr=pathTerm (K_WHERE cond=condition)? RPAR
;

vertexPattern:
    LPAR elementPatternFiller RPAR
;

// simplified, includes: element_variable_declaration, element_variable, isLabelExpression/isLabelDeclaration,
// element_pattern_where_clause, is_label_declaration
elementPatternFiller:
    var=sqlName? (K_IS labelName=labelExpression)? (K_WHERE cond=condition)?
;

// simplified, includes: label, label_disjunction
labelExpression:
    labels+=sqlName (VERBAR labels+=sqlName)*
;

edgePattern:
      fullEdgePattern
    | abbreviatedEdgePattern
;

fullEdgePattern:
      fullEdgePointingRight
    | fullEdgePointingLeft
    | fullEdgeAnyDirection
;

abbreviatedEdgePattern:
      MINUS GT      # abbreviatedEdgePatternPointingRight
    | MINUS_GT      # abbreviatedEdgePatternPointingRight
    | LT MINUS      # abbreviatedEdgePatternPointingLeft
    | MINUS         # abbreviatedEdgePatternAnyDirection
    | LT MINUS GT   # abbreviatedEdgePatternAnyDirection
    | LT_MINUS_GT   # abbreviatedEdgePatternAnyDirection
;

fullEdgePointingRight:
    MINUS LSQB elementPatternFiller RSQB (MINUS GT|MINUS_GT)
;

fullEdgePointingLeft:
    LT MINUS LSQB elementPatternFiller RSQB MINUS
;

fullEdgeAnyDirection:
      MINUS LSQB elementPatternFiller RSQB MINUS
    | LT MINUS LSQB elementPatternFiller RSQB (MINUS GT|MINUS_GT)
;

jsonArray:
      K_JSON_ARRAY LPAR jsonArrayContent RPAR
    | K_JSON LSQB jsonArrayContent RSQB
    | LSQB jsonArrayContent RSQB // undocumented, works in nested context only
;

jsonArrayContent:
      jsonArrayEnumerationContent
    | jsonArrayQueryContent
;

jsonArrayEnumerationContent:
    (elements+=jsonArrayElement (COMMA elements+=jsonArrayElement)*)?
        jsonOnNullClause?
        jsonReturningClause?
        options+=jsonOption*
;

jsonArrayQueryContent:
    queryExpression=subquery jsonOnNullClause? jsonReturningClause? options+=jsonOption*
;

// undocumented: pretty/ascii
jsonOption:
      K_STRICT
    | K_PRETTY
    | K_ASCII
    | K_TRUNCATE                            // from JSON_MERGEPATCH
    | (K_ALLOW | K_DISALLOW) K_SCALARS      // from JSON_QUERY
    | K_ORDERED                             // from JSON_SERIALIZE
;

jsonArrayElement:
    expr=expression formatClause?
;

formatClause:
    K_FORMAT K_JSON
;

jsonOnNullClause:
    (K_NULL|K_ABSENT) K_ON K_NULL
;

jsonReturningClause:
    K_RETURNING
        (
              K_VARCHAR2 (LPAR size=expression (K_BYTE|K_CHAR)? RPAR)? (K_WITH K_TYPENAME)?
            | K_CLOB
            | K_BLOB
            | K_JSON
        )
;

jsonTransformReturningClause:
    K_RETURNING
        (
              K_VARCHAR2 (LPAR size=expression (K_BYTE|K_CHAR)? RPAR)?
            | K_CLOB
            | K_BLOB
            | K_JSON
        ) (K_ALLOW|K_DISALLOW)?
;

// undocumented: every existing datatype is allowed
jsonQueryReturnType:
    dataType
;

jsonValueReturningClause:
    K_RETURNING jsonValueReturnType options+=jsonOption*
;

jsonValueReturnType:
      K_VARCHAR2 (LPAR size=expression (K_BYTE|K_CHAR)? RPAR)? K_TRUNCATE?
    | K_CLOB
    | K_NUMBER (LPAR precision=expression (COMMA scale=expression)? RPAR)?
    | (K_ALLOW|K_DISALLOW) K_BOOLEAN? K_TO K_NUMBER K_CONVERSION?
    | K_DATE ((K_TRUNCATE|K_PRESERVE) K_TIME)?
    | K_TIMESTAMP (K_WITH K_TIMEZONE)?
    | K_SDO_GEOMETRY
    | jsonValueReturnObjectInstance
;

jsonValueReturnObjectInstance:
    objectTypeName=qualifiedName jsonValueMapperClause?
;

jsonValueMapperClause:
    K_USING K_CASE_SENSITIVE K_MAPPING
;

jsonArrayagg:
    K_JSON_ARRAYAGG LPAR expr=expression
        formatClause? orderByClause? jsonOnNullClause? jsonReturningClause? options+=jsonOption* RPAR
;

jsonMergepatch:
    K_JSON_MERGEPATCH LPAR
        jsonTargetExpr=expression COMMA jsonPatchExpr=expression
        jsonReturningClause?
        options+=jsonOption*
        jsonOnErrorClause?
    RPAR
;

jsonOnErrorClause:
    (K_ERROR|K_NULL) K_ON K_ERROR
;

jsonObject:
      K_JSON_OBJECT LPAR jsonObjectContent RPAR
    | K_JSON LCUB jsonObjectContent RCUB
    | LCUB jsonObjectContent RCUB // undocumented, works in nested context only
;

jsonObjectContent:
    (
          AST
        | entries+=entry (COMMA entries+=entry)*
    )
    jsonOnNullClause? jsonReturningClause? options+=jsonOption*
    (K_WITH K_UNIQUE K_KEYS)?
;

entry:
    regularEntry formatClause?
;

regularEntry:
      K_KEY? key=expression K_VALUE value=expression
    | key=expression COLON value=expression
    | value=expression
;

jsonObjectagg:
    K_JSON_OBJECTAGG LPAR K_KEY? keyExpr=expression K_VALUE valExpr=expression
    jsonOnNullClause? jsonReturningClause? options+=jsonOption* (K_WITH K_UNIQUE K_KEYS)? RPAR
;

jsonQuery:
    K_JSON_QUERY LPAR expr=expression formatClause? COMMA jsonBasicPathExpression jsonPassingClause?
    (K_RETURNING jsonQueryReturnType)? options+=jsonOption* jsonQueryWrapperClause? jsonQueryOnErrorClause?
    jsonQueryOnEmptyClause? jsonQueryOnMismatchClause? jsonTypeClause? RPAR
;

jsonTypeClause:
    K_TYPE LPAR (K_STRICT|K_LAX) RPAR
;

// in SQL it is just a string
jsonBasicPathExpression:
    expr=expression
;

jsonQueryWrapperClause:
      K_WITHOUT K_ARRAY? K_WRAPPER
    | K_WITH (K_UNCONDITIONAL|K_CONDITIONAL)? K_ARRAY? K_WRAPPER
;

jsonQueryOnErrorClause:
    (
          K_ERROR
        | K_NULL
        | K_EMPTY
        | K_EMPTY K_ARRAY
        | K_EMPTY K_OBJECT
    ) K_ON K_ERROR
;

jsonQueryOnEmptyClause:
    (
          K_ERROR
        | K_NULL
        | K_EMPTY
        | K_EMPTY K_ARRAY
        | K_EMPTY K_OBJECT
    ) K_ON K_EMPTY
;

jsonQueryOnMismatchClause:
    (K_ERROR|K_NULL) K_ON K_MISMATCH
;

// wrong documentation, either "null on error" or "error on error" is allowed, but not both clauses
// therefore we use here the json_table_on_error_clause
jsonScalar:
    K_JSON_SCALAR LPAR expr=expression (K_SQL|K_JSON)? (K_NULL K_ON K_NULL)? jsonTableOnErrorClause? RPAR
;

jsonSerialize:
    K_JSON_SERIALIZE LPAR expr=expression jsonReturningClause? options+=jsonOption* jsonQueryOnErrorClause? RPAR
;

// jsonTypeClause does not work in 23.3, might be not supported yet or the syntax is still wrong
// see https://github.com/IslandSQL/IslandSQL/issues/48
jsonTable:
    K_JSON_TABLE LPAR expr=expression formatClause? (COMMA jsonBasicPathExpression)?
    jsonTableOnErrorClause? jsonTypeClause? jsonTableOnEmptyClause? jsonColumnsClause RPAR
;

jsonTableOnErrorClause:
    (K_ERROR|K_NULL) K_ON K_ERROR
;

jsonTableOnEmptyClause:
    (K_ERROR|K_NULL) K_ON K_EMPTY
;

jsonColumnsClause:
    K_COLUMNS LPAR columns+=jsonColumnDefinition (COMMA columns+=jsonColumnDefinition)* RPAR
;

jsonColumnDefinition:
      jsonExistColumn
    | jsonQueryColumn
    | jsonValueColumn
    | jsonNestedPath
    | ordinalityColumn
;

jsonExistColumn:
    columnName=sqlName jsonValueReturnType? K_EXISTS (K_PATH jsonPath)?
    jsonExistsOnErrorClause? jsonExistsOnEmptyClause?
;

jsonQueryColumn:
    columnName=sqlName jsonQueryReturnType? formatClause? ((K_ALLOW|K_DISALLOW) K_SCALARS)?
    jsonQueryWrapperClause? (K_PATH jsonPath)? jsonQueryOnErrorClause?
;

jsonValueColumn:
    columnName=sqlName jsonValueReturnType? K_TRUNCATE? (K_PATH jsonPath)?
    jsonValueOnErrorClause? jsonValueOnEmptyClause? jsonValueOnMismatchClause?
;

jsonValueOnErrorClause:
    (K_ERROR|K_NULL|K_DEFAULT literal=expression) K_ON K_ERROR
;

jsonValueOnEmptyClause:
    (K_ERROR|K_NULL|K_DEFAULT literal=expression) K_ON K_EMPTY
;

jsonValueOnMismatchClause:
    (K_IGNORE|K_ERROR|K_NULL) K_ON K_MISMATCH
    (LPAR options+=jsonValueOnMismatchClauseOption (COMMA options+=jsonValueOnMismatchClauseOption)* RPAR)?
;

jsonValueOnMismatchClauseOption:
      K_MISSING K_DATA
    | K_EXTRA K_DATA
    | K_TYPE K_ERROR
;

jsonNestedPath:
    K_NESTED K_PATH? jsonPath jsonColumnsClause
;

jsonPath:
      jsonBasicPathExpression
    | jsonRelativeObjectAccess
;

jsonRelativeObjectAccess:
    keys+=jsonObjectKey (PERIOD keys+=jsonObjectKey)*
;

ordinalityColumn:
    columnName=sqlName K_FOR K_ORDINALITY
;

// undocumented: some options such as pretty, ascii, allow scalars, disallow scalars
jsonTransform:
    K_JSON_TRANSFORM LPAR expr=expression COMMA operations+=operation (COMMA operations+=operation)*
    jsonTransformReturningClause? options+=jsonOption* jsonTypeClause? jsonPassingClause? RPAR
;

// case, copy, intersect, merge, minus, prepend, union are implemented according the description in the JSON Developer's Guide
operation:
      removeOp
    | insertOp
    | replaceOp
    | appendOp
    | setOp
    | renameOp
    | keepOp
    | sortOp
    | nestedPathOp
    | caseOp
    | copyOp
    | intersectOp
    | mergeOp
    | minusOp
    | prependOp
    | unionOp
;

removeOp:
    K_REMOVE pathExpr=expression
    (
          onExistingHandler
        | onMissingHandler
    )*
;

// works only if there is no space before INSERT as long as the INSERT statement is not supported fully
// not documented optional use of "path" keyword
insertOp:
    K_INSERT pathExpr=expression EQUALS K_PATH? rhsExpr=expression formatClause?
    (
          onExistingHandler
        | onMissingHandler
        | onNullHandler
        | onErrorHandler
    )*
;

// not documented optional use of "path" keyword
replaceOp:
    K_REPLACE pathExpr=expression EQUALS K_PATH? rhsExpr=expression formatClause?
    (
          onExistingHandler
        | onMissingHandler
        | onNullHandler
        | onEmptyHandler
        | onErrorHandler
    )*
;

// not documented optional use of "path" keyword
appendOp:
    K_APPEND pathExpr=expression EQUALS K_PATH? rhsExpr=expression formatClause?
    (
          onMissingHandler
        | onMismatchHandler
        | onNullHandler
        | onEmptyHandler
    )*

    ((K_CREATE|K_IGNORE|K_ERROR) K_ON K_MISSING)?
    ((K_NULL|K_IGNORE|K_ERROR) K_ON K_NULL)?
;

// not documented optional use of "path" keyword
setOp:
    K_SET pathExpr=expression EQUALS K_PATH? rhsExpr=expression formatClause?
    (
          onExistingHandler
        | onMissingHandler
        | onNullHandler
        | onEmptyHandler
        | onErrorHandler
    )*
;

renameOp:
    K_RENAME pathExpr=expression K_WITH renamed=expression
    (
          onExistingHandler
        | onMissingHandler
    )*
;

keepOp:
    K_KEEP items+=expression (COMMA items+=expression)* onMissingHandler?
;

sortOp:
    K_SORT pathExpr=expression
    (
          orderByClause?
        | (K_ASC | K_DESC) K_UNIQUE?
        | K_UNIQUE
    )
    (
          onMissingHandler
        | onMismatchHandler
        | onEmptyHandler
    )*
;

nestedPathOp:
    K_NESTED K_PATH? pathExpr=expression LPAR (operations+=operation (COMMA operations+=operation)*)? RPAR
;

caseOp:
    K_CASE
        (
              whens+=caseOpWhenClause+ caseOpElseClause?
            | caseOpElseClause
        )
    K_END
;

caseOpWhenClause:
    K_WHEN cond=condition K_THEN LPAR (operations+=operation (COMMA operations+=operation)*)? RPAR
;

caseOpElseClause:
    K_ELSE LPAR (operations+=operation (COMMA operations+=operation)*)? RPAR
;

copyOp:
    K_COPY pathExpr=expression EQUALS K_PATH? rhsExpr=expression formatClause?
    (
          onMissingHandler
        | onNullHandler
        | onEmptyHandler
    )*
;

intersectOp:
    K_INTERSECT pathExpr=expression EQUALS K_PATH? rhsExpr=expression formatClause?
    (
          onMissingHandler
        | onMismatchHandler
        | onNullHandler
    )*
;

mergeOp:
    K_MERGE pathExpr=expression EQUALS K_PATH? rhsExpr=expression formatClause?
    (
          onMissingHandler
        | onMismatchHandler
        | onNullHandler
        | onEmptyHandler
    )*
;

minusOp:
    K_MINUS pathExpr=expression EQUALS K_PATH? rhsExpr=expression formatClause?
    (
          onMissingHandler
        | onMismatchHandler
        | onNullHandler
    )*
;

// not documented, syntax according append
prependOp:
    K_PREPEND pathExpr=expression EQUALS K_PATH? rhsExpr=expression formatClause?
    (
          onMissingHandler
        | onMismatchHandler
        | onNullHandler
        | onEmptyHandler
    )*
;

unionOp:
    K_UNION pathExpr=expression EQUALS K_PATH? rhsExpr=expression formatClause?
    (
          onMissingHandler
        | onMismatchHandler
        | onNullHandler
    )*
;

// according https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/oracle-sql-function-json_transform.html#GUID-7BED994B-EAA3-4FF0-824D-C12ADAB862C1__GUID-B26D1238-D0C8-47AD-B904-50AE9573D7F7
onEmptyHandler:
    (K_NULL|K_ERROR|K_IGNORE) K_ON K_EMPTY
;

// according https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/oracle-sql-function-json_transform.html#GUID-7BED994B-EAA3-4FF0-824D-C12ADAB862C1__GUID-B26D1238-D0C8-47AD-B904-50AE9573D7F7
onErrorHandler:
    (K_NULL|K_ERROR|K_IGNORE) K_ON K_ERROR
;

// according https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/oracle-sql-function-json_transform.html#GUID-7BED994B-EAA3-4FF0-824D-C12ADAB862C1__GUID-B26D1238-D0C8-47AD-B904-50AE9573D7F7
onExistingHandler:
    (K_ERROR|K_IGNORE|K_REPLACE|K_REMOVE) K_ON K_EXISTING
;

// according https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/oracle-sql-function-json_transform.html#GUID-7BED994B-EAA3-4FF0-824D-C12ADAB862C1__GUID-B26D1238-D0C8-47AD-B904-50AE9573D7F7
onMismatchHandler:
    (K_NULL|K_ERROR|K_IGNORE|K_CREATE|K_REPLACE) K_ON K_MISMATCH
;

// according https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/oracle-sql-function-json_transform.html#GUID-7BED994B-EAA3-4FF0-824D-C12ADAB862C1__GUID-B26D1238-D0C8-47AD-B904-50AE9573D7F7
onMissingHandler:
    (K_ERROR|K_IGNORE|K_CREATE|K_NULL) K_ON K_MISSING
;

// according https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/oracle-sql-function-json_transform.html#GUID-7BED994B-EAA3-4FF0-824D-C12ADAB862C1__GUID-B26D1238-D0C8-47AD-B904-50AE9573D7F7
onNullHandler:
    (K_NULL|K_ERROR|K_IGNORE|K_REMOVE) K_ON K_NULL
;

// jsonBasicPathExpression is documented as optional, which makes no sense with a preceding comma
jsonValue:
    K_JSON_VALUE LPAR expr=expression formatClause? COMMA jsonBasicPathExpression
    jsonPassingClause? jsonValueReturningClause? jsonValueOnErrorClause?
    jsonValueOnEmptyClause? jsonValueOnMismatchClause? jsonTypeClause? RPAR
;

jsonEqualCondition:
    K_JSON_EQUAL LPAR expr1=expression COMMA expr2=expression jsonEqualConditionOption? RPAR
;

jsonEqualConditionOption:
      K_ERROR K_ON K_ERROR  # jsonEqualConditionErrorOnError
    | K_FALSE K_ON K_ERROR  # jsonEqualConditionFalseOnError
    | K_TRUE K_ON K_ERROR   # jsonEqualConditionTrueOnError
;

jsonExistsCondition:
    K_JSON_EXISTS LPAR
        expr=expression
        formatClause? COMMA path=expression
        jsonPassingClause? jsonExistsOnErrorClause?
        jsonExistsOnEmptyClause?
    RPAR
;

listagg:
    K_LISTAGG LPAR (K_ALL|K_DISTINCT)? expr=expression (COMMA delimiter=expression)? listaggOverflowClause? RPAR
        (K_WITHIN K_GROUP LPAR orderByClause RPAR)? (K_OVER LPAR queryPartitionClause? RPAR)?
;

nthValue:
    K_NTH_VALUE LPAR expr=expression COMMA n=expression RPAR
        (K_FROM (K_FIRST|K_LAST))?
        respectIgnoreNullsClause?
        overClause
;

costMatrixClause:
    K_COST
    (
          K_MODEL K_AUTO?
        | LPAR classValues+=expression (COMMA classValues+=expression)*
          RPAR K_VALUES LPAR costValues+=expression (COMMA costValues+=expression)* RPAR
    )
;

listaggOverflowClause:
      K_ON K_OVERFLOW K_ERROR
    | K_ON K_OVERFLOW K_TRUNCATE truncateIndicator=expression? ((K_WITH|K_WITHOUT) K_COUNT)?
;

// PostgreSQL
overlay:
    K_OVERLAY LPAR text=expression K_PLACING placing=expression
        K_FROM from=expression (K_FOR for=expression)? RPAR
;

// PostgreSQL
substring:
    K_SUBSTRING LPAR text=expression
    (
          K_FROM from=expression (K_FOR for=expression)?
        | K_FOR for=expression
        | K_SIMILAR pattern=expression K_ESCAPE escape=expression
    )
    RPAR
;

tableFunction:
    (K_TABLE|K_THE) LPAR (query=subquery|expr=expression) RPAR
;

treat:
    K_TREAT LPAR expr=expression K_AS
        (
              K_REF? (schema=sqlName PERIOD)? typeName=dataType
            | K_JSON
        )
    RPAR
;

trim:
    K_TRIM LPAR
        (
            (
                  (K_LEADING|K_TRAILING|K_BOTH) trimCharacter=expression?
                | trimCharacter=expression
            ) K_FROM
        )?
        trimSource=expression
        (COMMA trimCharacter=expression)?   // PostgreSQL
    RPAR
;

validateConversion:
    K_VALIDATE_CONVERSION LPAR expr=expression K_AS typeName=dataType
        (COMMA fmt=expression (COMMA nlsparam=expression)?)? RPAR
;

xmlcast:
    K_XMLCAST LPAR expr=expression K_AS typeName=dataType RPAR
;

xmlcolattval:
    K_XMLCOLATTVAL LPAR items+=xmlAttributeItem (COMMA items+=xmlAttributeItem)* RPAR
;

xmlelement:
    K_XMLELEMENT LPAR
        (K_ENTITYESCAPING|K_NOENTITYESCAPING)?
        (
              K_EVALNAME identifierExpr=expression
            | K_NAME? identifierName=sqlName
        )
        (COMMA xmlAttributesClause)?
        values+=xmlelementValue*
    RPAR
;

xmlAttributesClause:
    K_XMLATTRIBUTES LPAR
         (K_ENTITYESCAPING|K_NOENTITYESCAPING)?
         (K_SCHEMACHECK|K_NOSCHEMACHECK)?
         items+=xmlAttributeItem (COMMA items+=xmlAttributeItem)*
    RPAR
;

xmlAttributeItem:
    expr=expression
        (
              K_AS K_EVALNAME identifierExpr=expression
            | K_AS? K_NAME? identifierName=sqlName
        )?
;

xmlelementValue:
    COMMA expr=expression (K_AS? alias=sqlName)?
;

xmlexists:
    K_XMLEXISTS LPAR expr=expression xmlPassingClause? RPAR
;

xmlPassingClause:
    K_PASSING (K_BY K_VALUE)? items+=xmlPassingItem (COMMA items+=xmlPassingItem)*
;

xmlPassingItem:
    expr=expression (K_AS identifier=sqlName)?
;

xmlforest:
    K_XMLFOREST LPAR items+=xmlAttributeItem (COMMA items+=xmlAttributeItem)* RPAR
;

xmlparse:
    K_XMLPARSE LPAR (K_DOCUMENT|K_CONTENT) expr=expression K_WELLFORMED? RPAR
;

xmlpi:
    K_XMLPI LPAR
        (
              K_EVALNAME identifierExpr=expression
            | K_NAME? identifierName=sqlName
        ) (COMMA valueExpr=expression)?
    RPAR
;

xmlquery:
    K_XMLQUERY LPAR
        expr=expression xmlPassingClause? K_RETURNING K_CONTENT (K_NULL K_ON K_EMPTY)?
    RPAR
;

xmlroot:
    K_XMLROOT LPAR expr=expression
        COMMA K_VERSION (version=expression|K_NO K_VALUE)
        (COMMA K_STANDALONE xmlrootStandalone)?
    RPAR
;

xmlrootStandalone:
      K_YES         # xmlrootStandaloneYes
    | K_NO          # xmlrootStandaloneNo
    | K_NO K_VALUE  # xmlrootStandaloneNoValue
;

xmlserialize:
    K_XMLSERIALIZE LPAR
        (K_DOCUMENT|K_CONTENT) expr=expression (K_AS typeName=dataType)?
        (K_ENCODING encoding=expression)?
        (K_VERSION version=expression)?
        (K_NO K_INDENT|K_INDENT (K_SIZE EQUALS indent=expression)?)?
        ((K_HIDE|K_SHOW) K_DEFAULTS)?
    RPAR
;

xmltable:
    K_XMLTABLE LPAR (xmlNamespaceClause COMMA)? expr=expression xmltableOptions RPAR
;

xmlNamespaceClause:
    K_XMLNAMESPACES LPAR items+=xmlNamespaceItem (COMMA items+=xmlNamespaceItem)* RPAR
;

xmlNamespaceItem:
      expr=expression K_AS identifier=sqlName
    | K_DEFAULT defaultName=expression
;

xmltableOptions:
    xmlPassingClause?
    (K_RETURNING K_SEQUENCE K_BY K_REF)?
    (K_COLUMNS columns+=xmlTableColumn (COMMA columns+=xmlTableColumn)*)?
;

xmlTableColumn:
    column=sqlName
    (
          K_FOR K_ORDINALITY
        | (typeName=dataType|K_XMLTYPE (LPAR K_SEQUENCE RPAR K_BY K_REF)?)
          (K_PATH path=expression)? (K_DEFAULT defaultValue=expression)?
    )
;

functionExpression:
    name=sqlName (COMMAT dblink=qualifiedName)? LPAR (params+=functionParameter (COMMA params+=functionParameter)*)? RPAR
    withinClause?               // e.g. approx_percentile
    postgresfilterClause?       // e.g. count, sum
    keepClause?                 // e.g. first, last
    respectIgnoreNullsClause?   // e.g. lag
    overClause?                 // e.g. avg
;

functionParameter:
    // PostgreSQL := is older syntax supported for backward compatiblity only
    // OracleDB: no space between '=>' allowed
    (name=sqlName (EQUALS_GT | COLON EQUALS))? functionParameterPrefix? expr=condition functionParameterSuffix?
;

functionParameterPrefix:
      K_DISTINCT                // e.g. in any_value
    | K_ALL                     // e.g. in any_value
    | K_UNIQUE                  // e.g. bit_and_agg
    | K_INTO                    // e.g. cluster_details
    | K_OF                      // e.g. prediction_details
    | K_FOR                     // e.g. prediction_details
;

functionParameterSuffix:
      K_DETERMINISTIC                               // e.g. in approx_median, approx_percentile, approx_percentile_detail
    | K_USING K_NCHAR_CS                            // e.g. chr
    | K_USING K_CHAR_CS                             // e.g. translate
    | queryPartitionClause orderByClause            // e.g. approx_rank
    | queryPartitionClause                          // e.g. approx_rank
    | orderByClause                                 // e.g. approx_rank
    | weightOrderClause miningAttributeClause       // e.g. cluster_details
    | weightOrderClause                             // e.g. cluster_details
    | costMatrixClause miningAttributeClause        // e.g. prediction
    | miningAttributeClause                         // e.g. cluster_details
    | respectIgnoreNullsClause                      // e.g. lag
    | defaultOnConversionError                      // e.g. to_binary_double
;

// simplified: allow all combinations of aggregates
plsqlQualifiedExpression:
    typemark=sqlName LPAR aggregates+=aggregate? (COMMA aggregates+=aggregate)* RPAR
;

// simplified: others_choice handled as functionParameter
// functionExpression has precedence, as result some syntax variants are handled as functionExpression
aggregate:
      positionalChoiceList
    | explicitChoiceList
;

positionalChoiceList:
      expression
    | sequenceIteratorChoice
;

sequenceIteratorChoice:
    K_FOR iteratorName=sqlName K_SEQUENCE EQUALS_GT expr=expression
;

explicitChoiceList:
      namedChoiceList
    | indexedChoiceList
    | basicIteratorChoice
    | indexIteratorChoice
;

namedChoiceList:
    identifiers+=sqlName (VERBAR identifiers+=sqlName)* EQUALS_GT expr=expression
;

indexedChoiceList:
    indexes+=expression (VERBAR indexes+=expression)* EQUALS_GT expr=expression
;

basicIteratorChoice:
    K_FOR iteratorName=sqlName EQUALS_GT expr=expression
;

indexIteratorChoice:
    K_FOR iteratorName=sqlName K_INDEX EQUALS_GT expr=expression
;

placeholderExpression:
    COLON hostVariable=placeholderVariable (K_INDICATOR? COLON indicatorVariable=placeholderVariable)?
;

// a host variable be a unsigned integer
placeholderVariable:
      sqlName
    | NUMBER
;

withinClause:
    K_WITHIN K_GROUP LPAR orderByClause RPAR
;

postgresfilterClause:
    K_FILTER LPAR whereClause RPAR
;

keepClause:
    K_KEEP LPAR K_DENSE_RANK (K_FIRST|K_LAST) orderByClause RPAR
;

orderByClause:
    K_ORDER K_SIBLINGS? K_BY items+=orderByItem (COMMA items+=orderByItem)*
;

// PostgreSQL: using operator
orderByItem:
    expr=expression (K_ASC|K_DESC|K_USING orderByUsingOperator)? (K_NULLS (K_FIRST|K_LAST))?
;

// PostgreSQL (member of some B-tree operator family)
orderByUsingOperator:
      simpleComparisionOperator
    | binaryOperator
;

queryPartitionClause:
    K_PARTITION K_BY exprs+=expression (COMMA exprs+=expression)*
;

// artifical clause used before mining_attribute_clause
weightOrderClause:
      K_DESC
    | K_ASC
    | K_ABS
;

miningAttributeClause:
    K_USING (
          AST
        | attributes+=miningAttribute (COMMA attributes+=miningAttribute)*
    )
;

// undocumented: optionality of "as"
miningAttribute:
      (schema=sqlName PERIOD)? table=sqlName PERIOD AST
    | expr=expression (K_AS? alias=sqlName)?
;

overClause:
    K_OVER (windowName=sqlName|LPAR analyticClause RPAR)
;

analyticClause:
    (windowName=sqlName|queryPartitionClause)? (orderByClause windowingClause?)?
;

// called frame_clause in PostgreSQL
windowingClause:
    windowFrame=(K_ROWS|K_RANGE|K_GROUPS)
    (
          K_BETWEEN
          (
                fromUnboundedPreceding=K_UNBOUNDED K_PRECEDING
              | fromCurrentRow=K_CURRENT K_ROW
              | fromValuePreceding=expression K_PRECEDING
              | fromValueFollowing=expression K_FOLLOWING
          )
          K_AND
          (
                toUnboundedFollowing=K_UNBOUNDED K_FOLLOWING
              | toCurrentRow=K_CURRENT K_ROW
              | toValuePreceding=expression K_PRECEDING
              | toValueFollowing=expression K_FOLLOWING
          )
        | unboundedPreceding=K_UNBOUNDED K_PRECEDING
        | currentRow=K_CURRENT K_ROW
        | valuePreceding=expression K_PRECEDING
    )
    (
        K_EXCLUDE
        (
              excludeCurrentRow=K_CURRENT K_ROW
            | excludeGroup=K_GROUP // wrong documentation in OracleDB 23c (groups instead of group)
            | excludeTies=K_TIES
            | excludeNoOthers=K_NO K_OTHERS
        )
    )?
;

unaryOperator:
      PLUS                  # positiveSignOperator
    | MINUS                 # negativeSignOperator
    | COMMAT                # absoluteOperator          // PostgreSQL
    | VERBAR_SOL            # squareRootOperator        // PostgreSQL
    | VERBAR_VERBAR_SOL     # cubeRootOperator          // PostgreSQL
    | TILDE                 # bitwiseNotOperator        // PostgreSQL
    | COMMAT_MINUS_COMMAT   # totalLenthOperator        // PostgreSQL
    | COMMAT_COMMAT         # centerPointOperator       // PostgreSQL
    | NUM                   # numberOfPointsOperator    // PostgreSQL
    | QUEST_MINUS           # horizontalLineOperator    // PostgreSQL
    | QUEST_VERBAR          # verticalLineOperator      // PostgreSQL
    | EXCL_EXCL             # negateTsQueryOperator     // PostgreSQL
    | K_PRIOR               # priorOpertor              // hierarchical query operator
    | K_CONNECT_BY_ROOT     # connectByRootOperator     // hierarchical query operator
    | K_RUNNING             # runningOperator           // row_pattern_nav_logical
    | K_FINAL               # finalOperator             // row_pattern_nav_logical
    | K_NEW                 # newOperator               // type constructor
    | K_CURRENT K_OF        # currentOfOperator         // operator as update extension in PL/SQL where clause
;

// binary operators not handled in expression, only single token operators
// operator meaning is based on context, label can be misleading
// custom PostGIS operators according see https://postgis.net/docs/manual-3.4/reference.html#Operators
binaryOperator:
      AMP                           # bitwiseAndOperator
    | AMP_AMP                       # overlapsOperator
    | AMP_AMP_AMP                   # nDimIntersectOperator         // PostGIS
    | AMP_GT                        # notExtendsLeftOperator
    | AMP_LT                        # notExtendsRightOperator
    | AMP_LT_VERBAR                 # notExtendsAboveOperator
    | AMP_SOL_AMP                   # threeDimOverlapsOperator      // PostGIS, undocumented
    | COMMAT                        # absoluteValueOperator
    | COMMAT_COMMAT                 # matchOperator
    | COMMAT_COMMAT_COMMAT          # matchOperator                 // deprecated
    | COMMAT_GT                     # containsOperator
    | COMMAT_GT_GT                  # threeDimContainsOperator      // PostGIS, undocumented
    | COMMAT_QUEST                  # returnsAnyItemOperator
    | EXCL_TILDE                    # notMatchRegexOperator
    | EXCL_TILDE_AST                # notMatchRegexCaseInsensitiveOperator
    | GT_GT                         # bitwiseShiftRightOperator
    | GT_GT_EQUALS                  # strictlyContainsOrEqualOperator
    | GT_HAT                        # aboveOperator
    | HAT_COMMAT                    # startsWithOperator
    | LT_COMMAT                     # containedByOperator
    | LT_LT                         # bitwiseShiftLeftOperator
    | LT_LT_EQUALS                  # strictlyContainedByOrEqualOperator
    | LT_LT_MINUS_GT_GT             # nDimDistanceOperator          // PostGIS
    | LT_LT_NUM_GT_GT               # nDimBoxDistanceOperator       // PostGIS
    | LT_LT_VERBAR                  # strictlyBelowOperator
    | LT_HAT                        # belowOperator
    | LT_MINUS_GT                   # distanceOperator
    | LT_NUM_GT                     # boxDistanceOperator           // PostGIS
    | MINUS_GT                      # extractElementOperator
    | MINUS_GT_GT                   # extractObjectOperator
    | MINUS_VERBAR_MINUS            # adjacentOperator
    | NUM                           # bitwiseXorOperator
    | NUM_GT                        # extractSubObjectOperator
    | NUM_GT_GT                     # extractSubObjectTextOperator
    | QUEST                         # existsAnyOperator
    | QUEST_AMP                     # existsAllOperator
    | QUEST_NUM                     # intersectOperator
    | QUEST_MINUS                   # horizontallyAlignedOperator
    | QUEST_MINUS_VERBAR            # linesPerpendicularOperator
    | QUEST_MINUS_VERBAR_VERBAR     # linesParallelOperator
    | QUEST_VERBAR                  # existsAnyOperator
    | TILDE                         # boxContainsOperator           // PostGIS
    | TILDE_AST                     # matchRegexCaseInsensitiveOperator
    | TILDE_EQUAL_EQUAL             # threeDimSame                  // PostGIS, undocumented
    | TILDE_TILDE_EQUAL             # nDimSame                      // PostGIS, undocumented
    | VERBAR                        # bitwiseOrOperator
    | VERBAR_AMP_GT                 # notExtendsBelowOperator
    | VERBAR_EQUALS_VERBAR          # closestDistanceOperator
    | VERBAR_GT_GT                  # strictlyAboveOperator
;

postgresqlArrayConstructor:
      K_ARRAY LSQB (exprs+=postgresqlArrayElement (COMMA exprs+=postgresqlArrayElement)*)? RSQB
    | K_ARRAY LPAR expr=subquery RPAR
;

postgresqlArrayElement:
      expr=expression                                                                # postgresqlArrayElementItem
    | LSQB exprs+=postgresqlArrayElement (COMMA exprs+=postgresqlArrayElement)* RSQB # postgresqlArrayElementList
;

/*----------------------------------------------------------------------------*/
// Condition
/*----------------------------------------------------------------------------*/

// starting with 23c a condition is treated as a synonym to an expression
// therefore condition is implementend in expression
condition:
      cond=expression
;

// based on condition, considering only those conditions with a leading expression predicate
// that can be ommitted in a dangling_predicate of a case expression and case statement
danglingCondition:
      operator=K_AND right=expression                   # logicalConditionDangling
    | operator=K_OR right=expression                    # logicalConditionDangling
    | operator=simpleComparisionOperator
        groupOperator=(K_ANY|K_SOME|K_ALL)
        right=expression                                # groupComparisionConditionDangling
    | operator=simpleComparisionOperator
        right=expression                                # simpleComparisionConditionDangling
    | operator=K_IS K_NOT? (K_NAN|K_INFINITE)           # floatingPointConditionDangling
    | operator=K_IS K_ANY                               # isAnyConditionDangling // "any" only is handled as sqlName
    | operator=K_IS K_PRESENT                           # isPresentConditionDangling
    | operator=K_IS K_NOT? K_A K_SET                    # isASetConditionDangling
    | operator=K_IS K_NOT? K_EMPTY                      # isEmptyConditionDangling
    | operator=K_IS K_NOT? K_NULL                       # isNullConditionDangling
    | operator=K_IS K_NOT? K_TRUE                       # isTrueConditionDangling
    | operator=K_IS K_NOT? K_FALSE                      # isFalseConditionDangling
    | operator=K_IS K_NOT? K_DANGLING                   # isDanglingConditionDangling
    | operator=K_IS K_NOT? K_JSON formatClause?
        (
            LPAR (options+=jsonConditionOption+) RPAR
          | options+=jsonConditionOption*
        )                                               # isJsonConditionDangling
    | K_NOT? operator=K_MEMBER
        K_OF? right=expression                          # memberConditionDangling
    | K_NOT? operator=K_SUBMULTISET
        K_OF? right=expression                          # submultisetConditionDangling
    | K_NOT? operator=(K_LIKE|K_LIKEC|K_LIKE2|K_LIKE4)
        right=expression
        (K_ESCAPE escChar=expression)?                  # likeConditionDangling
    | K_NOT? operator=K_BETWEEN
        expr2=expression K_AND expr3=expression         # betweenConditionDangling
    | K_NOT? operator=K_IN
        right=expression                                # inConditionDangling
    | K_IS K_NOT? K_OF K_TYPE?
        LPAR types+=isOfTypeConditionItem
        (COMMA types+=isOfTypeConditionItem)* RPAR      # isOfTypeConditionDangling
;

jsonPassingClause:
    K_PASSING items+=jsonPassingItem (COMMA items+=jsonPassingItem)*
;

jsonPassingItem:
    expr=expression K_AS identifier=sqlName
;

jsonExistsOnErrorClause:
    (K_ERROR|K_TRUE|K_FALSE) K_ON K_ERROR
;

jsonExistsOnEmptyClause:
    (K_ERROR|K_TRUE|K_FALSE) K_ON K_EMPTY
;

simpleComparisionOperator:
      EQUALS            # eq
    | EXCL EQUALS       # ne
    | LT GT             # ne
    | TILDE EQUALS      # ne
    | HAT EQUALS        # ne
    | GT                # gt
    | LT                # lt
    | GT EQUALS         # ge
    | LT EQUALS         # le
;

// it's possible but not documented that options can be used in an arbitrary order
// it's also possible but not documented to place the options in parenthesis
jsonConditionOption:
      K_STRICT                                      # jsonConditionOptionStrict
    | K_LAX                                         # jsonConditionOptionLax
    | K_ALLOW K_SCALARS                             # jsonConditionOptionAllowScalars
    | K_DISALLOW K_SCALARS                          # jsonConditionOptionDisallowSclars
    | K_WITH K_UNIQUE K_KEYS                        # jsonConditionOptionWithUniqueKeys
    | K_WITHOUT K_UNIQUE K_KEYS                     # jsonConditionOptionWithoutUniqueKeys
    | K_VALIDATE K_CAST? K_USING? schema=expression # jsonConditionOptionValidate
;

isOfTypeConditionItem:
    K_ONLY? (schema=sqlName PERIOD)? type=sqlName
;

/*----------------------------------------------------------------------------*/
// Identifiers
/*----------------------------------------------------------------------------*/

keywordAsId:
      K_A
    | K_ABS
    | K_ABSENT
    | K_ACCESS
    | K_ACCESSIBLE
    | K_ACROSS
    | K_ADD
    | K_AFTER
    | K_AGENT
    | K_AGGREGATE
    | K_ALL
    | K_ALLOW
    | K_ANALYTIC
    | K_ANALYZE
    | K_ANCESTOR
    | K_AND
    | K_ANY
    | K_APPEND
    | K_APPLY
    | K_ARRAY
    | K_AS
    | K_ASC
    | K_ASCII
    | K_AT
    | K_AUTHID
    | K_AUTO
    | K_AUTOMATIC
    | K_AVERAGE_RANK
    | K_BADFILE
    | K_BATCH
    | K_BEGIN
    | K_BEGINNING
    | K_BETWEEN
    | K_BFILE
    | K_BIGINT
    | K_BIGRAM
    | K_BIGSERIAL
    | K_BINARY_DOUBLE
    | K_BINARY_FLOAT
    | K_BIT
    | K_BLOB
    | K_BLOCK
    | K_BODY
    | K_BOOL
    | K_BOOLEAN
    | K_BOTH
    | K_BOX
    | K_BREADTH
    | K_BUFFERS
    | K_BULK
    | K_BY
    | K_BYTE
    | K_BYTEA
    | K_C
    | K_CALL
    | K_CALLED
    | K_CASE
    | K_CASE_SENSITIVE
    | K_CAST
    | K_CHAIN
    | K_CHAR
    | K_CHARACTER
    | K_CHARACTERISTICS
    | K_CHARSETFORM
    | K_CHARSETID
    | K_CHAR_CS
    | K_CHECK
    | K_CIDR
    | K_CIRCLE
    | K_CLOB
    | K_CLOSE
    | K_CLUSTER
    | K_COLLATE
    | K_COLLATION
    | K_COLLECT
    | K_COLUMNS
    | K_COMMENT
    | K_COMMIT
    | K_COMMITTED
    | K_CONDITIONAL
    | K_CONFLICT
    | K_CONNECT
    | K_CONNECT_BY_ROOT
    | K_CONSTANT
    | K_CONSTRAINT
    | K_CONSTRAINTS
    | K_CONTAINERS_DEFAULT
    | K_CONTAINER_MAP
    | K_CONTENT
    | K_CONTEXT
    | K_CONTINUE
    | K_CONVERSION
    | K_COPY
    | K_CORRUPT_XID
    | K_CORRUPT_XID_ALL
    | K_COST
    | K_COSTS
    | K_COUNT
    | K_CREATE
    | K_CROSS
    | K_CURRENT
    | K_CURRENT_USER
    | K_CURSOR
    | K_CYCLE
    | K_DAMERAU_LEVENSHTEIN
    | K_DANGLING
    | K_DATA
    | K_DATE
    | K_DAY
    | K_DBTIMEZONE
    | K_DEC
    | K_DECIMAL
    | K_DECLARE
    | K_DECREMENT
    | K_DEFAULT
    | K_DEFAULTS
    | K_DEFERRABLE
    | K_DEFERRED
    | K_DEFINE
    | K_DEFINER
    | K_DELETE
    | K_DENSE_RANK
    | K_DEPTH
    | K_DESC
    | K_DETERMINISTIC
    | K_DIMENSION
    | K_DIRECTORY
    | K_DISALLOW
    | K_DISCARD
    | K_DISTINCT
    | K_DO
    | K_DOCUMENT
    | K_DOMAIN
    | K_DOUBLE
    | K_DURATION
    | K_EDITIONABLE
    | K_EDIT_TOLERANCE
    | K_ELSE
    | K_ELSIF
    | K_EMPTY
    | K_ENCODING
    | K_END
    | K_ENTITYESCAPING
    | K_ENV
    | K_ERROR
    | K_ERRORS
    | K_ESCAPE
    | K_EVALNAME
    | K_EXCEPT
    | K_EXCEPTION
    | K_EXCEPTIONS
    | K_EXCLUDE
    | K_EXCLUSIVE
    | K_EXECUTE
    | K_EXISTING
    | K_EXISTS
    | K_EXIT
    | K_EXPLAIN
    | K_EXTERNAL
    | K_EXTRA
    | K_EXTRACT
    | K_FACT
    | K_FALSE
    | K_FEATURE_COMPARE
    | K_FETCH
    | K_FILTER
    | K_FINAL
    | K_FIRST
    | K_FLOAT4
    | K_FLOAT8
    | K_FLOAT
    | K_FOLLOWING
    | K_FOR
    | K_FORALL
    | K_FORCE
    | K_FORMAT
    | K_FROM
    | K_FULL
    | K_FUNCTION
    | K_FUZZY_MATCH
    | K_GENERIC_PLAN
    | K_GOTO
    | K_GRAPH_TABLE
    | K_GROUP
    | K_GROUPING
    | K_GROUPS
    | K_HASH
    | K_HAVING
    | K_HIDE
    | K_HIERARCHIES
    | K_HIERARCHY
    | K_HIER_ANCESTOR
    | K_HIER_CAPTION
    | K_HIER_CHILD_COUNT
    | K_HIER_DEPTH
    | K_HIER_DESCRIPTION
    | K_HIER_LAG
    | K_HIER_LEAD
    | K_HIER_LEVEL
    | K_HIER_MEMBER_NAME
    | K_HIER_MEMBER_UNIQUE_NAME
    | K_HIER_PARENT
    | K_HIER_PARENT_LEVEL
    | K_HIER_PARENT_UNIQUE_NAME
    | K_HOUR
    | K_IF
    | K_IGNORE
    | K_IMMEDIATE
    | K_IMMUTABLE
    | K_IN
    | K_INCLUDE
    | K_INCREMENT
    | K_INDENT
    | K_INDEX
    | K_INDICATOR
    | K_INDICES
    | K_INET
    | K_INFINITE
    | K_INNER
    | K_INPUT
    | K_INSERT
    | K_INT2
    | K_INT4
    | K_INT8
    | K_INT
    | K_INTEGER
    | K_INTERSECT
    | K_INTERVAL
    | K_INTO
    | K_INVISIBLE
    | K_INVOKER
    | K_IS
    | K_ISNULL
    | K_ISOLATION
    | K_ITERATE
    | K_JARO_WINKLER
    | K_JAVA
    | K_JOIN
    | K_JSON
    | K_JSONB
    | K_JSON_ARRAY
    | K_JSON_ARRAYAGG
    | K_JSON_EQUAL
    | K_JSON_EXISTS
    | K_JSON_MERGEPATCH
    | K_JSON_OBJECT
    | K_JSON_OBJECTAGG
    | K_JSON_QUERY
    | K_JSON_SCALAR
    | K_JSON_SERIALIZE
    | K_JSON_TABLE
    | K_JSON_TRANSFORM
    | K_JSON_VALUE
    | K_KEEP
    | K_KEY
    | K_KEYS
    | K_LAG
    | K_LAG_DIFF
    | K_LAG_DIFF_PERCENT
    | K_LANGUAGE
    | K_LAST
    | K_LATERAL
    | K_LAX
    | K_LEAD
    | K_LEADING
    | K_LEAD_DIFF
    | K_LEAD_DIFF_PERCENT
    | K_LEAKPROOF
    | K_LEFT
    | K_LENGTH
    | K_LEVEL
    | K_LEVENSHTEIN
    | K_LIBRARY
    | K_LIKE2
    | K_LIKE4
    | K_LIKE
    | K_LIKEC
    | K_LIMIT
    | K_LINE
    | K_LISTAGG
    | K_LOCAL
    | K_LOCATION
    | K_LOCK
    | K_LOCKED
    | K_LOG
    | K_LOGFILE
    | K_LONG
    | K_LONGEST_COMMON_SUBSTRING
    | K_LOOP
    | K_LSEG
    | K_MACADDR8
    | K_MACADDR
    | K_MAIN
    | K_MAPPING
    | K_MATCH
    | K_MATCHED
    | K_MATCHES
    | K_MATCH_RECOGNIZE
    | K_MATERIALIZED
    | K_MAXLEN
    | K_MEASURES
    | K_MEMBER
    | K_MERGE
    | K_METADATA
    | K_MINUS
    | K_MINUTE
    | K_MISMATCH
    | K_MISSING
    | K_MLE
    | K_MODE
    | K_MODEL
    | K_MODIFY
    | K_MODULE
    | K_MONEY
    | K_MONTH
    | K_MULTISET
    | K_MUTABLE
    | K_NAME
    | K_NAN
    | K_NATIONAL
    | K_NATURAL
    | K_NAV
    | K_NCHAR
    | K_NCHAR_CS
    | K_NCLOB
    | K_NESTED
    | K_NEW
    | K_NEXT
    | K_NO
    | K_NOCOPY
    | K_NOCYCLE
    | K_NOENTITYESCAPING
    | K_NONE
    | K_NONEDITIONABLE
    | K_NOSCHEMACHECK
    | K_NOT
    | K_NOTHING
    | K_NOTNULL
    | K_NOVALIDATE
    | K_NOWAIT
    | K_NTH_VALUE
    | K_NULL
    | K_NULLS
    | K_NUMBER
    | K_NUMERIC
    | K_NVARCHAR2
    | K_OBJECT
    | K_OF
    | K_OFFSET
    | K_OLD
    | K_OMIT
    | K_ON
    | K_ONE
    | K_ONLY
    | K_OPEN
    | K_OPTION
    | K_OR
    | K_ORDER
    | K_ORDERED
    | K_ORDINALITY
    | K_OTHERS
    | K_OUT
    | K_OUTER
    | K_OVER
    | K_OVERFLOW
    | K_OVERLAY
    | K_OVERRIDING
    | K_PACKAGE
    | K_PAIRS
    | K_PARALLEL
    | K_PARALLEL_ENABLE
    | K_PARAMETERS
    | K_PARENT
    | K_PARTITION
    | K_PASSING
    | K_PAST
    | K_PATH
    | K_PATTERN
    | K_PER
    | K_PERCENT
    | K_PERIOD
    | K_PERMUTE
    | K_PG_LSN
    | K_PG_SNAPSHOT
    | K_PIPE
    | K_PIPELINED
    | K_PIVOT
    | K_PLACING
    | K_PLAN
    | K_POINT
    | K_POLYGON
    | K_POLYMORPHIC
    | K_POSITION
    | K_PRECEDING
    | K_PRECISION
    | K_PREDICTION
    | K_PREDICTION_COST
    | K_PREDICTION_DETAILS
    | K_PREPARED
    | K_PREPEND
    | K_PRESENT
    | K_PRESERVE
    | K_PRETTY
    | K_PRIOR
    | K_PROCEDURE
    | K_QUALIFY
    | K_RAISE
    | K_RANGE
    | K_RANK
    | K_RAW
    | K_READ
    | K_REAL
    | K_RECORD
    | K_RECURSIVE
    | K_REF
    | K_REFERENCE
    | K_REJECT
    | K_RELATE_TO_SHORTER
    | K_RELIES_ON
    | K_REMOVE
    | K_RENAME
    | K_REPEAT
    | K_REPEATABLE
    | K_REPLACE
    | K_RESERVABLE
    | K_RESPECT
    | K_RESTRICTED
    | K_RESULT_CACHE
    | K_RETURN
    | K_RETURNING
    | K_RETURNS
    | K_REVERSE
    | K_RIGHT
    | K_ROLLBACK
    | K_ROW
    | K_ROWID
    | K_ROWS
    | K_ROWTYPE
    | K_ROW_NUMBER
    | K_RULES
    | K_RUNNING
    | K_SAFE
    | K_SAMPLE
    | K_SAVE
    | K_SAVEPOINT
    | K_SCALAR
    | K_SCALARS
    | K_SCHEMACHECK
    | K_SCN
    | K_SDO_GEOMETRY
    | K_SEARCH
    | K_SECOND
    | K_SECURITY
    | K_SEED
    | K_SEGMENT
    | K_SELECT
    | K_SELF
    | K_SEQUENCE
    | K_SEQUENTIAL
    | K_SERIAL2
    | K_SERIAL4
    | K_SERIAL8
    | K_SERIAL
    | K_SERIALIZABLE
    | K_SESSION
    | K_SESSIONTIMEZONE
    | K_SET
    | K_SETOF
    | K_SETS
    | K_SHARD_ENABLE
    | K_SHARE
    | K_SHARE_OF
    | K_SHARING
    | K_SHOW
    | K_SIBLINGS
    | K_SIGNATURE
    | K_SIMILAR
    | K_SINGLE
    | K_SIZE
    | K_SKIP
    | K_SMALLINT
    | K_SMALLSERIAL
    | K_SNAPSHOT
    | K_SOME
    | K_SORT
    | K_SQL
    | K_SQL_MACRO
    | K_STABLE
    | K_STANDALONE
    | K_START
    | K_STATEMENT_ID
    | K_STRICT
    | K_STRUCT
    | K_SUBMULTISET
    | K_SUBPARTITION
    | K_SUBSET
    | K_SUBSTRING
    | K_SUBTYPE
    | K_SUMMARY
    | K_SUPPORT
    | K_SYMMETRIC
    | K_SYSTEM
    | K_TABLE
    | K_TABLESAMPLE
    | K_TDO
    | K_TEMP
    | K_TEMPORARY
    | K_TEXT
    | K_THE
    | K_THEN
    | K_TIES
    | K_TIME
    | K_TIMESTAMP
    | K_TIMESTAMPTZ
    | K_TIMETZ
    | K_TIMEZONE
    | K_TIMING
    | K_TO
    | K_TRAILING
    | K_TRANSACTION
    | K_TRANSFORM
    | K_TREAT
    | K_TRIGGER
    | K_TRIGRAM
    | K_TRIM
    | K_TRUE
    | K_TRUNCATE
    | K_TSQUERY
    | K_TSVECTOR
    | K_TXID_SNAPSHOT
    | K_TYPE
    | K_TYPENAME
    | K_UESCAPE
    | K_UNBOUNDED
    | K_UNCOMMITTED
    | K_UNCONDITIONAL
    | K_UNION
    | K_UNIQUE
    | K_UNKNOWN
    | K_UNLIMITED
    | K_UNLOGGED
    | K_UNMATCHED
    | K_UNPIVOT
    | K_UNSAFE
    | K_UNSCALED
    | K_UNTIL
    | K_UPDATE
    | K_UPDATED
    | K_UPSERT
    | K_UROWID
    | K_USE
    | K_USER
    | K_USING
    | K_UUID
    | K_VALIDATE
    | K_VALIDATE_CONVERSION
    | K_VALUE
    | K_VALUES
    | K_VARBIT
    | K_VARCHAR2
    | K_VARCHAR
    | K_VARRAY
    | K_VARYING
    | K_VERBOSE
    | K_VERSION
    | K_VERSIONS
    | K_VIEW
    | K_VISIBLE
    | K_VOLATILE
    | K_WAIT
    | K_WAL
    | K_WELLFORMED
    | K_WHEN
    | K_WHERE
    | K_WHILE
    | K_WHOLE_WORD_MATCH
    | K_WINDOW
    | K_WITH
    | K_WITHIN
    | K_WITHOUT
    | K_WORK
    | K_WRAPPER
    | K_WRITE
    | K_XML
    | K_XMLATTRIBUTES
    | K_XMLCAST
    | K_XMLCOLATTVAL
    | K_XMLELEMENT
    | K_XMLEXISTS
    | K_XMLFOREST
    | K_XMLNAMESPACES
    | K_XMLPARSE
    | K_XMLPI
    | K_XMLQUERY
    | K_XMLROOT
    | K_XMLSERIALIZE
    | K_XMLTABLE
    | K_XMLTYPE
    | K_YAML
    | K_YEAR
    | K_YES
    | K_ZONE
;

unquotedId:
      ID
    | keywordAsId
;

sqlName:
      unquotedId
    | QUOTED_ID
    | PLSQL_INQUIRY_DIRECTIVE
    | substitionVariable+
    | POSITIONAL_PARAMETER          // PostgreSQL
    | unicodeIdentifier             // PostgreSQL
    | psqlVariable                  // PostgreSQL
;

// PostgreSQL
unicodeIdentifier:
    UQUOTED_ID (K_UESCAPE STRING)?
;

// PostgreSQL
psqlVariable:
      COLON variable=qualifiedName
    | COLON stringVariable=STRING
;

// parser rule to handle conflict with PostgreSQL & operator
substitionVariable:
    (AMP|AMP_AMP) name=substitionVariableName period=PERIOD?
;

substitionVariableName:
      NUMBER
    | unquotedId
;

qualifiedName:
    sqlName (PERIOD sqlName)*
;

/*----------------------------------------------------------------------------*/
// Data Types
/*----------------------------------------------------------------------------*/

// A parser rule to distinguish between string types.
// Furthermore, it will simplify writing a value provider for a string.
string:
      STRING                                # simpleString
    | N_STRING                              # nationalString
    | N_STRING STRING+                      # concatenatedNationalString            // PostgreSQL, MySQL
    | E_STRING                              # escapedString                         // PostgreSQL
    | U_AMP_STRING (K_UESCAPE STRING)?      # unicodeString                         // PostgreSQL
    | B_STRING                              # bitString                             // PostgreSQL
    | STRING STRING+                        # concatenatedString                    // PostgreSQL, MySQL
    | Q_STRING                              # quoteDelimiterString
    | NQ_STRING                             # nationalQuoteDelimiterString
    | DOLLAR_STRING                         # dollarString                          // PostgreSQL
    | DOLLAR_ID_STRING                      # dollarIdentifierString                // PostgreSQL
;

/*----------------------------------------------------------------------------*/
// SQL statement end, slash accepted without preceding newline
/*----------------------------------------------------------------------------*/

sqlEnd:
      EOF
    | SEMI SOL?
    | SOL
    | PSQL_EXEC // PostgreSQL: alternative to semicolon to terminate a statement
    | BSOL SEMI // PostgreSQL: alternative to semicolon to terminate a statement
;
