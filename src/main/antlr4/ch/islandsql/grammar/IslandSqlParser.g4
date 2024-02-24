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
      dmlStatement
    | emptyStatement
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
          K_ONLY? dmlTableExpressionClause AST?             // PostgreSQL: only/*
        | K_ONLY LPAR dmlTableExpressionClause RPAR
    ) talias=sqlName?
    fromUsingClause?
    whereClause?
    returningClause?
    errorLoggingClause?
;

// simplified, table_collection_expression treated as expression
dmlTableExpressionClause:
      (schema=sqlName PERIOD)? table=sqlName (partitionExtensionClause | COMMAT dblink=qualifiedName)?
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
              LPAR option+=explainOption (COMMA option+=explainOption)* RPAR
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
    | K_ON K_CONSTRAINT constraint=sqlName
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
    K_LOCK K_TABLE objects+=lockTableObject (COMMA objects+=lockTableObject)*
        K_IN lockMode K_MODE lockTableWaitOption?
;

lockTableObject:
    (schema=sqlName PERIOD)? table=sqlName (partitionExtensionClause|COMMAT dblink=qualifiedName)?
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
    | K_SHARE K_UPDATE              # shareUpdateLockMode
    | K_SHARE                       # shareLockMode
    | K_SHARE K_ROW K_EXCLUSIVE     # shareRowExclusiveLockMode
    | K_EXCLUSIVE                   # exclusiveLockMode
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
    {unhideFirstHint();} K_MERGE hint?
    mergeIntoClause
    mergeUsingClause
    K_ON LPAR cond=condition RPAR
    (
          mergeUpdateClause mergeInsertClause?
        | mergeInsertClause
    )
    errorLoggingClause?
;

// artifical clause, undocumented: database link and subquery
// simplified using database link and subquery
mergeIntoClause:
    K_INTO dmlTableExpressionClause talias=sqlName?
;

// artifical clause, undocumented: database link, table function
// simplified using values_clause, subquery, database link, table function as query_table_expression
mergeUsingClause:
    K_USING queryTableExpression talias=sqlName?
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

/*----------------------------------------------------------------------------*/
// Select
/*----------------------------------------------------------------------------*/

selectStatement:
      select sqlEnd
    | LPAR select RPAR // in cursor for loop - TODO: remove with PL/SQL block support, see https://github.com/IslandSQL/IslandSQL/issues/29
;

select:
    subquery forUpdateClause?
    subqueryRestrictionClause? (K_CONTAINER_MAP|K_CONTAINERS_DEFAULT)? // TODO: remove with create view support, see https://github.com/IslandSQL/IslandSQL/issues/35
;

// moved with_clause from query_block to support main query in parenthesis (works, undocumented)
// undocumented: for_update_clause can be used before order_by_clause (but not with row_limiting_clause)
// PostgreSQL allows to use the values_clause as subquery in the with_clause (e.g. with set_operator)
subquery:
      withClause? queryBlock forUpdateClause? orderByClause? rowLimitingClause?         # subqueryQueryBlock
    | left=subquery setOperator right=subquery                                          # subquerySet
    | withClause? LPAR subquery RPAR forUpdateClause? orderByClause? rowLimitingClause? # subqueryParen
    | valuesClause orderByClause? rowLimitingClause?                                    # subqueryValues
;

queryBlock:
    {unhideFirstHint();} K_SELECT hint?
    queryBlockSetOperator?
    selectList
    (intoClause | bulkCollectIntoClause)? // in PL/SQL only
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

plsqlDeclarations:
      functionDeclaration
    | procedureDeclaration
;

// TODO: complete PL/SQL support, see https://github.com/IslandSQL/IslandSQL/issues/29
functionDeclaration:
    K_FUNCTION plsqlCode K_END sqlName? SEMI
;

