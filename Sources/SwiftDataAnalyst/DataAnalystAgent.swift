import Foundation
import SwiftDataFrame
import SwiftAgent
import SwiftStats

public struct AnalystResult: Sendable {
    public let originalProfile: String
    public let executedCommands: [String]
    public let finalDataFrame: DataFrame
    public let totalRevenue: Double
    public let averageOrderValue: Double
    public let highValueCustomersCount: Int
}

public final class DataAnalystAgent: Sendable {
    private let evaluator = SwiftAgentEvaluator()
    private let ragGenerator = RAGContextGenerator()

    public init() {}

    public func runAnalysis(df: DataFrame, userQuery: String) async throws -> AnalystResult {
        // 1. Build RAG Context profile
        let profile = ragGenerator.generateSummary(df: df, name: "EcommerceTransactions")

        // 2. Derive Autonomous Multi-Step Tool Pipeline
        var commands: [String] = []
        var currentDF = df

        if userQuery.lowercased().contains("electronics") {
            commands.append("filter category == Electronics")
        } else if userQuery.lowercased().contains("high value") || userQuery.lowercased().contains("vip") {
            commands.append("filter order_value > 300.0")
        } else if userQuery.lowercased().contains("ukraine") || userQuery.lowercased().contains("ua") {
            commands.append("filter country == UA")
        }

        commands.append("select customer_id, category, order_value, churn_risk")

        // 3. Execute Sandboxed Commands via SwiftAgentEvaluator
        for cmd in commands {
            currentDF = try await evaluator.evaluate(command: cmd, on: currentDF)
        }

        // 4. Compute Analytical KPIs
        let orderValues = (currentDF[column: "order_value", as: Double.self]?.values ?? []).compactMap { $0 }
        let totalRev = orderValues.reduce(0, +)
        let avgOrder = orderValues.isEmpty ? 0.0 : totalRev / Double(orderValues.count)
        let highVal = orderValues.filter { $0 >= 400.0 }.count

        return AnalystResult(
            originalProfile: profile,
            executedCommands: commands,
            finalDataFrame: currentDF,
            totalRevenue: totalRev,
            averageOrderValue: avgOrder,
            highValueCustomersCount: highVal
        )
    }
}
