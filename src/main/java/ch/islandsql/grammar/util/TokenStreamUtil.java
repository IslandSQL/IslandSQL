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
     */
    static public void hideOutOfScopeTokens(CommonTokenStream tokenStream, SyntaxErrorListener errorListener) {
        try {
            tokenStream.fill();
        } catch (IllegalStateException e) {
            // Workaround for issue 44 ("cannot consume EOF"). ATM no idea how to solve it.
            // I see the following options:
            //   a) abort process and return; then syntax errors are reported
            //   b) just ignore the exception and suppress the syntax errors
            //   c) ignore the exception and report the issue as syntax error
            // I chose c). However, the best would be to identify why this happens and to
            // fix the lexer. Reporting the error is the best option ATM and should help
            // to identify the root cause in the lexer.
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
        List<CommonToken> tokens = tokenStream.getTokens().stream().map(t -> (CommonToken)t).collect(Collectors.toList());
        CodePointCharStream charStream = CharStreams.fromString(tokenStream.getText());
        IslandSqlScopeLexer scopeLexer = new IslandSqlScopeLexer(charStream);
        if (errorListener != null) {
            scopeLexer.removeErrorListeners();
            scopeLexer.addErrorListener(errorListener);
        }
        CommonTokenStream scopeStream = new CommonTokenStream(scopeLexer);
        try {
            scopeStream.fill();
        } catch (IllegalStateException e) {
            // best effort, similar issue as for tokenStream, probably related.
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
                    break tokenLoop;
                }
            }
            if (token.getChannel() != Token.HIDDEN_CHANNEL &&
                    (scopeToken.getChannel() == Token.HIDDEN_CHANNEL || scopeToken.getType() == Token.EOF) ) {
                token.setChannel(Token.HIDDEN_CHANNEL);
            }
        }
        tokenStream.seek(0);
    }
}
