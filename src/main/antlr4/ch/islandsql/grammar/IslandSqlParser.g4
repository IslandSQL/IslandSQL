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

file: dmlStatement* EOF;

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

callStatement: CALL;
deleteStatement: DELETE;
explainPlanStatement: EXPLAIN_PLAN;
insertStatement: INSERT;
mergeStatement: MERGE;
updateStatement: UPDATE;

/*----------------------------------------------------------------------------*/
// Lock table
/*----------------------------------------------------------------------------*/

lockTableStatement:
    stmt=lockTableStatementUnterminated sqlEnd
;

lockTableStatementUnterminated:
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
// select
/*----------------------------------------------------------------------------*/

selectStatement:
      select sqlEnd
    | LPAR select RPAR // in cursor for loop - TODO: remove with PL/SQL block support, see https://github.com/IslandSQL/IslandSQL/issues/29
;

select:
   subquery forUpdateClause?
;

subquery:
      queryBlock orderByClause? rowLimitingClause?          # subqueryQueryBlock
    | left=subquery setOperator right=subquery              # subquerySet
    | LPAR subquery RPAR orderByClause? rowLimitingClause?  # subqueryParen
;

queryBlock:
    withClause?
    {unhideFirstHint();} K_SELECT hint?
    queryBlockSetOperator?
    selectList
    (intoClause | bulkCollectIntoClause)? // in PL/SQL only
    fromClause? // starting with Oracle Database 23c the from clause is optional
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
    )
;

plsqlDeclarations:
      functionDeclaration
    | procedureDeclaration
;

// TODO: complete with PL/SQL block support, see https://github.com/IslandSQL/IslandSQL/issues/29
functionDeclaration:
    K_FUNCTION plsqlCode K_END sqlName? SEMI
;

// TODO: complete with PL/SQL block support, see https://github.com/IslandSQL/IslandSQL/issues/29
procedureDeclaration:
    K_PROCEDURE plsqlCode K_END sqlName? SEMI
;

plsqlCode:
    .+?
;

factoringClause:
      subqueryFactoringClause
    | subavFactoringClause
;

subqueryFactoringClause:
    queryName=sqlName (LPAR caliases+=sqlName (COMMA caliases+=sqlName)* RPAR)?
    K_AS LPAR subquery RPAR
    searchClause?
    cycleClause?
;

searchClause:
    K_SEARCH (K_DEPTH|K_BREADTH) K_FIRST K_BY
    columns+=searchColumn (COMMA columns+=searchColumn)*
;

searchColumn:
    calias=sqlName (K_ASC|K_DESC)? (K_NULL (K_FIRST|K_LAST))?
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
    K_HIERARCHIES LPAR (items+=hierarchyItem (COMMA items+=hierarchyItem)*)? RPAR
;

hierarchyItem:
    (attrDimAlias=sqlName PERIOD)? hierAlias=sqlName
;

filterClauses:
    K_FILTER K_FACT LPAR filter+=filterClause (COMMA filter+=filterClause)* RPAR
;

// combinded filter_clause and hier_ids
filterClause:
    ids+=hierId (COMMA ids+=hierId)* K_TO predicate=condition
;

hierId:
      K_MEASURES                                    # hierIdMeasures
    | dimAlias=sqlName PERIOD hierAlias=sqlName     # hierIdDim
;

addMeasClause:
    K_ADD K_MEASURES LPAR measures+=cubeMeas (COMMA measures+=cubeMeas)* RPAR
;

cubeMeas:
    measName=sqlName (baseMeasClause|calcMeasClause)
;

baseMeasClause:
    K_FACT K_FOR K_MEASURE baseMeas=sqlName measAggregateClause
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
      K_GROUP K_BY items+=groupByItem (K_HAVING cond=condition)?
    | K_HAVING cond=condition K_GROUP K_BY items+=groupByItem       // undocumented, but allowed
;

// rollupCubeClause treated as expression
groupByItem:
      expression
    | groupingSetsClause
;

groupingSetsClause:
    K_GROUPING K_SETS LPAR groupingSets+=expression (COMMA groupingSets+=expression) RPAR
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
    (K_RULES (K_UPDATE|K_UPSERT K_ALL?)? ((K_AUTOMATIC|K_SEQUENTIAL) K_ORDER)? modelIterateClause?)?
    LPAR modelRules+=modelRule (COMMA modelRules+=modelRule)* RPAR
;

