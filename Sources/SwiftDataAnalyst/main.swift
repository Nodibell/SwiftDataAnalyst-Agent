import Foundation
import ArgumentParser
import SwiftDataFrame

@main
struct SwiftDataAnalystCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "data-analyst",
        abstract: "🤖 SwiftDataAnalyst-Agent — Autonomous AI-Powered E-Commerce Data Intelligence CLI",
        version: "3.5.0"
    )

    @Option(help: "Number of synthetic e-commerce orders to generate (default: 500)")
    var samples: Int = 500

    @Option(help: "Natural language query for the AI analyst agent (default: VIP high-value analysis)")
    var query: String = "Identify and profile our high value VIP customers in Electronics"

    @Option(name: .long, help: "Path to export interactive Plotly HTML dashboard (e.g. analyst_report.html)")
    var exportHtml: String?

    @Option(name: .long, help: "Path to export transaction dataset in Parquet format")
    var exportParquet: String?

    @Option(name: .long, help: "Path to export transaction dataset in CSV format")
    var exportCsv: String?

    func run() async throws {
        print("╔══════════════════════════════════════════════════════════════════════╗")
        print("║  🤖 SwiftDataAnalyst-Agent — Autonomous AI E-Commerce Intelligence   ║")
        print("║  Powered by SwiftSci 3.5.0 · SwiftAgent ReAct · SwiftDataFrame       ║")
        print("╚══════════════════════════════════════════════════════════════════════╝\n")

        print("📦 Ingesting e-commerce transaction dataset (\(samples) orders, 12 features)...")
        let df = EcommerceDataGenerator.generateDataset(samples: samples)

        print("📋 Dataset Schema:")
        print("   Columns: \(df.columnNames.joined(separator: ", "))")
        print("   Shape  : \(df.rowCount) rows × \(df.shape.columns) columns")

        print("\n💬 User Query: \"\(query)\"")
        print("🔄 Initializing autonomous ReAct agent with 4 registered tools...\n")

        let agent = DataAnalystAgent()
        let result = try await agent.runAnalysis(df: df, userQuery: query)

        // Print RAG Context summary
        print("📋 RAG Context Profile (injected into LLM system prompt):")
        for line in result.ragContext.components(separatedBy: "\n") {
            if !line.isEmpty { print("   \(line)") }
        }

        // Print ReAct Trace
        print("\n⚙️ ReAct Agent Execution Trace:")
        for (idx, step) in result.executionTrace.enumerated() {
            print("   [\(idx + 1)] Thought  : \(step.thought.prefix(120))")
            if let action = step.action, let input = step.actionInput {
                print("       Action   : \(action)")
                print("       Input    : \(input)")
            }
            if let obs = step.observation {
                let trimmed = obs.prefix(200).trimmingCharacters(in: .whitespacesAndNewlines)
                print("       Observe  : \(trimmed)")
            }
        }

        // Print KPI Dashboard
        let kpis = result.kpis
        print("\n📊 Segment KPI Dashboard:")
        print("   ┌────────────────────────────────────────────────────────────┐")
        print("   │  Matched Orders        : \(kpis.rowCount) records")
        print("   │  Total Segment Revenue : $\(String(format: "%.2f", kpis.totalRevenue))")
        print("   │  Average Order Value   : $\(String(format: "%.2f", kpis.averageOrderValue))")
        print("   │  Median Order Value    : $\(String(format: "%.2f", kpis.medianOrderValue))")
        print("   │  Max Order Value       : $\(String(format: "%.2f", kpis.maxOrderValue))")
        print("   ├────────────────────────────────────────────────────────────┤")
        print("   │  VIP Customers         : \(kpis.vipCount)")
        print("   │  At-Risk Customers     : \(kpis.atRiskCount)")
        print("   │  Avg Churn Risk        : \(String(format: "%.1f", kpis.avgChurnRisk * 100.0))%")
        print("   │  Avg Customer LTV      : $\(String(format: "%.2f", kpis.avgLTV))")
        print("   ├────────────────────────────────────────────────────────────┤")
        print("   │  Top Category          : \(kpis.topCategory)")
        print("   │  Top Country           : \(kpis.topCountry)")
        print("   │  Top Sales Channel     : \(kpis.topChannel)")
        print("   └────────────────────────────────────────────────────────────┘")

        // Sample rows
        let nr = min(5, result.filteredDataFrame.rowCount)
        if nr > 0 {
            print("\n🔍 Sample Segment Records (\(nr) of \(result.filteredDataFrame.rowCount)):")
            print("   +----------+-------------+--------------+-------+------------------+------------+")
            print("   | Order ID | Category    | Country      | Chan  | Order Value ($)  | Churn Risk |")
            print("   +----------+-------------+--------------+-------+------------------+------------+")
            for i in 0..<nr {
                let oid  = result.filteredDataFrame[column: "order_id",    as: Int64.self]?[i]  ?? 0
                let cat  = result.filteredDataFrame[column: "category",    as: String.self]?[i] ?? ""
                let ctr  = result.filteredDataFrame[column: "country",     as: String.self]?[i] ?? ""
                let chn  = result.filteredDataFrame[column: "channel",     as: String.self]?[i] ?? ""
                let val  = result.filteredDataFrame[column: "order_value", as: Double.self]?[i] ?? 0.0
                let churn = result.filteredDataFrame[column: "churn_risk", as: Double.self]?[i] ?? 0.0
                print(String(format: "   | %8d | %-11s | %-12s | %-5s | %16.2f | %9.1f%% |",
                    oid, (cat as NSString).utf8String!, (ctr as NSString).utf8String!,
                    (chn as NSString).utf8String!, val, churn * 100.0))
            }
            print("   +----------+-------------+--------------+-------+------------------+------------+")
        }

        // Export HTML Dashboard
        let htmlPath = exportHtml ?? "analyst_dashboard.html"
        try AnalystVisualizer.generateHTMLDashboard(result: result, fullDF: df, outputPath: htmlPath)
        print("\n📊 Interactive Plotly HTML Dashboard generated at: \(htmlPath)")

        if let parquetPath = exportParquet {
            try await df.writeParquet(to: URL(fileURLWithPath: parquetPath))
            print("💾 Dataset exported to Parquet: \(parquetPath)")
        }

        if let csvPath = exportCsv {
            try await df.writeCSV(to: URL(fileURLWithPath: csvPath))
            print("📄 Dataset exported to CSV: \(csvPath)")
        }

        print("\n✅ AI Data Analyst query execution completed successfully!")
    }
}
