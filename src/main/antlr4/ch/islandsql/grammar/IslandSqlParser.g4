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
// Start rules
/*----------------------------------------------------------------------------*/

// used in constructor of IslandSqlDocument
file:
    statement* EOF
;

// used in constructor of IslandSqlDocument for GENERIC and POSTGRESQL dialect with enabled subtrees option
postgresqlSqlCode:
    atomicStatement* EOF
;

// used in constructor of IslandSqlDocument for GENERIC and POSTGRESQL dialect with enabled subtrees option
// difference to OracleDB PL/SQL block: only one label allowed and final semicolon is optional
// other differences are handled in the PL/SQL specific rules
// stmts are optional in PL/pgSQL, undocumented in 16.3
// PL/pgSQL allows multiple declare sections, undocumented in 16.3
postgresqlPlpgsqlCode:
    compilerOptions+=postgresqlCompilerOption*
    label?
    (K_DECLARE declareSection?)*
    K_BEGIN
    stmts+=plsqlStatement*
    (K_EXCEPTION exceptionHandlers+=exceptionHandler+)?
    K_END name=sqlName? SEMI? EOF
;

postgresqlCompilerOption:
    NUM parameter=sqlName value=sqlName
;

/*----------------------------------------------------------------------------*/
// Statement
/*----------------------------------------------------------------------------*/

statement:
      ddlStatement
    | dmlStatement
    | doStatement
    | emptyStatement
    | plsqlBlockStatement
    | tclStatement
    | postgresqlDeclareStatement
;

/*----------------------------------------------------------------------------*/
// Data Definition Language
/*----------------------------------------------------------------------------*/

ddlStatement:
      createFunctionStatement
    | createJsonRelationalDualityViewStatement
    | createMaterializedViewStatement
    | createPackageStatement
    | createPackageBodyStatement
    | createProcedureStatement
    | createTableStatement
    | createTriggerStatement
    | createTypeStatement
    | createTypeBodyStatement
    | createViewStatement
;

/*----------------------------------------------------------------------------*/
// Create Function
/*----------------------------------------------------------------------------*/

createFunctionStatement:
    createFunction sqlEnd?
;

createFunction:
    K_CREATE (K_OR K_REPLACE)? (K_EDITIONABLE | K_NONEDITIONABLE)? K_FUNCTION
    (K_IF K_NOT K_EXISTS)? (plsqlFunctionSource | postgresqlFunctionSource)
;

// supporting function without body, e.g. when using aggregate_clause
// wrong documentation in 23.4: position of sharing_clause
plsqlFunctionSource:
    (schema=sqlName PERIOD)? functionName=sqlName sharingClause?
        (LPAR parameters+=parameterDeclaration (COMMA parameters+=parameterDeclaration)* RPAR)?
        K_RETURN returnType=plsqlDataType options+=plsqlFunctionOption*
        ((K_IS | K_AS) (declareSection? body | callSpec SEMI) | SEMI)
;

plsqlFunctionOption:
      invokerRightsclause
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

// extended by options available in createView, createTable only
sharingClause:
    K_SHARING EQUALS (K_METADATA | K_NONE | K_DATA | K_EXTENDED K_DATA)
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

postgresqlFunctionSource:
    (schema=sqlName PERIOD)? functionName=sqlName
        LPAR (parameters+=postgresqlParameterDeclaration (COMMA parameters+=postgresqlParameterDeclaration)*)? RPAR
        (
            K_RETURNS
            (
                  K_SETOF? (returnSchema=sqlName PERIOD)? returnType=plsqlDataType
                | K_TABLE LPAR columns+=postgresqlColumnDefinition (COMMA columns+=postgresqlColumnDefinition)* RPAR
            )
        )?
        postgresqlFunctionOption+
;

postgresqlParameterDeclaration:
    (
          argmode parameter=sqlName? type=plsqlDataType
        | parameter=sqlName argmode? type=plsqlDataType
        | type=plsqlDataType
    )
    ((K_DEFAULT | EQUALS) expr=expression)?
;

argmode:
      K_IN
    | K_OUT
    | K_INOUT
    | K_VARIADIC
;

// postgresqlSqlCode/postgresqlPlpgsqlCode is optionally populated when creating an IslandSqlDocument instance
postgresqlFunctionOption:
      K_LANGUAGE languageName=expression // expected sqlName, string is allowed but deprecated
    | K_TRANSFORM transformItems+=transformItem (COMMA transformItems+=transformItem)*
    | K_WINDOW
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
    | K_AS definition=postgresqlCode // subtree added for this option if definition is a string
    | K_AS objFile=expression COMMA linkSymbol=expression
    | sqlBody
    | otherOption=sqlName // e.g. used by PostGIS: _cost_low, _cost_medium, _cost_high, _cost_default
;

transformItem:
    K_FOR K_TYPE (typeSchema=sqlName PERIOD)? typeName=dataType
;

sqlBody:
      K_RETURN expr=expression
    | atomicBlock
;

/*----------------------------------------------------------------------------*/
// Create JSON Relational Duality View
/*----------------------------------------------------------------------------*/

createJsonRelationalDualityViewStatement:
    createJsonRelationalDualityView sqlEnd
;

createJsonRelationalDualityView:
    K_CREATE (K_OR K_REPLACE)? (K_NO? K_FORCE)?
    (
          K_EDITIONABLE
        | K_NONEDITIONABLE
    )? K_JSON K_RELATIONAL? K_DUALITY K_VIEW (K_IF K_NOT K_EXISTS)? (schema=sqlName PERIOD)? viewName=sqlName
    K_AS jsonRelationalDualityViewSource
;

// artificial clause because the query cababilities are not fully documented, e.g
// - query in paranthesis are allowed
// - using JSON_OBJECT () instead of JSON {} is allowed
// - using JSON_ARRAY () instead of JSON [] is allowed
// Instead we extend the select statement to cover the special clauses,
// similar to the select_into clause for PL/SQL.
jsonRelationalDualityViewSource:
      subquery
    | graphqlQueryForDv
;

tableTagsClause:
    K_WITH tags+=tableTagsClauseItem+
;

// artificial clause
tableTagsClauseItem:
      K_CHECK K_ETAG?
    | K_NOCHECK K_ETAG?
    | K_INSERT
    | K_NOINSERT
    | K_UPDATE
    | K_NOUPDATE
    | K_DELETE
    | K_NODELETE
;

// only components that are not handled by regularEntry for create_json_relational_duality_view
keyValueClause:
      regularEntry columnTagsClause
    | flexClause
    | K_UNNEST LPAR subquery RPAR
;

flexClause:
    columnName=qualifiedName K_AS K_FLEX K_COLUMN?
;

columnTagsClause:
    K_WITH tags+=columnTagsClauseItem+
;

// artificial clause
columnTagsClauseItem:
      K_CHECK K_ETAG?
    | K_NOCHECK K_ETAG?
    | K_UPDATE
    | K_NOUPDATE
;

// added "graphql" prefix to all graphql related clauses to avoid conflicts with grammar fields
graphqlQueryForDv:
    graphqlRootQueryField
;

graphqlRootQueryField:
    root=qualifiedName graphqlDirectives? graphqlSelectionSet
;

graphqlDirectives:
    directives=graphqlDirective+
;

graphqlDirective:
    COMMAT directive=sqlName (LPAR (args+=graphqlArgument)+ RPAR)?
;

graphqlArgument:
    name=sqlName COLON value=expression
;

graphqlSelectionSet:
      LSQB LCUB graphqlSelectionList RCUB RSQB
    | LCUB graphqlSelectionList RCUB
;

// undocumentend in 23.4: comma can be used as separator
graphqlSelectionList:
    selections+=graphqlSelection (COMMA? selections+=graphqlSelection)*
;

graphqlSelection:
      graphqlField
    | graphqlFragmentSpread
;

graphqlField:
    (alias=sqlName COLON)? field=qualifiedName graphqlDirectives? graphqlSelectionSet?
;

graphqlFragmentSpread:
      PERIOD PERIOD PERIOD name=sqlName
    | AST
;

/*----------------------------------------------------------------------------*/
// Create Materialized View
/*----------------------------------------------------------------------------*/

createMaterializedViewStatement:
    createMaterializedView sqlEnd
;

// wrong documentation in 23.4:
// - column list is optional and parentheses start/close the list not the column
// - on prebuilt table is optional
// - phyisical_properties and materialized_view_props are optional
createMaterializedView:
    K_CREATE K_MATERIALIZED K_VIEW
    (K_IF K_NOT K_EXISTS)? (schema=sqlName PERIOD)? mviewName=sqlName
    (K_OF (objectTypeSchema=sqlName PERIOD)? objectTypeName=sqlName)?
    (LPAR columns+=mviewColumn (COMMA columns+=mviewColumn)* RPAR)?
    (K_USING method=sqlName)? postgresqlViewOptions?  // PostgreSQL only
    defaultCollationClause?
    (K_ON K_PREBUILT K_TABLE ((K_WITH | K_WITHOUT) K_REDUCED K_PRECISION)?)?
    physicalProperties? materializedViewProps
    (
          K_USING K_INDEX physicalAttributesClause?
        | K_USING K_NO K_INDEX
    )?
    createMvRefresh?
    evaluationEditionClause? onQueryComputationClause?
    queryRewriteClause? concurrentRefreshClause? annotationsClause?
    K_AS subquery
    (K_WITH K_NO? K_DATA)?  // PostgreSQL only
;

// artificial clause
// wrong documentation in 23.4: scoped_table_ref_constraint cannot follow a column alias
mviewColumn:
      alias=sqlName (K_ENCRYPT encryptionSpec)? annotationsClause?
    | scopedTableRefConstraint?
;

scopedTableRefConstraint:
    K_SCOPE K_FOR LPAR refColumn=sqlName RPAR K_IS (schema=sqlName PERIOD)? scopeTableOrAlias=sqlName
;

// simplified as list of tokens
physicalProperties:
    (
          deferredSegmentCreation
        | segmentAttributesClause
        | K_ORGANIZATION ~SEMI+?
        | K_EXTERNAL ~SEMI+?
        | K_CLUSTER ~SEMI+?
    )
;

deferredSegmentCreation:
    K_SEGMENT K_CREATION (K_IMMEDIATE | K_DEFERRED)
;

// simplified as list of tokens
segmentAttributesClause:
    (
          K_PCTFREE
        | K_PCTUSED
        | K_INITRANS
        | K_STORAGE
        | K_TABLESPACE
        | K_LOGGING
        | K_NOLOGGING
        | K_FILESYSTEM_LIKE_LOGGING
    ) ~SEMI+?
;

materializedViewProps:
    columnProperties? tablePartitioningClauses? (K_CACHE | K_NOCACHE)? parallelClause?
    buildClause?
;

// simplified as list of tokens
columnProperties:
    (
          K_COLUMN
        | K_NESTED K_TABLE
        | K_VARRAY
        | K_LOB
        | K_XMLTYPE
        | K_JSON
    ) ~SEMI+?
;

// simplified as list of tokens
tablePartitioningClauses:
    (K_PARTITION | K_PARTITIONSET) K_BY ~SEMI+?
;

parallelClause:
      K_NOPARALLEL
    | K_PARALLEL degree=expression?
;

buildClause:
    K_BUILD (K_IMMEDIATE | K_DEFERRED)
;

// simplified as list of tokens
physicalAttributesClause:
    ~SEMI+?
;

createMvRefresh:
      K_REFRESH options+=createMvRefreshOption+
    | K_NEVER K_REFRESH
;

createMvRefreshOption:
      K_FAST
    | K_COMPLETE
    | K_FORCE
    | K_ON (K_DEMAND | K_COMMIT | K_STATEMENT)
    | (K_START K_WITH | K_NEXT) date=expression
    | K_WITH (K_PRIMARY K_KEY | K_ROWID)
    | K_USING K_DEFAULT (K_MASTER | K_LOCAL)? K_ROLLBACK K_SEGMENT
    | K_USING (K_MASTER | K_LOCAL)? K_ROLLBACK K_SEGMENT segment=sqlName
    | K_USING (K_ENFORCED | K_TRUSTED) K_CONSTRAINTS
;

// artificial clause to avoid multiple enable/disable keywords in rule
onQueryComputationClause:
    (K_ENABLE | K_DISABLE) K_ON K_QUERY K_COMPUTATION
;

// wrong documentation in 23.4: optionality of unusable_edition_clause
queryRewriteClause:
    (K_ENABLE | K_DISABLE) K_QUERY K_REWRITE unusableEditionsClause
;

concurrentRefreshClause:
    (K_ENABLE | K_DISABLE) K_CONCURRENT K_REFRESH
;

/*----------------------------------------------------------------------------*/
// Create Package
/*----------------------------------------------------------------------------*/

createPackageStatement:
    createPackage sqlEnd?
;

// wrong documenation in 23.3: package_item_list is not mandatory
createPackage:
    K_CREATE (K_OR K_REPLACE)? (K_EDITIONABLE | K_NONEDITIONABLE)? K_PACKAGE
    (K_IF K_NOT K_EXISTS)? plsqlPackageSource
    (K_IS | K_AS) items+=itemlistItem* K_END name=sqlName? SEMI
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

// wrong documentation in 23.3: declare_section is not mandatory
plsqlPackageBodySource:
    (schema=sqlName PERIOD)? packageName=sqlName sharingClause?
    (K_IS | K_AS) declareSection? initializeSection? K_END name=sqlName? SEMI
;

initializeSection:
    K_BEGIN
    stmts+=plsqlStatement+
    (K_EXCEPTION exceptionHandlers+=exceptionHandler+)?
;

/*----------------------------------------------------------------------------*/
// Create Procedure
/*----------------------------------------------------------------------------*/

createProcedureStatement:
    createProcedure sqlEnd?
;

createProcedure:
    K_CREATE (K_OR K_REPLACE)? (K_EDITIONABLE | K_NONEDITIONABLE)? K_PROCEDURE
    (K_IF K_NOT K_EXISTS)? (plsqlProcedureSource | postgresqlProcedureSource)
;

// wrong documentation in 23.4: position of sharing clause
plsqlProcedureSource:
    (schema=sqlName PERIOD)? procedureName=sqlName sharingClause?
        (LPAR parameters+=parameterDeclaration (COMMA parameters+=parameterDeclaration)* RPAR)?
        options+=plsqlProcedureOption*
        (K_IS | K_AS) (declareSection? body | callSpec SEMI)
;

plsqlProcedureOption:
      defaultCollationClause
    | invokerRightsclause
    | accessibleByClause
;

postgresqlProcedureSource:
    (schema=sqlName PERIOD)? procedureName=sqlName
        LPAR (parameters+=postgresqlParameterDeclaration (COMMA parameters+=postgresqlParameterDeclaration)*)? RPAR
        postgresqlProcedureOption+
;

// postgresqlSqlCode/postgresqlPlpgsqlCode is optionally populated when creating an IslandSqlDocument instance
postgresqlProcedureOption:
      K_LANGUAGE languageName=expression
    | K_TRANSFORM transformItems+=transformItem (COMMA transformItems+=transformItem)*
    | K_EXTERNAL? K_SECURITY (K_INVOKER | K_DEFINER)
    | K_SET parameterName=sqlName ((K_TO | EQUALS) values+=expression (COMMA values+=expression)* | K_FROM K_CURRENT)
    | K_AS definition=postgresqlCode // subtree added for this option if definition is a string
    | K_AS objFile=expression COMMA linkSymbol=expression
    | atomicBlock // subset of sql_body used in PostgreSQL function
;

atomicBlock:
    K_BEGIN K_ATOMIC
        stmts+=atomicStatement+
    K_END
;

atomicStatement:
      statement
    | unterminatedAtomicStatement SEMI
    | terminatedAtomicStatement
;

