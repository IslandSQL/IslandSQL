# IslandSQL

## Introduction

IslandSQL is an ANTLR 4 based parser for SQL.
The parser requires a Java Virtual Machine supporting version 8 or newer.

The parser provides chosen parts of grammars used in SQL files.

## Scope

### Database Management Systems

The following table shows the DBMS and their grammar versions in scope:

| DBMS   | Grammar  | Version | Reference                                                                                                    |
|--------|----------|---------|--------------------------------------------------------------------------------------------------------------|
| Oracle | SQL*Plus | 21c     | [User's Guide and Reference](https://docs.oracle.com/en/database/oracle/oracle-database/21/sqpug/)           |
|        | SQLcl    | 22.4    | [Users's Guide](https://docs.oracle.com/en/database/oracle/sql-developer-command-line/22.4/sqcug/index.html) |
|        | SQL      | 21c     | [Language Reference](https://docs.oracle.com/en/database/oracle/oracle-database/21/sqlrf/)                   |  
|        | PL/SQL   | 21c     | [Language Reference](https://docs.oracle.com/en/database/oracle/oracle-database/21/lnpls/)                   |

### Statements

The current islands of interests are:

| Statement      | Notes                                |
|----------------|--------------------------------------|
| `call`         | complete statement as a single token |
| `delete`       | complete statement as a single token |
| `explain plan` | complete statement as a single token |
| `insert`       | complete statement as a single token |
| `lock table`   | complete statement                   |
| `merge`        | complete statement as a single token |
| `select`       | complete statement as a single token |
| `update`       | complete statement as a single token |

## Limitations

### Common Principle

If a SQL script runs without errors, but IslandSQL reports parse errors, then we consider this to be a bug. Exceptions are documented here.

### Wrapped PL/SQL Code

Code that has been wrapped with the [wrap](https://docs.oracle.com/en/database/oracle/oracle-database/21/lnpls/plsql-source-text-wrapping.html#GUID-4C024F24-F054-4E11-BCAD-ACA9D6B745D2) utility can be installed in the target database. However, wrapped code is ignored by the IslandSQL grammar.

### Dynamic Grammar of SQL\*Plus

The following commands affect the grammar and are not interpreted by IslandSQL. The IslandSQL grammar is built on the default settings. As a result other values lead to errors.

- [set blockterminator](https://docs.oracle.com/en/database/oracle/oracle-database/21/sqpug/SET-system-variable-summary.html#GUID-2967B311-24CB-43E0-95F2-BFC429CF033D)
- [set cmdsep](https://docs.oracle.com/en/database/oracle/oracle-database/21/sqpug/SET-system-variable-summary.html#GUID-894E73DD-D2CF-4854-B918-AC57C4271C26)
- [set sqlterminator](https://docs.oracle.com/en/database/oracle/oracle-database/21/sqpug/SET-system-variable-summary.html#GUID-5D91A9A9-13A2-4F62-B02A-AD2F3AFF8BB7)

### SQL\*Plus Substitution Variables

[Substitution Variables](https://docs.oracle.com/en/database/oracle/oracle-database/21/sqpug/using-substitution-variables-sqlplus.html) can contain arbitrary text. They are replaced before the execution of a script. The IslandSQL grammar provides limited support for substitution variables. They can be used in places where a `sqlName` is valid. This is basically everywhere you can use an expression.

Here's an example of a supported usage:

```sql
lock table &table_name in exclusive mode wait &seconds;
```

And here's an example of an unsupported usage:

```sql
lock table dept in &lock_mode mode nowait;
```

The grammar expects certain keywords at the position of `&lock_mode`. Hence, this usage is not supported.

## License

IslandSQL is licensed under the Apache License, Version 2.0. You may obtain a copy of the License at <http://www.apache.org/licenses/LICENSE-2.0>.
