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

import ch.islandsql.grammar.IslandSqlParser;

import java.math.BigInteger;
import java.util.Arrays;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

/**
 * Methods to convert the content of an element of an ParserRuleContext.
 */
public class ConverterUtil {

    /**
     * Converts an {@link IslandSqlParser.ExpressionContext ExpressionContext} instance to a String. Expects the expression to contain
     * a PostgreSQL language definition. Either as a sqlName or as a string.
     *
     * @param language The expression containing a PostgreSQL language.
     * @return A String value in lowercase letters.
     */
    public static String fromLanguage(IslandSqlParser.ExpressionContext language) {
        if (language == null) {
            // the default language in PostgreSQL
            return "plpgsql";
        }
        List<IslandSqlParser.SqlNameContext> sqlNames = ParseTreeUtil.getAllContentsOfType(language, IslandSqlParser.SqlNameContext.class);
        if (sqlNames.size() == 1) {
            return sqlNames.get(0).getText().toLowerCase();
        }
        List<IslandSqlParser.StringContext> strings = ParseTreeUtil.getAllContentsOfType(language, IslandSqlParser.StringContext.class);
        if (strings.size() == 1) {
            return fromString(strings.get(0));
        }
        // fail-safe for unexpected expressions
        return "unknown";
    }

    /**
     * Determines the start of set of an {@link IslandSqlParser.StringContext StringContext} instance.
     *
     * @param str The StringContext input to be converted.
     * @return The start offset of the value in the string.
     */
    public static int startOffsetFromString(IslandSqlParser.StringContext str) {
        if (str == null) {
            return 0;
        }
        if (str instanceof IslandSqlParser.SimpleStringContext
                || str instanceof IslandSqlParser.ConcatenatedStringContext) {
            return 1;
        } else if (str instanceof IslandSqlParser.NationalStringContext
                || str instanceof IslandSqlParser.ConcatenatedNationalStringContext
                || str instanceof IslandSqlParser.EscapedStringContext
                || str instanceof IslandSqlParser.BitStringContext
                || str instanceof IslandSqlParser.DollarStringContext) {
            return 2;
        } else if (str instanceof IslandSqlParser.UnicodeStringContext) {
            return 3;
        } else if (str instanceof IslandSqlParser.QuoteDelimiterStringContext) {
            return 3;
        } else if (str instanceof IslandSqlParser.NationalQuoteDelimiterStringContext) {
            return 4;
        } else if (str instanceof IslandSqlParser.DollarIdentifierStringContext) {
            return str.getText().indexOf("$", 1) + 1;
        }
        // fail-safe for unexpected strings
        return 0;
    }

