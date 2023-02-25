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

// TODO: complete according https://github.com/IslandSQL/IslandSQL/issues/11
expression:
      expr=STRING                                               # simpleExpressionStringLiteral
    | expr=NUMBER                                               # simpleExpressionNumberLiteral
    | expr=sqlName                                              # simpleExpressionName
    | LPAR expr+=expression (COMMA expr+=expression)* RPAR      # expressionList
    | expr=caseExpression                                       # atomExpression
    | operator=unaryOperator expr=expression                    # unaryExpression
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

caseExpression:
    K_CASE (simpleCaseExpression|searchedCaseExpression) elseClause? K_END
;

simpleCaseExpression:
    expr=expression when+=simpleCaseExpressionWhenClause+
;

simpleCaseExpressionWhenClause:
    K_WHEN compExpr=expression K_THEN expr=expression
;

searchedCaseExpression:
    K_WHEN cond=condition K_THEN expr=expression
;

elseClause:
    K_ELSE expr=expression
;

unaryOperator:
      PLUS              # positiveSign
    | MINUS             # negativeSign
    | K_PRIOR           # prior
;

/*----------------------------------------------------------------------------*/
// Condition
/*----------------------------------------------------------------------------*/

condition:
      cond=expression                           # booleanCondition
    | left=expression
        operator=simpleComparisionOperator
        right=expression                        # simpleComparisionCondition
    | left=expression
        operator=simpleComparisionOperator
        groupOperator=(K_ANY|K_SOME|K_ALL)
        right=expression                        # groupComparisionCondition
;

simpleComparisionOperator:
      EQUALS            # eq
    | EXCL EQUALS       # ne
    | LT GT             # ne
    | TILDE EQUALS      # ne
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
    | K_ANY
    | K_CASE
    | K_COLLATE
    | K_ELSE
    | K_END
    | K_EXCLUSIVE
    | K_FOR
    | K_IN
    | K_LOCK
    | K_MODE
    | K_NOWAIT
    | K_PARTITION
    | K_PRIOR
    | K_ROW
    | K_SHARE
    | K_SOME
    | K_SUBPARTITION
    | K_TABLE
    | K_THEN
    | K_UPDATE
    | K_WAIT
    | K_WHEN
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
    AMP AMP? name=substitionVariableName
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
