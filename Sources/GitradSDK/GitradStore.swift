import Foundation
import Combine

/// Observable store that triggers SwiftUI redraws after a remote refresh.
public final class GitradStore: ObservableObject {
    @Published public private(set) var revision: Int = 0

    /// Look up a translated string for the current locale.
    public subscript(key: String) -> String {
        Gitrad.string(key)
    }

    func notifyRefresh() {
        if Thread.isMainThread {
            revision += 1
        } else {
            DispatchQueue.main.async { self.revision += 1 }
        }
    }
}
