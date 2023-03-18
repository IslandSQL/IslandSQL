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

import org.antlr.v4.runtime.ParserRuleContext;
import org.antlr.v4.runtime.tree.ParseTree;
import org.antlr.v4.runtime.tree.ParseTreeWalker;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Parse tree utilities.
 */
public class ParseTreeUtil {
    /**
     * Gets all nodes that are instances of the list of desired classes.
     * Start node can be any node in the parse tree.
     *
     * @param parseTree    Start node.
     * @param desiredTypes Desired classes (must be descendants of ParseTree).
     * @return List of nodes that are instances of the of desired class.
     */
    public static List<? extends ParseTree> getAllContentsOfTypes(ParseTree parseTree, List<Class<? extends ParseTree>> desiredTypes) {
        FindRuleListener listener = new FindRuleListener(desiredTypes);
        ParseTreeWalker walker = new ParseTreeWalker();
        int childCount = parseTree.getChildCount();
        for (int i = 0; i < childCount; i++) {
            walker.walk(listener, parseTree.getChild(i));
        }
        return listener.getResult();
    }

    /**
     * Gets all nodes that are instances of the desired class.
     * Start node can be any node in the parse tree.
     *
     * @param parseTree   Start node.
     * @param desiredType Desired class (must be a descendant of ParseTree).
     * @param <T>         The return type of the result.
     * @return List of nodes that are instances of the of desired class.
     */
    @SuppressWarnings("unchecked")
    public static <T extends ParseTree> List<T> getAllContentsOfType(ParseTree parseTree, Class<T> desiredType) {
        List<Class<? extends ParseTree>> desiredTypes = Collections.singletonList(desiredType);
        return (List<T>) getAllContentsOfTypes(parseTree, desiredTypes);
    }

    /**
     * Gets the parent node of the desired class.
     * Start node can be any node in the parse tree.
     *
     * @param parseTree   Start node (child).
     * @param desiredType Desired class (must be a descendant of ParseTree).
     * @param <T>         The return type of the result.
     * @return An instance of the desired class.
     */
    @SuppressWarnings("unchecked")
    public static <T extends ParseTree> T getContainerOfType(ParseTree parseTree, Class<T> desiredType) {
        ParseTree parent = parseTree.getParent();
        while (parent != null) {
            if (desiredType.isInstance(parent)) {
                return (T) parent;
            }
            parent = parent.getParent();
        }
        return null;
    }

    /**
     * Determines if a node is abstract.
     * A node is abstract if it contains the same token as its only child.
     *
     * @param parseTree Node to be checked.
     * @return Returns true if the node is abstract, otherwise false.
     */
    public static boolean isAbstract(ParseTree parseTree) {
        if (parseTree instanceof ParserRuleContext) {
            if (parseTree.getChildCount() == 1) {
                ParseTree child = parseTree.getChild(0);
                return child instanceof ParserRuleContext
                        && ((ParserRuleContext) child).getStart() == ((ParserRuleContext) parseTree).getStart()
                        && ((ParserRuleContext) child).getStop() == ((ParserRuleContext) parseTree).getStop();
            }
        }
        return false;
    }

    /**
     * Gets the most abstract parent node.
     * This is a parent node with the same tokens as the start node.
     *
     * @param parseTree Start node.
     * @return Returns a parent node or the start node.
     */
    public static ParseTree getMostAbstract(ParseTree parseTree) {
        ParserRuleContext result;
        if (parseTree instanceof ParserRuleContext) {
            result = (ParserRuleContext) parseTree;
            while (isAbstract(result.getParent())) {
                result = result.getParent();
            }
            return result;
        }
        return parseTree;
    }

    /**
     * Get the most concrete child node.
     * This is a child with the same tokens as the start node.
     *
     * @param parseTree Start node.
     * @return Returns a child node or the start node.
     */
    public static ParseTree getMostConcrete(ParseTree parseTree) {
        ParserRuleContext result;
        if (parseTree instanceof ParserRuleContext) {
            result = (ParserRuleContext) parseTree;
            while (isAbstract(result)) {
                result = (ParserRuleContext) result.getChild(0);
            }
            return result;
        }
        return parseTree;
    }

    /**
     * Get the previous sibling of the start node.
     * Abstract nodes are treated as non-existent.
     *
     * @param parseTree Start node.
     * @return Returns the most concrete node of the previous sibling. Returns null if the start node is the first child or the start node has no parent.
     */
    public static ParseTree getPreviousSibling(ParseTree parseTree) {
        ParseTree abstractParseTree = getMostAbstract(parseTree);
        ParseTree parent = abstractParseTree.getParent();
        ParseTree previous = null;
        if (parent != null) {
            int childCount = parent.getChildCount();
            for (int i = 0; i < childCount; i++) {
                ParseTree current = parent.getChild(i);
                if (current == abstractParseTree) {
                    return getMostConcrete(previous);
                }
                previous = current;
            }
        }
        return null;
    }

    /**
     * Get the next sibling of the start node.
     * Abstract nodes are treated as non-existent.
     *
     * @param parseTree Start node.
     * @return Returns the most concrete node of the next sibling. Returns null if the start node is the first child or the start node has no parent.
     */
    public static ParseTree getNextSibling(ParseTree parseTree) {
        ParseTree abstractParseTree = getMostAbstract(parseTree);
        ParseTree parent = abstractParseTree.getParent();
        ParseTree next = null;
        if (parent != null) {
            for (int i = parent.getChildCount() - 1; i >= 0; i--) {
                ParseTree current = parent.getChild(i);
                if (current == abstractParseTree) {
                    return getMostConcrete(next);
                }
                next = current;
            }
        }
        return null;
    }

    /**
     * Get all nodes that are an instance of the desired class and a sibling of the start node.
     * Abstract nodes are treated as non-existent.
     *
     * @param parseTree   Start node.
     * @param desiredType Desired class.
     * @param <T>         The return type of the result.
     * @return Returns a list of instances of the desired class that are siblings of the start node.
     */
    @SuppressWarnings("unchecked")
    public static <T extends ParseTree> List<T> getSiblingsOfType(ParseTree parseTree, Class<T> desiredType) {
        List<T> result = new ArrayList<>();
        ParseTree abstractCtx = getMostAbstract(parseTree);
        ParseTree parent = abstractCtx.getParent();
        if (parent != null) {
            int childCount = parent.getChildCount();
            for (int i = 0; i < childCount; i++) {
                ParseTree child = getMostConcrete(parent.getChild(i));
                if (desiredType.isInstance(child)) {
                    result.add((T) child);
                }
            }
        }
        return result;
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
    public static String getLabelName(ParserRuleContext ctx) {
        if (ctx.getClass().getSuperclass().getSimpleName().equals("ParserRuleContext")) {
            return null;
        } else {
            String className = ctx.getClass().getName();
            String labelName = className.substring(className.indexOf("$") + 1, className.lastIndexOf("Context"));
            return Character.toLowerCase(labelName.charAt(0)) + labelName.substring(1);
        }
    }

    /**
     * Produces a hierarchical parse tree as string.
     *
     * @param root The start node.
     * @return Returns a hierarchical parse tree as string.
     */
    public static String printParseTree(ParseTree root) {
        PrintRuleListener listener = new PrintRuleListener();
        ParseTreeWalker walker = new ParseTreeWalker();
        walker.walk(listener, root);
        return listener.getResult();
    }
}