// SQL statement not fully parsed by this grammar, SEMI provided in sqlStatement
unterminatedAtomicStatement:
      K_ALTER postgreSqlStatementTrailingTokens
    | K_ANALYZE postgreSqlStatementTrailingTokens
    | K_CHECKPOINT
    | K_CLUSTER postgreSqlStatementTrailingTokens
    | K_COMMENT postgreSqlStatementTrailingTokens
    | K_COPY postgreSqlStatementTrailingTokens
    | K_CREATE postgreSqlStatementTrailingTokens
    | K_DEALLOCATE postgreSqlStatementTrailingTokens
    | K_DISCARD postgreSqlStatementTrailingTokens
    | K_DROP postgreSqlStatementTrailingTokens
    | K_GRANT postgreSqlStatementTrailingTokens
    | K_IMPORT postgreSqlStatementTrailingTokens
    | K_PREPARE postgreSqlStatementTrailingTokens
    | K_REASSIGN postgreSqlStatementTrailingTokens
    | K_REFRESH postgreSqlStatementTrailingTokens
    | K_REINDEX postgreSqlStatementTrailingTokens
    | K_RESET postgreSqlStatementTrailingTokens
    | K_REVOKE postgreSqlStatementTrailingTokens
    | K_SECURITY postgreSqlStatementTrailingTokens
    | K_SET postgreSqlStatementTrailingTokens
    | K_TRUNCATE postgreSqlStatementTrailingTokens
;

// SQL statement not fully parsed by this parser, used in atomicBlock only
// end statement excluded due to conflict with end keyword in blocks
terminatedAtomicStatement:
      closeStatment
    | returnStatement // undocumented in 16.3
    | postgresqlFetchStatement
    | postgresqlMoveStatement
    | K_ABORT postgreSqlStatementTrailingTokens SEMI
    | K_LISTEN postgreSqlStatementTrailingTokens SEMI
    | K_LOAD postgreSqlStatementTrailingTokens SEMI
    | K_NOTIFY postgreSqlStatementTrailingTokens SEMI
    | K_SECURITY postgreSqlStatementTrailingTokens SEMI
    | K_SHOW postgreSqlStatementTrailingTokens SEMI
    | K_START postgreSqlStatementTrailingTokens SEMI
    | K_UNLISTEN postgreSqlStatementTrailingTokens SEMI
    | K_VACUUM  postgreSqlStatementTrailingTokens SEMI
;

postgreSqlStatementTrailingTokens:
    ~SEMI*?
;

/*----------------------------------------------------------------------------*/
// Create Table
/*----------------------------------------------------------------------------*/

createTableStatement:
    createTable sqlEnd
;

createTable:
    K_CREATE
    (
          (K_GLOBAL | K_PRIVATE) K_TEMPORARY
        | K_SHARDED
        | K_DUPLICATED
        | K_IMMUTABLE? K_BLOCKCHAIN
        | K_IMMUTABLE
        | (K_GLOBAL | K_LOCAL)? (K_TEMPORARY | K_TEMP)   // PostgreSQL
        | K_UNLOGGED    // PostgreSQL
    )?
    K_TABLE (K_IF K_NOT K_EXISTS)? (schema=sqlName PERIOD)? tableName=sqlName
    sharingClause?
    relationalTable
    (K_MEMOPTIMIZED K_FOR K_READ)?
    (K_MEMOPTIMIZED K_FOR K_WRITE)?
    (K_PARENT (parentSchema=sqlName PERIOD)? parentTableName=sqlName)?
    (
          K_REFRESH K_INTERVAL refreshRate=expression (K_SECOND | K_MINUTE | K_HOUR)
        | K_SYNCHRONOUS
    )?
;

// simplified, handles also object_table and xmltype_table
relationalTable:
    (LPAR relationalProperties RPAR)?
    (
          tableProperties
        | beforeTableProperties tableProperties
    )
;

relationalProperties:
    props+=relationalProperty (COMMA props+=relationalProperty)*
;

// artificial clause to handle list of properties
// wrong documentation domain_clause does not exists (part of datatype_domain in column_definition)
relationalProperty:
      columnDefinition
    | virtualColumnDefinition
    | periodDefinition
    | outOfLineConstraint
    | outOfLineRefConstraint
    | supplementalLoggingProps
    | postgresqlLikeOptions
;

// wrong documentation in 23.4: expr should not be mandatory, it's part of the default clause
columnDefinition:
    column=sqlName typeName=datatypeDomain?
    postgresqlStorage?
    postgresqlCompression?
    (
          K_COLLATE collate=sqlName
        | K_RESERVABLE
    )?
    K_SORT? (K_VISIBLE|K_INVISIBLE)?
    (
          K_DEFAULT ((K_ON K_NULL) (K_FOR K_INSERT (K_ONLY | K_AND K_UPDATE))?)? defaultExpr=expression
        | identityClause
    )?
    (K_ENCRYPT encryptionSpec)?
    (
          inlineConstraints+=inlineConstraint+
        | inlineRefConstraint
    )?
    annotationsClause?
;

// wrong documentation in 23.4: missing ref data type
datatypeDomain:
      K_REF? dataType (K_DOMAIN (domainOwner=sqlName PERIOD)?  domainName=sqlName)?
    | K_DOMAIN (domainOwner=sqlName PERIOD)? domainName=sqlName
;

postgresqlStorage:
    K_STORAGE (K_PLAIN | K_EXTERNAL | K_EXTENDED | K_MAIN | K_DEFAULT)
;

postgresqlCompression:
    K_COMPRESSION method=sqlName
;

identityClause:
    K_GENERATED
    (
          K_ALWAYS // default
        | K_BY K_DEFAULT (K_ON K_NULL (K_FOR K_INSERT (K_ONLY | K_AND K_UPDATE))?)?
    )?
    K_AS K_IDENTITY (LPAR identityOptions RPAR)?
;

identityOptions:
    identityOption+
;

// artificial clause
identityOption:
      K_START K_WITH (expr=expression | K_LIMIT K_VALUE)    # startIdentityOption
    | K_INCREMENT K_BY expr=expression                      # incrementIdentityOption
    | K_MAXVALUE expr=expression                            # maxIdentityOption
    | K_NOMAXVALUE                                          # nomaxIdentityOption
    | K_NO K_MAXVALUE                                       # nomaxIdentityOption // PostgreSQL
    | K_MINVALUE expr=expression                            # minIdentityOption
    | K_NOMINVALUE                                          # nominIdentityOption
    | K_NO K_MINVALUE                                       # nominIdentityOption // PostgreSQL
    | K_CYCLE                                               # cycleIdentityOption
    | K_NOCYCLE                                             # nocycleIdentityOption
    | K_NO K_CYCLE                                          # nocycleIdentityOption // PostgreSQL
    | K_CACHE expr=expression                               # cacheIdentityOption
    | K_NOCACHE                                             # nocacheIdentityOption
    | K_ORDER                                               # orderIdentityOption
    | K_NOORDER                                             # noorderIdenityOption
;

encryptionSpec:
    (K_USING encryptAlgorithm=string)? (K_IDENTIFIED K_BY password=expression)?
    integrityAlgorithm=string? (K_NO? K_SALT)?
;

inlineConstraint:
    (K_CONSTRAINT name=sqlName)?
    (
          K_NOT? K_NULL constraintState?
        | K_UNIQUE constraintState?
        | K_PRIMARY K_KEY constraintState?
        | referencesClause constraintState?
        | K_CHECK LPAR cond=expression RPAR constraintState? precheckState?
        | postgresqlColumnConstraint constraintState?
    )
;

// constraints not handled by inlineConstraint
postgresqlColumnConstraint:
      K_CHECK LPAR cond=expression RPAR (K_NO K_INHERIT)?
    | K_GENERATED K_ALWAYS K_AS LPAR expr=expression RPAR K_STORED?
    | K_GENERATED (K_ALWAYS | K_BY K_DEFAULT) K_AS K_IDENTITY (LPAR identityOption+ RPAR)?
    | K_UNIQUE (K_NULLS K_NOT? K_DISTINCT)? postgresqlIndexParameters*
    | K_PRIMARY K_KEY postgresqlIndexParameters*
    | K_REFERENCES reftable=qualifiedName (LPAR refcolumn=sqlName RPAR)?
        (K_MATCH K_FULL | K_MATCH K_PARTIAL | K_MATCH K_SIMPLE)?
        (K_ON K_DELETE onDeleteAction=postgresqlReferentialAction)?
        (K_ON K_UPDATE onUpdateAction=postgresqlReferentialAction)?
;

postgresqlIndexParameters:
      K_INCLUDE LPAR columns+=sqlName (COMMA columns+=sqlName)* RPAR
    | K_WITH LPAR options+=postgresqlOption (COMMA options+=postgresqlOption)* RPAR
    | K_USING K_INDEX K_TABLESPACE tablespaceName=sqlName
;

postgresqlReferentialAction:
      K_NO K_ACTION
    | K_RESTRICT
    | K_CASCADE
    | K_SET K_NULL LPAR (columns+=sqlName (COMMA columns+=sqlName)*)? RPAR
    | K_SET K_DEFAULT LPAR (columns+=sqlName (COMMA columns+=sqlName)*)? RPAR
;


// wrong documentation in 23.4: first part is not mandatory
// allow arbitrary order of states
constraintState:
    states+=constraintStateItem+
;

constraintStateItem:
      K_NOT? K_DEFERRABLE                       # deferrableConstraintStateItem
    | K_INITIALLY (K_DEFERRED | K_IMMEDIATE)?   # initallyConstraintStateItem
    | K_RELY                                    # relyConstraintStateItem
    | K_NORELY                                  # norelyConstraintStateItem
    | usingIndexClause                          # indexConstraintStateItem
    | K_ENABLE                                  # enableConstraintStateItem
    | K_DISABLE                                 # disableConstraintStateItem
    | K_VALIDATE                                # validateConstraintStateItem
    | K_NOVALIDATE                              # novalidateConstraintStateItem
    | exceptionsClause                          # exceptionConstraintStateItem
;

referencesClause:
    K_REFERENCES (schema=sqlName PERIOD)? objectName=sqlName
    (LPAR columns+=sqlName (COMMA columns+=sqlName)* RPAR)?
    (K_ON K_DELETE (K_CASCADE | K_SET K_NULL))?
;

precheckState:
      K_PRECHECK
    | K_NOPRECHECK
;

// simplified, list of tokens is considered good enough
usingIndexClause:
    K_USING K_INDEX usingIndexClauseCode
;

// artificial clause to handle token stream in "using index (create index i on t(c))"
// ensure that closing parentheses are consumed.
usingIndexClauseCode:
    ~SEMI+? RPAR*
;

exceptionsClause:
    K_EXCEPTIONS K_INTO (schema=sqlName PERIOD)? tableName=sqlName
;

inlineRefConstraint:
      K_SCOPE K_IS (schema=sqlName PERIOD)? tableName=sqlName
    | K_WITH K_ROWID
    | (K_CONSTRAINT constraitnName=sqlName) referencesClause constraintState?
;

// wrong documentation in 23.4: optionality of unusable_edition_clause
virtualColumnDefinition:
    column=sqlName (typeName=datatypeDomain (K_COLLATE collate=sqlName)?)?
    (K_VISIBLE | K_INVISIBLE)? (K_GENERATED K_ALWAYS)? K_AS LPAR expr=expression RPAR K_VIRTUAL?
    evaluationEditionClause? unusableEditionsClause constraints+=inlineConstraint*
;

evaluationEditionClause:
    K_EVALUATE K_USING
    (
          K_CURRENT K_EDITION
        | K_EDITION edition=sqlName
        | K_NULL K_EDITION
    )
;

unusableEditionsClause:
    (K_UNUSABLE K_BEFORE (K_CURRENT K_EDITION | K_EDITION edition=sqlName))?
    (K_UNUSABLE K_BEGINNING K_WITH (K_CURRENT K_EDITION | K_EDITION edition=sqlName | K_NULL K_EDITION))?
;

periodDefinition:
    K_PERIOD K_FOR validTimeColumn=sqlName (LPAR startTimeColumn=sqlName COMMA endTimeColumn=sqlName RPAR)?
;

outOfLineConstraint:
    (K_CONSTRAINT name=sqlName)?
    (
          K_UNIQUE LPAR columns+=sqlName (COMMA columns+=sqlName)* RPAR constraintState?
        | K_PRIMARY K_KEY LPAR columns+=sqlName (COMMA columns+=sqlName)* RPAR constraintState?
        | K_FOREIGN K_KEY LPAR columns+=sqlName (COMMA columns+=sqlName)* RPAR referencesClause constraintState?
        | K_CHECK LPAR cond=expression RPAR constraintState? precheckState?
        | postgresqlTableConstraint constraintState?
    )
;

// constraints not handled by outOflineConstraint
postgresqlTableConstraint:
      K_CHECK LPAR cond=expression RPAR (K_NO K_INHERIT)?
    | K_UNIQUE (K_NULLS K_NOT? K_DISTINCT)?
        LPAR columns+=sqlName (COMMA columns+=sqlName)* RPAR postgresqlIndexParameters*
    | K_PRIMARY K_KEY
        LPAR columns+=sqlName (COMMA columns+=sqlName)* RPAR postgresqlIndexParameters*
    | K_EXCLUDE (K_USING method=sqlName)?
        LPAR ecols+=postgresqlExcludeColumn (COMMA ecols+=postgresqlExcludeColumn)* RPAR
        postgresqlIndexParameters* (K_WHERE LPAR predicate=expression RPAR)?
    | K_FOREIGN K_KEY LPAR columns+=sqlName (COMMA columns+=sqlName)* RPAR
        K_REFERENCES reftable=qualifiedName (LPAR refcolumn=sqlName RPAR)?
        (K_MATCH K_FULL | K_MATCH K_PARTIAL | K_MATCH K_SIMPLE)?
        (K_ON K_DELETE onDeleteAction=postgresqlReferentialAction)?
        (K_ON K_UPDATE onUpdateAction=postgresqlReferentialAction)?
;

postgresqlExcludeColumn:
    excludeElement=sqlName K_WITH (binaryOperator | simpleComparisionOperator)
;

outOfLineRefConstraint:
      K_SCOPE K_FOR LPAR refCol+=sqlName RPAR K_IS (schema=sqlName PERIOD)? tableName=sqlName
    | K_REF LPAR refCol+=sqlName RPAR K_WITH K_ROWID
    | (K_CONSTRAINT constraitnName=sqlName) K_FOREIGN K_KEY
        LPAR refCol+=sqlName (COMMA refCol+=sqlName)* RPAR referencesClause constraintState?
;

supplementalLoggingProps:
    K_SUPPLEMENTAL K_LOG (supplementalLogGrpClause | supplementalLogKeyClause)
;

supplementalLogGrpClause:
    K_GROUP logGroup=sqlName
    LPAR columns+=supplementalLogGrpClauseColumn (COMMA columns+=supplementalLogGrpClauseColumn)* RPAR
    K_ALWAYS?
;

// artificial clause
supplementalLogGrpClauseColumn:
    column=sqlName (K_NO K_LOG)?
;

supplementalLogKeyClause:
    K_DATA LPAR options+=supplementalLogKeyClauseOption (COMMA options+=supplementalLogKeyClauseOption)* RPAR K_COLUMNS
;

// artificial clause
supplementalLogKeyClauseOption:
      K_ALL
    | K_PRIMARY K_KEY
    | K_UNIQUE
    | K_FOREIGN K_KEY
;

postgresqlLikeOptions:
    K_LIKE sourceTable=qualifiedName options+=postgresqlLikeOption (COMMA options+=postgresqlLikeOption)*
;

postgresqlLikeOption:
    (
          K_INCLUDING
        | K_EXCLUDING
    )
    (
          K_COMMENTS
        | K_COMPRESSION
        | K_CONSTRAINTS
        | K_DEFAULTS
        | K_GENERATED
        | K_IDENTITY
        | K_INDEXES
        | K_STATISTICS
        | K_STORAGE
        | K_ALL
    )
;

// artificial clause to handle everything up to table_properties
// simplified, list of tokens is considered good enough
beforeTableProperties:
    ~SEMI+?
;

// simplified, interested primarily in subquery,
// everything else is handled by beforeTableProperties
tableProperties:
    annotationsClause?
    (
           K_AS subquery (K_WITH K_NO? K_DATA)? // PostgreSQL allows "with (no) data"
        | K_FOR K_EXCHANGE K_WITH K_TABLE (schema=sqlName PERIOD)? tableName=sqlName
    )?
    (K_FOR K_STAGING)?
