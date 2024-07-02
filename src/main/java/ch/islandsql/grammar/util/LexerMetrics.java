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

/**
 * Representation of lexer metrics
 */
public class LexerMetrics {
    private final long scopeTime;
    private final long scopeMemory;
    private final long time;
    private final long memory;

    /**
     * Constructor.
     *
     * @param scopeTime   Number of nanoseconds spent in the scope lexer.
     * @param scopeMemory Number of bytes used by the scope lexer.
     * @param time        Number of nanoseconds spent in the lexer.
     * @param memory      Number of bytes used by the lexer.
     */
    public LexerMetrics(long scopeTime, long scopeMemory, long time, long memory) {
        this.scopeTime = scopeTime;
        this.scopeMemory = scopeMemory;
        this.time = time;
        this.memory = memory;
    }

    /**
     * Get the number of nanoseconds spent in the scope lexer.
     *
     * @return The number of nanoseconds spent in the scope lexer.
     */
    public long getScopeTime() {
        return scopeTime;
    }

    /**
     * Get the number of bytes used by the scope lexer.
     *
     * @return The number of bytes used by the scope lexer.
     */
    public long getScopeMemory() {
        return scopeMemory;
    }

    /**
     * Get the number of nanoseconds spent in the lexer.
     *
     * @return The number of nanoseconds spent in the lexer.
     */
    public long getTime() {
        return time;
    }

    /**
     * Get the number of bytes used by the lexer.
     *
     * @return The number of bytes used by the lexer.
     */
    public long getMemory() {
        return memory;
    }
}
