# Gitext OTA Client SDK Specification

> Version 2.0 — 2026-05-21

---

## Overview

Gitext publishes translation snapshots to Firebase Storage. Client SDKs download a single pre-built JSON file per environment — they never talk to GitHub or parse raw `.strings` / `.xml` / `.po` files directly. All format conversion and language filtering happen server-side at publish time.

### Roles

| Actor | Responsibility |
|-------|---------------|
| **Gitext server** | Fetches from GitHub, parses formats, builds OTA JSON, uploads to Firebase Storage |
| **Client SDK** | Downloads the OTA JSON via a signed URL, caches it, looks up strings at runtime |

---

## 1. OTA Payload Format

### 1.1 Shape

The server publishes one file per environment:

```
Firebase Storage: ota/{workspaceId}/{appId}/{envId}/translations.json
```

The file is a JSON object keyed by language code, then by translation key:

```json
{
  "en": {
    "greeting.hello": "Hello",
    "greeting.welcome": "Welcome, %s!",
    "notifications.count": {
      "zero": "No notifications",
      "one": "%d notification",
      "other": "%d notifications"
    }
  },
  "fr": {
    "greeting.hello": "Bonjour",
    "greeting.welcome": "Bienvenue, %s !",
    "notifications.count": {
      "one": "%d notification",
      "other": "%d notifications"
    }
  }
}
```

### 1.2 Value types

| Type | Shape | When |
|------|-------|------|
| Plain string | `"value"` | Single-form entry |
| Plural object | `{ "one": "…", "other": "…", … }` | Entry has plural forms |

Plural keys follow CLDR categories: `zero`, `one`, `two`, `few`, `many`, `other`. `other` is always present when plurals exist.

### 1.3 Keys

Keys use dot-notation regardless of source format:
- JSON nested objects are flattened: `{ "a": { "b": "v" } }` → key `a.b`
- iOS `.strings` keys are used verbatim
- Android `strings.xml` `name` attributes are used verbatim
- Gettext `msgctxt` is prepended as namespace when present: `msgctxt "ns" + msgid "k"` → key `ns.k`

### 1.4 Language codes

Codes use BCP 47 with a hyphen separator: `en`, `fr`, `de`, `fr-FR`, `zh-CN`. The server normalises Android's `-r` region prefix (`values-fr-rFR` → `fr-FR`).

---

## 2. Plural Handling

### 2.1 Runtime plural selection

The SDK selects the right plural form from the nested object using the locale's CLDR rules and the provided count:

```swift
// Swift
let text = Gitext.string("notifications.count", count: 3)
// → "3 notifications"
```

```kotlin
// Kotlin
val text = Gitext.string("notifications.count", count = 3)
// → "3 notifications"
```

### 2.2 Fallback order for missing categories

```
Requested CLDR category  (e.g. "few")
  → "other"             (always present)
  → entry plain value   (if plurals object is malformed)
```

### 2.3 CLDR rules

The SDK must ship a CLDR plural-rules table for all supported locales and must not rely on the OS for plural selection, since rules differ across platforms and OS versions.

Minimum required categories per locale are determined at build time from the CLDR data. Languages that only use `one` / `other` (English, French, Spanish…) only need those two keys in the payload; the server only emits categories that are actually populated.

---

## 3. Fetching Translations

### 3.1 Download flow

The SDK downloads translations in two steps:

```
Step 1 — Exchange API key for a signed URL
  GET {baseUrl}/api/ota/download
  Header: x-api-key: {plaintextApiKey}

  Success → HTTP 302
  Location: https://storage.googleapis.com/…?X-Goog-Signature=…  (1-hour TTL)

  Errors:
    401 — invalid or unknown API key
    403 — workspace subscription is not active or trialing

Step 2 — Download the payload from the signed URL
  GET {signedUrl}
  (no auth header required)

  Response: application/json — the OTA translations object
```

The SDK must follow the redirect automatically (standard HTTP client behaviour) or explicitly fetch `Location` from the 302 response.

### 3.2 When to fetch

| Trigger | Behaviour |
|---------|-----------|
| App cold start | Fetch before the first screen if no valid cache; otherwise serve cache then refresh in background |
| App foreground resume | Refresh if cached payload is older than `maxCacheAge` (default 1 h) |
| Signed URL expired | Re-request the download endpoint to get a new signed URL; then fetch again |
| Manual | `Gitext.refresh()` |
| Push notification | Custom APNs / FCM payload `{ "gitext_refresh": true }` triggers `Gitext.refresh()` |

Cold-start strategy: render with the bundled baseline immediately; swap to the downloaded payload once it resolves, without blocking the UI.

### 3.3 Signed URL TTL and caching

