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

The currrent islands of interests are:

| Statement | Notes                                |
|-----------|--------------------------------------|
| `select`  | complete statement as a single token |

## License

IslandSQL is licensed under the Apache License, Version 2.0. You may obtain a copy of the License at <http://www.apache.org/licenses/LICENSE-2.0>.
