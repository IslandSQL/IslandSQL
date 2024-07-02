/*
 * Copyright 2024 Philipp Salvisberg <philipp.salvisberg@gmail.com>
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

import ch.islandsql.grammar.IslandSqlLexer;
import ch.islandsql.grammar.IslandSqlParser;
import org.antlr.v4.runtime.CharStreams;
import org.antlr.v4.runtime.CommonTokenStream;
import org.antlr.v4.runtime.atn.PredictionContextCache;

import java.lang.reflect.Field;
import java.util.Map;

/**
 * Shared caches used by all lexer and parser instances.
 * Provides methods to clear all or chosen caches to reduce memory consumption.
 * Clearing caches has a negative effect on the runtime performance.
 */
public class SharedCache {
    private final IslandSqlLexer lexer;
    private final IslandSqlParser parser;

    /**
     * Constructor.
     */
    public SharedCache() {
        this.lexer = new IslandSqlLexer(CharStreams.fromString(""));
        this.parser = new IslandSqlParser(new CommonTokenStream(this.lexer));
    }

    /**
     * Clear shared DFA caches and shared context caches used by all lexer and parser instances.
     */
    public void clearAll() {
        clearDFA();
        clearPredictionContextCaches();
    }

    /**
     * Clear shared DFA caches used by all lexer and parser instances.
     */
    public void clearDFA() {
        clearLexerDFA();
        clearParserDFA();
    }

    /**
     * Clear shared prediction context caches used by all lexer and parser instances.
     */
    public void clearPredictionContextCaches() {
        clearLexerSharedContext();
        clearParserSharedContext();
    }

    /**
     * Clear shared DFA cache used by all lexer instances.
     */
    public void clearLexerDFA() {
        lexer.getInterpreter().clearDFA();
    }

    /**
     * Clear shared DFA cache used by all parser instances.
     */
    public void clearParserDFA() {
        parser.getInterpreter().clearDFA();
    }

    /**
     * Clears the cache of a PredictionContextCache instance.
     * Uses reflection to access protected field {@link PredictionContextCache#cache}.
     *
     * @param predictionContextCache Instance of the PredictionContext cache to be cleared.
     */
    private void clearPredictionContextCache(PredictionContextCache predictionContextCache) {
        try {
            Field cacheField = PredictionContextCache.class.getDeclaredField("cache");
            cacheField.setAccessible(true);
            Map<?, ?> cache = (Map<?, ?>) cacheField.get(predictionContextCache);
            cache.clear();
        } catch (NoSuchFieldException | IllegalAccessException e) {
            throw new RuntimeException(e);
        }
    }

    /**
     * Clear shared context cache used by all lexer instances.
     */
    public void clearLexerSharedContext() {
        clearPredictionContextCache(lexer.getInterpreter().getSharedContextCache());
    }

    /**
     * Clear shared context cache used by all parser instances.
     */
    public void clearParserSharedContext() {
        clearPredictionContextCache(parser.getInterpreter().getSharedContextCache());
    }
}
