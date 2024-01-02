# IslandSQL

## Introduction

IslandSQL is an ANTLR 4 based parser for SQL.
The parser requires a Java Virtual Machine supporting version 8 or newer.

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
| `call`         | complete statement as list of tokens                        |
| `delete`       | complete statement as list of tokens                        |
| `explain plan` | complete statement as list of tokens                        |
| `insert`       | complete statement as list of tokens                        |
| `lock table`   | complete statement                                          |
| `merge`        | complete statement as list of tokens                        |
| `select`       | complete statement (embedded PL/SQL only as list of tokens) |
| `update`       | complete statement as list of tokens                        |

Tokens that are not part of the statements listed above are preserved as hidden tokens. As a result, the token stream represents the complete input (file).

## Limitations

### Common Principle

If a SQL script runs without errors, but IslandSQL reports parse errors, then we consider this to be a bug. Exceptions are documented here.

### Wrapped PL/SQL Code

Code that has been wrapped with the [wrap](https://docs.oracle.com/en/database/oracle/oracle-database/21/lnpls/plsql-source-text-wrapping.html#GUID-4C024F24-F054-4E11-BCAD-ACA9D6B745D2) utility can be installed in the target database. However, wrapped code is ignored by the IslandSQL grammar.

### Dynamic Grammar of SQL\*Plus

The following commands affect the grammar and are not interpreted by IslandSQL. The IslandSQL grammar is built on the default settings. As a result other values lead to errors.

- [set blockterminator](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqpug/SET-system-variable-summary.html#GUID-2967B311-24CB-43E0-95F2-BFC429CF033D)
- [set cmdsep](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqpug/SET-system-variable-summary.html#GUID-894E73DD-D2CF-4854-B918-AC57C4271C26)
- [set sqlterminator](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqpug/SET-system-variable-summary.html#GUID-5D91A9A9-13A2-4F62-B02A-AD2F3AFF8BB7)

### SQL\*Plus Substitution Variables

[Substitution Variables](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqpug/using-substitution-variables-sqlplus.html) can contain arbitrary text. They are replaced before the execution of a script. The IslandSQL grammar provides limited support for substitution variables. They can be used in places where a `sqlName` is valid. This is basically everywhere you can use an expression.

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
