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
            // I see two options.
            //   a) abort process and return; then syntax errors are reported
            //   b) just ignore the exception and suppress the syntax errors
            // Both options have pros and cons. In any case the number of tokens are incomplete.
            // Suppressing the syntax errors is not optimal, but it's probably better than
            // reporting errors for SQL scripts of out-of-scope dialects.
            // TODO: add "return;" with https://github.com/IslandSQL/IslandSQL/issues/21
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
            // best effort
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
                    // best effort
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
