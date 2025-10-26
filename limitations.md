# Limitations

## Table of Contents

- [Common Principle](#common-principle)
- [Wrapped PL/SQL Code](#wrapped-plsql-code)
- [Keywords as Identifiers](#keywords-as-identifiers)
- [Keyword `end` as Identifier at the End of a Statement in a PL/SQL Block](#keyword-end-as-identifier-at-the-end-of-a-statement-in-a-plsql-block)
- [SQL\*Plus PROMPT and REMARK Commands](#sqlplus-prompt-and-remark-commands)
- [Dynamic Grammar of SQL\*Plus and psql](#dynamic-grammar-of-sqlplus-and-psql)
- [Unterminated Statements](#unterminated-statements)
- [Multiline Comments](#multiline-comments)
- [SQL\*Plus Substitution Variables](#sqlplus-substitution-variables)
- [Variables in psql](#variables-in-psql)
- [Conditional Compilation (Selection Directives)](#conditional-compilation-selection-directives)
- [Shallow Parsed Clauses](#shallow-parsed-clauses)
- [PostgreSQL Bitwise XOR Operator `#`](#postgresql-bitwise-xor-operator-)
- [Inquiry Directives](#inquiry-directives)

## Common Principle

If a SQL script runs without errors, but IslandSQL reports parse errors, then we consider this to be a bug. Exceptions are documented here.

## Wrapped PL/SQL Code

Code that has been wrapped with the [wrap](https://docs.oracle.com/en/database/oracle/oracle-database/21/lnpls/plsql-source-text-wrapping.html#GUID-4C024F24-F054-4E11-BCAD-ACA9D6B745D2) utility can be installed in the target database. However, wrapped code is ignored by the IslandSQL grammar.

## Keywords as Identifiers

The grammar allows keywords to be used as identifiers. This makes the grammar robust and supports the fact that OracleDB allows the use of keywords in various places.

However, there are cases where this leads to an unexpected parse tree, even if no keywords as identifiers are used. Here's an example: 

```sql
select *
  from emp
  left join dept on emp.deptno = dept.deptno;
```

In this case `left` is treated as a table alias of `emp`, since `join dept on emp.deptno = dept.deptno` is a valid [`innerCrossJoinClause`](https://islandsql.github.io/IslandSQL/grammar.html#innerCrossJoinClause) and the priority of the evaluation in ANTLR4 matches the order in the grammar.

Solving this issue is not simple, especially since OracleDB allows the use of `left` or `right` as valid table names and table aliases. Here's an another example:

```sql
with
   right as (
      select * from emp
   )
select *
  from right
 right join dept on right.deptno = dept.deptno;
```

In this example OracleDB selects 15 rows (an empty emp for deptno `40`). The token `right` on the last line is therefore treated as part of the [`outerJoinClause`](https://islandsql.github.io/IslandSQL/grammar.html#outerJoinClause) by OracleDB and not as a table alias.

Prohibiting keywords as identifiers in certain places could lead to parse errors for working SQL. Therefore, the production of a false parse tree due to the support of keywords as identifiers is considered acceptable.

## Keyword `end` as Identifier at the End of a Statement in a PL/SQL Block

If you use the [scope lexer to hide out-of-scope tokens](https://github.com/IslandSQL/IslandSQL/blob/v0.13.0/src/main/java/ch/islandsql/grammar/IslandSqlDocument.java#L241-L251), you must not use the `end` keyword as an identifier to terminate a statement within a PL/SQL block.

Here's an example of an unsupported use of the `end` keyword:

```sql
declare
   l_count integer;
begin
   select count(*)
     into l_count
     from end;
end;
/
```

In this case, the scope lexer hides the tokens in last two lines 7 and 8. As a result the parser will report a syntax error.

As a workaround you can disable the `hideOutOfScopeTokens` feature (the parser can handle this), or change the code. For example, as follows:

```sql
declare
   l_count integer;
begin
   select count(*)
     into l_count
     from "END";
end;
/
```

## SQL\*Plus PROMPT and REMARK Commands

The SQL\*Plus PROMPT and REMARK commands are treated like comments. They are recognized in the lexer and put on the hidden channel. So they are simply ignored by the parser. However, this may lead to parser errors if the following identifiers are used on a new line:

- `pro`
- `prom`
- `promp`
- `prompt`
- `rem`
- `rema`
- `remar`
- `remark`

Here's an example:

```sql
with 
pro as (select 42)
select * from pro;
```

In this case the second line is recognized as a prompt command and put on the hidden channel. The remaining statement `with select * from pro;` is not a valid statement anymore and a syntax error is reported.

The workaround is to reformat the statement and ensure `pro` does not start on a new line as shown below:

```sql
with pro as (select 42)
select * from pro;
```

There are also cases where an identifier is swallowed and does not appear in the parse tree. Here's an example:

```sql
select 42
rem
;
```

In this case `rem` is not identified as column alias by the parser. As a workaround write the statement on a single line or change the alias e.g. to `"REM"`.

## Dynamic Grammar of SQL\*Plus and psql

The following commands affect the grammar and are not interpreted by IslandSQL. The IslandSQL grammar is built on the default settings. As a result other values lead to errors.

- [set blockterminator](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqpug/SET-system-variable-summary.html#GUID-2967B311-24CB-43E0-95F2-BFC429CF033D)
- [set cmdsep](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqpug/SET-system-variable-summary.html#GUID-894E73DD-D2CF-4854-B918-AC57C4271C26)
- [set sqlterminator](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqpug/SET-system-variable-summary.html#GUID-5D91A9A9-13A2-4F62-B02A-AD2F3AFF8BB7)
- [single line option](https://www.postgresql.org/docs/current/app-psql.html#APP-PSQL-OPTION-SINGLE-LINE)

However, the following psql meta commands are supported as alternative to a semicolon:

- [\\g](https://www.postgresql.org/docs/current/app-psql.html#APP-PSQL-META-COMMAND-G)
- [\\;](https://www.postgresql.org/docs/current/app-psql.html#APP-PSQL-META-COMMAND-SEMICOLON)

## Unterminated Statements

The grammar expects an SQL statement to end with a semicolon, unless it is the last statement in a file. Here is a valid example:

```sql
select 42 as result;
select 'fourty-two' as result
```

Removing the semicolon in the scripts will result in a parse error.

## Multiline Comments

The implementation of multiline comments is specific to the IslandSQL dialect. The grammar consumes only complete multiline comments. As a result incomplete multiline comments may lead to parse errors.

Here's an example:

```sql
/* start multiline comment
/* start nested multiline comment
end of (nested) multiline comment */
select 42;
```

IslandSQL reports an `mismatched input '*'` error on line 1 for GENERIC and POSTGRESQL dialects because the outer multiline comment is not terminated. Only line 2 and 3 are recognized as a multiline comment. This behaviour is different to the DBMSs in scope.

The OracleDB executes `select 42;` without reporting an error. PostgreSQL doesn't execute anything because it waits for the outer comment to be terminated. In other words in PostgreSQL the whole SQL script is interpreted as a comment.

Here's another example:

```sql
/* start multiline comment
end of multiline comment */
select 42;
*/ 
```

IsqlandSQL ignores the incomplete multiline comment on line 4 for all dialects. This is different to the behaviour of OracleDB and PostgreSQL. Both DBMSs report an error on line 4.

Furthermore, IslandSQL supports nested multiline comments for GENERIC and POSTGRESQL dialects. Here's an example:

```sql
/* level 1 /* level 2 /* level 3 */ level 2 */ level 1 */
select 42;
```

For ORACLEDB dialect only `/* level 1 /* level 2 /* level 3 */` is recognised as comment. Everything up to the first `*/`. This matches the behaviour of the DBMSs in scope.

## SQL\*Plus Substitution Variables

[Substitution Variables](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqpug/using-substitution-variables-sqlplus.html) can contain arbitrary text. They are replaced before the execution of a script. The IslandSQL grammar provides limited support for substitution variables. They can be used in places where a [sqlName](https://islandsql.github.io/IslandSQL/grammar.html#sqlName) is valid.

Here's an example of a supported usage:

```sql
lock table &table_name in exclusive mode wait &seconds;
```

And here's an example of an unsupported usage:

```sql
lock table dept in &lock_mode mode nowait;
```

The grammar expects certain keywords at the position of `&lock_mode`. Hence, this usage is not supported.

## Variables in psql

[Variables in psql](https://www.postgresql.org/docs/current/app-psql.html#APP-PSQL-VARIABLES) can contain arbitrary text. They are replaced before the execution of a script. The IslandSQL grammar provides limited support for these variables. They can be used in places where a [sqlName](https://islandsql.github.io/IslandSQL/grammar.html#sqlName) is valid.

Here's an example of a supported usage:

```sql
\set schema public
select e.*, :'schema' as schema from :schema.emp as e;
```

And here's an example of an unsupported usage:

```sql
\set schema public.
select e.*, :'schema' as schema from :schema emp as e;
```

The grammar expects an identifier to not contain a period. Hence, this usage is not supported.

## Conditional Compilation (Selection Directives)

Selection directives are similar to substitution variables. They can contain arbitrary text and are replaced as part of the pre-compilation step. 

The IslandSQL grammar provides limited support for selection directives. They can be used in places where an [expression](https://islandsql.github.io/IslandSQL/grammar.html#expression), [itemlistItem](https://islandsql.github.io/IslandSQL/grammar.html#itemlistItem) or [plsqlStatement](https://islandsql.github.io/IslandSQL/grammar.html#plsqlStatement) is valid.

Here's an example of a supported usage:

```sql
create or replace package my_pkg as 
   $if dbms_db_version.version < 10 $then 
      subtype my_real is number;
   $else 
      subtype my_real is binary_double;
   $end
   my_pi my_real;
   my_e my_real;
end my_pkg;
```

And here's an example of an unsupported usage:

```sql
create or replace package my_pkg as
   subtype my_real is
      $if dbms_db_version.version < 10 $then  
         number;
      $else 
         binary_double;
      $end
   my_pi my_real;
   my_e my_real;
end my_pkg;
```

The grammar expects a plsqlDataType after `subtype my_real is` but got a selectionDirective.

## Shallow Parsed Clauses

The following clauses contain a flat sequence of tokens:

| Clause                                                                                                                                                                                                     | Parts containing token list                                                                                                                                                                                                                                                                                                                                                                                                                                         |
|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [column_properties](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqlrf/CREATE-MATERIALIZED-VIEW.html#GUID-EE262CA4-01E5-4618-B659-6165D993CA1B__I2116487)                                 | Complete clause                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| [create_table](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqlrf/CREATE-TABLE.html#GUID-F9CE0CC3-13AE-4744-A43C-EAC7A71AAAB6__GUID-1C10C8E9-09A7-45F3-B8B6-A6FC92CFBAA6)                 | Everything except `relational_properties`, `annotations_clause` and `subquery`                                                                                                                                                                                                                                                                                                                                                                                      |
| [explain_plan](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqlrf/EXPLAIN-PLAN.html#GUID-FD540872-4ED3-4936-96A2-362539931BA0__GUID-BDCC3613-9F65-476A-BEBC-4793321BF7A2)                 | SQL statements in `for statement clause` that are not in scope of IslandSQL                                                                                                                                                                                                                                                                                                                                                                                         |
| [inline_external_table](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqlrf/SELECT.html#GUID-CFA006CA-6FF1-4972-821E-6996142A51C6__GUID-AC907F76-4436-4D28-9EAB-FD3D93AE5648)              | Driver-specific `access parameters`, see [Oracle Database Administrator's Guide: Using Inline External Tables](https://docs.oracle.com/en/database/oracle/oracle-database/23/admin/managing-tables.html#GUID-621E5DDE-36D9-4661-9D14-80DE35858C3F), [Oracle Database Utilities: External Tables](https://docs.oracle.com/en/database/oracle/oracle-database/23/sutil/oracle-external-tables.html#GUID-038ED956-A6EE-4C6D-B7C9-0D406B8088B6)                         |
| [javascript_declaration](https://docs.oracle.com/en/database/oracle/oracle-database/23/lnpls/call-specification.html#GUID-C5F117AE-E9A2-499B-BA6A-35D072575BAD__GUID-59B2D1AA-DB1E-4E23-BEA2-51EFCC1F2098) | JavaScript `code`                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| [modified_external_table](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqlrf/SELECT.html#GUID-CFA006CA-6FF1-4972-821E-6996142A51C6__GUID-BC324A59-5780-461E-8DDF-F8ABCEFD741B)            | Driver-specific `access parameters`, see [Oracle Database Administrator's Guide: Overriding Parameters for External Tables in a Query](https://docs.oracle.com/en/database/oracle/oracle-database/23/admin/managing-tables.html#GUID-6E4219FF-A557-452E-A6E9-96C38BA87EE0), [Oracle Database Utilities: External Tables](https://docs.oracle.com/en/database/oracle/oracle-database/23/sutil/oracle-external-tables.html#GUID-038ED956-A6EE-4C6D-B7C9-0D406B8088B6) |
| [physical_attributes_clause](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqlrf/CREATE-MATERIALIZED-VIEW.html#GUID-EE262CA4-01E5-4618-B659-6165D993CA1B__I2116626)                        | Complete clause                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| [physical_properties](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqlrf/CREATE-MATERIALIZED-VIEW.html#GUID-EE262CA4-01E5-4618-B659-6165D993CA1B__I2147304)                               | Complete clause                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| [Selection Directives](https://docs.oracle.com/en/database/oracle/oracle-database/23/lnpls/plsql-language-fundamentals.html#GUID-78F2074C-C799-4CF9-9290-EB8473D0C8FB)                                     | `text`                                                                                                                                                                                                                                                                                                                                                                                                                                                              |                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| [sql_body](https://www.postgresql.org/docs/current/sql-createfunction.html)                                                                                                                                | SQL statements in atomic block that are not in scope of IslandSQL                                                                                                                                                                                                                                                                                                                                                                                                   |                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| [statements](https://www.postgresql.org/docs/16/plpgsql-structure.html#PLPGSQL-STRUCTURE)                                                                                                                  | SQL statements in PL/pgSQL blocks that are not in scope of IslandSQL                                                                                                                                                                                                                                                                                                                                                                                                |                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| [table_partitioning_clauses](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqlrf/CREATE-TABLE.html#GUID-F9CE0CC3-13AE-4744-A43C-EAC7A71AAAB6__I2129707)                                    | Complete clause                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| [using_index_clause](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqlrf/constraint.html#GUID-1055EA97-BA6F-4764-A15F-1024FD5B6DFE__CJAGEBIG)                                              | `create_index_statement` and `index_properties`                                                                                                                                                                                                                                                                                                                                                                                                                     |

This means that syntax errors may not be reported and static code analysis of these clauses is more complex.

## PostgreSQL Bitwise XOR Operator `#`

In OracleDB an unquoted identifier can contain a `#` character. In PostgreSQL this is not allowed.
The IslandSQL grammar supports identifiers containing `#`. As a result, in some cases, an expression containing a `#` 
is interpreted as an `identifier` instead of a `bitwise exclusive OR expression` in IslandSQL.

Here are some examples:

| Query                  | PostgreSQL             | IslandSQL              | Notes                                |
|------------------------|------------------------|------------------------|--------------------------------------|
| `select a#b from t;`   | Bitwise XOR expression | Identifier `a#b`       | No whitespace around operator        |
| `select a # b from t;` | Bitwise XOR expression | Bitwise XOR expression | Whitespace around operator           |
| `select a #b from t;`  | Bitwise XOR expression | Bitwise XOR expression | Identifier cannot start with a `#`   |
| `select 1#2;`          | Bitwise XOR expression | Bitwise XOR expression | Identifier cannot start with a digit |

## Inquiry Directives

By default, the parser uses a [GENERIC SQL dialect](src/main/java/ch/islandsql/grammar/IslandSqlDialect.java#L25). This means that the parser expects a file to contain statements using OracleDB and/or PostgreSQL syntax. This works well in most cases.

However, here's an example that causes a parse error:

```sql
alter session set plsql_ccflags = 'custom1:41, custom2:42';
begin
   dbms_output.put_line($$custom1);
   dbms_output.put_line($$custom2 || '(2)');
end;
```

Why? because `$$custom1);\n   dbms_output.put_line($$` is identified as a PostgreSQL [dollar-quoted string constant](https://www.postgresql.org/docs/16/sql-syntax-lexical.html#SQL-SYNTAX-DOLLAR-QUOTING) by the lexer.

To solve the problem, the following mechanisms are provided:

- Handle predefined inquiry directives (e.g. `$$plsql_unit`) for GENERIC SQL dialect.
- Disable dollar-quoted string constants for ORACLEDB SQL dialect
- Set SQL dialect explicitly when constructing an IslandSqlDocument.
- Detect SQL dialect automatically.

So, if you are using user-defined inquiry directives or PostgreSQL dollar-quoted string constants that start with a pre-defined inquiry directive name then you need to [set the dialect explicitly](src/main/java/ch/islandsql/grammar/IslandSqlDocument.java#L342) to avoid parse errors.
