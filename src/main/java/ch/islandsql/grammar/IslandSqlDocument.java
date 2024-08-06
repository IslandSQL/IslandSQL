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

package ch.islandsql.grammar;

import ch.islandsql.grammar.util.ConverterUtil;
import ch.islandsql.grammar.util.LexerMetrics;
import ch.islandsql.grammar.util.ParseTreeUtil;
import ch.islandsql.grammar.util.ParserMetrics;
import ch.islandsql.grammar.util.SyntaxErrorEntry;
import ch.islandsql.grammar.util.SyntaxErrorListener;
import ch.islandsql.grammar.util.TokenStreamUtil;
import org.antlr.v4.runtime.CharStreams;
import org.antlr.v4.runtime.CodePointCharStream;
import org.antlr.v4.runtime.CommonTokenStream;
import org.antlr.v4.runtime.ParserRuleContext;
import org.antlr.v4.runtime.tree.ParseTree;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Produces a parse-tree based on the content of a SQL-script.
 * Provides methods to navigate the parse tree.
 */
public class IslandSqlDocument {
    private final IslandSqlDialect dialect;
    private final CommonTokenStream tokenStream;
    private final IslandSqlParser.FileContext file;
    private final List<SyntaxErrorEntry> syntaxErrors;
    private final LexerMetrics lexerMetrics;
    private final ParserMetrics parserMetrics;

    /**
     * Constructor.
     *
     * @param builder The builder instance.
     */
    private IslandSqlDocument(Builder builder) {
        this.dialect = builder.dialect;
        CodePointCharStream charStream = CharStreams.fromString(builder.sql);
        IslandSqlLexer lexer = new IslandSqlLexer(charStream);
        lexer.setDialect(this.dialect);
        SyntaxErrorListener errorListener = new SyntaxErrorListener();
        lexer.removeErrorListeners();
        lexer.addErrorListener(errorListener);
        this.tokenStream = new CommonTokenStream(lexer);
        this.lexerMetrics = !builder.hideOutOfScopeTokens ? null : TokenStreamUtil.hideOutOfScopeTokens(tokenStream, errorListener);
        IslandSqlParser parser = new IslandSqlParser(tokenStream);
        parser.setProfile(builder.profile);
        parser.removeErrorListeners();
        parser.addErrorListener(errorListener);
        long parserStartTime = System.nanoTime();
        long parserStartMemory = Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory();
        this.file = parser.file();
        parseSubtrees(builder, file, lexer, parser);
        long parserTime = System.nanoTime() - parserStartTime;
        long parserMemory = Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory() - parserStartMemory;
        this.parserMetrics = new ParserMetrics(parserTime, parserMemory, parser.getParseInfo());
        this.syntaxErrors = errorListener.getSyntaxErrors();
    }

    /**
     * Guess the SQL dialect based on the specified SQL.
     *
     * @param sql The SQL statement to guess the dialect from.
     * @return The SQL dialect.
     */
    private static IslandSqlDialect guessDialect(String sql) {
        // A slash at the beginning of a line is used in SQL*Plus or SQLcl scripts to terminate
        // a DDL statement containing PL/SQL code. This is a good and cheap dialect detection mechanism.
        // Added new line after slash to ensure a multiline comment is not considered.
        return sql.contains("\n/\n") ? IslandSqlDialect.ORACLEDB : IslandSqlDialect.GENERIC;
    }