;

/*----------------------------------------------------------------------------*/
// Create Trigger
/*----------------------------------------------------------------------------*/

createTriggerStatement:
    createTrigger sqlEnd?
;

createTrigger:
    K_CREATE (K_OR K_REPLACE)? (K_EDITIONABLE | K_NONEDITIONABLE | K_CONSTRAINT)? K_TRIGGER
    (K_IF K_NOT K_EXISTS)? (plsqlTriggerSource | postgresqlTriggerSource)
;

plsqlTriggerSource:
    (schema=sqlName PERIOD)? triggerName=sqlName sharingClause? defaultCollationClause?
    (
          simpleDmlTrigger
        | insteadOfDmlTrigger
        | compoundDmlTrigger
        | systemTrigger
    )
;

simpleDmlTrigger:
    (K_BEFORE | K_AFTER) dmlEventClause referencingClause? (K_FOR K_EACH K_ROW)?
    triggerEditionClause? triggerOrderingClause? (K_ENABLE | K_DISABLE)?
    (K_WHEN LPAR cond=expression RPAR)? triggerBody
;

dmlEventClause:
    events+=dmlEvent (K_OR events+=dmlEvent)* K_ON (schema=sqlName PERIOD)? tableName=sqlName
;

dmlEvent:
      K_DELETE
    | K_INSERT
    | K_UPDATE (K_OF columns+=sqlName (COMMA columns+=sqlName)*)?
;

referencingClause:
    K_REFERENCING items+=refercingClauseItem+
;

refercingClauseItem:
      K_OLD K_AS? oldName=sqlName           # oldReferencingClauseItem
    | K_NEW K_AS? newName=sqlName           # newReferencingClauseItem
    | K_PARENT K_AS? parentName=sqlName     # parentReferencingClauseItem
;

triggerEditionClause:
    (K_FORWARD | K_REVERSE)? K_CROSSEDITION
;

triggerOrderingClause:
    (K_FOLLOWS | K_PRECEDES) triggers+=trigger
;

trigger:
    (schema=sqlName PERIOD)? triggerName=sqlName
;

triggerBody:
      plsqlBlock
    | K_CALL routineClause
;

routineClause:
    routine=expression
;

insteadOfDmlTrigger:
    K_INSTEAD K_OF events+=dmlEvent (K_OR events+=dmlEvent)*
    K_ON (K_NESTED K_TABLE nestedTableColumn=sqlName K_OF)? (schema=sqlName PERIOD)? viewName=sqlName
    referencingClause? (K_FOR K_EACH K_ROW)? triggerEditionClause?
    triggerOrderingClause? (K_ENABLE | K_DISABLE)? triggerBody
;

compoundDmlTrigger:
    K_FOR dmlEventClause referencingClause? triggerEditionClause? triggerOrderingClause?
    (K_ENABLE | K_DISABLE)? (K_WHEN LPAR cond=expression RPAR)? compoundTriggerBlock
;

compoundTriggerBlock:
    K_COMPOUND K_TRIGGER declareSection? timingPointSections+=timingPointSection+ K_END name=sqlName?
;

timingPointSection:
    startTimingPoint=timingPoint K_IS K_BEGIN tpsBody K_END endTimingPoint=timingPoint SEMI
;

timingPoint:
      K_BEFORE K_STATEMENT          # beforeStatementTimingPoint
    | K_BEFORE K_EACH K_ROW         # beforeEachRowTimingPoint
    | K_AFTER K_STATEMENT           # afterStatementTimingPoint
    | K_AFTER K_EACH K_ROW          # afterEachRowTimingPoint
    | K_INSTEAD K_OF K_EACH K_ROW   # insteadOfEachRowTimingPoint
;

tpsBody:
    stmts+=plsqlStatement+ (K_EXCEPTION exceptionHandlers+=exceptionHandler+)?
;

systemTrigger:
    (K_BEFORE | K_AFTER | K_INSTEAD K_OF)
    (ddlEvents+=ddlEvent | dbEvents+=databaseEvent) (K_OR (ddlEvents+=ddlEvent | dbEvents+=databaseEvent))*
    K_ON
    (
          (schema=sqlName PERIOD)? K_SCHEMA
        | K_PLUGGABLE? K_DATABASE
    )
    triggerOrderingClause? (K_ENABLE | K_DISABLE)? triggerBody
;

ddlEvent:
      K_ALTER                       # alterDdlEvent
    | K_ANALYZE                     # analyzeDdlEvent
    | K_ASSOCIATE K_STATISTICS      # associateStatisticsDdlEvent
    | K_AUDIT                       # auditDdlEvent
    | K_COMMENT                     # commentDdlEvent
    | K_CREATE                      # createDdlEvent
    | K_DISASSOCIATE K_STATISTICS   # disassociateStatisticsDdlEvent
    | K_DROP                        # dropDdlEvent
    | K_GRANT                       # grantDdlEvent
    | K_NOAUDIT                     # noAuditDdlEvent
    | K_RENAME                      # renameDdlEvent
    | K_REVOKE                      # revokeDdlEvent
    | K_TRUNCATE                    # truncateDdlEvent
    | K_DDL                         # ddlDdlEvent
;

// wrong documenation in 23.3: timepoint is not part of database_event
databaseEvent:
      K_STARTUP                     # statupDatabaseEvent
    | K_SHUTDOWN                    # shutdownDatabaseEvent
    | K_DB_ROLE_CHANGE              # dbRoleChangeDatabaseEvent
    | K_SERVERERROR                 # servererrorDatabaseEvent
    | K_LOGON                       # logonDatabaseEvent
    | K_LOGOFF                      # logoffDatabaseEvent
    | K_SUSPEND                     # suspendDatabaseEvent
    | K_CLONE                       # cloneDatabaseEvent
    | K_UNPLUG                      # unplugDatabaseEvent
    | K_SET K_CONTAINER             # setContainerDatabaseEvent
;

postgresqlTriggerSource:
    (triggerSchema=sqlName PERIOD)? triggerName=sqlName (K_BEFORE | K_AFTER | K_INSTEAD K_OF)
    events+=postgresqlTriggerEvent (K_OR events+=postgresqlTriggerEvent)*
    K_ON  (tableSchema=sqlName PERIOD)? tableName=sqlName
    postgresqlTriggerOption* K_EXECUTE (K_FUNCTION | K_PROCEDURE)
    (functionSchema=sqlName PERIOD)? functionName=sqlName
    LPAR (args+=expression (COMMA args+=expression)*)? RPAR
;

postgresqlTriggerEvent:
      K_INSERT
    | K_UPDATE (K_OF columns+=sqlName (COMMA columns+=sqlName)*)?
    | K_DELETE
    | K_TRUNCATE
;

postgresqlTriggerOption:
      K_FROM (referencedSchema=sqlName PERIOD)? referecedTableName=sqlName
    | K_NOT? K_DEFERRABLE
    | K_INITIALLY (K_IMMEDIATE | K_DEFERRED)
    | K_REFERENCING referencing+=postgresqlReferencing+
    | K_FOR K_EACH? (K_ROW | K_STATEMENT)
    | K_WHEN cond=expression
;

postgresqlReferencing:
    (K_OLD | K_NEW) K_TABLE K_AS? transitionRelationName=sqlName
;

/*----------------------------------------------------------------------------*/
// Create Type
/*----------------------------------------------------------------------------*/

createTypeStatement:
      createType sqlEnd
;

createType:
    K_CREATE (K_OR K_REPLACE)? (K_EDITIONABLE | K_NONEDITIONABLE)? K_TYPE
    (K_IF K_NOT K_EXISTS)? (plsqlTypeSource | postgresqlTypeSource)
;

plsqlTypeSource:
    (schema=sqlName PERIOD)? typeName=sqlName options+=plsqlTypeOption*
    (objectBaseTypeDef | objectSubtypeDef)
;

plsqlTypeOption:
      K_FORCE
    | K_OID objectIdentifier=STRING
    | sharingClause
    | defaultCollationClause
    | invokerRightsclause
    | accessibleByClause
;

objectBaseTypeDef:
    (K_IS | K_AS) (objectTypeDef | varayTypeSpec | nestedTableTypeSpec)
;

// wrong documentation in 23.3: optional attributes
objectTypeDef:
    K_OBJECT LPAR attributes+=attribute (COMMA attributes+=attribute)* (COMMA elements+=elementSpec)* RPAR
    options+=objectTypeDefOption*
;

attribute:
    name=sqlName type=plsqlDataType
;

// wrong documentation in 23.3: repeating subprogram_spec, constructor_spec, map_order_function_spec
// only pragma restrict_references is documented, but others such as pragma deprecate work as well
elementSpec:
    inheritanceClauses? (subprogramSpec | constructorSpec | mapOrderFunctionSpec | pragma)
;

subprogramSpec:
    (K_MEMBER | K_STATIC) (procedureSpec | functionSpec)
;

// wrong documentation in 23.3: mandatory parameters and parentheses,
// parameter direction missing (in/out), default values missing
procedureSpec:
    K_PROCEDURE name=sqlName
    (LPAR parameters+=parameterDeclaration (COMMA parameters+=parameterDeclaration)* RPAR)?
    ((K_IS | K_AS) callSpec)?
;

// wrong documentation in 23.3: mandatory parameters and parentheses,
// parameter direction missing (in/out), default values missing
functionSpec:
    K_FUNCTION name=sqlName
    (LPAR parameters+=parameterDeclaration (COMMA parameters+=parameterDeclaration)* RPAR)?
    returnClause
;

// not documented in 23.4: options are missing, at least pipelined_clause is working
returnClause:
    K_RETURN type=dataType options+=functionDeclarationOption* ((K_IS | K_AS) callSpec)?
;

// undocumented in 23.3: final/instantiable is an unordered group,
// wrong documentation in 23.3: mandatory parameters and parentheses,
// parameter direction missing (in/out), default values missing
constructorSpec:
    options+=constructorSpecOption* K_CONSTRUCTOR K_FUNCTION type=dataType
    (
        LPAR (K_SELF K_IN K_OUT selfType=dataType COMMA)?
        parameters+=parameterDeclaration (COMMA parameters+=parameterDeclaration)* RPAR
    )?
    K_RETURN K_SELF K_AS K_RESULT ((K_IS | K_AS) callSpec)?
;

constructorSpecOption:
      K_FINAL           # finalConstructor
    | K_INSTANTIABLE    # instantiableConstructor
;

mapOrderFunctionSpec:
    (K_MAP | K_ORDER) K_MEMBER functionSpec
;

inheritanceClauses:
    items=inheritanceClauseItem+
;

inheritanceClauseItem:
      K_NOT? K_OVERRIDING       # overridingInheritanceClauseItem
    | K_NOT? K_FINAL            # finalInheritanceClauseItem
    | K_NOT? K_INSTANTIABLE     # instantiableInheritanceClauseItem
;

objectTypeDefOption:
      K_NOT? K_FINAL            # finalObjectTypeDefOption
    | K_NOT? K_INSTANTIABLE     # intantiableObjectTypeDefOption
    | K_NOT? K_PERSISTABLE      # persistableObjectTypeDefOption
;

// not documented in 23.4: optionality of "not"
varayTypeSpec:
    (K_VARRAY | K_VARYING? K_ARRAY) LPAR sizeLimit=expression RPAR K_OF
    (
          plsqlDataType (K_NOT? K_NULL)?
        | LPAR plsqlDataType (K_NOT? K_NULL)? RPAR (K_NOT? K_PERSISTABLE)?
    )
;

// not documented in 23.4: optionality of "not"
nestedTableTypeSpec:
    K_TABLE K_OF
    (
          plsqlDataType (K_NOT? K_NULL)?
        | LPAR plsqlDataType (K_NOT? K_NULL)? RPAR (K_NOT? K_PERSISTABLE)?
    )
;

// not documented in 23.4: optionality of attributes
objectSubtypeDef:
    K_UNDER (schema=sqlName PERIOD)? superType=sqlName
    (LPAR objectSubtypeElements RPAR)?
    options+=objectTypeDefOption*
;

// artificial clause to handle optionality of attributes
objectSubtypeElements:
      attributes+=attribute (COMMA attributes+=attribute)* (COMMA elements+=elementSpec)*
    | elements+=elementSpec (COMMA elements+=elementSpec)*
;

postgresqlTypeSource:
    (schema=sqlName PERIOD)? typeName=sqlName
    (
          postgresqlType
        | postgresqlEnumType
        | postgresqlRangeType
        | postgresqlFunctionType
    )?
;

postgresqlType:
    K_AS LPAR (attributes+=postgresqlAttribute (COMMA attributes+=postgresqlAttribute)*)? RPAR
;

postgresqlAttribute:
    name=sqlName dataType (K_COLLATE collate=sqlName)?
;

postgresqlEnumType:
    K_AS K_ENUM LPAR (labels+=STRING (COMMA labels+=STRING)*)? RPAR
;

// simplified (making all options optional even if subtype is mandatory) to support arbitrary order
// undocumented in 16:3: subtype does not need to be the first option
postgresqlRangeType:
    K_AS K_RANGE LPAR options+=postgresqlOption (COMMA options+=postgresqlOption)* RPAR
;

// simplified (making all options optional even if input, output are mandatory) to support arbitrary order
// undocumented in 16:3: input, output do not need to be the first and second option
postgresqlFunctionType:
    LPAR options+=postgresqlOption (COMMA options+=postgresqlOption)* RPAR
;

/*----------------------------------------------------------------------------*/
// Create Type Body
/*----------------------------------------------------------------------------*/

createTypeBodyStatement:
    createTypeBody sqlEnd?
;

createTypeBody:
    K_CREATE (K_OR K_REPLACE)? (K_EDITIONABLE | K_NONEDITIONABLE)? K_TYPE K_BODY
    (K_IF K_NOT K_EXISTS)? plsqlTypeBodySource
;

plsqlTypeBodySource:
    (schema=sqlName PERIOD)? typeName=sqlName sharingClause?
    (K_IS | K_AS) items+=plsqlTypeBodyItem+ K_END SEMI
;

// wrong documentation in 23.3 type body: missing inheritanceClauses
plsqlTypeBodyItem:
    inheritanceClauses? (subprogDeclInType| mapOrderFuncDeclaration)
;

subprogDeclInType:
      subprogramDecl
    | constructorDeclaration
;

// wrong documenation in 23.3 type body: missing member, static
subprogramDecl:
    (K_MEMBER | K_STATIC) (procDeclInType | funcDeclInType)
;

procDeclInType:
    K_PROCEDURE name=sqlName
    (LPAR parameters+=parameterDeclaration (COMMA parameters+=parameterDeclaration)* RPAR)?
    (K_IS | K_AS) (declareSection? body | callSpec SEMI)
;

funcDeclInType:
    K_FUNCTION name=sqlName
    (LPAR parameters+=parameterDeclaration (COMMA parameters+=parameterDeclaration)* RPAR)?
    K_RETURN returnType=dataType options+=plsqlFunctionOption*
    (K_IS | K_AS) (declareSection? body | callSpec SEMI)
;

constructorDeclaration:
    options+=constructorSpecOption* K_CONSTRUCTOR K_FUNCTION type=dataType
    (
        LPAR (K_SELF K_IN K_OUT selfType=dataType COMMA)?
        parameters+=parameterDeclaration (COMMA parameters+=parameterDeclaration)* RPAR
    )?
    K_RETURN K_SELF K_AS K_RESULT
    (K_IS | K_AS) (declareSection? body | callSpec SEMI)
;

mapOrderFuncDeclaration:
    (K_MAP | K_ORDER) K_MEMBER funcDeclInType
;

/*----------------------------------------------------------------------------*/
// Create View
/*----------------------------------------------------------------------------*/

createViewStatement:
    createView sqlEnd
;

