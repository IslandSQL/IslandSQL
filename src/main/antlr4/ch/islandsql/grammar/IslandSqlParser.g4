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
selectStatement: SELECT;

/*----------------------------------------------------------------------------*/
// Lock table
/*----------------------------------------------------------------------------*/

lockTableStatement:
    stmt=lockTableStatementUnterminated sqlEnd
;

lockTableStatementUnterminated:
    K_LOCK K_TABLE objects+=lockTableObject (COMMA objects+=lockTableObject)*
        K_IN lockmode=lockMode K_MODE waitOption=lockTableWaitOption?
;

lockTableObject:
    (schema=sqlName PERIOD)? table=sqlName
        (
              partitionExctensionClause=partitionExtensionClause
            | COMMAT dblink=qualifiedName
        )?
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
// Expression
/*----------------------------------------------------------------------------*/

// TODO: complete according https://github.com/IslandSQL/IslandSQL/issues/23
// TODO: Analytic View Expressions
// TODO: CURSOR Expressions
// TODO: Datetime Expression
// TODO: Function Expressions
// TODO: Interval Expressions
// TODO: JSON Object Access Expressions
// TODO: Model Expressions
// TODO: Placeholder Expressions
// TODO: Scalar Subquery Expressions
// TODO: Type Construct Expressions
expression:
      expr=STRING                                               # simpleExpressionStringLiteral
    | expr=NUMBER                                               # simpleExpressionNumberLiteral
    | K_DATE expr=STRING                                        # dateLiteral
    | K_TIMESTAMP expr=STRING                                   # timestampLiteral
    | expr=intervalExpression                                   # intervalLiteral
    | expr=sqlName                                              # simpleExpressionName
    | LPAR exprs+=expression (COMMA exprs+=expression)* RPAR    # expressionList
    | expr=caseExpression                                       # caseExpr
    | operator=unaryOperator expr=expression                    # unaryExpression
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
              simple=simpleCaseExpression
            | searched=searchedCaseExpression
        )
        else=elseClause?
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

functionExpression:
    name=sqlName LPAR (params+=functionParameter (COMMA params+=functionParameter)*)? RPAR
    within=withinClause?    // e.g. approx_percentile
    over=overClause?        // e.g. avg
;

functionParameter:
    (name=sqlName EQUALS GT)? prefix=functionParameterPrefix?
    expr=expression
    suffix=functionParameterSuffix?
;

functionParameterPrefix:
      K_DISTINCT        // e.g. in any_value
    | K_ALL             // e.g. in any_value
    | K_UNIQUE          // e.g. bit_and_agg
;

functionParameterSuffix:
      K_DETERMINISTIC                       // e.g. in approx_median, approx_percentile, approx_percentile_detail
    | queryPartitionByClause orderByClause  // e.g. approx_rank
    | queryPartitionByClause                // e.g. approx_rank
    | orderByClause                         // e.g. approx_rank
;

withinClause:
    K_WITHIN K_GROUP LPAR orderByClause RPAR
;

orderByClause:
    K_ORDER siblings=K_SIBLINGS? K_BY items+=orderByItem (COMMA items+=orderByItem)*
;

orderByItem:
    expr=expression (asc=K_ASC|desc=K_DESC)? (K_NULLS (nullsFirst=K_FIRST|nullsLast=K_LAST))?
;

queryPartitionByClause:
    K_PARTITION K_BY exprs+=expression (COMMA exprs+=expression)*
;

overClause:
    K_OVER
    (
          windowName=sqlName
        | LPAR analytic=analyticClause RPAR
    )
;

analyticClause:
    (
          windowName=sqlName
        | partition=queryPartitionByClause
    )?
    (order=orderByClause windowing=windowingClause?)?
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
      PLUS              # positiveSign
    | MINUS             # negativeSign
    | K_PRIOR           # prior             // hierarchical query operator
    | K_CONNECT_BY_ROOT # connectByRoot     // hierarchical query operator
;

/*----------------------------------------------------------------------------*/
// Condition
/*----------------------------------------------------------------------------*/

// TODO: https://github.com/IslandSQL/IslandSQL/issues/22
// TODO: subquery in Simple Comparison Condition
// TODO: subquery in Group Comparison Condition
// TODO: Floating-point conditions
// TODO: Logical Conditions
// TODO: Model Conditions
// TODO: Multiset Conditions
// TODO: Pattern-matching Conditions
// TODO: Null Conditions
// TODO: XML Conditions
// TODO: SQL For JSON Conditions
// TODO: Compound Conditions
// TODO: BETWEEN Condition
// TODO: EXISTS Condition
// TODO: IN Condition
// TODO: IS OF type Condition
condition:
      cond=expression                           # booleanCondition
    | left=expression
        operator=simpleComparisionOperator
        groupOperator=(K_ANY|K_SOME|K_ALL)
        right=expression                        # groupComparisionCondition
    | left=expression
        operator=simpleComparisionOperator
        right=expression                        # simpleComparisionCondition
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

/*----------------------------------------------------------------------------*/
// Identifiers
/*----------------------------------------------------------------------------*/

keywordAsId:
      K_ALL
    | K_AND
    | K_ANY
    | K_ASC
    | K_BETWEEN
    | K_BY
    | K_CASE
    | K_COLLATE
    | K_CONNECT_BY_ROOT
    | K_CURRENT
    | K_DATE
    | K_DAY
    | K_DESC
    | K_DETERMINISTIC
    | K_DISTINCT
    | K_ELSE
    | K_END
    | K_EXCLUDE
    | K_EXCLUSIVE
    | K_FIRST
    | K_FOLLOWING
    | K_FOR
    | K_GROUP
    | K_GROUPS
    | K_HOUR
    | K_IN
    | K_INTERVAL
    | K_LAST
    | K_LOCK
    | K_MINUTE
    | K_MODE
    | K_MONTH
    | K_NO
    | K_NOWAIT
    | K_NULLS
    | K_ORDER
    | K_OTHERS
    | K_OVER
    | K_PARTITION
    | K_PRECEDING
    | K_PRIOR
    | K_RANGE
    | K_ROW
    | K_ROWS
    | K_SECOND
    | K_SHARE
    | K_SIBLINGS
    | K_SOME
    | K_SUBPARTITION
    | K_TABLE
    | K_THEN
    | K_TIES
    | K_TIMESTAMP
    | K_TO
    | K_UNBOUNDED
    | K_UNIQUE
    | K_UPDATE
    | K_WAIT
    | K_WHEN
    | K_WITHIN
    | K_YEAR
;

unquotedId:
      ID
    | keywordAsId
;

sqlName:
      unquotedId
    | QUOTED_ID
    | substitionVariable
;

substitionVariable:
    AMP AMP? name=substitionVariableName period=PERIOD?
;

substitionVariableName:
      NUMBER
    | sqlName
;

qualifiedName:
    sqlName (PERIOD sqlName)*
;

/*----------------------------------------------------------------------------*/
// SQL statement end, slash accepted without preceding newline
/*----------------------------------------------------------------------------*/

sqlEnd: EOF | SEMI | SOL;