    /**
     * Finds SQL and PL/pgSQL code in <code>create function</code>, <code>create procedure</code>,
     * and <code>do</code> statements, parses the code and adds the subtrees to the main parse tree.
     * Optionally removes the code as string from the parse tree.
     * Nested, dynamic SQL and PL/pgSQL code is not resolved.
     *
     * @param builder The builder with parameters used to build the IslandSqlDocument
     * @param file The root object of the main parse tree.
     * @param lexer The lexer used to produce the main parse tree.
     * @param parser The parser used to produce the main parse tree.
     */
    private static void parseSubtrees(Builder builder, IslandSqlParser.FileContext file, IslandSqlLexer lexer, IslandSqlParser parser) {
        if (builder.subtrees && (builder.dialect == IslandSqlDialect.POSTGRESQL || builder.dialect == IslandSqlDialect.GENERIC)) {
            try {
                List<Class<? extends ParseTree>> desiredTypes = new ArrayList<>();
                desiredTypes.add(IslandSqlParser.PostgresqlDoContext.class);
                desiredTypes.add(IslandSqlParser.PostgresqlFunctionSourceContext.class);
                desiredTypes.add(IslandSqlParser.PostgresqlProcedureSourceContext.class);
                List<? extends ParseTree> stmts = ParseTreeUtil.getAllContentsOfTypes(file, desiredTypes);
                for (ParseTree stmt : stmts) {
                    IslandSqlParser.StringContext codeAsString = null;
                    IslandSqlParser.ExpressionContext languageName = null;
                    if (stmt instanceof IslandSqlParser.PostgresqlDoContext) {
                        // do - SQL and PL/pgSQL: PostgreSQL does not support SQL language as string but the IslandSQL grammar accepts it nonetheless
                        IslandSqlParser.PostgresqlDoContext doStmt = (IslandSqlParser.PostgresqlDoContext) stmt;
                        IslandSqlParser.PostgresqlCodeContext code = doStmt.postgresqlCode();
                        if (code != null && code.elements.size() == 1 && code.elements.get(0) instanceof IslandSqlParser.StringCodeElementContext) {
                            codeAsString = ((IslandSqlParser.StringCodeElementContext) code.elements.get(0)).string();
                            languageName = doStmt.languageName;
                            if (parseSubtree(builder, lexer, parser, codeAsString, languageName, doStmt)) {
                                doStmt.code = null;
                            }
                        }
                    } else if (stmt instanceof IslandSqlParser.PostgresqlFunctionSourceContext) {
                        // function - SQL and PL/pgSQL
                        List<IslandSqlParser.PostgresqlFunctionOptionContext> definitionOptions =
                                ParseTreeUtil.getAllContentsOfType(stmt, IslandSqlParser.PostgresqlFunctionOptionContext.class).stream()
                                .filter(it -> it.definition != null).collect(Collectors.toList());
                        if (!definitionOptions.isEmpty()) {
                            ParseTree definition = ParseTreeUtil.getMostConcrete(definitionOptions.get(0).definition);
                            if (definition instanceof IslandSqlParser.StringContext) {
                                codeAsString = (IslandSqlParser.StringContext) definition;
                            }
                            List<IslandSqlParser.PostgresqlFunctionOptionContext> languageOptions =
                                    ParseTreeUtil.getAllContentsOfType(stmt, IslandSqlParser.PostgresqlFunctionOptionContext.class).stream()
                                    .filter(it -> it.languageName != null).collect(Collectors.toList());
                            if (!languageOptions.isEmpty()) {
                                languageName = languageOptions.get(0).languageName;
                            }
                            if (parseSubtree(builder, lexer, parser, codeAsString, languageName, definitionOptions.get(0))) {
                                definitionOptions.get(0).definition = null;
                            }
                        }
                    } else if (stmt instanceof IslandSqlParser.PostgresqlProcedureSourceContext) {
                        // procedure - SQL and PL/pgSQL
                        List<IslandSqlParser.PostgresqlProcedureOptionContext> definitionOptions =
                                ParseTreeUtil.getAllContentsOfType(stmt, IslandSqlParser.PostgresqlProcedureOptionContext.class).stream()
                                .filter(it -> it.definition != null).collect(Collectors.toList());
                        if (!definitionOptions.isEmpty()) {
                            ParseTree definition = ParseTreeUtil.getMostConcrete(definitionOptions.get(0).definition);
                            if (ParseTreeUtil.getMostConcrete(definition) instanceof IslandSqlParser.StringContext) {
                                codeAsString = (IslandSqlParser.StringContext) definition;
                            }
                            List<IslandSqlParser.PostgresqlProcedureOptionContext> languageOptions =
                                    ParseTreeUtil.getAllContentsOfType(stmt, IslandSqlParser.PostgresqlProcedureOptionContext.class).stream()
                                    .filter(it -> it.languageName != null).collect(Collectors.toList());
                            if (!languageOptions.isEmpty()) {
                                languageName = languageOptions.get(0).languageName;
                            }
                            if (parseSubtree(builder, lexer, parser, codeAsString, languageName, definitionOptions.get(0))) {
                                definitionOptions.get(0).definition = null;
                            }
                        }
                    }
                }
            } catch (Exception e) {
                throw new RuntimeException(e);
                // fail-safe, ignore all exceptions, keep parse-tree as is, proceed without producing subtrees
            }
        }
    }