modelIterateClause:
    K_ITERATE LPAR iterate=expression RPAR (K_UNTIL LPAR cond=condition RPAR)?
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
      STRING
    | NUMBER
    | sqlName
;

singleColumnForLoopPattern:
      STRING
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

selectWindow:
    windowName=sqlName K_AS windowSpecification
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
      tableReference            # tableReferenceFromItem
    | joinClause                # joinClauseFromItem
    | LPAR joinClause RPAR      # parenJoinClauseFromItem
    | inlineAnalyticView        # lineAnalyticviewFromItem
;

// containers_clause and shards_clause handeled as queryTableExpression (functions named containers/shards)
tableReference:
      K_ONLY LPAR qte=queryTableExpression RPAR flashbackQueryClause?
        (pivotClause|unpivotClause|rowPatternClause)? tAlias=sqlName?
    | qte=queryTableExpression flashbackQueryClause?
        (pivotClause|unpivotClause|rowPatternClause)? tAlias=sqlName?
;

// using table for query_name, table, view, mview, hierarchy
queryTableExpression:
      (schema=sqlName PERIOD)? table=sqlName
        (
              modifiedExternalTable
            | partitionExtensionClause
            | AST dblink=qualifiedName
            | hierarchiesClause
        )? sampleClause?
    | inlineExternalTable sampleClause?
    | expr=expression (LPAR PLUS RPAR)? // handle qualified function expressions
    | K_LATERAL? LPAR subquery subqueryRestrictionClause? RPAR
;

// grammar definition in SQL Language Reference 19c/21c is wrong, added LPAR/RPAR
modifiedExternalTable:
    K_EXTERNAL K_MODIFY LPAR properties+=modifyExternalTableProperties+ RPAR
;

// implemented as alternatives, all are technically optional
// grammar definition in SQL Language Reference 19c/21c is wrong regarding "access parameters"
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
    | K_REJECT K_LIMIT rejectLimit=expression               # rejectLimitModifyExternalProperty
;

externalFileLocation:
      directory=sqlName
    | (directory=sqlName COLON)? locationSpecifier=STRING
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

// We do not fully parse the unquoted opaque_format_spec. The reason is that the grammar
// is driver specific, e.g. ORACLE_DATAPUMP, ORACLE_HDFS, ORACLE_HIVE. The grammer is
// only documented in Oracle Database Utilities. See
// https://docs.oracle.com/en/database/oracle/oracle-database/21/sutil/oracle-external-tables-concepts.html#GUID-07D30CE6-128D-426F-8B76-B13E1C53BD5A
// TODO: document as permantent limitation
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

nativeOpaqueFormatSpec:
    .+?
;

// minimal clause for use in inlineExternalTable; the following is missing:
// default clause, identity_clause, encryption_spec, inline_constraint, inline_ref_constraint
columnDefinition:
    column=sqlName datatype=sqlName // TODO: complete datatype with expressions (cast)
    (K_COLLATE collate=sqlName)? K_SORT? (K_VISIBLE|K_INVISIBLE)?
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
    K_IN LPAR expr+=pivotInClauseExpression (COMMA expr+=pivotInClauseExpression)* RPAR
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
    (K_ONE K_ROW|K_ALL K_ROWS) K_PER K_MATCH
;