The signed URL expires after **1 hour**. The SDK must not cache the signed URL itself beyond its TTL — only cache the downloaded translations payload. Cache the payload on disk; on the next fetch cycle, request a fresh signed URL and download again only if `maxCacheAge` has elapsed.

### 3.4 Caching layers

```
Layer 1 — In-memory dictionary   (process lifetime, zero latency)
Layer 2 — Disk cache             (survives restarts; single JSON file in app cache dir)
Layer 3 — Bundled baseline       (shipped with the binary; used when offline + no cache)
```

Cache file locations:

| Platform | Path |
|----------|------|
| iOS | `Library/Caches/gitext/{envName}/translations.json` |
| Android | `context.cacheDir/gitext/{envName}/translations.json` |

### 3.5 Retry and back-off

On network failure, retry up to **4 times** with exponential back-off: 2 s → 4 s → 8 s → 16 s. After exhausting retries, fall back to the disk cache or bundled baseline silently — never crash or block the UI.

---

## 4. Environment Management

### 4.1 How environments work

Environments are configured entirely server-side in the Gitext dashboard:

| Setting | Where configured | Example |
|---------|-----------------|---------|
| GitHub branch / tag | Gitext dashboard | `main`, `v2.3.1` |
| Language filter | Gitext dashboard | `["en", "fr", "de"]`; empty = all |
| Storage path | Auto-generated | `ota/{workspaceId}/{appId}/{envId}/translations.json` |

The client SDK knows nothing about branches or repos. It only needs an API key.

### 4.2 API keys

Each environment has one or more API keys. Keys are:
- Generated as 32 random bytes encoded as base64url.
- Shown to the user **once** at creation; never stored in plaintext server-side (only a SHA-256 hash is kept).
- Scoped to a single environment.

Create separate keys for each release channel (production, staging, QA) so they can be rotated independently.

### 4.3 SDK configuration

```swift
// Swift — call once at app launch
Gitext.configure(
    apiKey:      Secrets.gitextApiKey,     // environment-scoped API key
    baseUrl:     "https://app.gitext.io",  // Gitext server base URL
    envName:     "production",             // used as local cache namespace only
    maxCacheAge: 3600                      // seconds before re-fetching; 0 = always
)
```

```kotlin
// Kotlin — Application.onCreate()
Gitext.configure(
    context     = this,
    apiKey      = BuildConfig.GITEXT_API_KEY,
    baseUrl     = "https://app.gitext.io",
    envName     = "production",
    maxCacheAge = 3600L
)
```

`envName` is a local label used only for cache namespacing. It does not need to match the server-side environment name, though keeping them consistent avoids confusion.

### 4.4 Multiple environments in one binary

```kotlin
val env = when (RemoteConfig.getString("gitext_env")) {
    "production" -> GitextConfig(apiKey = BuildConfig.GITEXT_KEY_PROD, envName = "production")
    "staging"    -> GitextConfig(apiKey = BuildConfig.GITEXT_KEY_STAGING, envName = "staging")
    else         -> GitextConfig(apiKey = BuildConfig.GITEXT_KEY_DEV, envName = "dev")
}
Gitext.configure(context = this, config = env, baseUrl = "https://app.gitext.io")
```

### 4.5 Key security

- API keys are read-only credentials scoped to one environment. A leaked key cannot write or publish.
- Deliver keys via CI build variables, never committed to source control.
- Rotate by creating a new key in the dashboard and deploying before deleting the old one.
- For post-ship rotation without a new release, deliver the key via Firebase Remote Config or a similar remote config service.

---

## 5. Swift Implementation

### 5.1 Initialisation

```swift
import GitextSwift

@main
struct MyApp: App {
    init() {
        Gitext.configure(
            apiKey:      Secrets.gitextApiKey,
            baseUrl:     "https://app.gitext.io",
            envName:     "production",
            maxCacheAge: 3600
        )
        Task { await Gitext.prefetch() }
    }

    var body: some Scene { WindowGroup { RootView() } }
}
```

### 5.2 String lookup

```swift
// Simple key
let title = Gitext.string("onboarding.welcome_title")

// With interpolation (SDK returns the format string; app does substitution)
let raw   = Gitext.string("greeting.welcome")      // "Welcome, %@!"
let final = String(format: raw, user.firstName)

// Plural
let badge = Gitext.string("notifications.count", count: unreadCount)
// count: 0 → "No notifications"
// count: 1 → "1 notification"
// count: 5 → "5 notifications"
```

### 5.3 SwiftUI integration

```swift
// Property wrapper — redraws on remote refresh
struct ContentView: View {
    @GitextStrings var strings

    var body: some View {
        Text(strings["onboarding.welcome_title"])
    }
}

@propertyWrapper
struct GitextStrings: DynamicProperty {
    @StateObject private var store = Gitext.shared.observableStore
    var wrappedValue: GitextStore { store }
}

final class GitextStore: ObservableObject {
    @Published private(set) var revision: Int = 0

    subscript(key: String) -> String {
        Gitext.shared.resolve(key: key)
    }
}
```

