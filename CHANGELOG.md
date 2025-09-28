## 0.0.1

- Initial version.

## 0.0.2

- Fix `computeSync()` method to handle states correctly.

## 0.0.3

- Remove type constraint

## 0.0.4

- Code refactors
- Implemented locking mechanism for using the value

## 0.0.5

- introduce custom disposer for the value

## 0.0.6

- Fix the issue with value getter

## 0.0.7

- Introduce EverCachedValue<T> class to wrap the actual to prevent cases which can occur if compute method returned null

## 0.0.8

- Fix the issue with EverCachedValue<T> class
- Refactors

## 0.0.9

- Refactor state of the cache

## 1.0.0

- Features

  - Publication-only refresh mode via `EverPublishMode.publicationOnly` to keep serving the last good value during background refresh failures (errors/null). Default remains `singlePublisher`.
  - TTL enhancements:
    - Sliding TTL mode (`EverTTLMode.sliding`) with `slideOnAccess` toggle (defaults to true) to control whether reads extend the window.
    - Stale-While-Revalidate prefetch using `EverTTL(prefetchBeforeExpiry: ...)` to refresh ahead of expiry.
  - Diagnostics:
    - Existing: `computeCount`, `lastComputedAt`, `lastError`, `lastErrorStackTrace`.
    - New: `nextExpiryAt`, `nextPrefetchAt`, and `prefetchScheduled` for better observability.
  - Null handling options: `allowNull` and `onNull` to treat `null` as a valid value or provide a fallback.
  - Convenience APIs: `ensure()`, `valueOrNull`, `snapshot`, `isValueCreated`, `computeAndGet()`, and `cancel()`.
  - Precomputed value constructor: `EverCache.value(T)`.
  - Event stream: broadcast `EverEvent<T>` stream in addition to existing `EverEvents` callbacks.
  - Multi-key cache: `EverCacheMap<K, V>` for managing per-key caches with shared options.
  - Dispose-on-invalidate: `invalidate(disposeValue: true)` will run the configured disposer for the current value.

- Changes

  - TTL scheduling refined to schedule/refresh timers after successful compute; sliding reschedule now gated by `slideOnAccess`.
  - Prefetch scheduling avoids starting while a computation is already in-flight.

- Docs

  - README updated with examples for sliding TTL, SWR prefetch, publication-only mode, and diagnostics.

- Tests

  - Added tests for sliding TTL (`slideOnAccess` true/false), publication-only refresh semantics, and diagnostics timing (`nextExpiryAt`/`nextPrefetchAt`).

- Breaking changes
  - None (new APIs are additive and defaults preserve previous behavior).
