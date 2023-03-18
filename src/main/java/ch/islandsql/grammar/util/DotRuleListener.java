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
import org.antlr.v4.runtime.misc.Utils;
import org.antlr.v4.runtime.tree.ErrorNode;
import org.antlr.v4.runtime.tree.ParseTree;
import org.antlr.v4.runtime.tree.ParseTreeListener;
import org.antlr.v4.runtime.tree.TerminalNode;
import org.antlr.v4.runtime.tree.Trees;

import java.util.Arrays;
import java.util.List;

/**
 * Listener to be used to produce a DOT representation of the parse tree.
 * The output can be used to produce a graphical representation of the parse tree
 * via online tools such as <a href="https://dreampuf.github.io/GraphvizOnline/">GraphvizOnline</a>
 * or <a href="http://www.webgraphviz.com/">WebGraphviz</a>.
 */
public class DotRuleListener implements ParseTreeListener {
    private final String NL = System.getProperty("line.separator");
    private final StringBuilder sb = new StringBuilder();
    private final List<String> parserRuleNames;
    private final String CTX_FILL_COLOR="#bfe6ff";
    private final String TERMINAL_FILL_COLOR="#fadabd";
    private int level = 0;

    /**
     * Constructor.
     */
    public DotRuleListener() {
        this.parserRuleNames = Arrays.asList(IslandSqlParser.ruleNames);
    }

    /**
     * Add TerminalNode to the result.
     *
     * @param node TerminalNode.
     */
    @Override
    public void visitTerminal(TerminalNode node) {
        sb.append("  ");
        sb.append('"');
        sb.append(node.hashCode()); // internal instance representation
        sb.append('"');
        sb.append(" [shape=box label=");
        sb.append('"');
        sb.append(node.getText()); // human-readable representation
        sb.append('"');
        sb.append(" style=filled fillcolor=");
        sb.append('"');
        sb.append(TERMINAL_FILL_COLOR);
        sb.append('"');
        sb.append("]");
        sb.append(NL);
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
        if (level == 0) {
            sb.append("digraph islandSQL {");
            sb.append(NL);
        }
        level++;
        sb.append("  ");
        sb.append('"');
        sb.append(ctx.hashCode()); // internal instance representation
        sb.append('"');
        sb.append(" [shape=ellipse label=");
        sb.append('"');
        String labelName = ParseTreeUtil.getLabelName(ctx);
        if (labelName == null) {
            sb.append(Utils.escapeWhitespace(Trees.getNodeText(ctx, parserRuleNames), false));
        } else {
            sb.append(labelName);
        }
        sb.append('"');
        sb.append(" style=filled fillcolor=");
        sb.append('"');
        sb.append(CTX_FILL_COLOR);
        sb.append('"');
        sb.append("]");
        sb.append(NL);
        for (ParseTree parseTree: ctx.children) {
            sb.append("  ");
            sb.append('"');
            sb.append(ctx.hashCode());
            sb.append('"');
            sb.append(" -> ");
            sb.append('"');
            sb.append(parseTree.hashCode());
            sb.append('"');
            sb.append(NL);
        }
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
            sb.append("}");
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
}