### 5.4 GitextSwift core (abbreviated)

```swift
public final class Gitext {
    public static let shared = Gitext()
    private var config: GitextConfig!
    private var payload: OTAPayload = [:]          // [language: [key: Entry]]
    let observableStore = GitextStore()

    public static func configure(apiKey: String, baseUrl: String, envName: String, maxCacheAge: Int) {
        shared.config  = GitextConfig(apiKey: apiKey, baseUrl: baseUrl, envName: envName, maxCacheAge: maxCacheAge)
        shared.payload = DiskCache.read(envName: envName) ?? BundleBaseline.load()
    }

    public static func prefetch() async { await shared.fetch() }

    public static func string(_ key: String, count: Int? = nil, language: String? = nil) -> String {
        let lang = language ?? Locale.current.language.languageCode?.identifier ?? "en"
        return shared.resolve(key: key, count: count, language: lang)
    }

    public static func refresh() async { await shared.fetch() }

    private func fetch() async {
        do {
            // Step 1: exchange API key for a signed URL
            let signedUrl = try await GitextClient(config: config).downloadUrl()
            // Step 2: download the translations payload
            let data      = try await URLSession.shared.data(from: signedUrl).0
            let newPayload = try JSONDecoder().decode(OTAPayload.self, from: data)
            payload = newPayload
            DiskCache.write(newPayload, envName: config.envName)
            observableStore.notifyRefresh()
        } catch {
            // serve from cache / bundle; never crash
        }
    }

    func resolve(key: String, count: Int?, language: String) -> String {
        let entry = payload[language]?[key]
                 ?? payload[baseLang(language)]?[key]   // strip region: fr-FR → fr
                 ?? payload["en"]?[key]
        guard let entry else { return key }

        switch entry {
        case .string(let s):
            return s
        case .plurals(let map):
            guard let count else { return map["other"] ?? key }
            return pluralForm(count: count, map: map, language: language)
        }
    }
}
```

### 5.5 Foreground refresh

```swift
.onChange(of: scenePhase) { phase in
    if phase == .active { Task { await Gitext.refresh() } }
}
```

---

## 6. Kotlin Implementation

### 6.1 Initialisation

```kotlin
class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        Gitext.configure(
            context     = this,
            apiKey      = BuildConfig.GITEXT_API_KEY,
            baseUrl     = "https://app.gitext.io",
            envName     = "production",
            maxCacheAge = 3600L
        )
        lifecycleScope.launch { Gitext.prefetch() }
    }
}
```

### 6.2 String lookup

```kotlin
// Simple key
val title = Gitext.string("onboarding.welcome_title")

// With interpolation
val template = Gitext.string("greeting.welcome")    // "Welcome, %s!"
val final    = String.format(template, user.firstName)

// Plural
val badge = Gitext.string("notifications.count", count = unreadCount)
```

### 6.3 Compose integration

```kotlin
@Composable
fun rememberGitextString(key: String, count: Int? = null): String {
    val revision by Gitext.revisionFlow.collectAsState()
    return remember(revision, key, count) { Gitext.string(key, count = count) }
}

@Composable
fun WelcomeScreen() {
    val title = rememberGitextString("onboarding.welcome_title")
    Text(text = title)
}
```

### 6.4 GitextSwift core (abbreviated)

```kotlin
object Gitext {
    private lateinit var config: GitextConfig
    private var payload: OTAPayload = emptyMap()    // Map<lang, Map<key, Entry>>
    private val _revisionFlow = MutableStateFlow(0)
    val revisionFlow: StateFlow<Int> = _revisionFlow

    fun configure(context: Context, apiKey: String, baseUrl: String, envName: String, maxCacheAge: Long) {
        config  = GitextConfig(context, apiKey, baseUrl, envName, maxCacheAge)
        payload = DiskCache.read(context, envName) ?: BundleBaseline.load(context)
    }

    suspend fun prefetch() = fetch()

    fun string(key: String, count: Int? = null, language: String = currentLanguage()): String {
        val entry = payload[language]?.get(key)
                 ?: payload[baseLang(language)]?.get(key)
                 ?: payload["en"]?.get(key)
                 ?: return key

        return when (entry) {
            is Entry.Str     -> entry.value
            is Entry.Plurals -> if (count != null) pluralForm(count, entry.map, language) else entry.map["other"] ?: key
        }
    }

    suspend fun refresh() = fetch()

    private suspend fun fetch() {
        runCatching {
            // Step 1: exchange API key for a signed URL
            val signedUrl  = GitextClient(config).downloadUrl()
            // Step 2: download the translations payload
            val newPayload = GitextClient(config).download(signedUrl)
            payload = newPayload
            DiskCache.write(config.context, config.envName, newPayload)
            _revisionFlow.update { it + 1 }
        }
        // errors swallowed; existing cache / bundle continues to serve
    }
}
```