// TODO: complete PL/SQL support, see https://github.com/IslandSQL/IslandSQL/issues/29
procedureDeclaration:
    K_PROCEDURE plsqlCode K_END sqlName? SEMI
;

// TODO: replace with complete PL/SQL support, see https://github.com/IslandSQL/IslandSQL/issues/29
plsqlCode:
    .+?
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
      LPAR expr+=expression (COMMA expr+=expression)* RPAR
    | expr+=expression
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
    K_TO cycleValue=expression
    K_DEFAULT noCycleValue=expression
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
    K_FILTER K_FACT LPAR filter+=filterClause (COMMA filter+=filterClause)* RPAR
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

groupByClause:
      K_GROUP K_BY items+=groupByItem (COMMA items+=groupByItem)* (K_HAVING cond=condition)?
    | K_HAVING cond=condition (K_GROUP K_BY items+=groupByItem (COMMA items+=groupByItem)*)? // undocumented, but allowed
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
      K_DISTINCT      # distinctQbOperator
    | K_UNIQUE        # distinctQbOperator
    | K_ALL           # allQbOperator
;

setOperator:
      K_UNION     K_ALL?    # unionSetOperator
    | K_INTERSECT K_ALL?    # intersectSetOperator
    | K_MINUS     K_ALL?    # minusSetOperator
    | K_EXCEPT    K_ALL?    # minusSetOperator
;

// only in PL/SQL
intoClause:
    K_INTO variables+=expression (COMMA variables+=expression)*
;

// only in PL/SQL
bulkCollectIntoClause:
    K_BULK K_COLLECT K_INTO variables+=expression (COMMA variables+=expression)*
;

fromClause:
    K_FROM items+=fromItem (COMMA items+=fromItem)*
;

fromItem:
      tableReference               # tableReferenceFromItem
    | fromItem joins+=joinVariant+ # joinClause
    | inlineAnalyticView           # inlineAnalyticViewFromItem
    | LPAR fromItem RPAR           # parenFromItem
;

// containers_clause and shards_clause handeled as queryTableExpression (functions named containers/shards)
// undocumented: use of optional AS in json_table (query_table_expression)
// undocumented: use of invalid t_alias before row_pattern_clause, see issue #74
tableReference:
      K_ONLY LPAR qte=queryTableExpression RPAR flashbackQueryClause?
        (invalidTalias=sqlName? (pivotClause|unpivotClause|rowPatternClause))? tAlias=sqlName?
    | qte=queryTableExpression flashbackQueryClause?
         (invalidTalias=sqlName? (pivotClause|unpivotClause|rowPatternClause))?
         (K_AS? tAlias=sqlName (LPAR caliases+=sqlName (COMMA caliases+=sqlName)* RPAR)?)? // PostgreSQL allows to caliases
;

// using table for query_name, table, view, mview, hierarchy
queryTableExpression:
      (schema=sqlName PERIOD)? table=sqlName
        (
              modifiedExternalTable
            | partitionExtensionClause
            | COMMAT dblink=qualifiedName
            | hierarchiesClause
        )? sampleClause?
    | inlineExternalTable sampleClause?
    | expr=expression (LPAR PLUS RPAR)? (K_WITH K_ORDINALITY)? // handle qualified function expressions, table_collection_expression; PostgreSQL: with ordinality
    | K_LATERAL? LPAR subquery subqueryRestrictionClause? RPAR
    | values=valuesClause // handled here to simplifiy grammar, even if pivot_clause etc. are not applicable
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
    K_SAMPLE K_BLOCK? LPAR samplePercent=expression RPAR (K_SEED LPAR seedValue=expression RPAR)?
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
    K_WITH (K_READ K_ONLY | K_CHECK K_OPTION) (K_CONSTRAINT constraint=sqlName)?
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
    K_IN LPAR (query=subquery | (expr+=pivotInClauseExpression (COMMA expr+=pivotInClauseExpression)*)) RPAR
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
          | K_USING LPAR columns+=qualifiedName (COMMA columns+=qualifiedName)* RPAR
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
        | K_USING LPAR columns+=qualifiedName (COMMA columns+=qualifiedName)* RPAR
    )?
