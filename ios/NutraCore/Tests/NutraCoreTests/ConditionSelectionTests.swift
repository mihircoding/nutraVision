import XCTest
@testable import NutraCore

/// "No condition" must never shadow a real condition as the primary one.
final class ConditionSelectionTests: XCTestCase {
  func testNormalized() {
    XCTAssertEqual(ConditionCatalog.normalized([]), ["general"])
    XCTAssertEqual(ConditionCatalog.normalized(["general"]), ["general"])
    XCTAssertEqual(ConditionCatalog.normalized(["general", "ckd"]), ["ckd"])
    XCTAssertEqual(ConditionCatalog.normalized(["ckd", "general", "ckd", "hypertension"]), ["ckd", "hypertension"])
  }

  func testPrimary() {
    XCTAssertEqual(ConditionCatalog.primaryId(["general", "ckd"]), "ckd")
    XCTAssertEqual(ConditionCatalog.primaryId([]), "general")
  }

  func testToggling() {
    // A new profile is ["general"]; the first pick replaces it and becomes primary.
    XCTAssertEqual(ConditionCatalog.toggling("ckd", in: ["general"]), ["ckd"])
    XCTAssertEqual(ConditionCatalog.toggling("hypertension", in: ["ckd"]), ["ckd", "hypertension"])
    XCTAssertEqual(ConditionCatalog.toggling("ckd", in: ["ckd", "hypertension"]), ["hypertension"])
    XCTAssertEqual(ConditionCatalog.toggling("ckd", in: ["ckd"]), ["general"])  // last one off -> none
    XCTAssertEqual(ConditionCatalog.toggling("general", in: ["ckd", "hypertension"]), ["general"])
  }

  func testTargetsIgnoreLeftoverGeneral() {
    let stats = BodyStats(sex: .male, birthDate: ISO8601DateFormatter().date(from: "1996-01-15T12:00:00Z"),
                          heightCm: 180, weightKg: 80, activity: .moderate)
    let now = ISO8601DateFormatter().date(from: "2026-11-04T12:00:00Z")!
    let withGeneral = TargetCalculator.targets(stats: stats, conditionIds: ["general", "ckd"], weeklyRateKg: 0, now: now)
    let ckdOnly = TargetCalculator.targets(stats: stats, conditionIds: ["ckd"], weeklyRateKg: 0, now: now)
    XCTAssertEqual(withGeneral, ckdOnly)
  }
}
