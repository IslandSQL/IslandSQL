# Frequently Asked Questions

## What is the value of this SQL grammar?

The ANLTR organisation on GitHub manages a repository with example grammars. You find the ones for SQL [here]((https://github.com/antlr/grammars-v4/tree/master/sql).

Most of the 3rd party grammars cover a large subset of the underlying languages. They define what they cover in ANTLR or by EBNF. However, they often do not define which versions they cover and they do not define what they don’t cover. As a result, you have to try if the grammar is sufficient for your use case. Furthermore, you have to assess if it is sufficient for future use cases and if the grammar will cover the changes in newer versions. This is very difficult without a clear scope.

IslandSQL is different. It defines the scope. The [Database Management Systems](README.md#database-management-systems) including the grammar versions and the [statements](README.md#statements)). The statements that are not in scope are kept as hidden tokens. They do not lead to parser errors. And the known [limitations](limitations.md) are documented.

## What is the scope?

See [Database Management Systems](README.md#database-management-systems) and [statements](README.md#statements).

## What are the limitations?

See [limitations](limitations.md)

## How is the grammar related to the SQL standard?

See [SQL:2023](SQL-2023.md).

## Are there any test cases?

Yes, but they are part of a private repository.