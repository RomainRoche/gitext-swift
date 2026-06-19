import Foundation
import Combine

/// Observable store that triggers SwiftUI redraws after a remote refresh.
public final class GitextStore: ObservableObject {
    @Published public private(set) var revision: Int = 0
    private let namespace: String?
    private var refreshSink: AnyCancellable?

    /// Shared store — created once by `Gitext.shared`. No namespace applied.
    init() {
        self.namespace = nil
    }

    /// Namespace-scoped store. Keys passed to the subscript are automatically
    /// prefixed with `namespace` before lookup. Refresh events are forwarded
    /// from the shared store so SwiftUI redraws still fire after a remote fetch.
    public init(namespace: String) {
        self.namespace = namespace
        refreshSink = Gitext.shared.observableStore.$revision
            .dropFirst()
            .sink { [weak self] value in
                if Thread.isMainThread {
                    self?.revision = value
                } else {
                    DispatchQueue.main.async { self?.revision = value }
                }
            }
    }

    /// Look up a translated string for the current locale.
    public subscript(key: String) -> String {
        if let ns = namespace {
            return Gitext.string(prefixedKey: "\(ns).\(key)", originalKey: key, count: nil, language: nil)
        }
        return Gitext.string(key)
    }

    func notifyRefresh() {
        if Thread.isMainThread {
            revision += 1
        } else {
            DispatchQueue.main.async { self.revision += 1 }
        }
    }
}
