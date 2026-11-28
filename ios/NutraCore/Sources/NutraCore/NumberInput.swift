import Foundation

/// Parses what someone typed into a number field. The decimal keypad shows "," instead of "." in many
/// regions (Germany, France, ...), so both are accepted; values outside `range` or not finite are rejected,
/// which also keeps absurd entries (a 20-digit calorie count) out of the database and away from `Int(_:)`.
public enum NumberInput {
    public static func parse(_ text: String, in range: ClosedRange<Double>) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value.isFinite, range.contains(value) else { return nil }
        return value
    }

    /// Empty is fine (the field is optional); anything typed must parse.
    public static func isValidOptional(_ text: String, in range: ClosedRange<Double>) -> Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty || parse(text, in: range) != nil
    }

    // Upper bounds generous enough for any real food or workout.
    public static let kcal: ClosedRange<Double> = 0...10_000
    public static let grams: ClosedRange<Double> = 0...5_000
    public static let milligrams: ClosedRange<Double> = 0...100_000
    public static let minutes: ClosedRange<Double> = 0...1_440
    public static let kilometers: ClosedRange<Double> = 0...1_000
}
