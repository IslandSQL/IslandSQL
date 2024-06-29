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
import org.antlr.v4.runtime.atn.DecisionInfo;
import org.antlr.v4.runtime.atn.DecisionState;
import org.antlr.v4.runtime.atn.ParseInfo;

import java.text.DecimalFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Representation of parser metrics.
 */
public class ParserMetrics {
    private final long time;
    private final long memory;
    private final ParseInfo parseInfo;

    /**
     * Constructor.
     *
     * @param time      Number of milliseconds spent in the parser.
     * @param memory    Number of bytes used by the parser.
     * @param parseInfo Statistics gathered during profiling of the parser.
     */
    public ParserMetrics(long time, long memory, ParseInfo parseInfo) {
        this.time = time;
        this.memory = memory;
        this.parseInfo = parseInfo;
    }

    /**
     * Get the number of milliseconds spent in the parser.
     *
     * @return The number of milliseconds spent in the parser.
     */
    public long getTime() {
        return time;
    }

    /**
     * Get the number of bytes used by the parser.
     *
     * @return The number of bytes used by the parser.
     */
    public long getMemory() {
        return memory;
    }

    /**
     * Get the object containing statistics gathered during profiling of the parser.
     *
     * @return The object containing statistics gathered during profiling of the parser.
     */
    public ParseInfo getParseInfo() {
        return parseInfo;
    }

    /**
     * Get the relevant decision information gathered during profiling of the parser.
     * <p>
     * Relevant are entries with a time spent > 0.
     * The entries are sorted by the time spent in descending order.
     * </p>
     *
     * @return The relevant decision information gathered during profiling of the parser.
     */
    public List<DecisionInfo> getRelevantDecisionInfo() {
        if (getParseInfo() == null) {
            return new ArrayList<>();
        } else {
            return Arrays.stream(getParseInfo().getDecisionInfo())
                    .filter(it -> it.timeInPrediction > 0)
                    .sorted((o1, o2) -> Long.compare(o2.timeInPrediction, o1.timeInPrediction))
                    .collect(Collectors.toList());
        }
    }

    /**
     * Get the text report based on the statistics gathered during profiling of the parser.
     *
     * @return The text report based on the statistics gathered during profiling of the parser.
     */
    public String printProfile() {
        DecimalFormat df = new DecimalFormat("###,###,###");
        StringBuilder sb = new StringBuilder();
        sb.append("Profile\n");
        sb.append("=======\n\n");
        sb.append("Total memory used by parser    : ");
        sb.append(df.format(Math.round((float) getMemory() / 1024)));
        sb.append(" KB\n");
        sb.append("Total time spent in parser     : ");
        sb.append(df.format(getTime()));
        sb.append(" ms\n");
        sb.append("Total time recorded by profiler: ");
        sb.append(df.format(getParseInfo() == null ? 0 : Math.round((float) getParseInfo().getTotalTimeInPrediction() / 1000000)));
        sb.append(" ms\n");
        sb.append("\n");
        sb.append("Rule Name (Decision)                     Time (ms) Invocations Lookahead Max Lookahead Ambiguities Errors\n");
        sb.append("---------------------------------------- --------- ----------- --------- ------------- ----------- ------\n");
        for (DecisionInfo info : getRelevantDecisionInfo()) {
            DecisionState ds = IslandSqlParser._ATN.getDecisionState(info.decision);
            String ruleNameAndDecision = IslandSqlParser.ruleNames[ds.ruleIndex] + " (" + info.decision + ")";
            sb.append(String.format("%-40.40s", ruleNameAndDecision));
            sb.append(String.format("%10s", df.format(Math.round((float) info.timeInPrediction / 1000000))));
            sb.append(String.format("%12s", df.format(info.invocations)));
            sb.append(String.format("%10s", df.format(info.LL_TotalLook)));
            sb.append(String.format("%14s", df.format(info.LL_MaxLook)));
            sb.append(String.format("%12s", df.format(info.ambiguities.size())));
            sb.append(String.format("%7s", df.format(info.errors.size())));
            sb.append("\n");
        }
        return sb.toString();
    }
}
