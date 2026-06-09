# GitradSDK

Swift client SDK for [Gitrad](https://app.gitrad.io) OTA translations. Downloads a pre-built JSON payload from Firebase Storage, caches it on disk, and provides synchronous string lookup with plural support and SwiftUI integration.

## Requirements

- iOS 16+ / macOS 13+
- Swift 5.9+
- Xcode 15+

## Installation

### Swift Package Manager

Add the package in Xcode via **File → Add Package Dependencies** and enter the repository URL, or add it directly to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/romainroche/gitrad-ios", from: "1.0.0")
],
targets: [
    .target(name: "MyApp", dependencies: ["GitradSDK"])
]
```

## Key namespaces

The Gitrad server prefixes every translation key with a namespace configured per translation file (e.g. `greeting.hello` → `app.greeting.hello`). How you handle namespaces in the SDK depends on your project structure:

**Single translation file** — pass `namespace` to `configure()` and keep using short keys everywhere:

```swift
Gitrad.configure(apiKey: ..., baseUrl: ..., namespace: "app")
Gitrad.string("greeting.hello")   // resolves "app.greeting.hello"
```

If no translation is found under the prefixed key, the SDK automatically retries with the bare key. This lets you gradually roll out a namespace on an existing payload without updating every key at once.

**Multiple translation files / monorepo packages** — leave `namespace: nil` (the default) in `configure()` and create a scoped accessor per package:

```swift
// In the Onboarding package
private let strings = Gitrad.scoped(to: "onboarding")
strings.string("welcome_title")            // resolves "onboarding.welcome_title"
strings.string("step_count", count: 3)    // plural — resolves "onboarding.step_count"
```

```swift
// In the Payments package
private let strings = Gitrad.scoped(to: "payments")
strings.string("checkout.confirm")        // resolves "payments.checkout.confirm"
```

For SwiftUI, pass `namespace` directly to `@GitradStrings`:

```swift
struct OnboardingView: View {
    @GitradStrings(namespace: "onboarding") var strings
    var body: some View { Text(strings["welcome_title"]) }
}
```

Environments created before namespaces were introduced publish keys without a prefix — leave `namespace: nil` and use full keys as-is.

---

## Setup

### 1. Get an API key

Create an environment in the [Gitrad dashboard](https://app.gitrad.io) and generate an API key for it. Each environment (production, staging, dev) should have its own key.

Never commit keys to source control — deliver them via CI build variables or a remote config service.

### 2. Configure at launch

Call `Gitrad.configure()` once, before any string lookup. Then kick off a background prefetch so the latest translations are ready for the first screen.

```swift
import GitradSDK

@main
struct MyApp: App {
    init() {
        Gitrad.configure(
            apiKey:      Secrets.gitradApiKey,     // environment-scoped API key
            baseUrl:     "https://app.gitrad.io",  // Gitrad server base URL
            maxCacheAge: 3600                      // seconds before re-fetching; 0 = always
        )
        Task { await Gitrad.prefetch() }
    }

    var body: some Scene { WindowGroup { RootView() } }
}
```

`configure()` loads the disk cache (or the bundled baseline if no cache exists) synchronously, so `string()` is safe to call immediately after.

### 3. Refresh on foreground resume

```swift
.onChange(of: scenePhase) { phase in
    if phase == .active { Task { await Gitrad.refresh() } }
}
```

`refresh()` checks `maxCacheAge` and skips the network call when the cached payload is still fresh.

## Usage

### Simple lookup

```swift
let title = Gitrad.string("onboarding.welcome_title")
```

Falls back through: exact locale → base language → `"en"` → the key itself. Never throws, never returns `nil`.

### With string interpolation

The SDK returns the raw format string; your code performs the substitution:

```swift
let template = Gitrad.string("greeting.welcome")   // "Welcome, %@!"
let greeting = String(format: template, user.firstName)
```

### Plurals

Pass a `count` and the SDK selects the correct CLDR plural form automatically:

```swift
let badge = Gitrad.string("notifications.count", count: unreadCount)
// count: 0 → "No notifications"
// count: 1 → "1 notification"
// count: 5 → "5 notifications"
```

The corresponding payload entry looks like:

```json
"notifications.count": {
    "zero":  "No notifications",
    "one":   "%d notification",
    "other": "%d notifications"
}
```

Supported plural categories: `zero`, `one`, `two`, `few`, `many`, `other` (CLDR). The SDK ships its own plural-rules table for 20+ languages and never delegates to the OS.

### Explicit language override

```swift
let frenchTitle = Gitrad.string("onboarding.welcome_title", language: "fr")
```

### SwiftUI integration

Use the `@GitradStrings` property wrapper to have your view automatically redraw whenever remote translations are refreshed:

```swift
import GitradSDK

struct ContentView: View {
    @GitradStrings var strings

    var body: some View {
        VStack {
            Text(strings["onboarding.welcome_title"])
            Text(strings["onboarding.subtitle"])
        }
    }
}
```

## Multiple environments

```swift
let key = isProduction ? Secrets.gitradKeyProd : Secrets.gitradKeyStaging
Gitrad.configure(
    apiKey:  key,
    baseUrl: "https://app.gitrad.io"
)
```

The local disk cache is automatically namespaced per API key, so switching between environments never causes cache collisions.

## Observability

Register an event handler to forward SDK events to your analytics or crash-reporting tool:

```swift
Gitrad.onEvent { event in
    switch event {
    case .fetchStarted:
        break
    case .fetchSucceeded(let languages, let ms):
        Analytics.track("gitrad_fetch_ok", ["langs": languages, "ms": ms])
    case .fetchFailed(let error):
        Crashlytics.record(error: error)
    case .cacheHit:
        break
    case .bundleFallback:
        Analytics.track("gitrad_bundle_fallback")
    }
}
```

## Push-notification refresh

To refresh translations on a push notification, call:

```swift
Gitrad.refresh()
```

from your notification handler when the payload contains `"gitrad_refresh": true`.

## Bundled baseline

Ship a snapshot of your production translations inside the app bundle so strings are available immediately on first launch and when the device is offline with no disk cache.

The file must be placed at:

```
Resources/gitrad-baseline/translations.json
```

Update it as part of each release by downloading the latest payload from Gitrad and committing it to that path.

## Error handling

`Gitrad.string()` always returns a `String`. On any failure (no network, expired key, malformed JSON) the SDK silently falls back through the cache layers and returns the key name as a last resort.

The `GitradError` type is surfaced exclusively through the `onEvent` handler:

| Error | Cause |
|---|---|
| `.unauthorized` | API key is invalid or unknown |
| `.subscriptionInactive` | Workspace subscription has lapsed |
| `.networkError` | Network unreachable; retried with back-off |
| `.parseError` | Malformed JSON payload; previous cache is preserved |

Network failures are retried up to 4 times with exponential back-off (2 s → 4 s → 8 s → 16 s) before falling back to the cache silently.

## Caching

| Layer | Location | Lifetime |
|---|---|---|
| In-memory | Process memory | Until the app is killed |
| Disk cache | `Library/Caches/gitrad/{apiKeyHash}/translations.json` | Until evicted by the OS or a fresh fetch |
| Bundled baseline | `Resources/gitrad-baseline/translations.json` | Shipped with the binary |
