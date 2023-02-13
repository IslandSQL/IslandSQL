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

import ch.islandsql.grammar.IslandSqlParser;
import org.antlr.v4.runtime.ParserRuleContext;
import org.antlr.v4.runtime.Vocabulary;
import org.antlr.v4.runtime.misc.Utils;
import org.antlr.v4.runtime.tree.ErrorNode;
import org.antlr.v4.runtime.tree.ParseTreeListener;
import org.antlr.v4.runtime.tree.TerminalNode;
import org.antlr.v4.runtime.tree.Trees;

import java.util.Arrays;
import java.util.List;

/**
 * Listener to be used to produce a hierarchical representation of the parse tree.
 */
public class PrintRuleListener implements ParseTreeListener {
    private final String NL = System.getProperty("line.separator");
    private final StringBuilder sb = new StringBuilder();
    private final List<String> parserRuleNames;
    private final Vocabulary vocabulary;
    private int level = 0;

    /**
     * Constructor.
     */
    public PrintRuleListener() {
        this.parserRuleNames = Arrays.asList(IslandSqlParser.ruleNames);
        this.vocabulary = IslandSqlParser.VOCABULARY;
    }

    /**
     * Add TerminalNode to the result.
     * Emits the type name of a symbol, followed by colon, followed by the value
     *
     * @param node TerminalNode.
     */
    @Override
    public void visitTerminal(TerminalNode node) {
        printNewLineAndIndent();
        int type = node.getSymbol().getType();
        if (type >= 0) {
            // all symbols except EOF
            sb.append(vocabulary.getSymbolicName(node.getSymbol().getType()));
            sb.append(":");
        }
        sb.append(Utils.escapeWhitespace(Trees.getNodeText(node, parserRuleNames), false));
    }

    /**
     * Not required to produce the result, but must be implemented.
     *
     * @param node ErrorNode.
     */
    @Override
    public void visitErrorNode(ErrorNode node) {
        // empty implementation
    }

    /**
     * Add ParserRuleContext to the result.
     * Every call increases the indentation by 1.
     * Emits the rule name, followed by a colon, followed by the label name (alternative)
     * Emits only the rule name if no label name is defined.
     *
     * @param ctx ParserRuleContext.
     */
    @Override
    public void enterEveryRule(ParserRuleContext ctx) {
        printNewLineAndIndent();
        String labelName = getLabelName(ctx);
        if (labelName == null) {
            sb.append(Utils.escapeWhitespace(Trees.getNodeText(ctx, parserRuleNames), false));
        } else {
            sb.append(parserRuleNames.get(ctx.getRuleIndex()));
            sb.append(":");
            sb.append(labelName);
        }
        level++;
    }

    /**
     * Every call decreases the indentation by 1.
     *
     * @param ctx ParseRuleContext.
     */
    @Override
    public void exitEveryRule(ParserRuleContext ctx) {
        level--;
        if (level == 0) {
            sb.append(NL);
        }
    }

    /**
     * Return the result after walking the parse-tree.
     *
     * @return Hierarchical representation of the parse tree as string.
     */
    public String getResult() {
        return sb.toString();
    }

    /**
     * Adds a new line and two characters per indentation level.
     */
    private void printNewLineAndIndent() {
        if (level > 0) {
            sb.append(NL);
        }
        for (int i=0; i<level; i++) {
            sb.append("  ");
        }
    }

    /**
     * Gets the label name of an alternative.
     * If an alternative is labeld with "#someLabel" in the grammar, then
     * a subclass named "IslandSqlParser$SomeLabelContext" of another
     * rule class (not ParserRuleContext) is created.
     *
     * @param ctx ParserRuleContext to get the alternative label name from.
     * @return Returns the label name or null, if no label is defined.
     */
    private String getLabelName(ParserRuleContext ctx) {
        if (ctx.getClass().getSuperclass().getSimpleName().equals("ParserRuleContext")) {
            return null;
        } else {
            String className = ctx.getClass().getName();
            String labelName = className.substring(className.indexOf("$") + 1, className.lastIndexOf("Context"));
            return Character.toLowerCase(labelName.charAt(0)) + labelName.substring(1);
        }
    }
}
