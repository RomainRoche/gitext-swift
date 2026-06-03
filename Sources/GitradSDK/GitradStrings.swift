#if canImport(SwiftUI)
import SwiftUI

/// Property wrapper that re-renders a SwiftUI view whenever remote translations are refreshed.
///
/// **Single namespace** (or no namespace):
/// ```swift
/// struct ContentView: View {
///     @GitradStrings var strings
///     var body: some View { Text(strings["onboarding.welcome_title"]) }
/// }
/// ```
///
/// **Per-package namespace** (multi-package apps):
/// ```swift
/// struct OnboardingView: View {
///     @GitradStrings(namespace: "onboarding") var strings
///     var body: some View { Text(strings["welcome_title"]) }
/// }
/// ```
@propertyWrapper
public struct GitradStrings: DynamicProperty {
    @ObservedObject private var store: GitradStore

    public init() {
        _store = ObservedObject(wrappedValue: Gitrad.shared.observableStore)
    }

    /// Creates a namespace-scoped property wrapper. Keys are automatically prefixed
    /// with `namespace` before lookup; use this in packages that own a specific namespace.
    public init(namespace: String) {
        _store = ObservedObject(wrappedValue: GitradStore(namespace: namespace))
    }

    public var wrappedValue: GitradStore { store }
}
#endif
