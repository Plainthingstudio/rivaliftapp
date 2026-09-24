import Foundation

/// Converts between kilograms (storage) and the user's display unit (SET-01).
enum UnitConverter {
    static let kgPerLb = 0.45359237

    static func toKg(_ value: Double, from unit: WeightUnit) -> Double {
        switch unit {
        case .kg: value
        case .lb: value * kgPerLb
        }
    }

    static func fromKg(_ kg: Double, to unit: WeightUnit) -> Double {
        switch unit {
        case .kg: kg
        case .lb: kg / kgPerLb
        }
    }

    /// Input step for the weight keypad (LOG-06): 0.5 kg or 1 lb.
    static func inputIncrement(for unit: WeightUnit) -> Double {
        switch unit {
        case .kg: 0.5
        case .lb: 1
        }
    }

    /// Rounds a value expressed in `unit` to the nearest input increment.
    static func snap(_ value: Double, in unit: WeightUnit) -> Double {
        let step = inputIncrement(for: unit)
        return (value / step).rounded() * step
    }

    /// Kilogram value converted to `unit` and rounded to two decimals, which removes
    /// floating point noise such as 100 lb → 45.359237 kg → 99.99999 lb.
    static func displayValue(_ kg: Double, in unit: WeightUnit) -> Double {
        (fromKg(kg, to: unit) * 100).rounded() / 100
    }
}

/// Locale-aware number formatting (decimal comma support, section 14.7).
enum WeightFormatter {
    static func string(kg: Double, unit: WeightUnit, locale: Locale = .current, includeUnit: Bool = false) -> String {
        let value = UnitConverter.displayValue(kg, in: unit)
        let number = value.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
        return includeUnit ? "\(number) \(unit.symbol)" : number
    }

    static func volume(kg: Double, unit: WeightUnit, locale: Locale = .current) -> String {
        let value = UnitConverter.fromKg(kg, to: unit).rounded()
        return "\(value.formatted(.number.precision(.fractionLength(0)).locale(locale))) \(unit.symbol)"
    }

    /// Parses user input honoring the locale's decimal separator; also accepts "." as a fallback.
    static func parse(_ text: String, locale: Locale = .current) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let separator = locale.decimalSeparator ?? "."
        let normalized = trimmed
            .replacingOccurrences(of: separator, with: ".")
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
}
