import Foundation
import SwiftDataFrame

/// Generates a realistic synthetic e-commerce transaction dataset for AI analyst demonstrations.
public enum EcommerceDataGenerator {
    public static let categories = ["Electronics", "Fashion", "Home & Garden", "Books", "Sports", "Beauty", "Automotive"]
    public static let countries = ["UA", "US", "DE", "PL", "GB", "FR", "CA", "JP"]
    public static let channels = ["Web", "Mobile App", "Marketplace", "Direct Sales"]
    public static let segments = ["New", "Returning", "VIP", "At-Risk"]

    /// Generates a structured e-commerce orders DataFrame with rich analytical features.
    public static func generateDataset(samples: Int = 500, seed: UInt64 = 42) -> DataFrame {
        var rng = SplitMix64(seed: seed)

        var orderIDs: [Int64] = []
        var customerIDs: [Int64] = []
        var ages: [Double] = []
        var countryList: [String] = []
        var channelList: [String] = []
        var categoryList: [String] = []
        var orderValues: [Double] = []
        var discountPcts: [Double] = []
        var unitCounts: [Int64] = []
        var churnScores: [Double] = []
        var ltv: [Double] = []
        var segmentList: [String] = []

        for i in 1...samples {
            let age = 18.0 + Double(rng.next() % 55)
            let country = countries[Int(rng.next() % UInt64(countries.count))]
            let channel = channels[Int(rng.next() % UInt64(channels.count))]
            let category = categories[Int(rng.next() % UInt64(categories.count))]
            let units = Int64(1 + rng.next() % 6)

            let basePricePerUnit: Double
            switch category {
            case "Electronics": basePricePerUnit = 280.0 + Double(rng.next() % 500)
            case "Fashion":     basePricePerUnit = 50.0  + Double(rng.next() % 150)
            case "Automotive":  basePricePerUnit = 120.0 + Double(rng.next() % 300)
            case "Beauty":      basePricePerUnit = 25.0  + Double(rng.next() % 80)
            default:            basePricePerUnit = 30.0  + Double(rng.next() % 100)
            }

            let discount = Double(rng.next() % 30) / 100.0  // 0–29% discount
            let orderVal = round(Double(units) * basePricePerUnit * (1.0 - discount) * 100.0) / 100.0
            let churnRisk = Double(rng.next() % 100) / 100.0
            let customerLTV = round((orderVal * (1.0 + Double(rng.next() % 5))) * 100.0) / 100.0

            // Segment assignment
            let segment: String
            if churnRisk > 0.75 { segment = "At-Risk" }
            else if orderVal > 700.0 { segment = "VIP" }
            else if rng.next() % 3 == 0 { segment = "New" }
            else { segment = "Returning" }

            orderIDs.append(Int64(10000 + i))
            customerIDs.append(Int64(1000 + i))
            ages.append(age)
            countryList.append(country)
            channelList.append(channel)
            categoryList.append(category)
            orderValues.append(orderVal)
            discountPcts.append(round(discount * 100.0) / 100.0)
            unitCounts.append(units)
            churnScores.append(churnRisk)
            ltv.append(customerLTV)
            segmentList.append(segment)
        }

        return try! DataFrame(columns: [
            TypedColumn(name: "order_id",      values: orderIDs),
            TypedColumn(name: "customer_id",   values: customerIDs),
            TypedColumn(name: "age",           values: ages),
            TypedColumn(name: "country",       values: countryList),
            TypedColumn(name: "channel",       values: channelList),
            TypedColumn(name: "category",      values: categoryList),
            TypedColumn(name: "units",         values: unitCounts),
            TypedColumn(name: "order_value",   values: orderValues),
            TypedColumn(name: "discount_pct",  values: discountPcts),
            TypedColumn(name: "churn_risk",    values: churnScores),
            TypedColumn(name: "customer_ltv",  values: ltv),
            TypedColumn(name: "segment",       values: segmentList)
        ])
    }
}

struct SplitMix64: Sendable {
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