createView:
    K_CREATE (K_OR K_REPLACE)? (K_NO? K_FORCE)?
    (K_TEMP | K_TEMPORARY)? K_RECURSIVE?    // PostgreSQL only
    (
          K_EDITIONING
        | K_EDITIONABLE K_EDITIONING?
        | K_NONEDITIONABLE
    )? K_VIEW (K_IF K_NOT K_EXISTS)? (schema=sqlName PERIOD)? viewName=sqlName
    sharingClause?
    (
          relationalViewClause
        | objectViewClause
        | xmltypeViewClause
    )?
    postgresqlViewOptions?
    defaultCollationClause?
    (K_BEQUEATH (K_CURRENT_USER | K_DEFINER))?
    annotationsClause?
    K_AS subquery subqueryRestrictionClause? (K_CONTAINER_MAP|K_CONTAINERS_DEFAULT)?
;

postgresqlViewOptions:
    K_WITH LPAR options+=postgresqlOption (COMMA options+=postgresqlOption)* RPAR
;

// used also for materialized view and therefore name is a qualifiedName
postgresqlOption:
    name=qualifiedName (EQUALS value=expression)?
;

// artificial clause
relationalViewClause:
    LPAR items+=relationalViewClauseItem (COMMA items+=relationalViewClauseItem)* RPAR
;

relationalViewClauseItem:
      alias=sqlName (K_VISIBLE | K_INVISIBLE)? inlineConstraint?
    | outOfLineConstraint
;

// oid is old syntax that is not documented anymore
// wrong documentation in 23.4: list of attributes and constraints does not make sense, omitted it therefore
objectViewClause:
    K_OF (schema=sqlName PERIOD)? typeName=sqlName
    (
          K_WITH K_OBJECT (K_IDENTIFIER | K_ID | K_OID) (K_DEFAULT | LPAR attributes+=sqlName (COMMA attributes+=sqlName)* RPAR)
        | K_UNDER (superSchema=sqlName PERIOD)? superViewName=sqlName
    )
;

// oid is old syntax that is not documented anymore
xmltypeViewClause:
    K_OF K_XMLTYPE xmlschemaSpec?
    K_WITH K_OBJECT (K_IDENTIFIER | K_ID | K_OID) (K_DEFAULT | LPAR exprs+=expression (COMMA exprs+=expression)* RPAR)
;

// wrong documentation in 23.4: url and element must be passed in double quotes (as quoted identifier)
// no need to deal with anchored element explicitly since they are part of the quoted identifier
xmlschemaSpec:
    (K_XMLSCHEMA url=QUOTED_ID)? K_ELEMENT element=QUOTED_ID
    (K_STORE K_ALL K_VARRAYS K_AS (K_LOBS | K_TABLES))?
    ((K_ALLOW | K_DISALLOW) K_NONSCHEMA)?
    ((K_ALLOW | K_DISALLOW) K_ANYSCHEMA)?
;

// contains part of annotations_list clause to simplify grammar
annotationsClause:
    K_ANNOTATIONS LPAR items+=annotationListItem (COMMA items+=annotationListItem)* RPAR
;

// artificial clause
annotationListItem:
    (
          K_ADD (K_IF K_NOT K_EXISTS | K_OR K_REPLACE)?
        | K_DROP (K_IF K_EXISTS)?
        | K_REPLACE
    )?
    annotation
;

// contains annotation_name and annotation_value to simplify grammar
annotation:
    name=sqlName value=string?
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

dmlTableExpressionClause:
      (schema=sqlName PERIOD)? table=sqlName AST? (partitionExtensionClause | COMMAT dblink=qualifiedName)? // PostgreSQL: *
    | LPAR query=subquery RPAR
    | tableCollectionExpression
;

tableCollectionExpression:
    K_TABLE LPAR (subquery | expr=expression) RPAR (LPAR PLUS RPAR)?
;

// introduced in OracleDB 23.2, re-use grammar in select statement
// it's similar to the fromClause, the only difference is that you can use K_USING instead of K_FROM
fromUsingClause:
    (K_FROM | K_USING) items+=fromItem (COMMA items+=fromItem)*
;

returningClause:
    (K_RETURN | K_RETURNING) sourceItems+=sourceItem (COMMA sourceItems+=sourceItem)*
    (
        (K_BULK K_COLLECT)? // within PL/SQL
        K_INTO K_STRICT? targetItems+=dataItem (COMMA targetItems+=dataItem)* // strict only in PL/pgSQL
    )?  // required in OracleDB but not allowed in PostgreSQL
;

// OLD and NEW are introduced in OracleDB 23.2
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
// Do
/*----------------------------------------------------------------------------*/

doStatement:
    postgresqlDo sqlEnd
;

// undocumented in PostgreSQL 16.3: language option after code
// subtree is optionally populated when creating an IslandSqlDocument instance
// subtree added for this option if code is a string
postgresqlDo:
    K_DO (
          code=postgresqlCode
        | K_LANGUAGE languageName=expression code=postgresqlCode
        | code=postgresqlCode K_LANGUAGE languageName=expression
    )
;

postgresqlCode:
    elements+=postgresqlCodeElement+
;

postgresqlCodeElement:
      string                # stringCodeElement
    | psqlStringVariable    # variableCodeElement
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

// insert_values_clause is redunant to subquery (ambiguity to be removed?)
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
    (LPAR columns+=columnReference (COMMA columns+=columnReference)* RPAR)?
;

columnReference:
    items+=columnReferenceItem (PERIOD items+=columnReferenceItem)*
;

columnReferenceItem:
      sqlName
    | postgresqlSubscriptReference+
    | sqlName postgresqlSubscriptReference+
;

postgresqlSubscriptReference:
      postgresqlSubscript
    | LSQB lower=expression RSQB
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
    K_WHEN cond=expression K_THEN intoClauses+=multiTableInsertClause+
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
      LPAR items+=postgresqlOnConflictTargetItem (COMMA items+=postgresqlOnConflictTargetItem)* RPAR  (K_WHERE indexPredicate=expression)?
    | K_ON K_CONSTRAINT constraintName=sqlName
;

postgresqlOnConflictTargetItem:
    expr=expression (opclass=sqlName)?
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
    items+=postgresqlOnConflictActionDoUpdateItem (COMMA items+=postgresqlOnConflictActionDoUpdateItem)*
    (K_WHERE cond=expression)?
;

postgresqlOnConflictActionDoUpdateItem:
      columns+=columnReference EQUALS exprs+=expression
    | LPAR columns+=columnReference (COMMA columns+=columnReference)* RPAR
        EQUALS K_ROW? LPAR ((exprs+=expression (COMMA exprs+=expression)*) | subquery) RPAR
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
        (K_IN lockMode K_MODE lockTableWaitOption?)? // PostgreSQL: optional lockMode
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
          LPAR cond=expression RPAR  // OracleDB
        | cond=expression            // PostgreSQL
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
      K_WHEN K_MATCHED (K_AND cond=expression)? K_THEN (mergeUpdate | mergeDelete | K_DO K_NOTHING)
    | K_WHEN K_NOT K_MATCHED (K_AND cond=expression)? K_THEN (mergeInsert | K_DO K_NOTHING)
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
;

select:
    subquery
;

// moved with_clause from query_block to support main query in parenthesis (works, undocumented)
// undocumented: for_update_clause can be used before order_by_clause (but not with row_limiting_clause)
// PostgreSQL allows to use the values_clause as subquery in the with_clause (e.g. with set_operator)
// PostgreSQL allows multiple forUpdateClauses scope is a table not a column as in OracleDB
// PostgreSQL allows the intoClause at the end (undocumented PL/pgSQL variant in 16.3)
subquery:
      withClause? queryBlock forUpdateClause+ orderByClause? rowLimitingClause? intoClause?         # queryBlockSubquery
    | withClause? queryBlock orderByClause? rowLimitingClause? forUpdateClause* intoClause?         # queryBlockSubquery
    | left=subquery setOperator right=subquery                                                      # setSubquery
    | withClause? LPAR subquery RPAR forUpdateClause+ orderByClause? rowLimitingClause? intoClause? # parenSubquery
    | withClause? LPAR subquery RPAR orderByClause? rowLimitingClause? forUpdateClause* intoClause? # parenSubquery
    | valuesClause orderByClause? rowLimitingClause? intoClause?                                    # valuesSubquery
    | K_TABLE K_ONLY? tableName=qualifiedName AST?                                                  # tableQueryBlockSubquery // PostgreSQL
;

queryBlock:
    {unhideFirstHint();} K_SELECT hint?
    queryBlockSetOperator?
    (
          selectList
        | intoClause selectList // undocumented PL/pgSQL variant in 16.3
        | selectList (intoClause | bulkCollectIntoClause | postgresqlIntoClause) // PL/SQL, PL/pgSQL, PostgreSQL SQL
    )? // PostgreSQL: select_list is optional, e.g. in subquery of exists condition
    fromClause? // starting with OracleDB 23.2 the from clause is optional
    intoClause? // undocumented PL/pgSQL variant in 16.3
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
        K_AS? talias=sqlName LPAR caliases+=sqlName (COMMA caliases+=sqlName)* RPAR     # qualifiedValuesClause
    | K_VALUES rows+=valuesRow (COMMA rows+=valuesRow)*                                 # defaultValuesClause
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
    ids+=hierId (COMMA ids+=hierId)* K_TO predicate=expression
;

hierId:
      K_MEASURES    # measuresHierId
    | hierarchyRef  # dimHierId
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
    K_WHERE cond=expression
;

hierarchicalQueryClause:
      K_CONNECT K_BY K_NOCYCLE? connectByCond=expression (K_START K_WITH startWithCond=expression)?
    | K_START K_WITH startWithCond=expression K_CONNECT K_BY K_NOCYCLE? connectByCond=expression
;

// PostgreSQL: all, distinct
groupByClause:
      K_GROUP K_BY (K_ALL|K_DISTINCT)? items+=groupByItem (COMMA items+=groupByItem)* (K_HAVING cond=expression)?
    | K_HAVING cond=expression (K_GROUP K_BY (K_ALL|K_DISTINCT)? items+=groupByItem (COMMA items+=groupByItem)*)? // undocumented, but allowed in OracleDB
;

// rollupCubeClause treated as expression
groupByItem:
      expression
    | groupingSetsClause
;

groupingSetsClause:
    K_GROUPING K_SETS LPAR items+=groupingSetItem (COMMA items+=groupingSetItem)* RPAR
;

// nested grouping sets are allowed in PostgreSQL
groupingSetItem:
      expression
    | groupingSetsClause
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
    K_ITERATE LPAR iterate=expression RPAR (K_UNTIL cond=expression)?
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
      expression
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

// only in PL/SQL, PL/pgSQL
intoClause:
    K_INTO K_STRICT? variables+=expression (COMMA variables+=expression)* // strict only in PL/pgSQL
;

// only in PL/SQL
bulkCollectIntoClause:
    K_BULK K_COLLECT K_INTO variables+=expression (COMMA variables+=expression)*
;

// handles only variants in PostgreSQL SQL
postgresqlIntoClause:
    K_INTO (K_TEMPORARY|K_TEMP|K_UNLOGGED)? K_TABLE tableName=qualifiedName
;

fromClause:
    K_FROM items+=fromItem (COMMA items+=fromItem)*
;

// handles table aliases for all from items, simplifies from items in parentheses
// table_tags_clause is valid only within create_json_relational_duality_view
fromItem:
      tableReference tableAlias? tableTagsClause?   # tableReferenceFromItem
    | fromItem joins+=joinVariant+                  # joinClause
    | inlineAnalyticView tableAlias?                # inlineAnalyticViewFromItem
    | LPAR fromItem RPAR tableAlias?                # parenFromItem
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
    | tableCollectionExpression
    | tableExpression
    | K_LATERAL? LPAR subquery subqueryRestrictionClause? RPAR
    | values=valuesClause // handled here to simplifiy grammar, even if pivot_clause etc. are not applicable
;

// table/column aliases are part of from_item
tableExpression:
       K_LATERAL (schema=sqlName PERIOD)? expr=tableExpressionFunction (K_WITH K_ORDINALITY)? // PostgreSQL
     | (schema=sqlName PERIOD)? expr=tableExpressionFunction (K_WITH K_ORDINALITY)? // OracleDB (without ordinality), PostgreSQL
     | K_LATERAL? K_ROWS K_FROM LPAR exprs+=rowsFromFunction (COMMA exprs+=rowsFromFunction)* RPAR (K_WITH K_ORDINALITY)? // PostgreSQL
;

tableExpressionFunction:
      functionExpression
    | specialFunctionExpression
;

rowsFromFunction:
    expr=functionExpression (K_AS LPAR cdefs+=postgresqlColumnDefinition (COMMA cdfs+=postgresqlColumnDefinition)* RPAR)?
;

// grammar definition in SQL Language Reference 19c/21c/23.3 is wrong, added LPAR/RPAR
modifiedExternalTable:
    K_EXTERNAL K_MODIFY LPAR properties+=modifyExternalTableProperties+ RPAR
;

// implemented as alternatives, all are technically optional
// grammar definition in SQL Language Reference 19c/21c/23.3 is wrong regarding "access parameters"
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
    ~SEMI+?
;

subqueryRestrictionClause:
    K_WITH
    (
          K_READ K_ONLY
        | K_CHECK K_OPTION
        | (K_CASCADED | K_LOCAL) K_CHECK K_OPTION   // PostgreSQL only
    )
    (K_CONSTRAINT constraintName=sqlName)?
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
      K_SHOW K_EMPTY K_MATCHES  # showEmptyMatchesRowPatternRowsPerMatch
    | K_OMIT K_EMPTY K_MATCHES  # omitEmptyMatchesRowPatternRowsPerMatch
    | K_WITH K_UNMATCHED K_ROWS # withUnmatchedRowsRowPatternRowsPerMatch
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
      AST_QUEST                                         # zeroOrMoreRowPatternQuantifier
    | AST QUEST?                                        # zeroOrMoreRowPatternQuantifier
    | PLUS_QUEST                                        # oneOrMoreRowPatternQuantifier
    | PLUS QUEST?                                       # oneOrMoreRowPatternQuantifier
    | QUEST_QUEST                                       # zeroOreOneRowPatternQuantifier
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
    variableName=sqlName K_AS cond=expression
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
            K_ON cond=expression
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
          K_ON cond=expression
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
      K_OFFSET offset=expression (K_ROW | K_ROWS)? (fetchClause rowLimitingPartitionClause? rowSpecification? accuracyClause?)?
    | fetchClause rowLimitingPartitionClause? rowSpecification? accuracyClause? (K_OFFSET offset=expression (K_ROW | K_ROWS)?)?
    | K_LIMIT (rowcount=expression|K_ALL) (K_OFFSET offset=expression (K_ROW | K_ROWS)?)? // PostgreSQL
    | (K_OFFSET offset=expression (K_ROW | K_ROWS)?) K_LIMIT (rowcount=expression|K_ALL)? // PostgreSQL
;

fetchClause:
    K_FETCH (K_EXACT | K_APPROX | K_APPROXIMATE)? (K_FIRST | K_NEXT)
;

// wrong documentation in 23.4: all clauses are optional (already optional in row_limiting_clause)
// making it mandatory for at least one item
rowLimitingPartitionClause:
    rowLimitingPartitionClauseItem+
;

// artificial clause to simplifiy cardinality handling
rowLimitingPartitionClauseItem:
    partitionCount=expression (K_PARTITION | K_PARTITIONS) K_BY partitionByExpr=expression COMMA
;

rowSpecification:
    (rowcount=expression | percent=expression K_PERCENT)? (K_ROW | K_ROWS) (K_ONLY | K_WITH K_TIES)
;

// wrong documentation in 23.4: optionality and alternatives are not plausible (keyword accuracy is required)
// adapted according examples in Oracle AI Vector Search User Guide
accuracyClause:
    (K_WITH K_TARGET)? K_ACCURACY
    (
          accuracy=expression K_PERCENT?
        | K_PARAMETERS LPAR params+=accuracyParameter+ (COMMA params+=accuracyParameter+)* RPAR
    )
;

// artifical clause to handle arbitrary parameter order
accuracyParameter:
      K_EFSEARCH efs=expression
    | K_NEIGHBOR K_PARTITION K_PROBES nprobes=expression
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
          K_ROW EQUALS expr=expression
        | items+=updateSetClauseItem (COMMA items+=updateSetClauseItem)*
        | K_VALUE LPAR talias=sqlName RPAR EQUALS (expr=expression | LPAR query=subquery RPAR)
    )
