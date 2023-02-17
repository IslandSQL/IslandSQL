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
    (schema=sqlName DOT)? table=sqlName
        (
              partitionExtensionClause
            | (AT_SIGN dblink=qualifiedName)
        )?
;

partitionExtensionClause:
      (K_PARTITION OPEN_PAREN partition=sqlName CLOSE_PAREN)        # partition
    | (K_PARTITION K_FOR OPEN_PAREN
        (keys+=expression (COMMA keys+=expression)*) CLOSE_PAREN)   # partitionKeys
    | (K_SUBPARTITION OPEN_PAREN subpartition=sqlName CLOSE_PAREN)  # subpartition
    | (K_SUBPARTITION K_FOR OPEN_PAREN
        (keys+=expression (COMMA keys+=expression)*) CLOSE_PAREN)   # subpartitionKeys
;

// TODO: complete according https://github.com/IslandSQL/IslandSQL/issues/11
expression:
      STRING        # stringLiteral
    | INT           # integerLiteral
    | sqlName       # sqlNameExpression
;

lockMode:
      (K_ROW K_SHARE)               # rowShare
    | (K_ROW K_EXCLUSIVE)           # rowExclusive
    | (K_SHARE K_UPDATE)            # shareUpdate
    | (K_SHARE)                     # share
    | (K_SHARE K_ROW K_EXCLUSIVE)   # shareRowExclusive
    | (K_EXCLUSIVE)                 # exclusive
;

lockTableWaitOption:
      K_NOWAIT          # nowait
    | K_WAIT wait=INT   # wait
;

/*----------------------------------------------------------------------------*/
// Identifiers
/*----------------------------------------------------------------------------*/

keywordAsId:
      K_EXCLUSIVE
    | K_FOR
    | K_IN
    | K_LOCK
    | K_MODE
    | K_NOWAIT
    | K_PARTITION
    | K_ROW
    | K_SHARE
    | K_SUBPARTITION
    | K_TABLE
    | K_UPDATE
    | K_WAIT
;

unquotedId:
      ID
    | keywordAsId
;

sqlName:
      unquotedId
    | QUOTED_ID
;

qualifiedName:
	sqlName (DOT sqlName)*
;

/*----------------------------------------------------------------------------*/
// SQL statement end, slash accepted without preceeding newline
/*----------------------------------------------------------------------------*/

sqlEnd: EOF | SEMI | SLASH;
