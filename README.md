# EverCache

A Dart package that provides advanced caching mechanisms with TTL (Time To Live), and events. Designed to enhance performance and resource management in Dart and Flutter applications by efficiently caching data.

## ✨ Key Features

- **⏳ TTL Support**: Say goodbye to stale data! Automatically purge cache entries after a set duration.
- **📡 Events**: Monitor the state of the cache based on delegates emitted from the instance.

## 🚀 Getting Started

Integrate EverCache into your project effortlessly. Just sprinkle this into your `pubspec.yaml`:

```yaml
dependencies:
  ever_cache: ^0.0.1
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
    // if you want the cache to be computed as soon as this constructor is called in the background
    earlyCompute: true,
    // if you want to meaningful debug logs in the console
    debug: true,
);
```

### 📚 Additional Methods

- **`compute()`**: Manually compute the cache entry.
- **`invalidate()`**: Invalidate the cache entry.
- **`dispose()`**: Dispose of the cache entry.

## Note

EverCache is an open-source project and contributions are welcome! If you encounter any issues or have feature requests, please file them on the project's issue tracker.

For more detailed documentation, please refer to the source code and comments within the lib/ directory.