;

updateSetClauseItem:
      LPAR columns+=columnReference (COMMA columns+=columnReference)* RPAR
        EQUALS LPAR query=subquery RPAR                                             # columnListUpdateSetClauseItem
    | LPAR columns+=columnReference (COMMA columns+=columnReference)* RPAR
        EQUALS K_ROW? LPAR exprs+=expression (COMMA exprs+=expression)* RPAR        # postgresqlRowUpdateSetClauseItem
    | LPAR columns+=columnReference RPAR
        EQUALS (expr=expression | LPAR query=subquery RPAR)                         # columnUpdateSetClauseItem
    | columns+=columnReference EQUALS (expr=expression | LPAR query=subquery RPAR)  # columnUpdateSetClauseItem
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
      pragma SEMI
    | typeDefinition
    | cursorDeclaration
    | cursorDefinition
    | itemDeclaration
    | functionDeclaration
    | functionDefinition
    | procedureDeclaration
    | procedureDefinition
    | selectionDirective
    | postgresqlCursorDefinition
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

// not documented in 23.4: optionality of "not"
assocArrayTypeDef:
    K_TABLE K_OF type=plsqlDataType (K_NOT? K_NULL)? K_INDEX K_BY indexType=plsqlDataType
;

plsqlDataType:
      K_REF dataType                                    # refPlsqlDataType
    | qualifiedName PERCNT K_TYPE dataTypeArray?        # percentTypePlsqlDataType
    | qualifiedName PERCNT K_ROWTYPE dataTypeArray?     # percentRowtypePlsqlDataType
    | dataType                                          # simplePlsqlDataType
;

// not documented in 23.4: optionality of "not"
varrayTypeDef:
    (K_VARRAY | K_VARYING? K_ARRAY) LPAR size=expression RPAR K_OF type=plsqlDataType (K_NOT? K_NULL)?
;

// not documented in 23.4: optionality of "not"
nestedTableTypeDef:
    K_TABLE K_OF type=plsqlDataType (K_NOT? K_NULL)?
;

recordTypeDefinition:
    K_TYPE name=sqlName K_IS K_RECORD LPAR
        fieldDefinitions+=fieldDefinition (COMMA fieldDefinitions+=fieldDefinition)*
    RPAR SEMI
;

// no space allowed between ':' and '=' in OracleDB 23.3
// not documented in 23.4: optionality of "not"
// not documented in 23.4: use of null without assignment
fieldDefinition:
    field=sqlName type=plsqlDataType ((K_NOT? K_NULL)? (COLON_EQUALS | K_DEFAULT) expr=expression | K_NULL)?
;

refCursorTypeDefinition:
    K_TYPE type=sqlName K_IS K_REF K_CURSOR (K_RETURN returnType=plsqlDataType)? SEMI
;

// not documented in 23.3: optionality of "not"
subtypeDefinition:
    K_SUBTYPE subtype=sqlName K_IS baseType=plsqlDataType
    (subtypeConstraint | K_CHARACTER K_SET characterSet=sqlName)? (K_NOT? K_NULL)? SEMI
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
    | postgresqlAliasDeclaration
;

// not documented in 23.4: optionality of "not"
// = allowed in PL/pgSQL as alternative to :=, DEFAULT
constantDeclaration:
    constant=sqlName K_CONSTANT type=plsqlDataType postgresqlCollation?
        (K_NOT? K_NULL)? ((COLON_EQUALS | K_DEFAULT | EQUALS) expr=postgresqlSqlExpression)? SEMI
;

// not documented in 23.4: optionality of "not"
// not documented in 23.4: use of null without assignment
// = allowed in PL/pgSQL as alternative to :=, DEFAULT
variableDeclaration:
    variable=sqlName type=plsqlDataType postgresqlCollation?
        ((K_NOT? K_NULL)? (COLON_EQUALS | K_DEFAULT | EQUALS) expr=postgresqlSqlExpression | K_NULL)? SEMI
;

postgresqlCollation:
    K_COLLATE collate=sqlName
;

postgresqlAliasDeclaration:
    newName=sqlName K_ALIAS K_FOR oldName=expression SEMI
;

functionDeclaration:
    functionHeading options+=functionDeclarationOption* SEMI
;

// contains also options in package_function_declaration
// not documented in 23.4: aggregarte_clause, sql_macro_clause
functionDeclarationOption:
      accessibleByClause
    | deterministicClause
    | pipelinedClause
    | shardEnableClause
    | parallelEnableClause
    | resultCacheClause
    | aggreagateClause
    | sqlMacroClause
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
                    | (K_HASH | K_RANGE) LPAR columns+=sqlName (COMMA columns+=sqlName)* RPAR streamingClause?
                    | K_VALUE LPAR columns+=sqlName RPAR
                )
            RPAR
        )?
;

streamingClause:
    (K_ORDER | K_CLUSTER) expr=expression K_BY LPAR columns+=sqlName (COMMA columns+=sqlName)* RPAR
;

resultCacheClause:
    K_RESULT_CACHE (K_RELIES_ON LPAR (dataSources+=qualifiedName (COMMA dataSources+=qualifiedName)*)? RPAR)?
;

functionHeading:
    K_FUNCTION functionName=sqlName
        (LPAR parameters+=parameterDeclaration (COMMA parameters+=parameterDeclaration)* RPAR)?
        K_RETURN returnType=plsqlDataType
;

functionDefinition:
    functionHeading options+=functionDefinitionOption* (K_IS | K_AS) (declareSection? body | callSpec SEMI)
;

// contains also options for package body function defintion
// not documented in 23.4: accessible_by_clause, shard_enable_clause
functionDefinitionOption:
      accessibleByClause
    | deterministicClause
    | shardEnableClause
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

// code is valid for 23.2 onwards (quoted-strings in 23.2, 23.3, unquoted strings, PostgreSQL strings in 23.4 onwards)
// scriptBody is valid for 23.4 onwards
javascriptDeclaration:
    K_MLE
        (
              K_MODULE (schema=sqlName PERIOD)? moduleName=sqlName
                (K_ENV (envSchema=sqlName PERIOD)? envName=sqlName)? K_SIGNATURE signature=string
            | K_LANGUAGE languageName=sqlName (code=string|scriptBody)
        )
;

// new syntax introduced in 23.4 (breaking change)
// script contains also the start and end delimiters, e.g. {{, }}
scriptBody:
    script=.*? // handles all kind of delimiters
;

// undocumented in 23.4: nameSchema and libNameSchema
cDeclaration:
    (K_LANGUAGE K_C | K_EXTERNAL)
        (
              (K_NAME (nameSchema=sqlName PERIOD)? name=sqlName)? K_LIBRARY (libNameSchema=sqlName PERIOD)? libName=sqlName
            | K_LIBRARY (libNameSchema=sqlName PERIOD)? libName=sqlName (K_NAME (nameSchema=sqlName PERIOD)? name=sqlName)?
        )
        (K_AGENT K_IN LPAR args+=sqlName (COMMA args+=sqlName)* RPAR)?
        (K_WITH K_CONTEXT)?
        (K_PARAMETERS LPAR params+=externalParameter (COMMA params+=externalParameter)* RPAR)?
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
    K_ACCESSIBLE K_BY LPAR accessors+=accessor (COMMA accessors+=accessor)* RPAR
;

accessor:
    unitKind? (schema=sqlName PERIOD)? unitName=sqlName
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

// stmts are optional in PL/pgSQL, undocumented in 16.3
body:
    K_BEGIN
    stmts+=plsqlStatement*
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
        | raiseStatement
        | returnStatement
        | selectionDirective
        | selectIntoStatement
        | sqlStatement
        | whileLoopStatement
        | pragma SEMI
        | postgresqlAssertStatement
        | postgresqlExecuteStatement
        | postgresqlFetchStatement
        | postgresqlForEachStatement
        | postgresqlGetDiagnosticsStatement
        | postgresqlGetStackedDiagnosticsStatement
        | postgresqlMoveStatement
        | postgresqlPerformStatement
        | postgresqlRaiseStatement
        | procedureCall // ambiguity with returnStatement, return is not a reserved keyword PostgreSQL
    )
;

assignmentStatement:
    target=expression
    (
          COLON_EQUALS      // OracleDB, PostgreSQL
        | EQUALS            // PostgreSQL
    ) value=postgresqlSqlExpression SEMI
;

// stmts are optional in PL/pgSQL, undocumented in 16.3
basicLoopStatement:
    K_LOOP stmts+=plsqlStatement* K_END K_LOOP name=sqlName? SEMI
;

caseStatement:
      simpleCaseStatement
    | searchedCaseStatement
;

// elseStmts are optional in PL/pgSQL, undocumented in 16.3
simpleCaseStatement:
    K_CASE selector=postgresqlSqlExpression whens+=simpleCaseStatementWhenClause+
    (K_ELSE elseStmts+=plsqlStatement*)? K_END K_CASE name=sqlName? SEMI
;

// stmts are optional in PL/pgSQL, undocumented in 16.3
simpleCaseStatementWhenClause:
    K_WHEN values+=whenClauseValue (COMMA values+=whenClauseValue)* K_THEN stmts+=plsqlStatement*
;

// elseStmts are optional in PL/pgSQL, undocumented in 16.3
searchedCaseStatement:
    K_CASE whens+=searchedCaseStatementWhenClause+
    (K_ELSE elseStmts+=plsqlStatement*)? K_END K_CASE name=sqlName? SEMI
;

// stmts are optional in PL/pgSQL, undocumented in 16.3
searchedCaseStatementWhenClause:
    K_WHEN cond=postgresqlSqlExpression K_THEN stmts+=plsqlStatement*
;

closeStatment:
    K_CLOSE COLON? cursor=qualifiedName SEMI
;

continueStatement:
    K_CONTINUE toLabel=sqlName? (K_WHEN cond=postgresqlSqlExpression)? SEMI
;

// wrong documentation in 23.3 regarding parentheses for cursor parameters
// PostgreSQL allows either record target or a list of scalar targets
// stmts are optional in PL/pgSQL, undocumented in 16.3
cursorForLoopStatement:
    K_FOR targets+=qualifiedName (COMMA targets+=qualifiedName)* K_IN (
          cursorName=qualifiedName LPAR params+=functionParameter (COMMA params+=functionParameter)* RPAR
        | LPAR select RPAR
        | select                                    // PostgreSQL
        | insert                                    // PostgreSQL with returning_clause
        | update                                    // PostgreSQL with returning_clause
        | delete                                    // PostgreSQL with returning_clause
        | K_EXECUTE query=expression usingClause?   // PostgreSQL
    ) K_LOOP stmts+=plsqlStatement* K_END K_LOOP name=sqlName? SEMI
;

executeImmediateStatement:
    executeImmediate SEMI
;

// required variant without ending on semicolon, used in forall_statement
executeImmediate:
    K_EXECUTE K_IMMEDIATE dynamicSqlStmt=expression (
          (intoClause | bulkCollectIntoClause) usingClause?
        | usingClause dynamicReturnClause?
        | dynamicReturnClause
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
    )? arg=postgresqlSqlExpression
;

dynamicReturnClause:
    (K_RETURNING | K_RETURN) (intoClause | bulkCollectIntoClause)
;

exitStatement:
    K_EXIT toLabel=sqlName? (K_WHEN expr=postgresqlSqlExpression)? SEMI
;

fetchStatement:
    K_FETCH COLON? cursor=qualifiedName (
          intoClause
        | bulkCollectIntoClause (K_LIMIT limit=expression)?
    ) SEMI
;

// stmts are optional in PL/pgSQL, undocumented in 16.3
forLoopStatement:
    K_FOR iterator K_LOOP stmts+=plsqlStatement* K_END K_LOOP name=sqlName? SEMI
;

iterator:
    firstIterand=iterandDecl (COMMA secondIterand=iterandDecl)? K_IN ctlSeq=iterationCtlSeq
;

iterandDecl:
    identifier=sqlName (K_MUTABLE | K_IMMUTABLE)? constrainedType?
;

constrainedType:
    dataType (K_NOT? K_NULL)?
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

predClauseSeq:
    (K_WHILE whileExpr=expression)? (K_WHEN whenExpr=expression)?
;

// no space allowed between periods, however we allow it to avoid conflict with substitugion variable ending on period
steppedControl:
    lowerBound=postgresqlSqlExpression PERIOD PERIOD upperBound=postgresqlSqlExpression (K_BY step=postgresqlSqlExpression)?
;

singleExpressionControl:
    K_REPEAT? expr=expression
;

valuesOfControl:
    K_VALUES K_OF
    (
          expr=expression
        | LPAR (stmt=staticSql | dynStmt=dynamicSql) RPAR
    )
;

// artifical clause, not all unterminated SQL statements are valid here
staticSql:
    (
          select
        | insert
        | update
        | delete
        | merge
    )
;

dynamicSql:
    K_EXECUTE K_IMMEDIATE dynamicSqlStmt=expression usingClause?
;

indicesOfControl:
    K_INDICES K_OF
    (
          expr=expression
        | LPAR (stmt=staticSql | dynStmt=dynamicSql) RPAR
    )

;

pairsOfControl:
    K_PAIRS K_OF
    (
          expr=expression
        | LPAR (stmt=staticSql | dynStmt=dynamicSql) RPAR
    )
;

cursorIterationControl:
    LPAR (expr=expression | stmt=staticSql | dynStmt=dynamicSql) RPAR
;

forallStatement:
    K_FORALL index=expression K_IN boundsClause (K_SAVE K_EXCEPTIONS)? stmt=forallDmlStatement SEMI
;

// no space allowed between periods, however we allow it to avoid conflict with substitugion variable ending on period
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

// elseStmts are optional in PL/pgSQL, undocumented in 16.3
// elseif can be used insted of elsif in PL/pgSQL, undocumented in 16.3
ifStatement:
    K_IF conditionToStmts+=conditionToStatements
    ((K_ELSIF | K_ELSEIF) conditionToStmts+=conditionToStatements)*
    (K_ELSE elseStmts=plsqlStatement*)?
    K_END K_IF SEMI
;

// artificial clause
// stmts are optional in PL/pgSQL, undocumented in 16.3
conditionToStatements:
    cond=postgresqlSqlExpression K_THEN stmts+=plsqlStatement*
;

nullStatement:
    K_NULL SEMI
;

// undocumented in 23.3: parenthesis are allowed without parameters
openStatement:
    K_OPEN cursor=qualifiedName (LPAR (params+=functionParameter (COMMA params+=functionParameter)*)? RPAR)? SEMI
;

openForStatement:
    K_OPEN COLON? cursor=qualifiedName
        (K_NO? K_SCROLL)?   // PostgreSQL
        K_FOR
        K_EXECUTE?          // PostgreSQL
        (selectStmt=select | expr=expression) usingClause? SEMI
;

pipeRowStatement:
    K_PIPE K_ROW LPAR row=expression RPAR SEMI
;

// wrong documentation of in 23.3: declere_section is not mandatory
// PL/pgSQL allows multiple declare sections, undocumented in 16.3
plsqlBlock:
    (K_DECLARE declareSection?)* body
;

// others is handled as normal exception name
// stmts are optional in PL/pgSQL, undocumented in 16.3
exceptionHandler:
    K_WHEN exceptions+=exceptionItem (K_OR exceptions+=exceptionItem)* K_THEN stmts+=plsqlStatement*
;

exceptionItem:
      qualifiedName
    | K_SQLSTATE code=expression    // PostgreSQL
;

// "end" is not allowed as procedure call to avoid conflicts with end keyword of a PL/SQL block.
// ANTLR can handle this conflict, however the parsing times increase with the number of nested blocks.
// "end" is allowed as column name, column alias, table name, table alias etc.
// A semantic predicate can improve the parse time. However, a grammar that does not allow
// a procedure call with "end" as first segment leads to the best results.
procedureCall:
    (LPAR castExpr=expression K_AS typeName=qualifiedName RPAR PERIOD)?
    (
          specialFunctionExpression
        | qualifiedProcedureName // based on functionExpression
            (COMMAT dblink=qualifiedName)?
            (LPAR ((params+=functionParameter (COMMA params+=functionParameter)*)? | functionParameterSuffix?) RPAR)?
    )
    (PERIOD expr=expression)? // methods applied on previous function call returning an object type/collection type
    SEMI
