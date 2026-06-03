import Foundation

/// A namespace-scoped accessor for translated strings.
///
/// Obtain one via `Gitrad.scoped(to:)` and store it as a constant in each
/// package or feature module. Keys passed to this type are automatically
/// prefixed with the namespace before lookup; the short key is returned as
/// the fallback when no translation is found.
///
/// ```swift
/// private let strings = Gitrad.scoped(to: "onboarding")
///
/// strings.string("welcome_title")            // looks up "onboarding.welcome_title"
/// strings.string("step_count", count: 3)    // plural lookup on "onboarding.step_count"
/// ```
public struct GitradNamespace {
    private let prefix: String

    init(prefix: String) {
        self.prefix = prefix
    }

    /// Returns a translated string for the current locale, never throws.
    /// Falls back through: exact locale → base language → `"en"` → `key` itself.
    public func string(_ key: String, count: Int? = nil, language: String? = nil) -> String {
        Gitrad.string(prefixedKey: "\(prefix).\(key)", originalKey: key, count: count, language: language)
    }
}
