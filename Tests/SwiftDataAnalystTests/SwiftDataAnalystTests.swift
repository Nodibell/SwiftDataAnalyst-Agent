import XCTest
import SwiftDataFrame
import SwiftAgent
@testable import SwiftDataAnalyst

final class SwiftDataAnalystTests: XCTestCase {

    func testDataGeneratorSchema() {
        let df = EcommerceDataGenerator.generateDataset(samples: 200, seed: 99)
        XCTAssertEqual(df.rowCount, 200)
        XCTAssertEqual(df.shape.columns, 12)
        XCTAssertTrue(df.columnNames.contains("order_value"))
        XCTAssertTrue(df.columnNames.contains("churn_risk"))
        XCTAssertTrue(df.columnNames.contains("customer_ltv"))
        XCTAssertTrue(df.columnNames.contains("segment"))
    }

    func testDataGeneratorValues() {
        let df = EcommerceDataGenerator.generateDataset(samples: 100, seed: 42)
        let vals = (df[column: "order_value", as: Double.self]?.values ?? []).compactMap { $0 }
        let churn = (df[column: "churn_risk", as: Double.self]?.values ?? []).compactMap { $0 }

        XCTAssertEqual(vals.count, 100)
        for v in vals { XCTAssertGreaterThan(v, 0.0) }
        for c in churn {
            XCTAssertGreaterThanOrEqual(c, 0.0)
            XCTAssertLessThanOrEqual(c, 1.0)
        }
    }

    func testAgentVIPQuery() async throws {
        let df = EcommerceDataGenerator.generateDataset(samples: 300, seed: 42)
        let agent = DataAnalystAgent()
        let result = try await agent.runAnalysis(df: df, userQuery: "high value VIP customers")

        XCTAssertGreaterThan(result.kpis.rowCount, 0)
        XCTAssertGreaterThan(result.kpis.totalRevenue, 0.0)
        // VIP threshold is order_value >= 700 — all returned rows should meet it
        let vals = (result.filteredDataFrame[column: "order_value", as: Double.self]?.values ?? []).compactMap { $0 }
        for v in vals { XCTAssertGreaterThanOrEqual(v, 700.0) }
        XCTAssertFalse(result.lineage.isEmpty)
    }

    func testAgentChurnQuery() async throws {
        let df = EcommerceDataGenerator.generateDataset(samples: 200, seed: 42)
        let agent = DataAnalystAgent()
        let result = try await agent.runAnalysis(df: df, userQuery: "churn risk analysis")

        XCTAssertGreaterThanOrEqual(result.kpis.avgChurnRisk, 0.0)
        XCTAssertLessThanOrEqual(result.kpis.avgChurnRisk, 1.0)
        XCTAssertFalse(result.lineage.isEmpty)
    }

    func testStatisticsToolDirectly() async throws {
        let df = EcommerceDataGenerator.generateDataset(samples: 100, seed: 1)
        let tool = StatisticsTool(dataframe: df)
        let output = try await tool.execute(input: "order_value")
        XCTAssertTrue(output.contains("Mean"))
        XCTAssertTrue(output.contains("Std Dev"))
    }

    func testChurnRiskProfilerDirectly() async throws {
        let df = EcommerceDataGenerator.generateDataset(samples: 150, seed: 7)
        let tool = ChurnRiskProfiler(dataframe: df)
        let output = try await tool.execute(input: "profile")
        XCTAssertTrue(output.contains("Low  Risk"))
        XCTAssertTrue(output.contains("High Risk"))
    }

    func testHTMLDashboardExport() async throws {
        let df = EcommerceDataGenerator.generateDataset(samples: 100, seed: 42)
        let agent = DataAnalystAgent()
        let result = try await agent.runAnalysis(df: df, userQuery: "high value VIP customers")

        let tempPath = NSTemporaryDirectory() + "test_dashboard_\(UUID().uuidString).html"
        try AnalystVisualizer.generateHTMLDashboard(result: result, fullDF: df, outputPath: tempPath)

        XCTAssertTrue(FileManager.default.fileExists(atPath: tempPath))
        let content = try String(contentsOfFile: tempPath)
        XCTAssertTrue(content.contains("Plotly.newPlot"))
        XCTAssertTrue(content.contains("SwiftDataAnalyst"))
        XCTAssertTrue(content.contains("SwiftSci 3.6.0"))
        try? FileManager.default.removeItem(atPath: tempPath)
    }

    func testMultiAgentOrchestratorAnalysis() async throws {
        let df = EcommerceDataGenerator.generateDataset(samples: 200, seed: 42)
        let agent = DataAnalystAgent()
        let result = try await agent.runMultiAgentAnalysis(df: df, userQuery: "high value VIP customers in Electronics")

        XCTAssertGreaterThan(result.messageHistory.count, 3)
        XCTAssertTrue(result.finalAnswer.contains("AI Multi-Agent Consensus Analysis Completed"))
        XCTAssertGreaterThan(result.kpis.rowCount, 0)
        XCTAssertFalse(result.lineage.isEmpty)

        // Verify that specialized agents participated
        let senders = Set(result.messageHistory.map { $0.sender })
        XCTAssertTrue(senders.contains("QuerySpecializedAgent"))
        XCTAssertTrue(senders.contains("StatsSpecializedAgent"))
        XCTAssertTrue(senders.contains("RiskSpecializedAgent"))
        XCTAssertTrue(senders.contains("SynthesisSpecializedAgent"))
    }

    func testMultiAgentChurnAnalysis() async throws {
        let df = EcommerceDataGenerator.generateDataset(samples: 150, seed: 10)
        let agent = DataAnalystAgent()
        let result = try await agent.runMultiAgentAnalysis(df: df, userQuery: "churn risk analysis")

        XCTAssertGreaterThanOrEqual(result.kpis.avgChurnRisk, 0.0)
        XCTAssertLessThanOrEqual(result.kpis.avgChurnRisk, 1.0)
        XCTAssertFalse(result.lineage.isEmpty)
        XCTAssertTrue(result.finalAnswer.contains("AI Multi-Agent Consensus Analysis Completed"))
    }

    func testDataFrameLineageTracking() async throws {
        let df = EcommerceDataGenerator.generateDataset(samples: 100, seed: 99)
        let agent = DataAnalystAgent()
        let result = try await agent.runMultiAgentAnalysis(df: df, userQuery: "VIP customers")

        XCTAssertGreaterThan(result.lineage.count, 0)
        for record in result.lineage {
            XCTAssertGreaterThanOrEqual(record.stepIndex, 0)
            XCTAssertFalse(record.operation.isEmpty)
            XCTAssertGreaterThan(record.inputRows, 0)
        }
    }
}
