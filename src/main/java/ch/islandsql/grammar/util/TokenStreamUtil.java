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

package ch.islandsql.grammar.util;

import ch.islandsql.grammar.IslandSqlScopeLexer;
import org.antlr.v4.runtime.CharStreams;
import org.antlr.v4.runtime.CodePointCharStream;
import org.antlr.v4.runtime.CommonToken;
import org.antlr.v4.runtime.CommonTokenStream;
import org.antlr.v4.runtime.Lexer;
import org.antlr.v4.runtime.Token;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

/**
 * TokenStream utilities.
 */
public class TokenStreamUtil {
    /**
     * Put all tokens that are not in the scope of IslandSQL on the HIDDEN channel.
     * All tokens in the tokenStream that overlap with the hidden tokens provided
     * by the IslandSqlScopeLexer are moved to the hidden channel.
     *
     * @param tokenStream The tokensStream produced by islandSqlLexer to process.
     * @return The lexer metrics.
     */
    static public LexerMetrics hideOutOfScopeTokens(CommonTokenStream tokenStream, SyntaxErrorListener errorListener) {
        long lexerStartTime = System.currentTimeMillis();
        long lexerStartMemory = Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory();
        try {
            tokenStream.fill();
        } catch (IllegalStateException e) {
            // Fail-safe for issues like #44 ("cannot consume EOF").
            // Syntax error is reported. This helps to identify the root cause in the lexer.
            if (errorListener != null) {
                Token offendingToken = null;
                int size = tokenStream.size();
                int line = 0;
                int charPositionInLine = 0;
                if (size > 0) {
                    offendingToken = tokenStream.get(size-1);
                    line = offendingToken.getLine();
                    charPositionInLine = offendingToken.getCharPositionInLine();
                }
                errorListener.syntaxError(null, offendingToken, line, charPositionInLine, e.getMessage() + " (IslandSqlLexer)", null);
            }
        }
        long lexerTime = System.currentTimeMillis() - lexerStartTime;
        long lexerMemory = Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory() - lexerStartMemory;
        List<CommonToken> tokens = tokenStream.getTokens().stream().map(t -> (CommonToken)t).collect(Collectors.toList());
        CodePointCharStream charStream = CharStreams.fromString(tokenStream.getText());
        IslandSqlScopeLexer scopeLexer = new IslandSqlScopeLexer(charStream);
        if (errorListener != null) {
            scopeLexer.removeErrorListeners();
            scopeLexer.addErrorListener(errorListener);
        }
        CommonTokenStream scopeStream = new CommonTokenStream(scopeLexer);
        long scopeLexerStartTime = System.currentTimeMillis();
        long scopeLexerStartMemory = Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory();
        try {
            scopeStream.fill();
        } catch (IllegalStateException e) {
            // Fail save for issues in the lexer.
            // Syntax error is reported. This helps to identify the root cause in the lexer.
            if (errorListener != null) {
                Token offendingToken = null;
                int size = scopeStream.size();
                int line = 0;
                int charPositionInLine = 0;
                if (size > 0) {
                    offendingToken = scopeStream.get(size-1);
                    line = offendingToken.getLine();
                    charPositionInLine = offendingToken.getCharPositionInLine();
                }
                errorListener.syntaxError(null, offendingToken, line, charPositionInLine, e.getMessage() + " (IslandSqlScopeLexer)", null);
            }
        }
        long scopeLexerTime = System.currentTimeMillis() - scopeLexerStartTime;
        long scopeLexerMemory = Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory() - scopeLexerStartMemory;
        List<Token> scopeTokens = new ArrayList<>(scopeStream.getTokens());
        int scopeIndex = 0;
        Token scopeToken = scopeTokens.get(scopeIndex);
        tokenLoop:
        for (CommonToken token : tokens) {
            while (scopeToken.getType() != Token.EOF && scopeToken.getStopIndex() < token.getStartIndex()) {
                scopeIndex++;
                try {
                    scopeToken = scopeTokens.get(scopeIndex);
                } catch (IndexOutOfBoundsException e) {
                    // best effort, subsequent error of previous IllegalStateException
                    // no need to report this error, just stop the processing,
                    // the parser will probably produce further subsequent errors.
                    // the root cause in the lexer needs to be identified and fixed.
                    break tokenLoop;
                }
            }
            if (token.getChannel() != Token.HIDDEN_CHANNEL &&
                    (scopeToken.getChannel() == Token.HIDDEN_CHANNEL || scopeToken.getType() == Token.EOF) ) {
                token.setChannel(Token.HIDDEN_CHANNEL);
            }
        }
        tokenStream.seek(0);
        return new LexerMetrics(scopeLexerTime, scopeLexerMemory, lexerTime, lexerMemory);
    }

    /**
     * Produces a SQL script containing only the islands of interest.
     * The original line numbers are preserved. However, the line lengths
     * will differ when the original line contains tokens that are not of interest.
     *
     * @param tokenStream The tokensStream produced by islandSqlLexer to process.
     * @return Returns a SQL script containing only the islands of interest.
     */
    public static String printScope(CommonTokenStream tokenStream) {
        final StringBuilder sb = new StringBuilder();
        for (Token token : tokenStream.getTokens()) {
            if (token.getType() > 0 && (token.getChannel() == Lexer.DEFAULT_TOKEN_CHANNEL || token.getType() <= 8)) {
                sb.append(token.getText());
            } else {
                // emit new lines in hidden tokens (e.g. multiline strings) to preserve original line numbers
                String text = token.getText();
                for (int i = 0; i < text.length(); i++) {
                    if (text.charAt(i) == '\n') {
                        sb.append('\n');
                    }
                }
            }
        }
        return sb.toString();
    }
}