;

// as qualifiedName but must not start with a reservedKeywordAsId
qualifiedProcedureName:
    procSqlName (PERIOD sqlName)*
;

raiseStatement:
    K_RAISE exceptionName=qualifiedName? SEMI
;

returnStatement:
    K_RETURN
    (
          K_QUERY K_EXECUTE command=expression usingClause?  // PostgreSQL
        | K_QUERY subquery                                   // PostgreSQL
        | K_NEXT expr=postgresqlSqlExpression                // PostgreSQL
        | expr=postgresqlSqlExpression
    )?
    SEMI
;

selectionDirective:
    DOLLAR_IF conditionToStmts+=selectionDirectiveConditionToStatements
    (DOLLAR_ELSIF conditionToStmts+=selectionDirectiveConditionToStatements)*
    (DOLLAR_ELSE elseTexts=selectionDirectiveText*)?
    DOLLAR_END
;

postgresqlCursorDefinition:
    name=sqlName (K_NO? K_SCROLL)? K_CURSOR
        (LPAR arguments+=postgresqlCursorArgument (COMMA arguments+=postgresqlCursorArgument)* RPAR)?
        (K_FOR|K_IS) // using "is" instead of "for" is not documented in 16.3
        query=subquery SEMI
;

postgresqlCursorArgument:
    name=sqlName plsqlDataType
;

// unterminated pragma (not ending on semicolon)
pragma:
      autonomousTransPragma
    | coveragePragma
    | deprecatePragma
    | exceptionInitPragma
    | inlinePragma
    | restrictReferencesPragma
    | seriallyReusablePragma
    | supressesWarning6009Pragma
    | udfPragma
    | namedPragma
;

autonomousTransPragma:
    K_PRAGMA K_AUTONOMOUS_TRANSACTION
;

coveragePragma:
    K_PRAGMA K_COVERAGE LPAR argument=string RPAR
;

deprecatePragma:
    K_PRAGMA K_DEPRECATE LPAR plsIdentifier=sqlName (COMMA warning=string)? RPAR
;

exceptionInitPragma:
    K_PRAGMA K_EXCEPTION_INIT LPAR exceptionName=sqlName COMMA errorNumber=expression RPAR
;

inlinePragma:
    K_PRAGMA K_INLINE LPAR subprogram=sqlName COMMA value=string RPAR
;

// simplified: subprogram, method and DEFAULT handled as sqlName
// wrong documentation in 23.4: optionality of comma between pragma states
restrictReferencesPragma:
    K_PRAGMA K_RESTRICT_REFERENCES LPAR name=sqlName
    COMMA states+=pragmaState (COMMA states+=pragmaState)* RPAR
;

pragmaState:
      K_RNDS    # readsNoDatabaseState
    | K_WNDS    # writesNoDatabaseState
    | K_RNPS    # readsNoPackageState
    | K_WNPS    # writesNoPackageState
    | K_TRUST   # trustedState
;

seriallyReusablePragma:
    K_PRAGMA K_SERIALLY_REUSABLE
;

supressesWarning6009Pragma:
    K_PRAGMA K_SUPPRESSES_WARNING_6009 LPAR plsIdentifier=sqlName RPAR
;

udfPragma:
    K_PRAGMA K_UDF
;

// undocumented pragmes such as unsupported, interface, supplemental_log_data, builtin, fipsflag, new_names, timestamp
// better support them in a generic way than to cause a parse error
namedPragma:
	K_PRAGMA name=sqlName (LPAR params+=expression (COMMA params+=expression) RPAR)?
;

postgresqlAssertStatement:
    K_ASSERT cond=postgresqlSqlExpression (COMMA message=postgresqlSqlExpression)? SEMI
;

postgresqlExecuteStatement:
    K_EXECUTE dynamicSqlStmt=postgresqlSqlExpression
        (
              intoClause usingClause?
            | usingClause intoClause? // undocumented in 16.3
        )?
        SEMI
;

postgresqlFetchStatement:
    K_FETCH (direction=fetchDirection (K_FROM | K_IN))? cursor=qualifiedName
        K_INTO targets+=qualifiedName (COMMA targets+=qualifiedName)* SEMI
;

fetchDirection:
      K_NEXT
    | K_PRIOR
    | K_FIRST
    | K_LAST
    | K_ABSOLUTE count=postgresqlSqlExpression
    | K_RELATIVE count=postgresqlSqlExpression
    | K_FORWARD count=postgresqlSqlExpression?      // undocumented count for move in 16.3
    | K_BACKWARD count=postgresqlSqlExpression?     // undocumented count for move in 16.3
;

postgresqlForEachStatement:
    K_FOREACH targets+=sqlName (COMMA targets+=sqlName)* (K_SLICE slice=expression)?
        K_IN K_ARRAY expr=postgresqlSqlExpression
        K_LOOP statements+=plsqlStatement+ K_END K_LOOP name=sqlName? SEMI
;

postgresqlGetDiagnosticsStatement:
    K_GET K_CURRENT? K_DIAGNOSTICS assignments+=postgresqlGetDiagnosticsAssignment
        (COMMA assignments+=postgresqlGetDiagnosticsAssignment)* SEMI
;

postgresqlGetDiagnosticsAssignment:
    variable=qualifiedName (COLON_EQUALS | EQUALS) diagnosticItem=postgresqlDiagnosticItem
;

postgresqlDiagnosticItem:
      K_ROW_COUNT
    | K_PG_CONTEXT
    | K_PG_ROUTINE_OID
;

postgresqlGetStackedDiagnosticsStatement:
   K_GET K_STACKED K_DIAGNOSTICS assignments+=postgresqlGetStackedDiagnosticsAssignment
        (COMMA assignments+=postgresqlGetStackedDiagnosticsAssignment)* SEMI
;

postgresqlGetStackedDiagnosticsAssignment:
    variable=qualifiedName (COLON_EQUALS | EQUALS) diagnosticItem=postgresqlStackedDiagnosticItem
;

postgresqlStackedDiagnosticItem:
      K_RETURNED_SQLSTATE
    | K_COLUMN_NAME
    | K_CONSTRAINT_NAME
    | K_PG_DATATYPE_NAME
    | K_MESSAGE_TEXT
    | K_TABLE_NAME
    | K_SCHEMA_NAME
    | K_PG_EXCEPTION_DETAIL
    | K_PG_EXCEPTION_HINT
    | K_PG_EXCEPTION_CONTEXT
;

postgresqlMoveStatement:
    K_MOVE (direction=fetchDirection (K_FROM | K_IN))? cursor=qualifiedName SEMI
;

postgresqlPerformStatement:
    K_PERFORM
    queryBlockSetOperator?
    selectList?
    fromClause?
    whereClause?
    groupByClause?
    windowClause?
    orderByClause?
    rowLimitingClause?
    SEMI
;

postgresqlRaiseStatement:
      K_RAISE raiseLevel?
      (
          format=string (COMMA formatExprs+=postgresqlSqlExpression)* (K_USING options+=raiseOption (COMMA options+=raiseOption)*)?
        | conditionName=qualifiedName (K_USING options+=raiseOption (COMMA options+=raiseOption)*)?
        | K_SQLSTATE sqlState=string (K_USING options+=raiseOption (COMMA options+=raiseOption)*)?
        | K_USING options+=raiseOption (COMMA options+=raiseOption)*
      )? SEMI
;

raiseLevel:
      K_DEBUG
    | K_LOG
    | K_INFO
    | K_NOTICE
    | K_WARNING
    | K_EXCEPTION
;

// := is not documented in 16.3
raiseOption:
    option=raiseOptionType (COLON_EQUALS | EQUALS) value=postgresqlSqlExpression
;

raiseOptionType:
      K_MESSAGE
    | K_DETAIL
    | K_HINT
    | K_ERRCODE
    | K_COLUMN
    | K_CONSTRAINT
    | K_DATATYPE
    | K_TABLE
    | K_SCHEMA
;

// artificial clause
selectionDirectiveConditionToStatements:
    cond=expression DOLLAR_THEN texts+=selectionDirectiveText*
;

selectionDirectiveText:
      errorDirective
    | .+?
;

errorDirective:
    DOLLAR_ERROR expr=expression DOLLAR_END
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
        | postgresqlSqlStatement
    ) SEMI
;

// SQL statements that are allowed in an PL/pgSQL block
// not allowed in PL/pgSQL or not handled in this rule: ABORT, BEGIN, DECLARE, END, EXECUTE, EXPLAIN, FETCH,
// LISTEN, LOAD, MOVE, NOTIFY, PREPARE TRANSACTION, RELEASE SAVEPOINT, SHOW, START TRANSACTION, UNLISTEN, VACUUM, VALUES
postgresqlSqlStatement:
      createTable
    | call
    | lockTable
    | postgresqlDo
    | createFunctionStatement
    | createProcedureStatement
    | unterminatedAtomicStatement
;

// stmts are optional in PL/pgSQL, undocumented in 16.3
whileLoopStatement:
    K_WHILE cond=expression K_LOOP stmts+=plsqlStatement* K_END K_LOOP name=sqlName? SEMI
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

// undocumented in 23.4: write options can have any order, force options, force with comment
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
            | K_IMMEDIATE (K_WAIT | K_NOWAIT)?
            | K_BATCH (K_WAIT | K_NOWAIT)?
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
    ) (K_IMMEDIATE | K_DEFERRED)
;

constraint:
    name=qualifiedName (COMMAT dblink=qualifiedName)?
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
          modes+=transactionMode (COMMA modes+=transactionMode)* (K_NAME name=expression)? // OracleDB: name
        | K_SNAPSHOT snapshotId=expression // PostgreSQL: accepted also for "set session characteristics as"
        | K_USE K_ROLLBACK K_SEGMENT rollbackSegment=sqlName (K_NAME name=expression)? // OracleDB
        | K_NAME name=expression // OracleDB
    )
;

/*----------------------------------------------------------------------------*/
// PostgreSQL Declare
/*----------------------------------------------------------------------------*/

// cannot be used in PL/pgSQL
postgresqlDeclareStatement:
    postgresqlDeclare sqlEnd
;

postgresqlDeclare:
    K_DECLARE cursorName=sqlName K_BINARY? (K_ASENSITIVE | K_INSENSITIVE)? (K_NO? K_SCROLL)?
    K_CURSOR ((K_WITH | K_WITHOUT) K_HOLD)? K_FOR subquery
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
      oracleBuiltInDatatype dataTypeArray?
    | ansiSupportedDatatype dataTypeArray?
    | postgresqlDatatype dataTypeArray?
    | userDefinedType dataTypeArray?  // ambiguous
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
    | vectorDatatype
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
    K_JSON (LPAR jsonColumnModifier RPAR)?
;

jsonColumnModifier:
      K_VALUE
    | K_ARRAY
    | K_OBJECT
    | K_SCALAR jsonScalarModifier?
;

jsonScalarModifier:
      K_NUMBER
    | K_STRING
    | K_BINARY_DOUBLE
    | K_BINARY_FLOAT
    | K_DATE
    | K_TIMESTAMP (K_WITH K_TIME K_ZONE)?
    | K_NULL
    | K_BOOLEAN
    | K_BINARY
    | K_INTERVAL K_YEAR K_TO K_MONTH
    | K_INTERVAL K_DAY K_TO K_SECOND
;

booleanDatatype:
    K_BOOLEAN
;

vectorDatatype:
    K_VECTOR (LPAR numberOfDimensions=expression (COMMA dimensionElementFormat=expression)? RPAR)?
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

// PostgreSQL
dataTypeArray:
      K_ARRAY
    | K_ARRAY dims+=dataTypeArrayDim+
    | dims+=dataTypeArrayDim+
;

// PostgreSQL
dataTypeArrayDim:
    LSQB size=NUMBER? RSQB
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
    | LPAR (exprs+=expression (COMMA exprs+=expression)*)? RPAR # expressionList                // also parenthesisCondition, empty list is undocumented
    | LPAR expr=expression K_AS
        (schema=sqlName PERIOD)? typeName=sqlName RPAR          # typeCastExpression            // undocumented in 23.3, see example 14-22
    | K_CURSOR LPAR expr=subquery RPAR                          # cursorExpression
    | expr=caseExpression                                       # caseExpressionParent
    | expr=selectionDirective                                   # selectionDirectiveExpression
    | expr=jsonObjectAccessExpression                           # jsonObjectAccessExpressionParent
    | operator=unaryOperator expr=expression                    # unaryExpression               // precedence 0, must be evaluated before functions
    | expr=specialFunctionExpression                            # specialFunctionExpressionParent
    | expr=functionExpression                                   # functionExpressionParent
    | expr=expression LPAR dims+=expression RPAR
        (LPAR dims+=expression RPAR)*                           # plsqlMultiDimensionalExpression
    | expr=plsqlQualifiedExpression                             # plsqlQualifiedExpressionParent
    | expr=placeholderExpression                                # placeholderExpressionParent
    | expr=AST                                                  # allColumnWildcardExpression
    | type=dataType expr=string                                 # postgresqlStringCast
    | left=expression operator=PERIOD right=expression          # qualifiedExpression           // precedence 1
    | expr=expression operator=COLON_COLON type=dataType        # postgresqlHistoricalCast      // precedence 2
    | expr=expression
        LSQB (cellAssignmentList|multiColumnForLoop) RSQB       # modelExpression               // precedence 3, also PostgreSQL array element selection
    | expr=expression postgresqlSubscript                       # postgresqlSubscriptParent     // precedence 3, PostgreSQL subscripts are handeld as model_expression
    | expr=postgresqlArrayConstructor                           # postgresqlArrayConstructorParent // precedence 3
    | left=expression operator=K_COLLATE right=sqlName          # collateExpression             // precedence 5
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
    | left=expression
        (
              operator=HAT      // PostgreSQL
            | operator=AST_AST  // OracleDB (PL/SQL only)
        )
        right=expression                                        # exponentiationExpression      // precedence 7, PostgreSQL
    | left=expression operator=AST right=expression             # multiplicationExpression      // precedence 8
    | left=expression operator=SOL right=expression             # divisionExpression            // precedence 8
    | left=expression operator=PERCNT right=expression          # moduloExpression              // precedence 8, PostgreSQL
    | left=expression operator=K_MOD right=expression           # moduloExpression              // precedence 8, PL/SQL
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
    // starting with 23.2 a condition is treated as a synonym to an expression
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
        operator=K_IS K_NOT? K_JSON
        jsonModifierList? formatClause?
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
        operator=(K_LIKE|K_LIKEC|K_LIKE2|K_LIKE4|K_ILIKE)                                   // PostgreSQL: ilike (case-insensitive)
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
    | left=expression
        K_IS K_NOT? K_SOURCE K_OF right=expression              # sourcePredicate
    | left=expression
        K_IS K_NOT? K_DESTINATION K_OF right=expression         # destinationPredicate
    | left=expression K_OVERLAPS right=expression               # overlapsExpression
;

postgresqlSubscript:
      LSQB lower=expression COLON upper=expression RSQB
    | LSQB lower=expression COLON RSQB
    | LSQB COLON lower=expression RSQB
    | LSQB COLON RSQB // undocumented in PostgreSQL 16.3
;

// PostgreSQL: single column, 0-1 result rows
// not part of expression to avoid left-recursive use of this rule
// used in PL/SQL elements instead of expression for PL/pgSQL compatiblity
postgresqlSqlExpression:
    expr=expression (K_AS? cAlias=sqlName)?
    fromClause?
    whereClause?
    groupByClause?
    windowClause?
    orderByClause?
    rowLimitingClause?
    forUpdateClause*
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
    K_WHEN cond=expression K_THEN expr=expression
;

elseClause:
    K_ELSE expr=expression
;

