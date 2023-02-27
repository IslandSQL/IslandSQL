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
    static public void hideOutOfScopeTokens(CommonTokenStream tokenStream) {
        tokenStream.fill();
        List<CommonToken> tokens = tokenStream.getTokens().stream().map(t -> (CommonToken)t).collect(Collectors.toList());
        CodePointCharStream charStream = CharStreams.fromString(tokenStream.getText());
        IslandSqlScopeLexer scopeLexer = new IslandSqlScopeLexer(charStream);
        CommonTokenStream scopeStream = new CommonTokenStream(scopeLexer);
        scopeStream.fill();
        List<Token> scopeTokens = new ArrayList<>(scopeStream.getTokens());
        int scopeIndex = 0;
        Token scopeToken = scopeTokens.get(scopeIndex);
        for (CommonToken token : tokens) {
            while (scopeToken.getType() != Token.EOF && scopeToken.getStopIndex() < token.getStartIndex()) {
                scopeIndex++;
                scopeToken = scopeTokens.get(scopeIndex);
            }
            if (token.getChannel() != Token.HIDDEN_CHANNEL &&
                    (scopeToken.getChannel() == Token.HIDDEN_CHANNEL || scopeToken.getType() == Token.EOF) ) {
                token.setChannel(Token.HIDDEN_CHANNEL);
            }
        }
        tokenStream.seek(0);
    }
}
