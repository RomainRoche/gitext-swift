# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
swift build                                                    # build the package
swift test                                                     # run all tests
swift test --filter DomainTests/PluralRulesTests               # run a single test class
swift test --filter DomainTests/PluralRulesTests/test_russian  # run a single test method
```

## Architecture — Clean Architecture with three SPM targets

Only `GitradSDK` is a public library product. `Domain` and `Data` are internal targets; consumers cannot import them.

```
Sources/
  Domain/          ← Core. Zero external dependencies. Uses `package` access.
    Entities/      ← TranslationEntry, TranslationPayload, TranslationFetchError
    Repositories/  ← TranslationRepository protocol (only protocol, no implementation)
    UseCases/      ← LoadInitialTranslationsUseCase, FetchTranslationsUseCase, ResolveTranslationUseCase
    Support/       ← PluralRules (pure CLDR logic, no OS delegation)
  Data/            ← Repository implementations. Depends on Domain. Uses `package` access for factory only.
    DTOs/          ← TranslationPayloadDTO, TranslationEntryDTO (Codable, internal)
    Mappers/       ← TranslationPayloadMapper (DTO ↔ Domain, internal)
    DataSources/   ← RemoteTranslationDataSource, LocalTranslationDataSource, BundleTranslationDataSource (internal)
    Repositories/  ← DefaultTranslationRepository (internal)
    TranslationRepositoryFactory.swift  ← only package-visible entry point into Data
  GitradSDK/       ← Presentation (public API). Depends on Domain + Data.
    Gitrad.swift           ← public facade + singleton
    DependencyContainer.swift  ← composition root (internal struct)
    GitradStore.swift      ← ObservableObject for SwiftUI
    GitradStrings.swift    ← @GitradStrings property wrapper
    Models/        ← GitradConfig, GitradError, GitradEvent (all public)
Tests/
  DomainTests/     ← imports Domain directly (package access, no @testable needed)
  DataTests/       ← @testable import Data (accesses internal types)
  SDKIntegrationTests/  ← import GitradSDK (public API only)
```

### Dependency rule

```
GitradSDK → Data → Domain     (only direction allowed)
GitradSDK → Domain            (direct, for use case types)
```

### Key data flow

**`OTAPayload` format:** `[language: [key: entry]]` where entry is either a plain string or a CLDR plural map.

**`configure()` flow (synchronous):**
1. `DependencyContainer` wires all dependencies via `TranslationRepositoryFactory`
2. `LoadInitialTranslationsUseCase` loads disk cache → bundled baseline → empty (in that order)
3. Facade stores payload in memory, emits `.cacheHit` or `.bundleFallback`

**`prefetch()` / `refresh()` flow (async):**
- `prefetch()` calls `FetchTranslationsUseCase.execute()` unconditionally
- `refresh()` checks cache age in the facade first (to emit `fetchStarted` only when actually fetching), then calls `FetchTranslationsUseCase`
- On success: in-memory payload updated, `GitradStore.revision` bumped on main thread, `.fetchSucceeded` emitted
- On error: existing payload kept, `.fetchFailed` emitted

**`string()` flow (synchronous, never throws):**
- `ResolveTranslationUseCase` walks: exact locale → base language → `"en"` → key itself
- For plurals, `count == 0` tries an explicit `"zero"` key before CLDR category selection

### Access control pattern

- `Domain` types: `package` — visible within the package, invisible to consumers
- `Data` concrete types: `internal` — invisible even within the package; only `TranslationRepositoryFactory` is `package`
- `GitradSDK` public API: `public` — consumers see only these types

### Thread safety

`Gitrad` singleton protects `_container`, `_payload`, and `_eventHandler` with `NSLock` via a private `withLock {}` wrapper. `LocalTranslationDataSource` protects `_lastSaveDate` with its own `NSLock`. `GitradStore` dispatches `revision` increments to the main thread.

### Caching layers (priority order)

| Layer | Location | Tracked by |
|---|---|---|
| In-memory | `Gitrad._payload` | facade |
| Disk | `Library/Caches/gitrad/{envName}/translations.json` | `LocalTranslationDataSource` |
| Bundle | `Resources/gitrad-baseline/translations.json` | `BundleTranslationDataSource` |

### Architecture deviations to know about

- **Staleness check in the facade**: `Gitrad.fetchIfStale()` performs the cache-age check directly (using `repository.cacheModificationDate()` and `maxCacheAge`) rather than in a dedicated `RefreshTranslationsUseCase`. This preserves the invariant that `.fetchStarted` is only emitted when a network call will follow.
- **`Data` target name**: Shadows `Foundation.Data` as a module name. Safe because Swift resolves `Data` in type position to `Foundation.Data`; the module name only applies in `import` statements.
- **`GitradError` in Presentation maps `Domain.TranslationFetchError`**: `GitradError(from:)` converts the package-internal `TranslationFetchError` to the public `GitradError` at the Presentation boundary.
- **No data source protocols**: `RemoteTranslationDataSource`, `LocalTranslationDataSource`, and `BundleTranslationDataSource` are concrete final classes with no protocols. Testability is achieved by testing through `DefaultTranslationRepository` with `@testable import Data`.
