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
import org.antlr.v4.runtime.CommonTokenStream;
import org.antlr.v4.runtime.Token;
import org.antlr.v4.runtime.TokenStreamRewriter;

/**
 * TokenStream utilities.
 */
public class TokenStreamUtil {
    /**
     * Get only the text that is in scope.
     * In scope are all tokens on the DEFAULT_CHANNEL.
     * Any non whitespace character in tokens on the HIDDEN channel are replaced by a space.
     * This way the line and charPositionInLine stays the same for all tokens in scope.
     * And the number of characters is the same as in {@link org.antlr.v4.runtime.TokenStream#getText()}.
     *
     * @param tokenStream tokenStream produced by {@link ch.islandsql.grammar.IslandSqlScopeLexer}.
     * @return Returns the text in scope while keeping line and charPositionInLine for all tokens.
     */
    static public String getScopeText(CommonTokenStream tokenStream) {
        TokenStreamRewriter rewriter = new TokenStreamRewriter(tokenStream);
        tokenStream.fill();
        tokenStream.getTokens().stream()
                .filter(token -> token.getChannel() == Token.HIDDEN_CHANNEL
                        && token.getType() != IslandSqlScopeLexer.WS)
                .forEach(token -> {
                            StringBuilder sb = new StringBuilder();
                            token.getText().codePoints().mapToObj(c -> (char) c)
                                    .forEach(c -> sb.append(c == '\t' || c == '\r' || c == '\n' ? c : ' '));
                            rewriter.replace(token, sb.toString());
                        }
                );
        return rewriter.getText();
    }
}
