import Foundation

@main
struct SwiftDataAnalystCLI {
    static func main() async {
        print("=================================================================")
        print("🤖 SwiftDataAnalyst-Agent — Autonomous AI Data Intelligence")
        print("Powered by SwiftSci (SwiftAgent, SwiftDataFrame, SwiftDatabase)")
        print("=================================================================\n")

        print("🔄 Ingesting e-commerce transaction logs (500 orders)...")
        let df = EcommerceDataGenerator.generateDataset(samples: 500)
        let agent = DataAnalystAgent()

        let userQuery = "Identify and profile our high value VIP customers in Electronics"
        print("👤 User Natural Language Query:\n   \"\(userQuery)\"\n")

        do {
            let result = try await agent.runAnalysis(df: df, userQuery: userQuery)

            print("📋 Autonomous Agent RAG Context:")
            for line in result.originalProfile.components(separatedBy: "\n") {
                if !line.isEmpty { print("   " + line) }
            }

            print("\n⚙️ Sandboxed AST Execution Trace:")
            for (idx, cmd) in result.executedCommands.enumerated() {
                print("   [\(idx + 1)] SwiftAgentEvaluator -> `\(cmd)`")
            }

            print("\n📊 Segment Analytics:")
            print("   • Filtered Records:     \(result.finalDataFrame.rowCount) customers")
            print("   • Total Segment Gross:  $\(String(format: "%.2f", result.totalRevenue))")
            print("   • Average Order Value:  $\(String(format: "%.2f", result.averageOrderValue))")
            print("   • VIP Order Count:      \(result.highValueCustomersCount)")

            print("\n🔍 Sample Output Rows:")
            print("   +-------------+-------------+--------------+------------+")
            print("   | Customer ID | Category    | Order Value  | Churn Risk |")
            print("   +-------------+-------------+--------------+------------+")
            let nRows = min(5, result.finalDataFrame.rowCount)
            for i in 0..<nRows {
                let cid = result.finalDataFrame[column: "customer_id", as: Int64.self]?[i] ?? 0
                let cat = result.finalDataFrame[column: "category", as: String.self]?[i] ?? ""
                let val = result.finalDataFrame[column: "order_value", as: Double.self]?[i] ?? 0.0
                let churn = result.finalDataFrame[column: "churn_risk", as: Double.self]?[i] ?? 0.0
                print(String(format: "   |  %9d  | %-11s |  $%8.2f   |   %5.1f%%   |", cid, (cat as NSString).utf8String ?? "", val, churn * 100.0))
            }
            print("   +-------------+-------------+--------------+------------+")

            print("\n✅ AI Data Analyst query execution completed successfully!")
        } catch {
            print("❌ Agent failed with error: \(error)")
            exit(1)
        }
    }
}