    /**
     * Parses the code and adds the resulting subtree to the main parse tree.
     * Optionally removes the code as string from the parse tree.
     *
     * @param builder The builder with parameters used to build the IslandSqlDocument.
     * @param lexer The lexer used to produce the main parse tree.
     * @param parser The parser used to produce the main parse tree.
     * @param codeAsString The code to be parsed.
     * @param languageName The language of the code to be parsed.
     * @param parent Then node in the parse three which contains codeAsString and the subtree to be created
     * @return true if the child node containing codeAsString has been removed.
     */
    private static boolean parseSubtree(Builder builder, IslandSqlLexer lexer, IslandSqlParser parser,
                                        IslandSqlParser.StringContext codeAsString,
                                        IslandSqlParser.ExpressionContext languageName,
                                        ParserRuleContext parent) {
        String language = ConverterUtil.fromLanguage(languageName);
        if (codeAsString != null && (language.equals("sql") || language.equals("plpgsql"))) {
            CodePointCharStream charStream = CharStreams.fromString(ConverterUtil.fromString(codeAsString));
            lexer.setInputStream(charStream);
            // match original character stream, is accurate if a single string segment is used in codeAsString without escaped characters.
            lexer.setLine(codeAsString.start.getLine());
            lexer.setCharPositionInLine(codeAsString.start.getCharPositionInLine() + ConverterUtil.startOffsetFromString(codeAsString));
            CommonTokenStream tokenStream = new CommonTokenStream(lexer);
            parser.setTokenStream(tokenStream);
            ParserRuleContext codeSubtree = language.equals("sql") ? parser.postgresqlSqlCode() : parser.postgresqlPlpgsqlCode();
            if (codeSubtree.children.size() > 1) {
                if (codeSubtree.children.get(codeSubtree.children.size() - 1).getText().equals("<EOF>")) {
                    codeSubtree.removeLastChild();
                }
                codeSubtree.parent = parent;
                parent.children.add(codeSubtree);
                if (builder.removeCode) {
                    for (int i = parent.children.size() - 1; i > 0; i--) {
                        if (parent.children.get(i) == codeAsString
                                || ParseTreeUtil.getAllContentsOfType(parent.children.get(i), codeAsString.getClass()).stream().filter(it -> it == codeAsString).count() == 1) {
                            parent.children.remove(i);
                            return true;
                        }
                    }
                }
            }
        }
        return false;
    }

    /**
     * Builds a new instance of {@link IslandSqlDocument IslandSqlDocument} with a fluent API.
     */
    public static class Builder {
        private String sql = "";
        private boolean hideOutOfScopeTokens = true;
        private IslandSqlDialect dialect = null;
        private boolean profile = false;
        private boolean subtrees = true;
        private boolean removeCode = false;

        /**
         * Sets the SQL script to be parsed as string.
         * Default is an empty SQL script.
         *
         * @param sql The SQL script as string.
         * @return The builder instance.
         */
        public Builder sql(String sql) {
            this.sql = sql != null ? sql : "";
            return this;
        }

        /**
         * Sets flag to hide out of scope tokens before calling the parser.
         * Default is true, this means the scope lexer is used to hide out of scope tokens.
         *
         * @param hideOutOfScopeTokens Hide out of scope tokens before calling parser?
         * @return The builder instance.
         */
        public Builder hideOutOfScopeTokens(boolean hideOutOfScopeTokens) {
            this.hideOutOfScopeTokens = hideOutOfScopeTokens;
            return this;
        }

        /**
         * Sets the SQL dialect to be used.
         * Default is null, this means the dialect will be guessed based on the provided sql script.
         *
         * @param dialect The SQL dialect to be used.
         * @return The builder instance.
         */
        public Builder dialect(IslandSqlDialect dialect) {
            this.dialect = dialect;
            return this;
        }

        /**
         * Sets the flag to collect ANTLR profiling data during lexing/parsing.
         * Default is false, this means no profiling data is gathered during lexing/parsing.
         *
         * @param profile Collect ANTLR profiling data during lexing/parsing?
         * @return The builder instance.
         */
        public Builder profile(boolean profile) {
            this.profile = profile;
            return this;
        }

