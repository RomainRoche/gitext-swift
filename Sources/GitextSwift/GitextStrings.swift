#if canImport(SwiftUI)
import SwiftUI

/// Property wrapper that re-renders a SwiftUI view whenever remote translations are refreshed.
///
/// **Single namespace** (or no namespace):
/// ```swift
/// struct ContentView: View {
///     @GitextStrings var strings
///     var body: some View { Text(strings["onboarding.welcome_title"]) }
/// }
/// ```
///
/// **Per-package namespace** (multi-package apps):
/// ```swift
/// struct OnboardingView: View {
///     @GitextStrings(namespace: "onboarding") var strings
///     var body: some View { Text(strings["welcome_title"]) }
/// }
/// ```
@propertyWrapper
public struct GitextStrings: DynamicProperty {
    @ObservedObject private var store: GitextStore

    public init() {
        _store = ObservedObject(wrappedValue: Gitext.shared.observableStore)
    }

    /// Creates a namespace-scoped property wrapper. Keys are automatically prefixed
    /// with `namespace` before lookup; use this in packages that own a specific namespace.
    public init(namespace: String) {
        _store = ObservedObject(wrappedValue: GitextStore(namespace: namespace))
    }

    public var wrappedValue: GitextStore { store }
}
#endif