// Functions and function-like conditions that have a syntax that
// cannot be handled by the generic functionExpression.
specialFunctionExpression:
      avExpression
    | cast
    | collation // PostgreSQL
    | extract
    | featureCompare
    | fromVector
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
    | vectorChunks
    | vectorSerialize
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
      K_LEVEL levelRef=sqlName?                             # levelAvLevelRef
    | K_PARENT                                              # parentAvLevelRef
    | K_ACROSS? K_ANCESTOR K_AT K_LEVEL levelRef=sqlName
       (K_POSITION K_FROM (K_BEGINNING|K_END)?)?            # ancestorAvLevelRef
    | K_MEMBER expr=memberExpression                        # memberAvLevelRef
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
      levelMemberLiteral            # levelMemberMemberExpr
    | hierNavigationExpression      # hierNavigationMemberExpr
    | K_CURRENT K_MEMBER            # currentMemberMemberExpr
    | K_NULL                        # nullMemberExpr
    | K_ALL                         # allMemberExpr
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
      hierAncestorExpression    # ancestorHierNavigationExpr
    | hierParentExpression      # parentHierNavigationExpr
    | hierLeadLagExpression     # leadLagHierNavigationExpr
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
        (K_COLLATE collate=sqlName)?
        domainValidateClause?
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

// PostgreSQL
collation:
    K_COLLATION K_FOR LPAR expr=postgresqlSqlExpression RPAR
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

fromVector:
    K_FROM_VECTOR LPAR expr=expression (K_RETURNING dataType)? RPAR
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
    (K_WHERE cond=expression)?
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
    LPAR expr=pathTerm (K_WHERE cond=expression)? RPAR
;

vertexPattern:
    LPAR elementPatternFiller RPAR
;

// simplified, includes: element_variable_declaration, element_variable, isLabelExpression/isLabelDeclaration,
// element_pattern_where_clause, is_label_declaration
elementPatternFiller:
    var=sqlName? (K_IS labelName=labelExpression)? (K_WHERE cond=expression)?
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
      MINUS GT      # pointingRightAbbreviatedEdgePattern
    | MINUS_GT      # pointingRightAbbreviatedEdgePattern
    | LT MINUS      # pointingLeftAbbreviatedEdgePattern
    | MINUS         # anyDirectionAbbreviatedEdgePattern
    | LT MINUS GT   # anyDirectionAbbreviatedEdgePattern
    | LT_MINUS_GT   # anyDirectionAbbreviatedEdgePattern
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

jsonModifierList:
      LPAR modifiers+=jsonColumnModifier (COMMA modifiers+=jsonColumnModifier)* RPAR
    | modifiers+=jsonColumnModifier
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
    | keyValueClause // only in create_json_relational_duality_view
;

// undocumented in 23.4: "is" instead of ":", "key" in combination with "is"/":"
regularEntry:
      K_KEY? key=expression K_VALUE value=expression
    | K_KEY? key=expression (COLON|K_IS) value=expression
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

// undocumented in 23.4: parenthesis around condition are documented, but not necessary
jsonColumnsClause:
    K_COLUMNS
    (
          LPAR columns+=jsonColumnDefinition (COMMA columns+=jsonColumnDefinition)* RPAR
        | columns+=jsonColumnDefinition (COMMA columns+=jsonColumnDefinition)*
    )
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
    K_WHEN cond=expression K_THEN LPAR (operations+=operation (COMMA operations+=operation)*)? RPAR
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
      K_ERROR K_ON K_ERROR  # errorOnErrorJsonEqualCondition
    | K_FALSE K_ON K_ERROR  # falseOnErrorJsonEqualCondition
    | K_TRUE K_ON K_ERROR   # trueOnErrorJsonEqualCondition
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

vectorChunks:
    K_VECTOR_CHUNKS LPAR chunkTableArguments RPAR
;

// all components of chunking_spec are optional, therfore it is here mandatory
chunkTableArguments:
    textDocument=expression chunkingSpec
;

chunkingSpec:
    (K_BY chunkingMode)? (K_MAX max=expression)? (K_OVERLAP overlap=expression)?
    (K_SPLIT K_BY? splitCharactersList)? (K_LANGUAGE languageName=expression)?
    (K_NORMALIZE normalizationSpec)? K_EXTENDED?
;

chunkingMode:
      K_WORDS                                       # wordsChunkingMode
    | K_CHARS                                       # charsChunkingMode
    | K_CHARACTERS                                  # charsChunkingMode
    | K_VOCABULARY vocabularyName=qualifiedName     # vocabularyChunkingMode
;

splitCharactersList:
      K_NONE                                        # noneSplitCharacterList
    | K_BLANKLINE                                   # blanklineSplitCharacterList
    | K_NEWLINE                                     # newlineSplitCharacterList
    | K_SPACE                                       # spaceSplitCharacterList
    | K_RECURSIVELY                                 # recursivelySplitCharacterList
    | K_SENTENCE                                    # sentenceSplitCharacterList
    | K_CUSTOM customSplitCharactersList            # customSplitCharacterList
;

customSplitCharactersList:
    LPAR chars+=expression (COMMA chars+=expression)* RPAR
;

normalizationSpec:
      K_NONE                                        # noneNormalizationSpec
    | K_ALL                                         # allNormalizationSpec
    | customNormalizationSpec                       # custNormalizationSpec
;

customNormalizationSpec:
    LPAR modes+=normalizationMode (COMMA modes+=normalizationMode)* RPAR
;

normalizationMode:
      K_WHITESPACE                                  # whitespaceNormalizationMode
    | K_PUNCTUATION                                 # punctuationNormalizationMode
    | K_WIDECHAR                                    # widecharNormalizationMode
;

vectorSerialize:
    K_VECTOR_SERIALIZE LPAR expr=expression (K_RETURNING dataType)? RPAR
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
      K_YES         # yesXmlrootStandalone
    | K_NO          # noXmlrootStandalone
    | K_NO K_VALUE  # noValueXmlrootStandalone
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
    name=sqlName (COMMAT dblink=qualifiedName)? LPAR ((params+=functionParameter (COMMA params+=functionParameter)*)? | functionParameterSuffix?) RPAR
    withinClause?               // e.g. approx_percentile
    postgresqlFilterClause?     // e.g. count, sum
    keepClause?                 // e.g. first, last
    respectIgnoreNullsClause?   // e.g. lag
    overClause?                 // e.g. avg
;

functionParameter:
    // PostgreSQL := is older syntax supported for backward compatiblity only
    // OracleDB: no space between '=>' allowed
    (name=sqlName (EQUALS_GT | COLON_EQUALS))? functionParameterPrefix? expr=postgresqlSqlExpression functionParameterSuffix?
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
    K_FOR iterator K_SEQUENCE EQUALS_GT expr=expression
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
    K_FOR iterator EQUALS_GT expr=expression
;

indexIteratorChoice:
    K_FOR iterator K_INDEX indexExpr=expression EQUALS_GT valueExpr=expression
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

postgresqlFilterClause:
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
            | excludeGroup=K_GROUP // wrong documentation in OracleDB 23.3 (groups instead of group)
            | excludeTies=K_TIES
            | excludeNoOthers=K_NO K_OTHERS
        )
    )?
;

unaryOperator:
      PLUS                  # positiveSignOperator
    | MINUS                 # negativeSignOperator
    | K_PRIOR               # priorOpertor              // hierarchical query operator
    | K_CONNECT_BY_ROOT     # connectByRootOperator     // hierarchical query operator
    | K_RUNNING             # runningOperator           // row_pattern_nav_logical
    | K_FINAL               # finalOperator             // row_pattern_nav_logical
    | K_NEW                 # newOperator               // type constructor
    | K_CURRENT K_OF        # currentOfOperator         // operator as update extension in PL/SQL where clause
    | POSTGRESQL_OPERATOR   # postgresqlUnaryOperator
    | COMMAT                # postgresqlUnaryOperator
    | NUM                   # postgresqlUnaryOperator
    | TILDE                 # postgresqlUnaryOperator
    | K_VARIADIC            # postgresqlUnaryOperator

;

// binary operators not handled in expression, only single token operators
// operator meaning is based on context, label can be misleading
// custom PostGIS operators according see https://postgis.net/docs/manual-3.4/reference.html#Operators
binaryOperator:
      POSTGRESQL_OPERATOR                       # postgresqlBinaryOperator
    | AMP                                       # postgresqlBinaryOperator
    | AMP_AMP                                   # postgresqlBinaryOperator
    | COMMAT                                    # postgresqlBinaryOperator
    | EXCL_TILDE                                # postgresqlBinaryOperator
    | GT_GT                                     # postgresqlBinaryOperator
    | LT_LT                                     # postgresqlBinaryOperator
    | LT_MINUS_GT                               # postgresqlBinaryOperator
    | MINUS_GT                                  # postgresqlBinaryOperator
    | NUM                                       # postgresqlBinaryOperator
    | QUEST                                     # postgresqlBinaryOperator
    | TILDE                                     # postgresqlBinaryOperator
    | VERBAR                                    # postgresqlBinaryOperator
    | K_OPERATOR LPAR postgresqlOperator RPAR   # functionOperator
;

postgresqlOperator:
    schema=sqlName PERIOD postgresqlOperatorName
;

postgresqlOperatorName:
    ~RPAR+
;

postgresqlArrayConstructor:
      K_ARRAY LSQB (exprs+=postgresqlArrayElement (COMMA exprs+=postgresqlArrayElement)*)? RSQB
    | K_ARRAY LPAR expr=subquery RPAR
;

postgresqlArrayElement:
      expr=expression                                                                # itemPostgresqlArrayElement
    | LSQB exprs+=postgresqlArrayElement (COMMA exprs+=postgresqlArrayElement)* RSQB # listPostgresqlArrayElement
;

/*----------------------------------------------------------------------------*/
// Condition
/*----------------------------------------------------------------------------*/

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
    | operator=K_IS K_NOT? K_JSON
        jsonModifierList? formatClause?
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
    | K_IS K_NOT? K_SOURCE K_OF right=expression        # sourcePredicateDangling
    | K_IS K_NOT? K_DESTINATION K_OF right=expression   # destinationPredicateDangling
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
    | EXCL_EQUALS       # ne
    | EXCL EQUALS       # ne
    | LT_GT             # ne
    | LT GT             # ne
    | TILDE_EQUALS      # ne
    | TILDE EQUALS      # ne
    | HAT_EQUALS        # ne
    | HAT EQUALS        # ne
    | GT                # gt
    | LT                # lt
    | GT_EQUALS         # ge
    | GT EQUALS         # ge
    | LT_EQUALS         # le
    | LT EQUALS         # le
;

// it's possible but not documented that options can be used in an arbitrary order
// it's also possible but not documented to place the options in parenthesis
jsonConditionOption:
      K_STRICT                                      # strictJsonConditionOption
    | K_LAX                                         # laxJsonConditionOption
    | K_ALLOW K_SCALARS                             # allowScalarsJsonConditionOption
    | K_DISALLOW K_SCALARS                          # disallowSclarsJsonConditionOption
    | K_WITH K_UNIQUE K_KEYS                        # withUniqueKeysJsonConditionOption
    | K_WITHOUT K_UNIQUE K_KEYS                     # withoutUniqueKeysJsonConditionOption
    | K_VALIDATE K_CAST? K_USING? schema=expression # validateJsonConditionOption
;

isOfTypeConditionItem:
    K_ONLY? (schema=sqlName PERIOD)? type=sqlName
;

/*----------------------------------------------------------------------------*/
// Identifiers
/*----------------------------------------------------------------------------*/

