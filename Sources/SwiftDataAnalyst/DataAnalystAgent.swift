import Foundation
import SwiftDataFrame
import SwiftAgent
import SwiftStats

// MARK: - Analysis Result Types

public struct SegmentKPIs: Sendable {
    public let rowCount: Int
    public let totalRevenue: Double
    public let averageOrderValue: Double
    public let medianOrderValue: Double
    public let maxOrderValue: Double
    public let vipCount: Int
    public let atRiskCount: Int
    public let avgChurnRisk: Double
    public let avgLTV: Double
    public let topCategory: String
    public let topCountry: String
    public let topChannel: String
}

public struct AgentRunResult: Sendable {
    public let query: String
    public let ragContext: String
    public let executionTrace: [AgentStep]
    public let finalAnswer: String
    public let filteredDataFrame: DataFrame
    public let kpis: SegmentKPIs
}

// MARK: - SQL Query Tool

/// Tool: executes structured SQL-like query commands against the active DataFrame
public struct SQLQueryTool: AgentTool, Sendable {
    public let name: String = "SQLQuery"
    public let description: String = """
        Executes SQL-like commands on the dataset. Supported:
        - filter <col> <op> <val>   (ops: ==, !=, >, <, >=, <=)
        - select <col1>, <col2>, ...
        - groupby <col> <agg>       (agg: sum, mean, min, max, count)
        - head <n>
        - sample <n>
        """
    private let evaluator: SwiftAgentEvaluator
    private var currentDF: DataFrame

    public init(dataframe: DataFrame) {
        self.evaluator = SwiftAgentEvaluator()
        self.currentDF = dataframe
    }

    public func execute(input: String) async throws -> String {
        let result = try await evaluator.evaluate(command: input, on: currentDF)
        let totalRevenue = (result[column: "order_value", as: Double.self]?.values ?? [])
            .compactMap { $0 }.reduce(0, +)

        var out = "📋 Query result: \(result.rowCount) rows\n"
        out += "   Columns: \(result.columnNames.joined(separator: ", "))\n"
        if totalRevenue > 0 {
            out += "   Total revenue in selection: $\(String(format: "%.2f", totalRevenue))\n"
        }
        let preview = min(3, result.rowCount)
        if preview > 0 {
            out += "   Sample: "
            for col in result.columnNames.prefix(3) {
                if let v = result[column: col]?.value(at: 0) {
                    out += "\(col)=\(v) "
                }
            }
        }
        return out
    }
}

// MARK: - Statistics Tool

/// Tool: computes descriptive statistics on a given DataFrame column
public struct StatisticsTool: AgentTool, Sendable {
    public let name: String = "Statistics"
    public let description: String = """
        Computes descriptive statistics for a numeric column.
        Input format: "<column_name>"
        Returns: mean, median, stddev, min, max, percentiles
        """
    private let df: DataFrame

    public init(dataframe: DataFrame) {
        self.df = dataframe
    }

    public func execute(input: String) async throws -> String {
        let col = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let values = (df[column: col, as: Double.self]?.values ?? []).compactMap { $0 }
        guard !values.isEmpty else { return "⚠️ Column '\(col)' not found or has no numeric values." }

        let sorted = values.sorted()
        let mean = values.reduce(0.0, +) / Double(values.count)
        let median: Double
        let n = sorted.count
        if n % 2 == 0 {
            median = (sorted[n/2 - 1] + sorted[n/2]) / 2.0
        } else {
            median = sorted[n/2]
        }
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0.0, +) / Double(n)
        let stddev = variance.squareRoot()
        let p25 = sorted[n / 4]
        let p75 = sorted[3 * n / 4]

        return """
        📊 Statistics for '\(col)' (\(n) records):
           Mean      : \(String(format: "%.2f", mean))
           Median    : \(String(format: "%.2f", median))
           Std Dev   : \(String(format: "%.2f", stddev))
           Min / Max : \(String(format: "%.2f", sorted.first ?? 0)) / \(String(format: "%.2f", sorted.last ?? 0))
           P25 / P75 : \(String(format: "%.2f", p25)) / \(String(format: "%.2f", p75))
        """
    }
}

// MARK: - Churn Risk Profiling Tool

/// Tool: segments customers by churn risk category and computes group statistics
public struct ChurnRiskProfiler: AgentTool, Sendable {
    public let name: String = "ChurnRiskProfiler"
    public let description: String = """
        Profiles customers by churn risk segment (Low/Medium/High) and returns counts and avg LTV.
        Input: any string (e.g., "profile" or "all")
        """
    private let df: DataFrame

    public init(dataframe: DataFrame) {
        self.df = dataframe
    }

    public func execute(input: String) async throws -> String {
        let churn = (df[column: "churn_risk", as: Double.self]?.values ?? []).compactMap { $0 }
        let ltvs = (df[column: "customer_ltv", as: Double.self]?.values ?? []).compactMap { $0 }
        let n = min(churn.count, ltvs.count)

        var low = 0, med = 0, high = 0
        var lowLTV = 0.0, medLTV = 0.0, highLTV = 0.0

        for i in 0..<n {
            if churn[i] < 0.33 { low += 1; lowLTV += ltvs[i] }
            else if churn[i] < 0.66 { med += 1; medLTV += ltvs[i] }
            else { high += 1; highLTV += ltvs[i] }
        }

        let fmt = { (count: Int, total: Double) -> String in
            count > 0 ? String(format: "%.2f", total / Double(count)) : "N/A"
        }

        return """
        🔴 Churn Risk Segmentation (\(n) customers):
           Low  Risk (< 33%) : \(low)  customers · Avg LTV $\(fmt(low, lowLTV))
           Med  Risk (33-66%): \(med)  customers · Avg LTV $\(fmt(med, medLTV))
           High Risk (> 66%) : \(high) customers · Avg LTV $\(fmt(high, highLTV))
        """
    }
}

