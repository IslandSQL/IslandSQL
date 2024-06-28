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

import ch.islandsql.grammar.util.LexerMetrics;
import ch.islandsql.grammar.util.ParseTreeUtil;
import ch.islandsql.grammar.util.ParserMetrics;
import ch.islandsql.grammar.util.SyntaxErrorEntry;
import ch.islandsql.grammar.util.SyntaxErrorListener;
import ch.islandsql.grammar.util.TokenStreamUtil;
import org.antlr.v4.runtime.CharStreams;
import org.antlr.v4.runtime.CodePointCharStream;
import org.antlr.v4.runtime.CommonTokenStream;
import org.antlr.v4.runtime.tree.ParseTree;

import java.util.List;

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
     * Constructor. Private to allow future optimization such as caching.
     *
     * @param sql SQL-script as string.
     * @param hideOutOfScopeTokens hide out of scope tokens before calling parser?
     * @param dialect The SQL dialect to be used.
     * @param profile collect ANTLR profiling data during lexing/parsing
     */
    private IslandSqlDocument(String sql, boolean hideOutOfScopeTokens, IslandSqlDialect dialect, boolean profile) {
        assert sql != null : "sql must not be null";
        this.dialect = dialect == null ? guessDialect(sql) : dialect;
        CodePointCharStream charStream = CharStreams.fromString(sql);
        IslandSqlLexer lexer = new IslandSqlLexer(charStream);
        lexer.setDialect(this.dialect);
        SyntaxErrorListener errorListener = new SyntaxErrorListener();
        lexer.removeErrorListeners();
        lexer.addErrorListener(errorListener);
        this.tokenStream = new CommonTokenStream(lexer);
        if (hideOutOfScopeTokens) {
            lexerMetrics = TokenStreamUtil.hideOutOfScopeTokens(tokenStream, errorListener);
        } else {
            lexerMetrics = null;
        }
        IslandSqlParser parser = new IslandSqlParser(tokenStream);
        if (profile) {
            parser.setProfile(true);
        }
        parser.removeErrorListeners();
        parser.addErrorListener(errorListener);
        long parserStartTime = System.currentTimeMillis();
        long parserStartMemory = Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory();
        this.file = parser.file();
        long parserTime = System.currentTimeMillis() - parserStartTime;
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
     * Factory to construct an IslandSqlDocument.
     *
     * @param sql SQL-script as string.
     * @return Constructed IslandSqlDocument.
     */
    public static IslandSqlDocument parse(String sql) {
        return parse(sql, true);
    }

    /**
     * Factory to construct an IslandSqlDocument.
     *
     * @param sql SQL-script as string.
     * @param hideOutOfScopeTokens hide out of scope tokens before calling parser?
     * @return Constructed IslandSqlDocument.
     */
    public static IslandSqlDocument parse(String sql, boolean hideOutOfScopeTokens) {
        return new IslandSqlDocument(sql, hideOutOfScopeTokens, null, false);
    }

    /**
     * Factory to construct an IslandSqlDocument.
     *
     * @param sql SQL-script as string.
     * @param hideOutOfScopeTokens hide out of scope tokens before calling parser?
     * @param dialect The SQL dialect to be used.
     * @return Constructed IslandSqlDocument.
     */
    public static IslandSqlDocument parse(String sql, boolean hideOutOfScopeTokens, IslandSqlDialect dialect) {
        return new IslandSqlDocument(sql, hideOutOfScopeTokens, dialect, false);
    }

    /**
     * Factory to construct an IslandSqlDocument.
     *
     * @param sql SQL-script as string.
     * @param hideOutOfScopeTokens hide out of scope tokens before calling parser?
     * @param dialect The SQL dialect to be used.
     * @param profile collect ANTLR profiling data during lexing/parsing
     * @return Constructed IslandSqlDocument.
     */
    public static IslandSqlDocument parse(String sql, boolean hideOutOfScopeTokens, IslandSqlDialect dialect, boolean profile) {
        return new IslandSqlDocument(sql, hideOutOfScopeTokens, dialect, profile);
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
     * @return List of nodes that are instances of the of desired class.
     * @param <T> The return type of the result.
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
