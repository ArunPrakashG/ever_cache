<div align="center">
  <h1>🚀 EverCache</h1>

  <p align="center">
    <a href="https://pub.dev/packages/ever_cache"> 
      <img src="https://img.shields.io/pub/v/ever_cache?color=blueviolet" alt="Pub Version"/> 
    </a> 
    <br>
    <img src="https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
    <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter" />
    <br>
    <p>
        A simple dart package which extends the functionality of Dart's built-in `late` keyword to provide a more robust and flexible way to handle lazy initialization. It closesly resembles the `Lazy<T>` from C#.
    </p>
</p>
</div>

## ✨ Key Features

- **🚀 Lazy Initialization**: Compute the cache entry only when it is accessed for the first time. (or trigger the compute manually!)
- **⏳ TTL Support**: Automatically purge cache entries after a set duration.
- **📡 Events**: Monitor the state of the cache based on delegates invoked from the instance.
- **🔧 Placeholder**: Provide placeholder data to be returned when cache is being computed.
- **🔍 Access Locking**: Control acess to the computed value by using `lock` functionality.
- **🛡️ Error Caching (optional)**: Choose whether to cache the first exception until invalidation (akin to C# Lazy<T>) or not cache errors.
- **📌 isValueCreated & snapshot**: Inspect without forcing computation.
- **🪄 valueOrNull()**: Safe read that never throws; returns placeholder or null.
- **⚡ ensure()**: Await until a value exists; starts compute if needed.
- **📦 Precomputed value constructor**: `EverCache.value(T)` to wrap an existing value with TTL/events behavior.
- **🧊 Sliding TTL (configurable)**: Absolute or sliding TTL; optionally disable sliding on read via `slideOnAccess`.
- **🔁 Publication-only refresh**: Keep serving the last good value during background refresh errors/nulls; publish only on success.
- **🧭 Diagnostics**: Inspect `computeCount`, `lastComputedAt`, `lastError`, `lastErrorStackTrace`, and upcoming expirations.

## 🚀 Getting Started

Integrate `ever_cache` into your project effortlessly. Just sprinkle this into your `pubspec.yaml`:

```yaml
dependencies:
  ever_cache: ^0.0.8
```

then run `pub get` or `flutter pub get`.

## 🌟 Usage

```dart
import 'package:ever_cache/ever_cache.dart';

final cache = EverCache<String>(
    () async {
        // Your computation

        return 'Hello, World!';
    },
    // set a placeholder if you wish to return a default value when the computation is in progress.
    placeholder: () => 'placeholder',
    // set a TTL (Time To Live) for the cache entry.
    ttl: EverTTL.seconds(5),
    // if you want to monitor different events emitted from the cache.
  events: EverEvents(
        onComputing: () => print('Conjuring...'),
        onComputed: () => print('Voila!'),
        onInvalidated: () => print('Poof! Gone!'),
        onError: (e, stackTrace) => print('Oops! Computation failed: $e'),
    ),
    // control exception semantics: do not cache by default; or cache until invalidated
    errorCaching: EverErrorCachingMode.cacheUntilInvalidate,
    // keep last good value during refresh failures, publish only on success
    publishMode: EverPublishMode.publicationOnly,
    // if you want the cache to be computed as soon as this constructor is called in the background
    earlyCompute: true,
);

// access the computed value
// cache.value
// non-throwing access: cache.valueOrNull
// inspect state without computing: cache.snapshot
// wait for a value (starts compute if needed): await cache.ensure()
// has it been created? cache.isValueCreated
// diagnostics: computeCount/lastComputedAt/lastError/lastErrorStackTrace
// and nextExpiryAt/nextPrefetchAt/prefetchScheduled
```

### 📚 Additional Methods

- **`compute()`**: Manually compute the cache entryin async.
- **`computeSync()`**: Manually compute the cache entry in sync.
- **`lock()`**: Lock the cache entry to prevent further access till the provided callback is executed.
- **`invalidate()`**: Invalidate the cache entry.
- **`dispose()`**: Dispose of the cache entry.
- **`ensure()`**: Returns a Future<T> that completes when a value exists.
- **`valueOrNull`**: Returns T? without throwing; may return placeholder.
- **`isValueCreated`**: Indicates whether a value has been computed.

### ⏳ TTL modes and sliding control

Use absolute or sliding TTL via `EverTTL`:

```dart
// Absolute TTL, no sliding
ttl: EverTTL.seconds(30),

// Sliding TTL restarted on access
ttl: EverTTL.seconds(30, mode: EverTTLMode.sliding),

// Sliding TTL but keep window fixed on reads (only refresh slides on write)
ttl: EverTTL.seconds(30, mode: EverTTLMode.sliding, slideOnAccess: false),
```

To prefetch before expiry (SWR), set `prefetchBeforeExpiry`:

```dart
ttl: EverTTL.minutes(5, prefetchBeforeExpiry: const Duration(seconds: 30)),
```

### 🔁 Publication-only refresh

If a value already exists and you refresh in the background, you can keep the last good value visible even if the refresh fails or returns null:

```dart
final cache = EverCache<MyType>(
  () async => fetchLatest(),
  publishMode: EverPublishMode.publicationOnly,
  ttl: EverTTL.minutes(5, prefetchBeforeExpiry: const Duration(seconds: 30)),
);
```

### 🧭 Diagnostics

These read-only fields help with observability:

- `computeCount`, `lastComputedAt`
- `lastError`, `lastErrorStackTrace`
- `nextExpiryAt` — scheduled expiry time
- `nextPrefetchAt` — scheduled prefetch time
- `prefetchScheduled` — whether a prefetch timer is active

## Note

EverCache is an open-source project and contributions are welcome! If you encounter any issues or have feature requests, please file them on the project's issue tracker.

For more detailed documentation, please refer to the source code and comments within the lib/ directory.

## 🧭 Roadmap / Ideas

Drawing inspiration from C# `Lazy<T>`:

- Thread-safety modes (ExecutionAndPublication/PublicationOnly) — Not applicable to single-threaded Dart by default; consider isolates or re-entrant guards if needed.
- Reset semantics — today use `invalidate()`; may add `reset()` alias.
- Exception caching — implemented via `EverErrorCachingMode`.
- Diagnostics — counters for compute attempts, last error, last compute time.

Contributions and discussions are welcome!