// MARK: - Orchestration Engine

public final class DataAnalystAgent: Sendable {
    private let ragGenerator = RAGContextGenerator()

    public init() {}

    public func runAnalysis(
        df: DataFrame,
        userQuery: String,
        maxSteps: Int = 4
    ) async throws -> AgentRunResult {
        // 1. Build RAG Context profile (injected into LLM system prompt)
        let profile = ragGenerator.generateSummary(df: df, name: "EcommerceTransactions")

        // 2. Register domain-specific Tools
        let agent = ReActAgent(maxSteps: maxSteps)
        await agent.registerTool(DataFrameAgentTool(dataframe: df))
        await agent.registerTool(SQLQueryTool(dataframe: df))
        await agent.registerTool(StatisticsTool(dataframe: df))
        await agent.registerTool(ChurnRiskProfiler(dataframe: df))

        // 3. Deterministic mock LLM planner — derives action chain from user query
        //    (In production replace this closure with an actual Gemini/GPT API call)
        let query = userQuery.lowercased()
        let (finalAnswer, trace) = try await agent.run(query: userQuery) { prompt in
            // Parse query intent and emit structured ReAct-style response
            if query.contains("vip") || query.contains("high value") {
                return """
                Thought: The user wants to identify VIP and high-value customers. I should first filter the dataset for VIP segment and high order values, then compute statistics on order_value.
                Action: SQLQuery
                Action Input: filter order_value >= 700.0
                """
            } else if query.contains("churn") {
                return """
                Thought: The user wants a churn risk analysis. I should profile the customer base by churn risk level.
                Action: ChurnRiskProfiler
                Action Input: profile
                """
            } else if query.contains("electronics") {
                return """
                Thought: The user wants to analyze the Electronics category. I'll filter for it and then compute order_value statistics.
                Action: SQLQuery
                Action Input: filter category == Electronics
                """
            } else if query.contains("statistic") || query.contains("distribution") || query.contains("revenue") {
                return """
                Thought: The user wants order_value statistics across the full dataset.
                Action: Statistics
                Action Input: order_value
                """
            } else {
                return """
                Thought: General dataset overview requested. I'll sample 10 rows to inspect the data.
                Action: SQLQuery
                Action Input: head 10
                """
            }
        }

        // 4. Execute real DataFrame pipeline based on detected intent
        let evaluator = SwiftAgentEvaluator()
        var filteredDF = df

        if query.contains("vip") || query.contains("high value") {
            filteredDF = try await evaluator.evaluate(command: "filter order_value >= 700.0", on: df)
        } else if query.contains("electronics") {
            filteredDF = try await evaluator.evaluate(command: "filter category == Electronics", on: df)
        } else if query.contains("churn") {
            filteredDF = try await evaluator.evaluate(command: "filter churn_risk >= 0.66", on: df)
        }
        filteredDF = try await evaluator.evaluate(command: "select order_id, customer_id, category, country, channel, order_value, customer_ltv, churn_risk, segment", on: filteredDF)

        // 5. Compute analytical KPIs on the filtered segment
        let kpis = computeKPIs(df: filteredDF, original: df)

        return AgentRunResult(
            query: userQuery,
            ragContext: profile,
            executionTrace: trace,
            finalAnswer: finalAnswer,
            filteredDataFrame: filteredDF,
            kpis: kpis
        )
    }

    private func computeKPIs(df: DataFrame, original: DataFrame) -> SegmentKPIs {
        let values = (df[column: "order_value", as: Double.self]?.values ?? []).compactMap { $0 }
        let ltvs   = (df[column: "customer_ltv", as: Double.self]?.values ?? []).compactMap { $0 }
        let churn  = (df[column: "churn_risk", as: Double.self]?.values ?? []).compactMap { $0 }
        let segs   = (df[column: "segment", as: String.self]?.values ?? []).compactMap { $0 }
        let cats   = (df[column: "category", as: String.self]?.values ?? []).compactMap { $0 }
        let ctrs   = (df[column: "country", as: String.self]?.values ?? []).compactMap { $0 }
        let chns   = (df[column: "channel", as: String.self]?.values ?? []).compactMap { $0 }

        let n = values.count
        let total = values.reduce(0.0, +)
        let avg = n > 0 ? total / Double(n) : 0.0
        let sorted = values.sorted()
        let median = (n > 0) ? (n % 2 == 0 ? (sorted[n/2-1]+sorted[n/2])/2 : sorted[n/2]) : 0.0
        let avgLTV = (ltvs.isEmpty ? 0.0 : ltvs.reduce(0.0, +) / Double(ltvs.count))
        let avgChurn = (churn.isEmpty ? 0.0 : churn.reduce(0.0, +) / Double(churn.count))

        func topKey(_ arr: [String]) -> String {
            var c: [String: Int] = [:]
            for v in arr { c[v, default: 0] += 1 }
            return c.max(by: { $0.value < $1.value })?.key ?? "—"
        }

        return SegmentKPIs(
            rowCount: n,
            totalRevenue: total,
            averageOrderValue: avg,
            medianOrderValue: median,
            maxOrderValue: sorted.last ?? 0.0,
            vipCount: segs.filter { $0 == "VIP" }.count,
            atRiskCount: segs.filter { $0 == "At-Risk" }.count,
            avgChurnRisk: avgChurn,
            avgLTV: avgLTV,
            topCategory: topKey(cats),
            topCountry: topKey(ctrs),
            topChannel: topKey(chns)
        )
    }
}
