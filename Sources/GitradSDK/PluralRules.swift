import Foundation

// CLDR plural rules: https://unicode.org/reports/tr35/tr35-numbers.html#Language_Plural_Rules
// The SDK ships its own table and never delegates to the OS for plural selection.
enum PluralRules {

    // Returns the CLDR plural category for the given integer count and language tag.
    static func category(count: Int, language: String) -> String {
        let base = language.components(separatedBy: "-").first?.lowercased() ?? "en"
        switch base {

        // Invariant — always "other"
        case "ja", "zh", "ko", "th", "vi", "id", "ms", "lo", "my", "km",
             "bo", "dz", "ii", "jbo", "kde", "kea", "sah", "ses", "sg", "wo", "yo":
            return "other"

        // French-style: one for n ≤ 1, other otherwise
        case "fr", "ff", "kab", "mg", "mfe", "hy":
            return count <= 1 ? "one" : "other"

        // East Slavic: one / few / many
        case "ru", "uk", "be":
            return slavicRUCategory(count: count)

        // Czech / Slovak: one / few / other
        case "cs", "sk":
            if count == 1 { return "one" }
            if count >= 2 && count <= 4 { return "few" }
            return "other"

        // Polish: one / few / many / other
        case "pl":
            return polishCategory(count: count)

        // Arabic: zero / one / two / few / many / other
        case "ar":
            return arabicCategory(count: count)

        // Latvian: zero / one / other
        case "lv":
            if count == 0 { return "zero" }
            if count % 10 == 1 && count % 100 != 11 { return "one" }
            return "other"

        // Irish: one / two / few / many / other
        case "ga":
            if count == 1 { return "one" }
            if count == 2 { return "two" }
            if count >= 3 && count <= 6 { return "few" }
            if count >= 7 && count <= 10 { return "many" }
            return "other"

        // Romanian: one / few / other
        case "ro":
            if count == 1 { return "one" }
            let mod100 = count % 100
            if count == 0 || (mod100 >= 1 && mod100 <= 19) { return "few" }
            return "other"

        // Lithuanian: one / few / other
        case "lt":
            return lithuanianCategory(count: count)

        // Slovenian: one / two / few / other
        case "sl":
            let mod100 = count % 100
            if mod100 == 1 { return "one" }
            if mod100 == 2 { return "two" }
            if mod100 >= 3 && mod100 <= 4 { return "few" }
            return "other"

        // Hebrew: one / two / many / other
        case "he", "iw":
            if count == 1 { return "one" }
            if count == 2 { return "two" }
            if count >= 11 && count % 10 == 0 { return "many" }
            return "other"

        // Macedonian: one / other
        case "mk":
            return (count % 10 == 1 && count != 11) ? "one" : "other"

        // Default Germanic/Romance rule: n==1 → "one", else → "other"
        // Covers: en, de, nl, it, es, pt, sv, da, fi, nb, el, hu, bg, hr, sr, ca, gl, sq…
        default:
            return count == 1 ? "one" : "other"
        }
    }

    // Returns the translated plural string for the given count.
    // Special-cases count==0 to try the explicit "zero" key before falling back to CLDR.
    static func form(count: Int, map: [String: String], language: String) -> String {
        if count == 0, let zeroForm = map["zero"] {
            return String(format: zeroForm, count)
        }
        let cat = category(count: count, language: language)
        let raw = map[cat] ?? map["other"] ?? ""
        return String(format: raw, count)
    }

    // MARK: - Private helpers

    private static func slavicRUCategory(count: Int) -> String {
        let mod10  = abs(count) % 10
        let mod100 = abs(count) % 100
        if mod10 == 1 && mod100 != 11 { return "one" }
        if mod10 >= 2 && mod10 <= 4 && !(mod100 >= 12 && mod100 <= 14) { return "few" }
        return "many"
    }

    private static func polishCategory(count: Int) -> String {
        if count == 1 { return "one" }
        let mod10  = count % 10
        let mod100 = count % 100
        if mod10 >= 2 && mod10 <= 4 && !(mod100 >= 12 && mod100 <= 14) { return "few" }
        if mod10 == 0 || mod10 == 1 || mod10 >= 5 || (mod100 >= 12 && mod100 <= 14) {
            return "many"
        }
        return "other"
    }

    private static func arabicCategory(count: Int) -> String {
        if count == 0 { return "zero" }
        if count == 1 { return "one" }
        if count == 2 { return "two" }
        let mod100 = count % 100
        if mod100 >= 3  && mod100 <= 10 { return "few" }
        if mod100 >= 11 && mod100 <= 99 { return "many" }
        return "other"
    }

    private static func lithuanianCategory(count: Int) -> String {
        let mod10  = count % 10
        let mod100 = count % 100
        let teenRange = 11...19
        if mod10 == 1 && !teenRange.contains(mod100) { return "one" }
        if mod10 >= 2 && mod10 <= 9 && !teenRange.contains(mod100) { return "few" }
        return "other"
    }
}