;

outerJoinType:
    (K_FULL|K_LEFT|K_RIGHT) K_OUTER?
;

crossOuterApplyClause:
    (K_CROSS|K_OUTER) K_APPLY (tableReference|expression)
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
rowLimitingClause:
      K_OFFSET offset=expression (K_ROW | K_ROWS)
    | (K_OFFSET offset=expression (K_ROW | K_ROWS))?
      K_FETCH (K_FIRST | K_NEXT) (rowcount=expression | percent=expression K_PERCENT)?
      (K_ROW | K_ROWS) (K_ONLY | K_WITH K_TIES)
;

forUpdateClause:
    K_FOR K_UPDATE
    (K_OF columns+=forUpdateColumn (COMMA columns+=forUpdateColumn)*)?
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
    {unhideFirstHint();} K_UPDATE hint?
    (
          dmlTableExpressionClause
        | K_ONLY LPAR dmlTableExpressionClause RPAR
    ) talias=sqlName?
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
    | LPAR columns+=qualifiedName RPAR
        EQUALS (expr=expression | LPAR query=subquery RPAR)                         # updateSetClauseItemColumn
    | columns+=qualifiedName EQUALS (expr=expression | LPAR query=subquery RPAR)    # updateSetClauseItemColumn
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
userDefinedType:
    name=qualifiedName
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
    | left=expression operator=AMP right=expression             # bitwiseAndExpression          // precedence 10
    | left=expression operator=VERBAR right=expression          # bitwiseOrExpression           // precedence 10
    | left=expression operator=NUM right=expression             # bitwiseXorExpression          // precedence 10
    | left=expression operator=LT_LT right=expression           # bitwiseShiftLeftExpression    // precedence 10
    | left=expression operator=GT_GT right=expression           # bitwiseShiftRightExpression   // precedence 10
    | left=expression operator=customOperator right=expression  # customOperatorExpression      // precedence 10
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
    | expr=expression operator=K_IS K_NOT? K_TRUE               # isTrueCondition
    | expr=expression operator=K_IS K_NOT? K_FALSE              # isFalseCondition
    | expr=expression operator=K_IS K_NOT? K_DANGLING           # isDanglingCondition
    | expr=expression operator=K_IS K_NOT? K_UNKNOWN            # isUnknownCondition        // PostgreSQL
    | expr=expression
        operator=K_IS K_NOT? K_JSON formatClause?
        (
            LPAR (options+=jsonConditionOption+) RPAR
          | options+=jsonConditionOption*
        )                                                       # isJsonCondition
    | left=expression K_NOT? operator=K_MEMBER
        K_OF? right=expression                                  # memberCondition
    | left=expression K_NOT? operator=K_SUBMULTISET
        K_OF? right=expression                                  # submultisetCondition
    | left=expression K_NOT?
        operator=(K_LIKE|K_LIKEC|K_LIKE2|K_LIKE4)
        right=expression
        (K_ESCAPE escChar=expression)?                          # likeCondition
    | expr1=expression K_NOT? operator=K_BETWEEN
        expr2=expression K_AND expr3=expression                 # betweenCondition
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
    tableAlias=sqlName PERIOD jsonColumn=sqlName (PERIOD keys+=jsonObjectKey)+
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
        K_AS K_DOMAIN? typeName=dataType
        defaultOnConversionError?
        (COMMA fmt=expression (COMMA nlsparam=expression)?)?
    RPAR
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
      pathFactor
    | pathTerm pathFactor
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
    var=sqlName? (K_IS label=labelExpression)? (K_WHERE cond=condition)?
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
    | LT MINUS      # abbreviatedEdgePatternPointingLeft
    | MINUS         # abbreviatedEdgePatternAnyDirection
    | LT MINUS GT   # abbreviatedEdgePatternAnyDirection
    | LT_MINUS_GT   # abbreviatedEdgePatternAnyDirection