        /**
         * Sets the flag to add subtrees for code provided as string.
         * Default is true, this means that SQL and PL/pgSQL code provided in
         * <code>create function</code>, <code>create procedure</code>,
         * and <code>do</code> statements is parsed and
         * the resulting parse tree is added to the main parse tree.
         * This flag is only considered for {@link IslandSqlDialect#GENERIC GENERIC} and
         * {@link IslandSqlDialect#POSTGRESQL POSTGRESQL} dialect.
         *
         * @param subtrees Add subtrees for code provided as string?
         * @return The builder instance.
         */
        public Builder subtrees(boolean subtrees) {
            this.subtrees = subtrees;
            return this;
        }

        /**
         * Sets the flag to remove the code as string after adding a subtree.
         * Default is false, this means the code is kept twice in the parser tree.
         * Once as string and once as a subtree.
         * This flag has no effect if {@link #subtrees subtrees} is set to false.
         *
         * @param removeCode Remove the code as string after adding a subtree?
         * @return The builder instance.
         */
        public Builder removeCode(boolean removeCode) {
            this.removeCode = removeCode;
            return this;
        }

        /**
         * Builds and returns an IslandSqlDocument instance.
         *
         * @return The IslandSqlDocument instance.
         */
        public IslandSqlDocument build() {
            this.dialect = dialect == null ? guessDialect(this.sql) : dialect;
            return new IslandSqlDocument(this);
        }
    }

    /**
     * Factory to construct an IslandSqlDocument.
     *
     * @param sql SQL-script as string.
     * @return Constructed IslandSqlDocument.
     */
    public static IslandSqlDocument parse(String sql) {
        return new Builder().sql(sql).build();
    }

    /**
     * Factory to construct an IslandSqlDocument.
     *
     * @param sql                  SQL-script as string.
     * @param hideOutOfScopeTokens hide out of scope tokens before calling parser?
     * @return Constructed IslandSqlDocument.
     */
    public static IslandSqlDocument parse(String sql, boolean hideOutOfScopeTokens) {
        return new Builder().sql(sql).hideOutOfScopeTokens(hideOutOfScopeTokens).build();
    }

    /**
     * Factory to construct an IslandSqlDocument.
     *
     * @param sql                  SQL-script as string.
     * @param hideOutOfScopeTokens hide out of scope tokens before calling parser?
     * @param dialect              The SQL dialect to be used.
     * @return Constructed IslandSqlDocument.
     */
    public static IslandSqlDocument parse(String sql, boolean hideOutOfScopeTokens, IslandSqlDialect dialect) {
        return new Builder().sql(sql).hideOutOfScopeTokens(hideOutOfScopeTokens).dialect(dialect).build();
    }

    /**
     * Returns the SQL dialect used to parse the document.
     *
     * @return SQL dialect.
     */
    public IslandSqlDialect getDialect() {
        return dialect;
    }

    /**
     * Returns the token stream produced by the lexer.
     * Can be used to access hidden tokens.
     *
     * @return Token stream.
     */
    public CommonTokenStream getTokenStream() {
        return tokenStream;
    }

    /**
     * Returns the start node of the parse tree.
     *
     * @return File (start rule).
     */
    public IslandSqlParser.FileContext getFile() {
        return file;
    }

    /**
     * Gets all nodes that are instances of a desired class.
     * Start node is file.
     *
     * @param desiredType Desired class (must be a descendant of ParseTree).
     * @param <T>         The return type of the result.
     * @return List of nodes that are instances of the of desired class.
     */
    public <T extends ParseTree> List<T> getAllContentsOfType(Class<T> desiredType) {
        return ParseTreeUtil.getAllContentsOfType(file, desiredType);
    }

    /**
     * Gets all syntax error entries for the document.
     * The list is empty, if no syntax errors are found.
     *
     * @return Returns a list of syntax errors.
     */
    public List<SyntaxErrorEntry> getSyntaxErrors() {
        return syntaxErrors;
    }

    /**
     * Get the lexer metrics gathered during construction with hideOutOfScopeTokens.
     *
     * @return The lexer metrics gathered during construction with hideOutOfScopeTokens.
     */
    public LexerMetrics getLexerMetrics() {
        return lexerMetrics;
    }

    /**
     * Get the parser metrics gathered during construction with or without profiling.
     *
     * @return The parser metrics gathered during construction with or without profiling.
     */
    public ParserMetrics getParserMetrics() {
        return parserMetrics;
    }
}
