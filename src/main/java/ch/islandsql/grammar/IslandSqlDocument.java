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

import org.antlr.v4.runtime.CharStreams;
import org.antlr.v4.runtime.CodePointCharStream;
import org.antlr.v4.runtime.CommonTokenStream;
import org.antlr.v4.runtime.tree.ParseTree;
import org.antlr.v4.runtime.tree.ParseTreeWalker;

import java.util.List;

public class IslandSqlDocument {
    private final CommonTokenStream tokenStream;
    private final IslandSqlParser.FileContext file;

    private IslandSqlDocument(String sql) {
        CodePointCharStream charStream = CharStreams.fromString(sql);
        IslandSqlLexer lexer = new IslandSqlLexer(charStream);
        this.tokenStream = new CommonTokenStream(lexer);
        IslandSqlParser parser = new IslandSqlParser(tokenStream);
        this.file = parser.file();
    }

    public static IslandSqlDocument parse(String sql) {
        return new IslandSqlDocument(sql);
    }

    public CommonTokenStream getTokenStream() {
        return tokenStream;
    }

    public IslandSqlParser.FileContext getFile() {
        return file;
    }

    public <T extends ParseTree> List<T> getAllContentsOfType(ParseTree parseTree, Class<T> desiredType) {
        FindRuleListener listener = new FindRuleListener(desiredType);
        ParseTreeWalker walker = new ParseTreeWalker();
        walker.walk(listener, parseTree);
        return listener.getResult();
    }
    public <T extends ParseTree> List<T> getAllContentsOfType(Class<T> desiredType) {
        return getAllContentsOfType(file, desiredType);
    }
}