;

fullEdgePointingRight:
    MINUS LSQB elementPatternFiller RSQB MINUS GT
;

fullEdgePointingLeft:
    LT MINUS LSQB elementPatternFiller RSQB MINUS
;

fullEdgeAnyDirection:
      MINUS LSQB elementPatternFiller RSQB MINUS
    | LT MINUS LSQB elementPatternFiller RSQB MINUS GT
;

jsonArray:
      K_JSON_ARRAY LPAR jsonArrayContent RPAR
    | K_JSON LSQB jsonArrayContent RSQB
;

jsonArrayContent:
      jsonArrayEnumerationContent
    | jsonArrayQueryContent
;

jsonArrayEnumerationContent:
    (element+=jsonArrayElement (COMMA element+=jsonArrayElement)*)?
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
    K_RETURNING jsonValueReturnType jsonOption*
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
;

jsonObjectContent:
    (
          AST
        | entries+=entry (COMMA entries+=entry)*
    )
    jsonOnNullClause? jsonReturningClause? jsonOption*
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
    jsonOnNullClause? jsonReturningClause? jsonOption* (K_WITH K_UNIQUE K_KEYS)? RPAR
;

jsonQuery:
    K_JSON_QUERY LPAR expr=expression formatClause? COMMA jsonBasicPathExpression jsonPassingClause?
    (K_RETURNING jsonQueryReturnType)? jsonOption* jsonQueryWrapperClause? jsonQueryOnErrorClause?
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
    K_JSON_SERIALIZE LPAR expr=expression jsonReturningClause? jsonOption* jsonQueryOnErrorClause? RPAR
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

jsonTransform:
    K_JSON_TRANSFORM LPAR expr=expression COMMA operations+=operation (COMMA operations+=operation)*
    jsonTransformReturningClause? jsonTypeClause? jsonPassingClause? RPAR
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
    K_KEEP items+=keepOpItem (COMMA items+=keepOpItem)*
    onMissingHandler?
;

keepOpItem:
    pathExpr=expression ((K_IGNORE|K_ERROR) K_ON K_MISSING)?
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

// syntax based on
nestedPathOp:
    K_NESTED K_PATH? pathExpr=expression LPAR (operations+=operation (COMMA operations+=operation)*) RPAR
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
    (name=sqlName EQUALS GT)? functionParameterPrefix? expr=condition functionParameterSuffix?
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

orderByItem:
    expr=expression (K_ASC|K_DESC)? (K_NULLS (K_FIRST|K_LAST))?
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
            | excludeGroups=K_GROUPS
            | excludeTies=K_TIES
            | excludeNoOthers=K_NO K_OTHERS
        )
    )?
;

unaryOperator:
      PLUS              # positiveSignOperator
    | MINUS             # negativeSignOperator
    | COMMAT            # absoluteOperator          // PostgreSQL
    | VERBAR_SOL        # squareRootOperator        // PostgreSQL
    | VERBAR_VERBAR_SOL # cubeRootOperator          // PostgreSQL
    | TILDE             # bitwiseNotOperator        // PostgreSQL
    | K_PRIOR           # priorOpertor              // hierarchical query operator
    | K_CONNECT_BY_ROOT # connectByRootOperator     // hierarchical query operator
    | K_RUNNING         # runningOperator           // row_pattern_nav_logical
    | K_FINAL           # finalOperator             // row_pattern_nav_logical
    | K_NEW             # newOperator               // type constructor
    | K_CURRENT K_OF    # currentOfOperator         // operator as update extension in PL/SQL where clause
;

