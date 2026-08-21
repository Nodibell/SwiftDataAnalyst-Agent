import XCTest
import SwiftDataFrame
import SwiftAgent
@testable import SwiftDataAnalyst

final class SwiftDataAnalystTests: XCTestCase {
    func testDatasetGeneration() throws {
        let df = EcommerceDataGenerator.generateDataset(samples: 100)
        XCTAssertEqual(df.shape.rows, 100)
        XCTAssertEqual(df.shape.columns, 6)
    }

    func testAgentQueryAnalysis() async throws {
        let df = EcommerceDataGenerator.generateDataset(samples: 200)
        let agent = DataAnalystAgent()
        let result = try await agent.runAnalysis(df: df, userQuery: "Filter for Electronics category")

        XCTAssertFalse(result.executedCommands.isEmpty)
        XCTAssertGreaterThan(result.finalDataFrame.rowCount, 0)
        XCTAssertLessThanOrEqual(result.finalDataFrame.rowCount, 200)
        XCTAssertGreaterThan(result.totalRevenue, 0.0)
    }
}
