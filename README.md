<div align="center">
  <h1>🚀 EverCache</h1>

  <p align="center">
    <a href="https://pub.dev/packages/wordpress_client"> 
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

## 🚀 Getting Started

Integrate `ever_cache` into your project effortlessly. Just sprinkle this into your `pubspec.yaml`:

```yaml
dependencies:
  ever_cache: ^0.0.6
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
);
```

### 📚 Additional Methods

- **`compute()`**: Manually compute the cache entryin async.
- **`computeSync()`**: Manually compute the cache entry in sync.
- **`lock()`**: Lock the cache entry to prevent further access till the provided callback is executed.
- **`invalidate()`**: Invalidate the cache entry.
- **`dispose()`**: Dispose of the cache entry.

## Note

EverCache is an open-source project and contributions are welcome! If you encounter any issues or have feature requests, please file them on the project's issue tracker.

For more detailed documentation, please refer to the source code and comments within the lib/ directory.