// only non-conflicting binary operators, this means they are not implemented by OracleDB or PostgreSQL
// therefore excluded the following PostGIS operators: '<<', '=', '>>', '~='
// see https://postgis.net/docs/manual-3.4/reference.html#Operators
customOperator:
      AMP_AMP               # postgisIntersectOperator
    | AMP_AMP_AMP           # postgisNDIntersectOperator
    | AMP_LT                # postgisOverlapsLeftOperator
    | AMP_LT_VERBAR         # postgisOverlapsBelowOperator
    | AMP_GT                # postgisOverlapsRightOperator
    | LT_LT_VERBAR          # postgisStrictlyBelowOperator
    | COMMAT                # postgisContainedByOperator
    | VERBAR_AMP_GT         # postgisOverlapsAboveOperator
    | VERBAR_GT_GT          # postgisStrictlyAboveOperator
    | TILDE                 # postgisContainsOperator
    | LT_MINUS_GT           # postgisDistanceOperator
    | VERBAR_EQUALS_VERBAR  # postgisClosestDistanceOperator
    | LT_NUM_GT             # postgisBoxDistanceOperator
    | LT_LT_MINUS_GT_GT     # postgisNDCentroidBoxDistanceOperator
    | LT_LT_NUM_GT_GT       # postgisNDBoxDistance
;

postgresqlArrayConstructor:
      K_ARRAY LSQB exprs+=postgresqlArrayElement (COMMA exprs+=postgresqlArrayElement)* RSQB
    | K_ARRAY LPAR expr+=subquery RPAR
;