    /**
     * Converts an {@link IslandSqlParser.StringContext StringContext} instance to a String.
     * The value represents the content of a string as shown as a result of a select statement.
     *
     * @param str The StringContext input to be converted.
     * @return A String value.
     */
    public static String fromString(IslandSqlParser.StringContext str) {
        if (str == null) {
            return "";
        }
        if (str instanceof IslandSqlParser.SimpleStringContext) {
            // example: 'that''s it' -> that's it
            return str.getText().substring(1, str.getText().length() - 1).replace("''", "'");
        } else if (str instanceof IslandSqlParser.NationalStringContext) {
            // example: n'that''s it' -> that's it
            return str.getText().substring(2, str.getText().length() - 1).replace("''", "'");
        } else if (str instanceof IslandSqlParser.ConcatenatedNationalStringContext) {
            // example: n'that''s' ' ' 'it' -> that's it
            IslandSqlParser.ConcatenatedNationalStringContext p = (IslandSqlParser.ConcatenatedNationalStringContext) str;
            return (p.N_STRING().getText().substring(2, p.N_STRING().getText().length() - 1) +
                    p.STRING()
                            .stream()
                            .map(s -> s.getText().substring(1, s.getText().length() - 1))
                            .collect(Collectors.joining())).replace("''", "'");
        } else if (str instanceof IslandSqlParser.EscapedStringContext) {
            // example: e'hello' '\n' 'world' -> hello
            //                                   world
            IslandSqlParser.EscapedStringContext p = (IslandSqlParser.EscapedStringContext) str;
            return (p.E_STRING().getText().substring(2, p.E_STRING().getText().length() - 1) +
                    p.STRING()
                            .stream()
                            .map(s -> s.getText().substring(1, s.getText().length() - 1))
                            .collect(Collectors.joining())).replace("''", "'")
                    .replace("\\t", "\t")
                    .replace("\\b", "\b")
                    .replace("\\n", "\n")
                    .replace("\\r", "\r")
                    .replace("\\f", "\f")
                    .replace("\\'", "'")
                    .replace("\\\"", "\"")
                    .replace("\\\\", "\\");
        } else if (str instanceof IslandSqlParser.UnicodeStringContext) {
            // example1: u&'test: ' '"' '@0441@043B@043E@043D' '"' uescape '@' -> test: "слон"
            // example2: u&'\+01F600' -> 😀
            IslandSqlParser.UnicodeStringContext p = (IslandSqlParser.UnicodeStringContext) str;
            String value = (p.U_AMP_STRING().getText().substring(3, p.U_AMP_STRING().getText().length() - 1) +
                    p.concats
                            .stream()
                            .map(s -> s.getText().substring(1, s.getText().length() - 1))
                            .collect(Collectors.joining()))
                    .replace("''", "'");
            String escapeChar = p.escapeChar == null ? "\\\\" :
                    "\\\\".substring(1) // escaping any char, avoid "Illegal/unsupported escape sequence" in IntelliJ IDEA
                    + p.escapeChar.getText().charAt(1);
            Pattern pattern = Pattern.compile("[" + escapeChar + "][+]?[0-9A-Fa-f]{4,6}");
            Matcher matcher = pattern.matcher(value);
            StringBuffer result = new StringBuffer();
            while (matcher.find()) {
                String hexSequence = matcher.group(0);
                String convertedSequence = Arrays.stream(hexSequence.split(escapeChar))
                        .filter(part -> !part.isEmpty())
                        .map(part -> Integer.parseInt(part.substring(1), 16))
                        .map(Character::toChars)
                        .map(String::valueOf)
                        .collect(Collectors.joining());
                matcher.appendReplacement(result, convertedSequence);
            }
            matcher.appendTail(result);
            return result.toString();
        } else if (str instanceof IslandSqlParser.BitStringContext) {
            // example1: b'1010' '0001' -> 10100001
            // example2: x'a' '1' -> 10100001
            IslandSqlParser.BitStringContext p = (IslandSqlParser.BitStringContext) str;
            String firstSegment = (p.B_STRING() != null ? p.B_STRING() : p.X_STRING()).getText();
            String value = firstSegment.substring(2, firstSegment.length() - 1) +
                    p.STRING()
                            .stream()
                            .map(s -> s.getText().substring(1, s.getText().length() - 1))
                            .collect(Collectors.joining());
            if (value.isEmpty()) {
                return "";
            } else if (p.B_STRING() != null) {
                return value;
            } else {
                return (new BigInteger(value, 16)).toString(2);
            }
        } else if (str instanceof IslandSqlParser.ConcatenatedStringContext) {
            // example: 'that''s' ' ' 'it' -> that's it
            IslandSqlParser.ConcatenatedStringContext p = (IslandSqlParser.ConcatenatedStringContext) str;
            return (p.STRING()
                            .stream()
                            .map(s -> s.getText().substring(1, s.getText().length() - 1))
                            .collect(Collectors.joining())).replace("''", "'");
        } else if (str instanceof IslandSqlParser.QuoteDelimiterStringContext) {
            // example: q'[that's it]' -> that's it
            return str.getText().substring(3, str.getText().length() - 2);
        } else if (str instanceof IslandSqlParser.NationalQuoteDelimiterStringContext) {
            // example: nq'[that's it]' -> that's it
            return str.getText().substring(4, str.getText().length() - 2);
        } else if (str instanceof IslandSqlParser.DollarStringContext) {
            // example: $$that's it$$ -> that's it
            return str.getText().substring(2, str.getText().length() - 2);
        } else if (str instanceof IslandSqlParser.DollarIdentifierStringContext) {
            // example: $example$that's it$example$ -> that's it
            int secondDollarPos = str.getText().indexOf("$", 1);
            return str.getText().substring(secondDollarPos + 1, str.getText().length() - secondDollarPos - 1);
        }
        // fail-safe for unexpected strings
        return str.getText();
    }
}
