import Foundation
import SwiftVisualization

public enum AnalystVisualizer {

    /// Generates an interactive Plotly HTML dashboard for the analyst session
    public static func generateHTMLDashboard(
        result: AgentRunResult,
        fullDF: DataFrame,
        outputPath: String
    ) throws {
        let kpis = result.kpis

        // Revenue by category (from full dataset)
        let cats = EcommerceDataGenerator.categories
        var catRevenue: [String: Double] = [:]
        for cat in cats { catRevenue[cat] = 0.0 }
        let dfCats = (fullDF[column: "category", as: String.self]?.values ?? []).compactMap { $0 }
        let dfVals = (fullDF[column: "order_value", as: Double.self]?.values ?? []).compactMap { $0 }
        for i in 0..<min(dfCats.count, dfVals.count) {
            catRevenue[dfCats[i], default: 0.0] += dfVals[i]
        }
        let catLabels = cats.map { "\"\($0)\"" }.joined(separator: ",")
        let catValues = cats.map { String(format: "%.0f", catRevenue[$0] ?? 0.0) }.joined(separator: ",")

        // Churn risk distribution buckets
        let churnVals = (fullDF[column: "churn_risk", as: Double.self]?.values ?? []).compactMap { $0 }
        var low = 0, med = 0, high = 0
        for v in churnVals {
            if v < 0.33 { low += 1 } else if v < 0.66 { med += 1 } else { high += 1 }
        }

        // Segment distribution
        let segVals = (fullDF[column: "segment", as: String.self]?.values ?? []).compactMap { $0 }
        var segCounts: [String: Int] = ["New": 0, "Returning": 0, "VIP": 0, "At-Risk": 0]
        for s in segVals { segCounts[s, default: 0] += 1 }
        let segLabels = segCounts.keys.map { "\"\($0)\"" }.joined(separator: ",")
        let segValues = segCounts.values.map { "\($0)" }.joined(separator: ",")

        let traceSteps = result.executionTrace.map { step -> String in
            let action = step.action.map { " → \($0)" } ?? ""
            return "<li><b>Thought:</b> \(step.thought)\(action)</li>"
        }.joined(separator: "\n")

        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <title>🤖 SwiftDataAnalyst-Agent — AI E-Commerce Intelligence</title>
            <script src="https://cdn.plot.ly/plotly-2.35.2.min.js"></script>
            <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
            <style>
                :root {
                    --bg: #0d1117; --card: #161b22; --border: #30363d;
                    --text: #f0f6fc; --sub: #8b949e;
                    --cyan: #58a6ff; --green: #3fb950; --amber: #d29922;
                    --purple: #bc8cff; --red: #f85149;
                }
                * { box-sizing: border-box; margin: 0; padding: 0; }
                body { background: var(--bg); color: var(--text); font-family: 'Inter', sans-serif; padding: 24px; }
                .header { border-bottom: 1px solid var(--border); padding-bottom: 16px; margin-bottom: 24px; display: flex; justify-content: space-between; align-items: center; }
                h1 { font-size: 22px; font-weight: 700; color: var(--cyan); }
                .sub { font-size: 13px; color: var(--sub); margin-top: 4px; }
                .badge { background: #1f2937; border: 1px solid var(--border); padding: 6px 14px; border-radius: 20px; font-size: 12px; color: var(--green); font-weight: 600; }
                .kpi-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 14px; margin-bottom: 24px; }
                .kpi { background: var(--card); border: 1px solid var(--border); border-radius: 8px; padding: 14px; }
                .kpi-label { font-size: 11px; text-transform: uppercase; color: var(--sub); font-weight: 600; letter-spacing: 0.5px; }
                .kpi-value { font-size: 22px; font-weight: 700; margin-top: 6px; }
                .kpi-hint { font-size: 11px; color: var(--sub); margin-top: 3px; }
                .charts-row { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 18px; margin-bottom: 24px; }
                @media (max-width: 1000px) { .charts-row { grid-template-columns: 1fr; } }
                .chart-card { background: var(--card); border: 1px solid var(--border); border-radius: 8px; padding: 18px; }
                .react-trace { background: var(--card); border: 1px solid var(--border); border-radius: 8px; padding: 18px; margin-bottom: 24px; }
                .react-trace h3 { font-size: 14px; font-weight: 600; color: var(--amber); margin-bottom: 12px; }
                .react-trace .query { font-size: 14px; color: var(--cyan); background: #0d1117; border: 1px solid var(--border); border-radius: 6px; padding: 10px 14px; margin-bottom: 12px; }
                .react-trace ol { padding-left: 20px; }
                .react-trace li { font-size: 13px; color: var(--text); margin-bottom: 8px; line-height: 1.5; }
                .final-answer { background: #0d261a; border: 1px solid #3fb950; border-radius: 8px; padding: 14px 18px; margin-top: 12px; font-size: 14px; color: var(--green); }
                .footer { text-align: center; font-size: 12px; color: var(--sub); margin-top: 32px; }
            </style>
        </head>
        <body>
            <div class="header">
                <div>
                    <h1>🤖 SwiftDataAnalyst-Agent — AI E-Commerce Intelligence</h1>
                    <p class="sub">Autonomous ReAct Agent · DataFrameAgentTool · SQLQueryTool · StatisticsTool · ChurnRiskProfiler</p>
                </div>
                <div class="badge">⚡ SwiftSci 3.5.0 · SwiftAgent</div>
            </div>

            <div class="kpi-grid">
                <div class="kpi">
                    <div class="kpi-label">Segment Records</div>
                    <div class="kpi-value" style="color:var(--cyan)">\(kpis.rowCount)</div>
                    <div class="kpi-hint">Orders in query result</div>
                </div>
                <div class="kpi">
                    <div class="kpi-label">Total Revenue</div>
                    <div class="kpi-value" style="color:var(--green)">$\(String(format: "%.0f", kpis.totalRevenue))</div>
                    <div class="kpi-hint">Gross Merchandise Value</div>
                </div>
                <div class="kpi">
                    <div class="kpi-label">Avg Order Value</div>
                    <div class="kpi-value" style="color:var(--green)">$\(String(format: "%.0f", kpis.averageOrderValue))</div>
                    <div class="kpi-hint">Mean AOV in segment</div>
                </div>
                <div class="kpi">
                    <div class="kpi-label">Median AOV</div>
                    <div class="kpi-value" style="color:var(--cyan)">$\(String(format: "%.0f", kpis.medianOrderValue))</div>
                    <div class="kpi-hint">P50 order value</div>
                </div>
                <div class="kpi">
                    <div class="kpi-label">VIP Customers</div>
                    <div class="kpi-value" style="color:var(--purple)">\(kpis.vipCount)</div>
                    <div class="kpi-hint">AOV ≥ $700</div>
                </div>
                <div class="kpi">
                    <div class="kpi-label">At-Risk Customers</div>
                    <div class="kpi-value" style="color:var(--red)">\(kpis.atRiskCount)</div>
                    <div class="kpi-hint">Churn risk > 75%</div>
                </div>
                <div class="kpi">
                    <div class="kpi-label">Avg Churn Risk</div>
                    <div class="kpi-value" style="color:var(--amber)">\(String(format: "%.1f", kpis.avgChurnRisk * 100))%</div>
                    <div class="kpi-hint">Mean churn probability</div>
                </div>
                <div class="kpi">
                    <div class="kpi-label">Avg Customer LTV</div>
                    <div class="kpi-value" style="color:var(--cyan)">$\(String(format: "%.0f", kpis.avgLTV))</div>
                    <div class="kpi-hint">Lifetime value estimate</div>
                </div>
            </div>

            <div class="react-trace">
                <h3>⚙️ ReAct Agent Reasoning Trace</h3>
                <div class="query">💬 Query: "\(result.query)"</div>
                <ol>
                    \(traceSteps.isEmpty ? "<li>Direct answer returned (no tool call required)</li>" : traceSteps)
                </ol>
                <div class="final-answer">✅ Final Answer: \(result.finalAnswer.isEmpty ? "Analysis completed. See KPI dashboard above." : result.finalAnswer)</div>
            </div>

            <div class="charts-row">
                <div class="chart-card"><div id="revenueChart" style="height:300px"></div></div>
                <div class="chart-card"><div id="churnChart" style="height:300px"></div></div>
                <div class="chart-card"><div id="segChart" style="height:300px"></div></div>
            </div>

            <div class="footer">
                Generated with <b>SwiftDataAnalyst-Agent</b> powered by <b>SwiftSci 3.5.0</b> · ReActAgent · DataFrameAgentTool · SwiftStats
            </div>

            <script>
                const DARK = '#161b22'; const BORDER = '#30363d';

                Plotly.newPlot('revenueChart', [{
                    x: [\(catLabels)], y: [\(catValues)],
                    type: 'bar', marker: { color: '#58a6ff' }
                }], {
                    title: { text: '<b>Revenue by Category</b>', font: { color: '#f0f6fc', size: 14 } },
                    paper_bgcolor: DARK, plot_bgcolor: DARK,
                    xaxis: { color: '#8b949e', gridcolor: BORDER },
                    yaxis: { title: 'Revenue ($)', color: '#8b949e', gridcolor: BORDER },
                    margin: { t: 40, b: 60, l: 60, r: 20 }
                }, { responsive: true });

                Plotly.newPlot('churnChart', [{
                    labels: ['Low Risk', 'Medium Risk', 'High Risk'],
                    values: [\(low), \(med), \(high)],
                    type: 'pie',
                    marker: { colors: ['#3fb950', '#d29922', '#f85149'] },
                    textinfo: 'label+percent'
                }], {
                    title: { text: '<b>Churn Risk Distribution</b>', font: { color: '#f0f6fc', size: 14 } },
                    paper_bgcolor: DARK, plot_bgcolor: DARK,
                    legend: { font: { color: '#f0f6fc' } },
                    margin: { t: 40, b: 20, l: 20, r: 20 }
                }, { responsive: true });

                Plotly.newPlot('segChart', [{
                    x: [\(segLabels)], y: [\(segValues)],
                    type: 'bar',
                    marker: { color: ['#58a6ff', '#3fb950', '#bc8cff', '#f85149'] }
                }], {
                    title: { text: '<b>Customer Segment Breakdown</b>', font: { color: '#f0f6fc', size: 14 } },
                    paper_bgcolor: DARK, plot_bgcolor: DARK,
                    xaxis: { color: '#8b949e', gridcolor: BORDER },
                    yaxis: { title: 'Count', color: '#8b949e', gridcolor: BORDER },
                    margin: { t: 40, b: 60, l: 60, r: 20 }
                }, { responsive: true });
            </script>
        </body>
        </html>
        """

        let url = URL(fileURLWithPath: outputPath)
        try html.write(to: url, atomically: true, encoding: .utf8)
    }
}
