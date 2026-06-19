# GitextSwift

Swift client SDK for [Gitext](https://app.gitext.io) OTA translations. Downloads a pre-built JSON payload from Firebase Storage, caches it on disk, and provides synchronous string lookup with plural support and SwiftUI integration.

## Requirements

- iOS 16+ / macOS 13+
- Swift 5.9+
- Xcode 15+

## Installation

### Swift Package Manager

Add the package in Xcode via **File → Add Package Dependencies** and enter the repository URL, or add it directly to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/romainroche/gitext-swift", from: "1.0.0")
],
targets: [
    .target(name: "MyApp", dependencies: ["GitextSwift"])
]
```

## Key namespaces

The Gitext server prefixes every translation key with a namespace configured per translation file (e.g. `greeting.hello` → `app.greeting.hello`). How you handle namespaces in the SDK depends on your project structure:

**Single translation file** — pass `namespace` to `configure()` and keep using short keys everywhere:

```swift
Gitext.configure(apiKey: ..., baseUrl: ..., namespace: "app")
Gitext.string("greeting.hello")   // resolves "app.greeting.hello"
```

If no translation is found under the prefixed key, the SDK automatically retries with the bare key. This lets you gradually roll out a namespace on an existing payload without updating every key at once.

**Multiple translation files / monorepo packages** — leave `namespace: nil` (the default) in `configure()` and create a scoped accessor per package:

```swift
// In the Onboarding package
private let strings = Gitext.scoped(to: "onboarding")
strings.string("welcome_title")            // resolves "onboarding.welcome_title"
strings.string("step_count", count: 3)    // plural — resolves "onboarding.step_count"
```

```swift
// In the Payments package
private let strings = Gitext.scoped(to: "payments")
strings.string("checkout.confirm")        // resolves "payments.checkout.confirm"
```

For SwiftUI, pass `namespace` directly to `@GitextStrings`:

```swift
struct OnboardingView: View {
    @GitextStrings(namespace: "onboarding") var strings
    var body: some View { Text(strings["welcome_title"]) }
}
```

Environments created before namespaces were introduced publish keys without a prefix — leave `namespace: nil` and use full keys as-is.

---

## Setup

### 1. Get an API key

Create an environment in the [Gitext dashboard](https://app.gitext.io) and generate an API key for it. Each environment (production, staging, dev) should have its own key.

Never commit keys to source control — deliver them via CI build variables or a remote config service.

### 2. Configure at launch

Call `Gitext.configure()` once, before any string lookup. Then kick off a background prefetch so the latest translations are ready for the first screen.

```swift
import GitextSwift

@main
struct MyApp: App {
    init() {
        Gitext.configure(
            apiKey:      Secrets.gitextApiKey,     // environment-scoped API key
            baseUrl:     "https://app.gitext.io",  // Gitext server base URL
            maxCacheAge: 3600                      // seconds before re-fetching; 0 = always
        )
        Task { await Gitext.prefetch() }
    }

    var body: some Scene { WindowGroup { RootView() } }
}
```

`configure()` loads the disk cache (or the bundled baseline if no cache exists) synchronously, so `string()` is safe to call immediately after.

### 3. Refresh on foreground resume

```swift
.onChange(of: scenePhase) { phase in
    if phase == .active { Task { await Gitext.refresh() } }
}
```

`refresh()` checks `maxCacheAge` and skips the network call when the cached payload is still fresh.

## Usage

### Simple lookup

```swift
let title = Gitext.string("onboarding.welcome_title")
```

Falls back through: exact locale → base language → `"en"` → the key itself. Never throws, never returns `nil`.

### With string interpolation

The SDK returns the raw format string; your code performs the substitution:

```swift
let template = Gitext.string("greeting.welcome")   // "Welcome, %@!"
let greeting = String(format: template, user.firstName)
```

### Plurals

Pass a `count` and the SDK selects the correct CLDR plural form automatically:

```swift
let badge = Gitext.string("notifications.count", count: unreadCount)
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
let frenchTitle = Gitext.string("onboarding.welcome_title", language: "fr")
```

### SwiftUI integration

Use the `@GitextStrings` property wrapper to have your view automatically redraw whenever remote translations are refreshed:

```swift
import GitextSwift

struct ContentView: View {
    @GitextStrings var strings

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
let key = isProduction ? Secrets.gitextKeyProd : Secrets.gitextKeyStaging
Gitext.configure(
    apiKey:  key,
    baseUrl: "https://app.gitext.io"
)
```

The local disk cache is automatically namespaced per API key, so switching between environments never causes cache collisions.

## Observability

Register an event handler to forward SDK events to your analytics or crash-reporting tool:

```swift
Gitext.onEvent { event in
    switch event {
    case .fetchStarted:
        break
    case .fetchSucceeded(let languages, let ms):
        Analytics.track("gitext_fetch_ok", ["langs": languages, "ms": ms])
    case .fetchFailed(let error):
        Crashlytics.record(error: error)
    case .cacheHit:
        break
    case .bundleFallback:
        Analytics.track("gitext_bundle_fallback")
    }
}
```

## Push-notification refresh

To refresh translations on a push notification, call:

```swift
Gitext.refresh()
```

from your notification handler when the payload contains `"gitext_refresh": true`.

## Bundled baseline

Ship a snapshot of your production translations inside the app bundle so strings are available immediately on first launch and when the device is offline with no disk cache.

The file must be placed at:

```
Resources/gitext-baseline/translations.json
```

Update it as part of each release by downloading the latest payload from Gitext and committing it to that path.

## Error handling

`Gitext.string()` always returns a `String`. On any failure (no network, expired key, malformed JSON) the SDK silently falls back through the cache layers and returns the key name as a last resort.

The `GitextError` type is surfaced exclusively through the `onEvent` handler:

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
| Disk cache | `Library/Caches/gitext/{apiKeyHash}/translations.json` | Until evicted by the OS or a fresh fetch |
| Bundled baseline | `Resources/gitext-baseline/translations.json` | Shipped with the binary |