### 6.5 Lifecycle refresh

```kotlin
// Activity
override fun onResume() {
    super.onResume()
    lifecycleScope.launch { Gitext.refresh() }
}
```

Background refresh with WorkManager:

```kotlin
val work = PeriodicWorkRequestBuilder<GitextRefreshWorker>(1, TimeUnit.HOURS)
    .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
    .build()
WorkManager.getInstance(context)
    .enqueueUniquePeriodicWork("gitext_refresh", ExistingPeriodicWorkPolicy.KEEP, work)

class GitextRefreshWorker(ctx: Context, params: WorkerParameters) : CoroutineWorker(ctx, params) {
    override suspend fun doWork(): Result { Gitext.refresh(); return Result.success() }
}
```

---

## 7. Language Selection and Fallback Chain

The SDK resolves a string using this waterfall:

```
1. Exact language match   ("fr-FR")
2. Base language          ("fr", stripped from "fr-FR")
3. English fallback       ("en")
4. Disk cache (stale)     (any language, from previous successful fetch)
5. Bundled baseline       (shipped with binary)
6. Return the key itself  (never crash)
```

---

## 8. Error Handling

| Scenario | SDK behaviour |
|----------|--------------|
| No network | Serve disk cache or bundle; schedule retry with back-off |
| HTTP 401 from download endpoint | Log; surface `GitextError.unauthorized`; serve cache |
| HTTP 403 from download endpoint | Log `GitextError.subscriptionInactive`; serve cache |
| Signed URL expired (403 from Storage) | Re-request download endpoint for a new signed URL, then retry once |
| Malformed JSON payload | Discard; keep previous cache; log parse error |
| Disk cache corrupt | Delete cache entry; fall back to bundle |

`Gitext.string()` always returns a `String`. It never throws.

---

## 9. Security

- API keys are environment-scoped and read-only. A leaked key allows downloading translations for that environment only — it cannot publish, modify, or access other environments.
- Never commit API keys to source control. Deliver via CI build variables or remote config.
- Rotate by creating a new key in the Gitext dashboard, deploying, then revoking the old key.
- The SDK validates JSON structure before evicting the current cache to prevent a malformed publish from breaking the app.
- Do not log API keys or raw payload contents in production builds.

---

## 10. Observability

```swift
Gitext.onEvent { event in
    switch event {
    case .fetchStarted:                                analytics.track("gitext_fetch_started")
    case .fetchSucceeded(languages: let n, ms: let t): analytics.track("gitext_fetch_ok", ["langs": n, "ms": t])
    case .fetchFailed(error: let e):                   Crashlytics.record(error: e)
    case .cacheHit:                                    break
    case .bundleFallback:                              analytics.track("gitext_bundle_fallback")
    }
}
```

Minimum metrics to capture:

- Fetch latency (p50 / p95)
- Cache hit rate
- Bundle fallback rate (signals repeated network failure or stale app)
- 401 / 403 rate (subscription or key issues)

---

## 11. Bundled Baseline

Ship a snapshot of the production translations inside the app bundle. The SDK reads it automatically when the network is unavailable and the disk cache is cold.

Update the bundled baseline as part of each release:

1. Trigger a publish in the Gitext dashboard for the production environment.
2. CI calls `GET /api/ota/download` with the production API key and saves the response.
3. The saved `translations.json` is committed to the bundle resources directory.

Recommended paths:

```
iOS       Resources/gitext-baseline/translations.json
Android   assets/gitext-baseline/translations.json
```

---

## Appendix A — Subscription Gating

| Action | Required subscription |
|--------|----------------------|
| Create apps / environments (dashboard) | Any (including free) |
| Publish translations | Pro tier |
| Download via API key | Active or trialing subscription |

If `GET /api/ota/download` returns 403, the workspace subscription has lapsed. The SDK surfaces `GitextError.subscriptionInactive` via the observability event handler and continues serving cached strings.

---

## Appendix B — Minimal Integration Checklist

- [ ] API key created in Gitext dashboard for each environment (production, staging, dev)
- [ ] Keys delivered via CI build variables, not committed to source control
- [ ] `Gitext.configure()` called before any `Gitext.string()` call
- [ ] `prefetch()` called at app launch before first screen render
- [ ] Foreground resume triggers `Gitext.refresh()`
- [ ] Push notification handler wired to `Gitext.refresh()`
- [ ] Background refresh scheduled (WorkManager / BGAppRefreshTask)
- [ ] Bundled baseline `translations.json` included in app bundle and kept up to date
- [ ] Observability events forwarded to analytics / crash reporting
