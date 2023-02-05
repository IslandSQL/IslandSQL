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

import org.antlr.v4.runtime.ParserRuleContext;
import org.antlr.v4.runtime.tree.ErrorNode;
import org.antlr.v4.runtime.tree.ParseTree;
import org.antlr.v4.runtime.tree.ParseTreeListener;
import org.antlr.v4.runtime.tree.TerminalNode;

import java.util.ArrayList;
import java.util.List;

/**
 * Listener to be used to find nodes of a desiredType.
 */
public class FindRuleListener implements ParseTreeListener {
    private final List<ParseTree> result;
    private final List<Class<? extends ParseTree>> desiredTypes;

    /**
     * Constructor.
     *
     * @param desiredTypes find nodes of these classes.
     */
    FindRuleListener(List<Class<? extends ParseTree>> desiredTypes) {
        this.result = new ArrayList<>();
        this.desiredTypes = desiredTypes;
    }

    /**
     * Add TerminalNode to result.
     *
     * @param node TerminalNode
     */
    @Override
    public void visitTerminal(TerminalNode node) {
        for (Class<? extends ParseTree> desiredType : desiredTypes) {
            if (desiredType.isInstance(node)) {
                result.add(node);
            }
        }
    }

    /**
     * Add ErrorNode to result.
     *
     * @param node ErrorNode
     */
    @Override
    public void visitErrorNode(ErrorNode node) {
        for (Class<? extends ParseTree> desiredType : desiredTypes) {
            if (desiredType.isInstance(node)) {
                result.add(node);
            }
        }
    }

    /**
     * Add ParserRuleContext to the result.
     *
     * @param ctx ParserRuleContext
     */
    @Override
    public void enterEveryRule(ParserRuleContext ctx) {
        for (Class<? extends ParseTree> desiredType : desiredTypes) {
            if (desiredType.isInstance(ctx)) {
                result.add(ctx);
            }
        }
    }

    /**
     * Not required to produce the result, but must be implemented.
     *
     * @param ctx ParserRuleContext
     */
    @Override
    public void exitEveryRule(ParserRuleContext ctx) {
        // empty implementation
    }

    /**
     * Return the result after walking the parse-tree.
     *
     * @return List of nodes matching the desired class.
     * @param <T> The return type of the result.
     */
    @SuppressWarnings("unchecked")
    public <T extends ParseTree> List<T> getResult() {
        return (List<T>) result;
    }
}
