#if canImport(SwiftUI)
import SwiftUI

/// Property wrapper that re-renders a SwiftUI view whenever remote translations are refreshed.
///
/// Usage:
/// ```swift
/// struct ContentView: View {
///     @GitradStrings var strings
///     var body: some View { Text(strings["onboarding.welcome_title"]) }
/// }
/// ```
@propertyWrapper
public struct GitradStrings: DynamicProperty {
    @ObservedObject private var store: GitradStore

    public init() {
        _store = ObservedObject(wrappedValue: Gitrad.shared.observableStore)
    }

    public var wrappedValue: GitradStore { store }
}
#endif