postgresqlArrayElement:
      expr+=expression                                                               # postgresqlArrayElementItem
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
    | K_ACROSS
    | K_ADD
    | K_AFTER
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
    | K_AUTO
    | K_AUTOMATIC
    | K_AVERAGE_RANK
    | K_BADFILE
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
    | K_CALL
    | K_CASE
    | K_CASE_SENSITIVE
    | K_CAST
    | K_CHAR
    | K_CHARACTER
    | K_CHAR_CS
    | K_CHECK
    | K_CIDR
    | K_CIRCLE
    | K_CLOB
    | K_COLLATE
    | K_COLLECT
    | K_COLUMNS
    | K_CONDITIONAL
    | K_CONFLICT
    | K_CONNECT
    | K_CONNECT_BY_ROOT
    | K_CONSTRAINT
    | K_CONTAINERS_DEFAULT
    | K_CONTAINER_MAP
    | K_CONTENT
    | K_CONVERSION
    | K_COPY
    | K_COST
    | K_COSTS
    | K_COUNT
    | K_CREATE
    | K_CROSS
    | K_CURRENT
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
    | K_DECREMENT
    | K_DEFAULT
    | K_DEFAULTS
    | K_DEFINE
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
    | K_EDIT_TOLERANCE
    | K_ELSE
    | K_EMPTY
    | K_ENCODING
    | K_END
    | K_ENTITYESCAPING
    | K_ERROR
    | K_ERRORS
    | K_ESCAPE
    | K_EVALNAME
    | K_EXCEPT
    | K_EXCLUDE
    | K_EXCLUSIVE
    | K_EXISTING
    | K_EXISTS
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
    | K_FORMAT
    | K_FROM
    | K_FULL
    | K_FUNCTION
    | K_FUZZY_MATCH
    | K_GENERIC_PLAN
    | K_GRAPH_TABLE
    | K_GROUP
    | K_GROUPING
    | K_GROUPS
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
    | K_IGNORE
    | K_IN
    | K_INCLUDE
    | K_INCREMENT
    | K_INDENT
    | K_INDICATOR
    | K_INET
    | K_INFINITE
    | K_INNER
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
    | K_IS
    | K_ITERATE
    | K_JARO_WINKLER
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
    | K_LAST
    | K_LATERAL
    | K_LAX
    | K_LEAD
    | K_LEADING
    | K_LEAD_DIFF
    | K_LEAD_DIFF_PERCENT
    | K_LEFT
    | K_LEVEL
    | K_LEVENSHTEIN
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
    | K_MEASURES
    | K_MEMBER
    | K_MERGE
    | K_MINUS
    | K_MINUTE
    | K_MISMATCH
    | K_MISSING
    | K_MODE
    | K_MODEL
    | K_MODIFY
    | K_MONEY
    | K_MONTH
    | K_MULTISET
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
    | K_NOCYCLE
    | K_NOENTITYESCAPING
    | K_NOSCHEMACHECK
    | K_NOT
    | K_NOTHING
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
    | K_OPTION
    | K_OR
    | K_ORDER
    | K_ORDERED
    | K_ORDINALITY
    | K_OTHERS
    | K_OUTER
    | K_OVER
    | K_OVERFLOW
    | K_OVERRIDING
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
    | K_PIVOT
    | K_PLAN
    | K_POINT
    | K_POLYGON
    | K_POSITION
    | K_PRECEDING
    | K_PRECISION
    | K_PREDICTION
    | K_PREDICTION_COST
    | K_PREDICTION_DETAILS
    | K_PREPEND
    | K_PRESENT
    | K_PRESERVE
    | K_PRETTY
    | K_PRIOR
    | K_PROCEDURE
    | K_QUALIFY
    | K_RANGE
    | K_RANK
    | K_RAW
    | K_READ
    | K_REAL
    | K_RECURSIVE
    | K_REF
    | K_REFERENCE
    | K_REJECT
    | K_RELATE_TO_SHORTER
    | K_REMOVE
    | K_RENAME
    | K_REPLACE
    | K_RESERVABLE
    | K_RESPECT
    | K_RETURN
    | K_RETURNING
    | K_RIGHT
    | K_ROW
    | K_ROWID
    | K_ROWS
    | K_ROW_NUMBER
    | K_RULES
    | K_RUNNING
    | K_SAMPLE
    | K_SCALARS
    | K_SCHEMACHECK
    | K_SCN
    | K_SDO_GEOMETRY
    | K_SEARCH
    | K_SECOND
    | K_SEED
    | K_SELECT
    | K_SEQUENCE
    | K_SEQUENTIAL
    | K_SERIAL2
    | K_SERIAL4
    | K_SERIAL8
    | K_SERIAL
    | K_SESSIONTIMEZONE
    | K_SET
    | K_SETS
    | K_SHARE
    | K_SHARE_OF
    | K_SHOW
    | K_SIBLINGS
    | K_SINGLE
    | K_SIZE
    | K_SKIP
    | K_SMALLINT
    | K_SMALLSERIAL
    | K_SOME
    | K_SORT
    | K_SQL
    | K_STANDALONE
    | K_START
    | K_STATEMENT_ID
    | K_STRICT
    | K_SUBMULTISET
    | K_SUBPARTITION
    | K_SUBSET
    | K_SUMMARY
    | K_SYSTEM
    | K_TABLE
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
    | K_TREAT
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
    | K_UNCONDITIONAL
    | K_UNION
    | K_UNIQUE
    | K_UNKNOWN
    | K_UNLIMITED
    | K_UNMATCHED
    | K_UNPIVOT
    | K_UNSCALED
    | K_UNTIL
    | K_UPDATE
    | K_UPDATED
    | K_UPSERT
    | K_UROWID
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
    | K_VARYING
    | K_VERBOSE
    | K_VERSION
    | K_VERSIONS
    | K_VIEW
    | K_VISIBLE
    | K_WAIT
    | K_WAL
    | K_WELLFORMED
    | K_WHEN
    | K_WHERE
    | K_WHOLE_WORD_MATCH
    | K_WINDOW
    | K_WITH
    | K_WITHIN
    | K_WITHOUT
    | K_WRAPPER
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
;

// PostgreSQL
unicodeIdentifier:
    UQUOTED_ID (K_UESCAPE STRING)?
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
;
