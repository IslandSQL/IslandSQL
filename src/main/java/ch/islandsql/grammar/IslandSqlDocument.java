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

import ch.islandsql.grammar.util.ParseTreeUtil;
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
    private final CommonTokenStream tokenStream;
    private final IslandSqlParser.FileContext file;
    private final List<SyntaxErrorEntry> syntaxErrors;


    /**
     * Constructor. Private to allow future optimization such as caching.
     *
     * @param sql SQL-script as string.
     */
    private IslandSqlDocument(String sql) {
        CodePointCharStream scopeCharStream = CharStreams.fromString(sql);
        IslandSqlScopeLexer scopeLexer = new IslandSqlScopeLexer(scopeCharStream);
        CommonTokenStream scopeTokenStream = new CommonTokenStream(scopeLexer);
        CodePointCharStream charStream = CharStreams.fromString(TokenStreamUtil.getScopeText(scopeTokenStream));
        IslandSqlLexer lexer = new IslandSqlLexer(charStream);
        this.tokenStream = new CommonTokenStream(lexer);
        IslandSqlParser parser = new IslandSqlParser(tokenStream);
        SyntaxErrorListener errorListener = new SyntaxErrorListener();
        lexer.removeErrorListeners();
        lexer.addErrorListener(errorListener);
        parser.removeErrorListeners();
        parser.addErrorListener(errorListener);
        this.file = parser.file();
        this.syntaxErrors = errorListener.getSyntaxErrors();
    }

    /**
     * Factory to construct an IslandSqlDocument.
     *
     * @param sql SQL-script as string.
     * @return Constructed IslandSqlDocument.
     */
    public static IslandSqlDocument parse(String sql) {
        return new IslandSqlDocument(sql);
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
     * Gets a syntax error entries for the document.
     * The list is empty, if no syntax errors are found.
     *
     * @return Returns a list of syntax errors.
     */
    public List<SyntaxErrorEntry> getSyntaxErrors() {
        return syntaxErrors;
    }
}
