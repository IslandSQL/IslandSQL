# IslandSQL

## Introduction

IslandSQL is an ANTLR 4 based parser for SQL.
The parser requires a Java Virtual Machine supporting version 8 or newer and is available on [Maven Central](https://central.sonatype.com/artifact/ch.islandsql/islandsql).

The parser provides chosen parts of grammars used in SQL files.

## Scope

### Database Management Systems

The following table shows the DBMS and their grammar versions in scope:

| DBMS   | Grammar  | Version | HTML Reference (live)                                                                                        | PDF Reference (snapshot)                           |
|--------|----------|---------|--------------------------------------------------------------------------------------------------------------| -------------------------------------------------- |
| Oracle | SQL*Plus | 23c     | [User's Guide and Reference](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqpug/)           | [PDF](docs/sqlplus-users-guide-and-reference.pdf)  |
|        | SQLcl    | 23.3    | [Users's Guide](https://docs.oracle.com/en/database/oracle/sql-developer-command-line/23.3/sqcug/index.html) | [PDF](docs/oracle-sqlcl-users-guide.pdf)           |
|        | SQL      | 23c     | [Language Reference](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqlrf/)                   | [PDF](docs/sql-language-reference.pdf)             | 
|        | PL/SQL   | 23c     | [Language Reference](https://docs.oracle.com/en/database/oracle/oracle-database/23/lnpls/)                   | [PDF](docs/database-pl-sql-language-reference.pdf) |

The HTML reference shows the latest version of the document. However, the latest snapshot version in PDF format represents the version that was used to define the grammar.

### Statements

The current islands of interests are:

| Statement      | Notes                                                       |
|----------------|-------------------------------------------------------------|
| `call`         | complete statement                                          |
| `delete`       | complete statement                                          |
| `explain plan` | complete statement                                          |
| `insert`       | complete statement                                          |
| `lock table`   | complete statement                                          |
| `merge`        | complete statement                                          |
| `select`       | complete statement (embedded PL/SQL only as list of tokens) |
| `update`       | complete statement                                          |

Tokens that are not part of the statements listed above are preserved as hidden tokens. As a result, the token stream represents the complete input (file).

## IslandSQL Grammar

The syntax diagrams of the IslandSQL grammar are produced by [RR](https://github.com/GuntherRademacher/rr)
and can be found [here](https://islandsql.github.io/IslandSQL/grammar.html).

## SQL:2023 / ISO/IEC 9075:2023

The IslandSQL grammar is based on the grammars of the DBMSs in scope and not on the SQL:2023 standard.
Nevertheless, it is interesting to consult the standard for constructs that are implemented differently in the DBMSs.

The table below shows links to the freely available BNF of the SQL:2023 standard. Furthermore, it contains links to 
some chosen root elements in the derived syntax diagrams of grammars produced by [RR](https://github.com/GuntherRademacher/rr). 

Please note that not all freely available parts of the standard contain a grammar definition in BNF.

| BNF                                                                                                                                                                   | Derived Syntax Diagram                                                                                                                                                                                                                                                                                                                                                   |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [Part 2: Foundation (SQL/Foundation)](https://standards.iso.org/iso-iec/9075/-2/ed-6/en/ISO_IEC_9075-2(E)_Foundation.bnf.txt)                                         | [preparable_statement](https://islandsql.github.io/IslandSQL/sql-2023-2-foundation.html#preparable_statement), [embedded_SQL_statement](https://islandsql.github.io/IslandSQL/sql-2023-2-foundation.html#embedded_SQL_statement), [direct_SQL_statement](https://islandsql.github.io/IslandSQL/sql-2023-2-foundation.html#direct_SQL_statement)                          | 
| [Part 3: Call-Level Interface (SQL/CLI)](https://standards.iso.org/iso-iec/9075/-3/ed-6/en/ISO_IEC_9075-3(E)_CLI.bnf.txt)                                             | [CLI_routine](https://islandsql.github.io/IslandSQL/sql-2023-3-cli.html#CLI_routine)                                                                                                                                                                                                                                                                                     | 
| [Part 4: Persistent stored modules (SQL/PSM)](https://standards.iso.org/iso-iec/9075/-4/ed-7/en/ISO_IEC_9075-4(E)_PSM.bnf.txt)                                        | [SQL_schema_definition_statement](https://islandsql.github.io/IslandSQL/sql-2023-4-psm.html#SQL_schema_definition_statement), [SQL_schema_manipulation_statement](https://islandsql.github.io/IslandSQL/sql-2023-4-psm.html#SQL_schema_manipulation_statement), [SQL_control_statement](https://islandsql.github.io/IslandSQL/sql-2023-4-psm.html#SQL_control_statement) | 
| [Part 9: Management of External Data (SQL/MED)](https://standards.iso.org/iso-iec/9075/-9/ed-5/en/ISO_IEC_9075-9(E)_MED.bnf.txt)                                      | [SQL_schema_definition_statement](https://islandsql.github.io/IslandSQL/sql-2023-9-med.html#SQL_schema_definition_statement), [SQL_schema_manipulation_statement](https://islandsql.github.io/IslandSQL/sql-2023-9-med.html#SQL_schema_manipulation_statement)                                                                                                           | 
| [Part 10: Object language bindings (SQL/OLB)](https://standards.iso.org/iso-iec/9075/-10/ed-5/en/ISO_IEC_9075-10(E)_OLB.bnf.txt)                                      | [statement_or_declaration](https://islandsql.github.io/IslandSQL/sql-2023-10-olb.html#statement_or_declaration)                                                                                                                                                                                                                                                          | 
| [Part 13: SQL Routines and types using the Java TM programming language (SQL/JRT)](https://standards.iso.org/iso-iec/9075/-13/ed-5/en/ISO_IEC_9075-13(E)_JRT.bnf.txt) | [user-defined_type_body](https://islandsql.github.io/IslandSQL/sql-2023-13-jrt.html#user-defined_type_body)                                                                                                                                                                                                                                                              | 
| [Part 14: XML-Related Specifications (SQL/XML)](https://standards.iso.org/iso-iec/9075/-14/ed-6/en/ISO_IEC_9075-14(E)_XML.bnf.txt)                                    | [table_primary](https://islandsql.github.io/IslandSQL/sql-2023-14-xml.html#table_primary), [aggregate_function](https://islandsql.github.io/IslandSQL/sql-2023-14-xml.html#aggregate_function)                                                                                                                                                                           | 
| [Part 15: Multidimensional arrays (SQL/MDA)](https://standards.iso.org/iso-iec/9075/-15/ed-2/en/ISO_IEC_9075-15(E)_MDA.bnf.txt)                                       | [table_primary](https://islandsql.github.io/IslandSQL/sql-2023-15-mda.html#table_primary)                                                                                                                                                                                                                                                                                | 
| [Part 16: Property Graph Queries (SQL/PGQ)](https://standards.iso.org/iso-iec/9075/-16/ed-1/en/ISO_IEC_9075-16(E)_PGQ.bnf.txt)                                        | [SQL_schema_definition_statement](https://islandsql.github.io/IslandSQL/sql-2023-16-pgq.html#SQL_schema_definition_statement), [SQL_schema_manipulation_statement](https://islandsql.github.io/IslandSQL/sql-2023-16-pgq.html#SQL_schema_manipulation_statement), [table_primary](https://islandsql.github.io/IslandSQL/sql-2023-16-pgq.html#table_primary)              | 


## Limitations

### Common Principle

If a SQL script runs without errors, but IslandSQL reports parse errors, then we consider this to be a bug. Exceptions are documented here.

### Wrapped PL/SQL Code

Code that has been wrapped with the [wrap](https://docs.oracle.com/en/database/oracle/oracle-database/21/lnpls/plsql-source-text-wrapping.html#GUID-4C024F24-F054-4E11-BCAD-ACA9D6B745D2) utility can be installed in the target database. However, wrapped code is ignored by the IslandSQL grammar.

### Keywords as Identifiers

The grammar allows the use of keywords as identifiers. This makes the grammar robust and supports the fact the Oracle Database allows the use of keywords in various places.

However, there are cases where this leads to an unexpected parse tree, even if no keywords as identifiers are used. Here's an example: 

```sql
select *
  from emp
  left join dept on emp.deptno = dept.deptno;
```

In this case `left` is treated as a table alias of `emp`, since `join dept on emp.deptno = dept.deptno` is a valid [`innerCrossJoinClause`](https://islandsql.github.io/IslandSQL/grammar.xhtml#innerCrossJoinClause) and the priority of the evaluation in ANTLR4 matches the order in the grammar.

Solving this issue is not simple, especially since the Oracle Database allows the use of `left` or `right` as valid table names and table aliases. Here's an another example:

```sql
with
   right as (
      select * from emp
   )
select *
  from right
 right join dept on right.deptno = dept.deptno;
```

In this example the Oracle Database selects 15 rows (an empty emp for deptno `40`). The token `right` on the last line is therefore treated as part of the [`outerJoinClause`](https://islandsql.github.io/IslandSQL/grammar.xhtml#outerJoinClause) by the Oracle Database and not as a table alias.

Prohibiting keywords as identifiers in certain places could lead to parse errors for working SQL. Therefore, the production of a false parse tree due to the support of keywords as identifiers is considered acceptable.

### Dynamic Grammar of SQL\*Plus

The following commands affect the grammar and are not interpreted by IslandSQL. The IslandSQL grammar is built on the default settings. As a result other values lead to errors.

- [set blockterminator](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqpug/SET-system-variable-summary.html#GUID-2967B311-24CB-43E0-95F2-BFC429CF033D)
- [set cmdsep](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqpug/SET-system-variable-summary.html#GUID-894E73DD-D2CF-4854-B918-AC57C4271C26)
- [set sqlterminator](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqpug/SET-system-variable-summary.html#GUID-5D91A9A9-13A2-4F62-B02A-AD2F3AFF8BB7)

### SQL\*Plus Substitution Variables

[Substitution Variables](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqpug/using-substitution-variables-sqlplus.html) can contain arbitrary text. They are replaced before the execution of a script. The IslandSQL grammar provides limited support for substitution variables. They can be used in places where a `sqlName` is valid. This is basically everywhere you can use an [expression](https://islandsql.github.io/IslandSQL/grammar.xhtml#expression) or a [sqlName](https://islandsql.github.io/IslandSQL/grammar.xhtml#sqlName).

Here's an example of a supported usage:

```sql
lock table &table_name in exclusive mode wait &seconds;
```

And here's an example of an unsupported usage:

```sql
lock table dept in &lock_mode mode nowait;
```

The grammar expects certain keywords at the position of `&lock_mode`. Hence, this usage is not supported.

### External Table Access Parameters

The `access_parameters` clause used in [inline_external_table](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqlrf/SELECT.html#GUID-CFA006CA-6FF1-4972-821E-6996142A51C6__GUID-AC907F76-4436-4D28-9EAB-FD3D93AE5648) or [modified_external_table](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqlrf/SELECT.html#GUID-CFA006CA-6FF1-4972-821E-6996142A51C6__GUID-BC324A59-5780-461E-8DDF-F8ABCEFD741B) is driver specific. You can pass this access parameters as string or as a subquery returning a CLOB or embed the driver specific parameters directly. All variants are supported. 

However, when you embed the drivers specific parameters directly, the parameters are parsed as a list of tokens. We do not plan to implement the driver specific grammars. See also:

- [Oracle Database Utilities: External Tables](https://docs.oracle.com/en/database/oracle/oracle-database/23/sutil/oracle-external-tables.html#GUID-038ED956-A6EE-4C6D-B7C9-0D406B8088B6) 
- [Oracle Database Administrator's Guide: Using Inline External Tables](https://docs.oracle.com/en/database/oracle/oracle-database/23/admin/managing-tables.html#GUID-621E5DDE-36D9-4661-9D14-80DE35858C3F)
- [Oracle Database Administrator's Guide: Overriding Parameters for External Tables in a Query](https://docs.oracle.com/en/database/oracle/oracle-database/23/admin/managing-tables.html#GUID-6E4219FF-A557-452E-A6E9-96C38BA87EE0)

## License

IslandSQL is licensed under the Apache License, Version 2.0. You may obtain a copy of the License at <http://www.apache.org/licenses/LICENSE-2.0>.