rowPatternSkipTo:
    K_AFTER K_MATCH K_SKIP
    (
          (K_TO K_NEXT|K_PAST K_LAST) K_ROW
        | K_TO (K_FIRST|K_LAST) variableName=sqlName
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
      | LPAR rowPatternTerm? RPAR rowPatternQuantifier?
      | LCUB MINUS rowPatternTerm MINUS RCUB rowPatternQuantifier?
      | left=rowPatternTerm VERBAR right=rowPatternTerm rowPatternQuantifier?
      | rowPatternPermute rowPatternQuantifier?
;

rowPatternPermute:
    K_PERMUTE LPAR rowPatternTerm (COMMA rowPatternTerm)* RPAR
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

joinClause:
    tableReference joins+=joinVariant+
;

joinVariant:
      innerCrossJoinClause
    | outerJoinClause
    | crossOuterApplyClause
;

innerCrossJoinClause:
      K_INNER? K_JOIN tableReference
      (
            K_ON cond=condition
          | K_USING LPAR columns+=qualifiedName (COMMA columns+=qualifiedName)* RPAR
      )
    | K_CROSS K_JOIN  tableReference
    | K_NATURAL K_INNER? K_JOIN tableReference
;

outerJoinClause:
    left=queryPartitionClause? K_NATURAL? outerJoinType K_JOIN
    tableReference right=queryPartitionClause?
    (
          K_ON cond=condition
        | K_USING LPAR columns+=qualifiedName (COMMA columns+=qualifiedName)* RPAR
    )
;

outerJoinType:
    (K_FULL|K_LEFT|K_RIGHT) K_OUTER?
;

crossOuterApplyClause:
    (K_CROSS|K_OUTER) K_APPLY (tableReference|expression)
;

inlineAnalyticView:
    K_ANALYTIC K_VIEW
;

// ensure that at least one alternative is not optional
rowLimitingClause:
      K_OFFSET offset=expression (K_ROW | K_ROWS)
    | (K_OFFSET offset=expression (K_ROW | K_ROWS))?
      K_FETCH (K_FIRST | K_NEXT) (rowcount=expression | percent=expression K_PERCENT)
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
// Data types
/*----------------------------------------------------------------------------*/

dataType:
      oracleBuiltInDatatype
    | ansiSupportedDatatype
    | userDefinedType
;

oracleBuiltInDatatype:
      characterDatatype
    | numberDatatype
    | longAndRawDatatype
    | datetimeDatatype
    | largeObjectDatatype
    | rowidDatatype
;

characterDatatype:
      K_CHAR (LPAR size=expression (K_BYTE|K_CHAR)? RPAR)?
    | K_VARCHAR2 LPAR size=expression (K_BYTE|K_CHAR)? RPAR
    | K_NCHAR (LPAR size=expression RPAR)
    | K_NVARCHAR2 (LPAR size=expression RPAR)
;

numberDatatype:
      K_NUMBER (LPAR precision=expression (COMMA scale=expression)? RPAR)?
    | K_FLOAT (precision=expression)?
    | K_BINARY_FLOAT
    | K_BINARY_DOUBLE
;

longAndRawDatatype:
    | K_LONG
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

ansiSupportedDatatype:
      K_CHARACTER K_VARYING? LPAR size=expression RPAR
    | (K_CHAR|K_NCHAR) K_VARYING LPAR size=expression RPAR
    | K_VARCHAR LPAR size=expression RPAR
    | K_NATIONAL (K_CHARACTER|K_CHAR) K_VARYING? LPAR size=expression RPAR
    | (K_NUMERIC|K_DECIMAL|K_DEC) (LPAR precision=expression (COMMA scale=expression)? RPAR)?
    | (K_INTEGER|K_INT|K_SMALLINT)
    | K_FLOAT (LPAR size=expression RPAR)?
    | K_DOUBLE K_PRECISION
    | K_REAL
;

// handles also Oracle_supplied_types, which are just a special type of user_defined_types
userDefinedType:
    name=qualifiedName
;

/*----------------------------------------------------------------------------*/
// Expression
/*----------------------------------------------------------------------------*/

// TODO: complete according https://github.com/IslandSQL/IslandSQL/issues/23
// TODO: Analytic View Expressions
// TODO: Datetime Expression
// TODO: Function Expressions
// TODO: Interval Expressions
// TODO: JSON Object Access Expressions
// TODO: Placeholder Expressions
// TODO: Type Construct Expressions
expression:
      expr=STRING                                               # simpleExpressionStringLiteral
    | expr=NUMBER                                               # simpleExpressionNumberLiteral
    | K_DATE expr=STRING                                        # dateLiteral
    | K_TIMESTAMP expr=STRING                                   # timestampLiteral
    | expr=intervalExpression                                   # intervalLiteral
    | expr=sqlName                                              # simpleExpressionName
    | LPAR expr=subquery RPAR                                   # scalarSubqueryExpression
    | LPAR exprs+=expression (COMMA exprs+=expression)* RPAR    # expressionList
    | K_CURSOR LPAR expr=subquery RPAR                          # cursorExpression
    | expr=caseExpression                                       # caseExpr
    | expr=modelExpression                                      # modelExpr
    | operator=unaryOperator expr=expression                    # unaryExpression
    | expr=specialFunctionExpression                            # specialFunctionExpr
    | expr=functionExpression                                   # functionExpr
    | expr=AST                                                  # allColumnWildcardExpression
    | left=expression operator=(AST|SOL) right=expression       # binaryExpression
    | left=expression
        (
              operator=PLUS
            | operator=MINUS
            | operator=VERBAR VERBAR
        )
      right=expression                                          # binaryExpression
    | left=expression operator=K_COLLATE right=expression       # binaryExpression
    | left=expression operator=PERIOD right=expression          # binaryExpression
    | left=expression K_AT
        (
              K_LOCAL
            | K_TIME K_ZONE
                (
                     K_DBTIMEZONE
                   | K_SESSIONTIMEZONE
                   | right=expression
                )
        )                                                       # datetimeExpression
;

intervalExpression:
      intervalYearToMonth
    | intervalDayToSecond
;

intervalYearToMonth:
    K_INTERVAL expr=STRING
        from=(K_YEAR|K_MONTH) (LPAR precision=NUMBER RPAR)? (K_TO to=(K_YEAR|K_MONTH))?
;

intervalDayToSecond:
    K_INTERVAL expr=STRING
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

caseExpression:
    K_CASE
        (
              simpleCaseExpression
            | searchedCaseExpression
        )
        elseClause?
    K_END
;

simpleCaseExpression:
    expr=expression whens+=simpleCaseExpressionWhenClause+
;

simpleCaseExpressionWhenClause:
    K_WHEN compExpr=expression K_THEN expr=expression
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

// analytic_function is handled in expression
modelExpression:
    column=sqlName LSQB (cellAssignmentList|multiColumnForLoop) RSQB
;

// Functions and function-like conditions that have a syntax that
// cannot be handled by the generic functionExpression.
specialFunctionExpression:
      cast
    | jsonExistsCondition
;

cast:
    K_CAST LPAR
        (
              expr=expression
            | K_MULTISET LPAR subquery RPAR
        )
        K_AS typeName=dataType
        (K_DEFAULT returnValue=expression K_ON K_CONVERSION K_ERROR)?
        (COMMA fmt=expression (COMMA nlsparam=expression)?)?
    RPAR
;

jsonExistsCondition:
    K_JSON_EXISTS LPAR
        expr=expression
        (K_FORMAT K_JSON)? COMMA path=expression
        jsonPassingClause? jsonExistsOnErrorClause?
        jsonExistsOnEmptyClause?
    RPAR
;

functionExpression:
    name=sqlName LPAR (params+=functionParameter (COMMA params+=functionParameter)*)? RPAR
    withinClause?   // e.g. approx_percentile
    overClause?     // e.g. avg
;

functionParameter:
    (name=sqlName EQUALS GT)? functionParameterPrefix? expr=expression functionParameterSuffix?
;

functionParameterPrefix:
      K_DISTINCT        // e.g. in any_value
    | K_ALL             // e.g. in any_value
    | K_UNIQUE          // e.g. bit_and_agg
;

functionParameterSuffix:
      K_DETERMINISTIC                       // e.g. in approx_median, approx_percentile, approx_percentile_detail
    | queryPartitionClause orderByClause    // e.g. approx_rank
    | queryPartitionClause                  // e.g. approx_rank
    | orderByClause                         // e.g. approx_rank
;

withinClause:
    K_WITHIN K_GROUP LPAR orderByClause RPAR
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
    | K_PRIOR           # priorOpertor              // hierarchical query operator
    | K_CONNECT_BY_ROOT # connectByRootOperator     // hierarchical query operator
    | K_RUNNING         # runningOperator           // row_pattern_nav_logical
    | K_FINAL           # finalOperator             // row_pattern_nav_logical
;

/*----------------------------------------------------------------------------*/
// Condition
/*----------------------------------------------------------------------------*/

condition:
      cond=expression                                   # booleanCondition
    | operator=K_NOT cond=condition                     # notCondition
    | LPAR cond=condition RPAR                          # parenthesisCondition
    | left=condition operator=K_AND right=condition     # logicalCondition
    | left=condition operator=K_OR right=condition      # logicalCondition
    | left=expression
        operator=simpleComparisionOperator
        groupOperator=(K_ANY|K_SOME|K_ALL)
        right=expression                                # groupComparisionCondition
    | left=expression
        operator=simpleComparisionOperator
        right=expression                                # simpleComparisionCondition
    | expr=expression
        operator=K_IS K_NOT? (K_NAN|K_INFINITE)         # floatingPointCondition
    | expr=expression operator=K_IS K_ANY               # isAnyCondition // "any" only is handled as sqlName
    | expr=expression operator=K_IS K_PRESENT           # isPresentCondition
    | expr=expression operator=K_IS K_NOT? K_A K_SET    # isASetCondition
    | expr=expression operator=K_IS K_NOT? K_EMPTY      # isEmptyCondition
    | expr=expression operator=K_IS K_NOT? K_NULL       # isNullCondition
    | expr=expression
        operator=K_IS K_NOT? K_JSON
        (K_FORMAT K_JSON)?
        (
            LPAR (options+=jsonConditionOption+) RPAR
          | options+=jsonConditionOption*
        )                                               # isJsonCondition
    | left=expression K_NOT? operator=K_MEMBER
        K_OF? right=expression                          # memberCondition
    | left=expression K_NOT? operator=K_SUBMULTISET
        K_OF? right=expression                          # submultisetCondition
    | left=expression
        operator=(K_LIKE|K_LIKEC|K_LIKE2|K_LIKE4)
        right=expression
        (K_ESCAPE escChar=expression)?                  # likeCondition
    | expr1=expression K_NOT? operator=K_BETWEEN
        expr2=expression K_AND expr3=expression         # betweenCondition
    | K_EXISTS LPAR subquery RPAR                       # existsCondition
    | left=expression K_NOT? operator=K_IN
        right=expression                                # inCondition
    | expr=expression K_IS K_NOT? K_OF K_TYPE?
        LPAR types+=isOfTypeConditionItem
        (COMMA types+=isOfTypeConditionItem)* RPAR      # isOfTypeCondition
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
      K_STRICT                  # jsonConditionOptionStrict
    | K_LAX                     # jsonConditionOptionLax
    | K_ALLOW K_SCALARS         # jsonConditionOptionAllowScalars
    | K_DISALLOW K_SCALARS      # jsonConditionOptionDisallowSclars
    | K_WITH K_UNIQUE K_KEYS    # jsonConditionOptionWithUniqueKeys
    | K_WITHOUT K_UNIQUE K_KEYS # jsonConditionOptionWithoutUniqueKeys
;

isOfTypeConditionItem:
    K_ONLY? (schema=sqlName PERIOD)? type=sqlName
;

/*----------------------------------------------------------------------------*/
// Identifiers
/*----------------------------------------------------------------------------*/

keywordAsId:
      K_A
    | K_ACCESS
    | K_ADD
    | K_AFTER
    | K_AGGREGATE
    | K_ALL
    | K_ALLOW
    | K_ANALYTIC
    | K_AND
    | K_ANY
    | K_APPLY
    | K_AS
    | K_ASC
    | K_AT
    | K_AUTOMATIC
    | K_BADFILE
    | K_BETWEEN
    | K_BFILE
    | K_BINARY_DOUBLE
    | K_BINARY_FLOAT
    | K_BLOB
    | K_BLOCK
    | K_BREADTH
    | K_BULK
    | K_BY
    | K_BYTE
    | K_CASE
    | K_CAST
    | K_CHAR
    | K_CHARACTER
    | K_CHECK
    | K_CLOB
    | K_COLLATE
    | K_COLLECT
    | K_CONNECT
    | K_CONNECT_BY_ROOT
    | K_CONSTRAINT
    | K_CONVERSION
    | K_CROSS
    | K_CURRENT
    | K_CURSOR
    | K_CYCLE
    | K_DATE
    | K_DAY
    | K_DBTIMEZONE
    | K_DEC
    | K_DECIMAL
    | K_DECREMENT
    | K_DEFAULT
    | K_DEFINE
    | K_DEPTH
    | K_DESC
    | K_DETERMINISTIC
    | K_DIMENSION
    | K_DIRECTORY
    | K_DISALLOW
    | K_DISCARD
    | K_DISTINCT
    | K_DOUBLE
    | K_ELSE
    | K_EMPTY
    | K_END
    | K_ERROR
    | K_ESCAPE
    | K_EXCEPT
    | K_EXCLUDE
    | K_EXCLUSIVE
    | K_EXISTS
    | K_EXTERNAL
    | K_FACT
    | K_FALSE
    | K_FETCH
    | K_FILTER
    | K_FINAL
    | K_FIRST
    | K_FLOAT
    | K_FOLLOWING
    | K_FOR
    | K_FORMAT
    | K_FROM
    | K_FULL
    | K_FUNCTION
    | K_GROUP
    | K_GROUPING
    | K_GROUPS
    | K_HAVING
    | K_HIERARCHIES
    | K_HOUR
    | K_IGNORE
    | K_IN
    | K_INCLUDE
    | K_INCREMENT
    | K_INFINITE
    | K_INNER
    | K_INT
    | K_INTEGER
    | K_INTERSECT
    | K_INTERVAL
    | K_INTO
    | K_INVISIBLE
    | K_IS
    | K_ITERATE
    | K_JOIN
    | K_JSON
    | K_JSON_EXISTS
    | K_KEEP
    | K_KEYS
    | K_LAST
    | K_LATERAL
    | K_LAX
    | K_LEFT
    | K_LIKE2
    | K_LIKE4
    | K_LIKE
    | K_LIKEC
    | K_LIMIT
    | K_LOCAL
    | K_LOCATION
    | K_LOCK
    | K_LOCKED
    | K_LOGFILE
    | K_LONG
    | K_MAIN
    | K_MATCH
    | K_MATCH_RECOGNIZE
    | K_MEASURE
    | K_MEASURES
    | K_MEMBER
    | K_MINUS
    | K_MINUTE
    | K_MODE
    | K_MODEL
    | K_MODIFY
    | K_MONTH
    | K_MULTISET
    | K_NAN
    | K_NATIONAL
    | K_NATURAL
    | K_NAV
    | K_NCHAR
    | K_NCLOB
    | K_NEXT
    | K_NO
    | K_NOCYCLE
    | K_NOT
    | K_NOWAIT
    | K_NULL
    | K_NULLS
    | K_NUMBER
    | K_NUMERIC
    | K_NVARCHAR2
    | K_OF
    | K_OFFSET
    | K_ON
    | K_ONE
    | K_ONLY
    | K_OPTION
    | K_OR
    | K_ORDER
    | K_OTHERS
    | K_OUTER
    | K_OVER
    | K_PARAMETERS
    | K_PARTITION
    | K_PASSING
    | K_PAST
    | K_PATTERN
    | K_PER
    | K_PERCENT
    | K_PERIOD
    | K_PERMUTE
    | K_PIVOT
    | K_PRECEDING
    | K_PRECISION
    | K_PRESENT
    | K_PRIOR
    | K_PROCEDURE
    | K_RANGE
    | K_RAW
    | K_READ
    | K_REAL
    | K_REFERENCE
    | K_REJECT
    | K_RETURN
    | K_RIGHT
    | K_ROW
    | K_ROWID
    | K_ROWS
    | K_RULES
    | K_RUNNING
    | K_SAMPLE
    | K_SCALARS
    | K_SCN
    | K_SEARCH
    | K_SECOND
    | K_SEED
    | K_SELECT
    | K_SEQUENTIAL
    | K_SESSIONTIMEZONE
    | K_SET
    | K_SETS
    | K_SHARE
    | K_SIBLINGS
    | K_SINGLE
    | K_SKIP
    | K_SMALLINT
    | K_SOME
    | K_SORT
    | K_START
    | K_STRICT
    | K_SUBMULTISET
    | K_SUBPARTITION
    | K_SUBSET
    | K_TABLE
    | K_THEN
    | K_TIES
    | K_TIME
    | K_TIMESTAMP
    | K_TO
    | K_TRUE
    | K_TYPE
    | K_UNBOUNDED
    | K_UNION
    | K_UNIQUE
    | K_UNPIVOT
    | K_UNTIL
    | K_UPDATE
    | K_UPDATED
    | K_UPSERT
    | K_UROWID
    | K_USING
    | K_VARCHAR2
    | K_VARCHAR
    | K_VARYING
    | K_VERSIONS
    | K_VIEW
    | K_VISIBLE
    | K_WAIT
    | K_WHEN
    | K_WHERE
    | K_WINDOW
    | K_WITH
    | K_WITHIN
    | K_WITHOUT
    | K_XML
    | K_YEAR
    | K_ZONE
;

unquotedId:
      ID
    | keywordAsId
;

sqlName:
      unquotedId
    | QUOTED_ID
    | substitionVariable+
;

substitionVariable:
    AMP AMP? name=substitionVariableName period=PERIOD?
;

substitionVariableName:
      NUMBER
    | unquotedId
;

qualifiedName:
    sqlName (PERIOD sqlName)*
;

/*----------------------------------------------------------------------------*/
// SQL statement end, slash accepted without preceding newline
/*----------------------------------------------------------------------------*/

sqlEnd: EOF | SEMI SOL? | SOL;
