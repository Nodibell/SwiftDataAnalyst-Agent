import Foundation
import SwiftDataFrame

public enum EcommerceDataGenerator {
    public static func generateDataset(samples: Int = 500, seed: UInt64 = 42) -> DataFrame {
        var rng = SplitMix64(seed: seed)

        let categories = ["Electronics", "Fashion", "Home & Garden", "Books", "Sports"]
        let countries = ["UA", "US", "DE", "PL", "GB"]

        var ids: [Int64] = []
        var ages: [Double] = []
        var countryList: [String] = []
        var categoryList: [String] = []
        var orderValues: [Double] = []
        var churnScores: [Double] = []

        for i in 1...samples {
            let age = 18.0 + Double(rng.next() % 55)
            let country = countries[Int(rng.next() % UInt64(countries.count))]
            let category = categories[Int(rng.next() % UInt64(categories.count))]
            let baseOrder = (category == "Electronics") ? 450.0 : ((category == "Fashion") ? 120.0 : 80.0)
            let orderVal = baseOrder + Double(rng.next() % 200) + Double(rng.next() % 100) / 100.0
            let churn = Double(rng.next() % 100) / 100.0

            ids.append(Int64(1000 + i))
            ages.append(age)
            countryList.append(country)
            categoryList.append(category)
            orderValues.append(round(orderVal * 100) / 100.0)
            churnScores.append(churn)
        }

        return try! DataFrame(columns: [
            TypedColumn(name: "customer_id", values: ids),
            TypedColumn(name: "age", values: ages),
            TypedColumn(name: "country", values: countryList),
            TypedColumn(name: "category", values: categoryList),
            TypedColumn(name: "order_value", values: orderValues),
            TypedColumn(name: "churn_risk", values: churnScores)
        ])
    }
}

private struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}