keywordAsId:
      K_A
    | K_ABORT
    | K_ABS
    | K_ABSENT
    | K_ABSOLUTE
    | K_ACCESS
    | K_ACCESSIBLE
    | K_ACCURACY
    | K_ACROSS
    | K_ACTION
    | K_ADD
    | K_AFTER
    | K_AGENT
    | K_AGGREGATE
    | K_ALIAS
    | K_ALL
    | K_ALLOW
    | K_ALTER
    | K_ALWAYS
    | K_ANALYTIC
    | K_ANALYZE
    | K_ANCESTOR
    | K_AND
    | K_ANNOTATIONS
    | K_ANY
    | K_ANYSCHEMA
    | K_APPEND
    | K_APPLY
    | K_APPROX
    | K_APPROXIMATE
    | K_ARRAY
    | K_AS
    | K_ASC
    | K_ASCII
    | K_ASENSITIVE
    | K_ASSERT
    | K_ASSOCIATE
    | K_AT
    | K_ATOMIC
    | K_AUDIT
    | K_AUTHID
    | K_AUTO
    | K_AUTOMATIC
    | K_AUTONOMOUS_TRANSACTION
    | K_AVERAGE_RANK
    | K_BACKWARD
    | K_BADFILE
    | K_BATCH
    | K_BEFORE
    | K_BEGIN
    | K_BEGINNING
    | K_BEQUEATH
    | K_BETWEEN
    | K_BFILE
    | K_BIGINT
    | K_BIGRAM
    | K_BIGSERIAL
    | K_BINARY
    | K_BINARY_DOUBLE
    | K_BINARY_FLOAT
    | K_BIT
    | K_BLANKLINE
    | K_BLOB
    | K_BLOCK
    | K_BLOCKCHAIN
    | K_BODY
    | K_BOOL
    | K_BOOLEAN
    | K_BOTH
    | K_BOX
    | K_BREADTH
    | K_BUFFERS
    | K_BUILD
    | K_BULK
    | K_BY
    | K_BYTE
    | K_BYTEA
    | K_C
    | K_CACHE
    | K_CALL
    | K_CALLED
    | K_CASCADE
    | K_CASCADED
    | K_CASE
    | K_CASE_SENSITIVE
    | K_CAST
    | K_CHAIN
    | K_CHAR
    | K_CHARACTER
    | K_CHARACTERISTICS
    | K_CHARACTERS
    | K_CHARS
    | K_CHARSETFORM
    | K_CHARSETID
    | K_CHAR_CS
    | K_CHECK
    | K_CHECKPOINT
    | K_CIDR
    | K_CIRCLE
    | K_CLOB
    | K_CLONE
    | K_CLOSE
    | K_CLUSTER
    | K_COLLATE
    | K_COLLATION
    | K_COLLECT
    | K_COLUMN
    | K_COLUMNS
    | K_COLUMN_NAME
    | K_COMMENT
    | K_COMMENTS
    | K_COMMIT
    | K_COMMITTED
    | K_COMPLETE
    | K_COMPOUND
    | K_COMPRESSION
    | K_COMPUTATION
    | K_CONCURRENT
    | K_CONDITIONAL
    | K_CONFLICT
    | K_CONNECT
    | K_CONNECT_BY_ROOT
    | K_CONSTANT
    | K_CONSTRAINT
    | K_CONSTRAINTS
    | K_CONSTRAINT_NAME
    | K_CONSTRUCTOR
    | K_CONTAINER
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
    | K_COVERAGE
    | K_CREATE
    | K_CREATION
    | K_CROSS
    | K_CROSSEDITION
    | K_CURRENT
    | K_CURRENT_USER
    | K_CURSOR
    | K_CUSTOM
    | K_CYCLE
    | K_DAMERAU_LEVENSHTEIN
    | K_DANGLING
    | K_DATA
    | K_DATABASE
    | K_DATATYPE
    | K_DATE
    | K_DAY
    | K_DBTIMEZONE
    | K_DB_ROLE_CHANGE
    | K_DDL
    | K_DEALLOCATE
    | K_DEBUG
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
    | K_DEMAND
    | K_DENSE_RANK
    | K_DEPRECATE
    | K_DEPTH
    | K_DESC
    | K_DESTINATION
    | K_DETAIL
    | K_DETERMINISTIC
    | K_DIAGNOSTICS
    | K_DIMENSION
    | K_DIRECTORY
    | K_DISABLE
    | K_DISALLOW
    | K_DISASSOCIATE
    | K_DISCARD
    | K_DISTINCT
    | K_DO
    | K_DOCUMENT
    | K_DOMAIN
    | K_DOUBLE
    | K_DROP
    | K_DUALITY
    | K_DUPLICATED
    | K_DURATION
    | K_EACH
    | K_EDITION
    | K_EDITIONABLE
    | K_EDITIONING
    | K_EDIT_TOLERANCE
    | K_EFSEARCH
    | K_ELEMENT
    | K_ELSE
    | K_ELSEIF
    | K_ELSIF
    | K_EMPTY
    | K_ENABLE
    | K_ENCODING
    | K_ENCRYPT
    | K_ENFORCED
    | K_ENTITYESCAPING
    | K_ENUM
    | K_ENV
    | K_ERRCODE
    | K_ERROR
    | K_ERRORS
    | K_ESCAPE
    | K_ETAG
    | K_EVALNAME
    | K_EVALUATE
    | K_EXACT
    | K_EXCEPT
    | K_EXCEPTION
    | K_EXCEPTIONS
    | K_EXCEPTION_INIT
    | K_EXCHANGE
    | K_EXCLUDE
    | K_EXCLUDING
    | K_EXCLUSIVE
    | K_EXECUTE
    | K_EXISTING
    | K_EXISTS
    | K_EXIT
    | K_EXPLAIN
    | K_EXTENDED
    | K_EXTERNAL
    | K_EXTRA
    | K_EXTRACT
    | K_EXTSCHEMA
    | K_FACT
    | K_FALSE
    | K_FAST
    | K_FEATURE_COMPARE
    | K_FETCH
    | K_FILESYSTEM_LIKE_LOGGING
    | K_FILTER
    | K_FINAL
    | K_FIRST
    | K_FLEX
    | K_FLOAT4
    | K_FLOAT8
    | K_FLOAT
    | K_FOLLOWING
    | K_FOLLOWS
    | K_FOR
    | K_FORALL
    | K_FORCE
    | K_FOREACH
    | K_FOREIGN
    | K_FORMAT
    | K_FORWARD
    | K_FROM
    | K_FROM_VECTOR
    | K_FULL
    | K_FUNCTION
    | K_FUZZY_MATCH
    | K_GENERATED
    | K_GENERIC_PLAN
    | K_GET
    | K_GLOBAL
    | K_GOTO
    | K_GRANT
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
    | K_HINT
    | K_HOLD
    | K_HOUR
    | K_ID
    | K_IDENTIFIED
    | K_IDENTIFIER
    | K_IDENTITY
    | K_IF
    | K_IGNORE
    | K_ILIKE
    | K_IMMEDIATE
    | K_IMMUTABLE
    | K_IMPORT
    | K_IN
    | K_INCLUDE
    | K_INCLUDING
    | K_INCREMENT
    | K_INDENT
    | K_INDEX
    | K_INDEXES
    | K_INDICATOR
    | K_INDICES
    | K_INET
    | K_INFINITE
    | K_INFO
    | K_INHERIT
    | K_INITIALLY
    | K_INITRANS
    | K_INLINE
    | K_INNER
    | K_INOUT
    | K_INPUT
    | K_INSENSITIVE
    | K_INSERT
    | K_INSTANTIABLE
    | K_INSTEAD
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
    | K_LISTEN
    | K_LOAD
    | K_LOB
    | K_LOBS
    | K_LOCAL
    | K_LOCATION
    | K_LOCK
    | K_LOCKED
    | K_LOG
    | K_LOGFILE
    | K_LOGGING
    | K_LOGOFF
    | K_LOGON
    | K_LONG
    | K_LONGEST_COMMON_SUBSTRING
    | K_LOOP
    | K_LSEG
    | K_MACADDR8
    | K_MACADDR
    | K_MAIN
    | K_MAP
    | K_MAPPING
    | K_MASTER
    | K_MATCH
    | K_MATCHED
    | K_MATCHES
    | K_MATCH_RECOGNIZE
    | K_MATERIALIZED
    | K_MAX
    | K_MAXLEN
    | K_MAXVALUE
    | K_MEASURES
    | K_MEMBER
    | K_MEMOPTIMIZED
    | K_MERGE
    | K_MESSAGE
    | K_MESSAGE_TEXT
    | K_METADATA
    | K_MINUS
    | K_MINUTE
    | K_MINVALUE
    | K_MISMATCH
    | K_MISSING
    | K_MLE
    | K_MOD
    | K_MODE
    | K_MODEL
    | K_MODIFY
    | K_MODULE
    | K_MONEY
    | K_MONTH
    | K_MOVE
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
    | K_NEIGHBOR
    | K_NESTED
    | K_NEVER
    | K_NEW
    | K_NEWLINE
    | K_NEXT
    | K_NO
    | K_NOAUDIT
    | K_NOCACHE
    | K_NOCHECK
    | K_NOCOPY
    | K_NOCYCLE
    | K_NODELETE
    | K_NOENTITYESCAPING
    | K_NOINSERT
    | K_NOLOGGING
    | K_NOMAXVALUE
    | K_NOMINVALUE
    | K_NONE
    | K_NONEDITIONABLE
    | K_NONSCHEMA
    | K_NOORDER
    | K_NOPARALLEL
    | K_NOPRECHECK
    | K_NORELY
    | K_NORMALIZE
    | K_NORMALIZED
    | K_NOSCHEMACHECK
    | K_NOT
    | K_NOTHING
    | K_NOTICE
    | K_NOTIFY
    | K_NOTNULL
    | K_NOUPDATE
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
    | K_OID
    | K_OLD
    | K_OMIT
    | K_ON
    | K_ONE
    | K_ONLY
    | K_OPEN
    | K_OPERATOR
    | K_OPTION
    | K_OR
    | K_ORDER
    | K_ORDERED
    | K_ORDINALITY
    | K_ORGANIZATION
    | K_OTHERS
    | K_OUT
    | K_OUTER
    | K_OVER
    | K_OVERFLOW
    | K_OVERLAP
    | K_OVERLAPS
    | K_OVERLAY
    | K_OVERRIDING
    | K_PACKAGE
    | K_PAIRS
    | K_PARALLEL
    | K_PARALLEL_ENABLE
    | K_PARAMETERS
    | K_PARENT
    | K_PARTIAL
    | K_PARTITION
    | K_PARTITIONS
    | K_PARTITIONSET
    | K_PASSING
    | K_PAST
    | K_PATH
    | K_PATTERN
    | K_PCTFREE
    | K_PCTUSED
    | K_PER
    | K_PERCENT
    | K_PERFORM
    | K_PERIOD
    | K_PERMUTE
    | K_PERSISTABLE
    | K_PG_CONTEXT
    | K_PG_DATATYPE_NAME
    | K_PG_EXCEPTION_CONTEXT
    | K_PG_EXCEPTION_DETAIL
    | K_PG_EXCEPTION_HINT
    | K_PG_LSN
    | K_PG_ROUTINE_OID
    | K_PG_SNAPSHOT
    | K_PIPE
    | K_PIPELINED
    | K_PIVOT
    | K_PLACING
    | K_PLAIN
    | K_PLAN
    | K_PLUGGABLE
    | K_POINT
    | K_POLYGON
    | K_POLYMORPHIC
    | K_POSITION
    | K_PRAGMA
    | K_PREBUILT
    | K_PRECEDES
    | K_PRECEDING
    | K_PRECHECK
    | K_PRECISION
    | K_PREDICTION
    | K_PREDICTION_COST
    | K_PREDICTION_DETAILS
    | K_PREPARE
    | K_PREPARED
    | K_PREPEND
    | K_PRESENT
    | K_PRESERVE
    | K_PRETTY
    | K_PRIMARY
    | K_PRIOR
    | K_PRIVATE
    | K_PROBES
    | K_PROCEDURE
    | K_PUNCTUATION
    | K_QUALIFY
    | K_QUERY
    | K_RAISE
    | K_RANGE
    | K_RANK
    | K_RAW
    | K_READ
    | K_REAL
    | K_REASSIGN
    | K_RECORD
    | K_RECURSIVE
    | K_RECURSIVELY
    | K_REDUCED
    | K_REF
    | K_REFERENCE
    | K_REFERENCES
    | K_REFERENCING
    | K_REFRESH
    | K_REINDEX
    | K_REJECT
    | K_RELATE_TO_SHORTER
    | K_RELATIONAL
    | K_RELATIVE
    | K_RELIES_ON
    | K_RELY
    | K_REMOVE
    | K_RENAME
    | K_REPEAT
    | K_REPEATABLE
    | K_REPLACE
    | K_RESERVABLE
    | K_RESET
    | K_RESPECT
    | K_RESTRICT
    | K_RESTRICTED
    | K_RESTRICT_REFERENCES
    | K_RESULT
    | K_RESULT_CACHE
    | K_RETURN
    | K_RETURNED_SQLSTATE
    | K_RETURNING
    | K_RETURNS
    | K_REVERSE
    | K_REVOKE
    | K_REWRITE
    | K_RIGHT
    | K_RNDS
    | K_RNPS
    | K_ROLLBACK
    | K_ROW
    | K_ROWID
    | K_ROWS
    | K_ROWTYPE
    | K_ROW_COUNT
    | K_ROW_NUMBER
    | K_RULES
    | K_RUNNING
    | K_SAFE
    | K_SALT
    | K_SAMPLE
    | K_SAVE
    | K_SAVEPOINT
    | K_SCALAR
    | K_SCALARS
    | K_SCHEMA
    | K_SCHEMACHECK
    | K_SCHEMA_NAME
    | K_SCN
    | K_SCOPE
    | K_SCROLL
    | K_SDO_GEOMETRY
    | K_SEARCH
    | K_SECOND
    | K_SECURITY
    | K_SEED
    | K_SEGMENT
    | K_SELECT
    | K_SELF
    | K_SENTENCE
    | K_SEQUENCE
    | K_SEQUENTIAL
    | K_SERIAL2
    | K_SERIAL4
    | K_SERIAL8
    | K_SERIAL
    | K_SERIALIZABLE
    | K_SERIALLY_REUSABLE
    | K_SERVERERROR
    | K_SESSION
    | K_SESSIONTIMEZONE
    | K_SET
    | K_SETOF
    | K_SETS
    | K_SHARDED
    | K_SHARD_ENABLE
    | K_SHARE
    | K_SHARE_OF
    | K_SHARING
    | K_SHOW
    | K_SHUTDOWN
    | K_SIBLINGS
    | K_SIGNATURE
    | K_SIMILAR
    | K_SIMPLE
    | K_SINGLE
    | K_SIZE
    | K_SKIP
    | K_SLICE
    | K_SMALLINT
    | K_SMALLSERIAL
    | K_SNAPSHOT
    | K_SOME
    | K_SORT
    | K_SOURCE
    | K_SPACE
    | K_SPLIT
    | K_SQL
    | K_SQLSTATE
    | K_SQL_MACRO
    | K_STABLE
    | K_STACKED
    | K_STAGING
    | K_STANDALONE
    | K_START
    | K_STARTUP
    | K_STATEMENT
    | K_STATEMENT_ID
    | K_STATIC
    | K_STATISTICS
    | K_STORAGE
    | K_STORE
    | K_STORED
    | K_STRICT
    | K_STRING
    | K_STRUCT
    | K_SUBMULTISET
    | K_SUBPARTITION
    | K_SUBSET
    | K_SUBSTRING
    | K_SUBTYPE
    | K_SUMMARY
    | K_SUPPLEMENTAL
    | K_SUPPORT
    | K_SUPPRESSES_WARNING_6009
    | K_SUSPEND
    | K_SYMMETRIC
    | K_SYNCHRONOUS
    | K_SYSTEM
    | K_TABLE
    | K_TABLES
    | K_TABLESAMPLE
    | K_TABLESPACE
    | K_TABLE_NAME
    | K_TARGET
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
    | K_TRUST
    | K_TRUSTED
    | K_TSQUERY
    | K_TSVECTOR
    | K_TXID_SNAPSHOT
    | K_TYPE
    | K_TYPENAME
    | K_UDF
    | K_UESCAPE
    | K_UNBOUNDED
    | K_UNCOMMITTED
    | K_UNCONDITIONAL
    | K_UNDER
    | K_UNION
    | K_UNIQUE
    | K_UNKNOWN
    | K_UNLIMITED
    | K_UNLISTEN
    | K_UNLOGGED
    | K_UNMATCHED
    | K_UNNEST
    | K_UNPIVOT
    | K_UNPLUG
    | K_UNSAFE
    | K_UNSCALED
    | K_UNTIL
    | K_UNUSABLE
    | K_UPDATE
    | K_UPDATED
    | K_UPSERT
    | K_UROWID
    | K_USE
    | K_USER
    | K_USING
    | K_UUID
    | K_VACUUM
    | K_VALIDATE
    | K_VALIDATE_CONVERSION
    | K_VALUE
    | K_VALUES
    | K_VARBIT
    | K_VARCHAR2
    | K_VARCHAR
    | K_VARIADIC
    | K_VARRAY
    | K_VARRAYS
    | K_VARYING
    | K_VECTOR
    | K_VECTOR_CHUNKS
    | K_VECTOR_SERIALIZE
    | K_VERBOSE
    | K_VERSION
    | K_VERSIONS
    | K_VIEW
    | K_VIRTUAL
    | K_VISIBLE
    | K_VOCABULARY
    | K_VOLATILE
    | K_WAIT
    | K_WAL
    | K_WARNING
    | K_WELLFORMED
    | K_WHEN
    | K_WHERE
    | K_WHILE
    | K_WHITESPACE
    | K_WHOLE_WORD_MATCH
    | K_WIDECHAR
    | K_WINDOW
    | K_WITH
    | K_WITHIN
    | K_WITHOUT
    | K_WNDS
    | K_WNPS
    | K_WORDS
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
    | K_XMLSCHEMA
    | K_XMLSERIALIZE
    | K_XMLTABLE
    | K_XMLTYPE
    | K_YAML
    | K_YEAR
    | K_YES
    | K_ZONE
;

reservedKeywordAsId:
    K_END
;

unquotedId:
      ID
    | keywordAsId
;

procSqlName:
      unquotedId
    | QUOTED_ID
    | PLSQL_INQUIRY_DIRECTIVE
    | substitionVariable+
    | POSITIONAL_PARAMETER          // PostgreSQL
    | unicodeIdentifier             // PostgreSQL
    | psqlVariable                  // PostgreSQL
;

sqlName:
      unquotedId
    | reservedKeywordAsId
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
      psqlSimpleVariable
    | psqlStringVariable
    | psqlExtschemaVariable
    | psqlVariableTest
;

// PostgreSQL
psqlSimpleVariable:
    COLON variable=qualifiedName
;

// PostgreSQL
psqlStringVariable:
    COLON stringVariable=STRING
;

// PostgreSQL
psqlExtschemaVariable:
    COMMAT K_EXTSCHEMA (COLON name=unquotedId)? COMMAT
;

psqlVariableTest:
    LCUB QUEST variable=qualifiedName RCUB
;

// parser rule to handle conflict with PostgreSQL & operator
// we have to distinguish between period as end of a substition variable and
// a subsequent period as identifier separator, therefere we must not introduce
// a dedicated PL/SQL range operator
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
      STRING STRING+                    # concatenatedString            // PostgreSQL, MySQL
    | STRING                            # simpleString
    | N_STRING STRING+                  # concatenatedNationalString    // PostgreSQL, MySQL
    | N_STRING                          # nationalString
    | E_STRING STRING*                  # escapedString                 // PostgreSQL
    | U_AMP_STRING concats+=STRING*
        (K_UESCAPE escapeChar=STRING)?  # unicodeString                 // PostgreSQL
    | B_STRING STRING*                  # bitString                     // PostgreSQL bit string in binary format
    | X_STRING STRING*                  # bitString                     // PostgreSQL bit string in hex format
    | Q_STRING                          # quoteDelimiterString
    | NQ_STRING                         # nationalQuoteDelimiterString
    | DOLLAR_STRING                     # dollarString                  // PostgreSQL (no concatenation!)
    | DOLLAR_ID_STRING                  # dollarIdentifierString        // PostgreSQL (no concatenation!)
;

/*----------------------------------------------------------------------------*/
// SQL statement end, slash accepted without preceding newline
/*----------------------------------------------------------------------------*/

sqlEnd:
      EOF
    | SEMI SOL?
    | SOL
    | SEMI PSQL_EXEC // PostgreSQL: execute statement and execute results
    | PSQL_EXEC // PostgreSQL: alternative to semicolon to terminate a statement
    | BSOL SEMI // PostgreSQL: alternative to semicolon to terminate a statement
;
