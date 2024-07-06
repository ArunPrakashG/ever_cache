import 'dart:async';

import '../ever_cache.dart';

/// A Dart class that manages caching of a value of type [T] with support for time-to-live (TTL),
/// placeholders, and custom events.
///
/// This class provides a way to fetch and cache a value asynchronously, with the option to set a TTL
/// for the cached value. It also supports placeholders for the value while it's being fetched and
/// custom events for various states of the value computation process.
///
/// Parameters:
/// - [_fetch]: A function that asynchronously fetches the value to be cached.
/// - [events]: An optional instance of [EverEvents] to handle custom events.
/// - [placeholder]: An optional function that returns a placeholder value until the actual value is fetched.
/// - [ttl]: An optional instance of [EverTTL] to set a TTL for the cached value.
/// - [earlyCompute]: A boolean indicating whether to compute the value immediately upon instantiation.
final class EverCache<T> extends ILockable<T> {
  /// Constructor for creating an instance of [EverCache].
  EverCache(
    this._fetch, {
    this.events,
    this.placeholder,
    this.ttl,
    this.disposer,
    bool earlyCompute = false,
  }) {
    if (earlyCompute) {
      computeSync();
    }

    if (ttl != null) {
      _scheduleInvalidation();
    }

    if (placeholder != null) {
      _state = EverCachedState<T>.placeholder(placeholder!());
    }
  }

  /// A function that asynchronously fetches the value to be cached.
  final Future<T> Function() _fetch;

  /// An optional function that returns a placeholder value until the actual value is fetched.
  final T Function()? placeholder;

  /// An optional function that allows to define custom disposing logic for the object.
  final void Function(EverCachedState<T> value)? disposer;

  /// An optional instance of [EverEvents] to handle custom events.
  final EverEvents? events;

  /// An optional instance of [EverTTL] to set a TTL for the cached value.
  final EverTTL? ttl;

  EverCachedState<T> _state = EverCachedState<T>.empty();
  Timer? _timer;
  bool _isComputing = false;
  bool _isDisposed = false;

  /// Indicates whether the value has been computed and cached.
  bool get computed {
    return !_state.isEmpty && !_state.isPlaceholder;
  }

  /// Indicates whether the value is being computed.
  bool get computing => _isComputing;

  /// Indicates whether the value has been disposed.
  bool get disposed => _isDisposed && _state.disposed;

  /// Indicates whether a timer for invalidation (based on TTL) is scheduled.
  bool get scheduled => _timer != null;

  /// The cached state of type [T].
  ///
  /// Please note the difference between `state` and `value`:
  ///
  /// - `state` returns an instance of [EverCachedState] that contains the value and metadata.
  /// - `value` returns the actual value of type [T].
  ///
  /// The `state` property is useful when you need to access the cache state safely.
  /// For example, you can check if the computation returned a null value or if the value is a placeholder.
  /// ```dart
  /// final state = cache.state;
  ///
  /// if (state.hasValue) {
  ///   print(state.value);
  /// }
  ///
  /// if (state.isPlaceholder) {
  ///   print('Value is a placeholder.');
  /// }
  /// ```
  ///
  /// Throws an [EverStateException] if the value has been disposed.
  ///
  /// If the value is not yet computed, it will be computed in the background as soon as possible.
  @override
  EverCachedState<T> get state {
    if (disposed) {
      throw const EverStateException('Value has been disposed.');
    }

    if (!computed && !computing) {
      computeSync();
    }

    return _state;
  }

  /// The underlying cached value of type [T].
  ///
  /// Throws an [EverStateException] if the value has been disposed, not computed or is being computed.
  ///
  /// It also throws an [EverStateException] if the computed value is null.
  @override
  T get value {
    if (disposed) {
      throw const EverStateException('Value has been disposed.');
    }

    if (!computed) {
      if (_state.isPlaceholder) {
        return _state.value!;
      }

      throw const EverStateException('Value is not yet computed.');
    }

    if (computing) {
      throw const EverStateException('Value is being evaluated.');
    }

    if (!_state.hasValue) {
      throw const EverStateException(
        'The computation resulted in a null value. Please use `placeholder()` to provide a default value.',
      );
    }

    return _state.value!;
  }

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode {
    return _state.hashCode;
  }

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(covariant EverCache<T> other) {
    if (identical(this, other)) return true;

    return other._state == _state;
  }

  /// Returns the cached value of type [T] synchronously.
  ///
  /// Throws an [EverStateException] if the value is being evaluated.
  T call() => value;

  /// Fetches and caches the value asynchronously.
  ///
  /// If the value is already computed and not forced, it will return `true`.
  Future<bool> compute({bool force = false}) async {
    if (disposed) {
      throw const EverStateException('Value has been disposed.');
    }

    if (computing) {
      if (placeholder != null) {
        return false;
      }

      throw const EverStateException('Value is being evaluated.');
    }

    if (computed && !force) {
      return true;
    }

    _state = await guard<EverCachedState<T>>(
      () async {
        final result = await _fetch();

        return EverCachedState<T>(result);
      },
      EverCachedState<T>.empty,
      onError: events?.onError?.call,
      onStart: () {
        _isComputing = true;
        events?.onComputing?.call();
      },
      onEnd: () {
        _isComputing = false;
        events?.onComputed?.call();
      },
    );

    return computed;
  }

  /// Fetches and caches the value synchronously.
  ///
  /// If the value is already computed and not forced, it will return `true`.
  void computeSync({bool force = false}) {
    if (disposed) {
      throw const EverStateException('Value has been disposed.');
    }

    if (computing) {
      if (placeholder != null) {
        return;
      }

      throw const EverStateException('Value is being evaluated.');
    }

    if (computed && !force) {
      return;
    }

    backgrounded<EverCachedState<T>>(
      () async {
        final result = await _fetch();

        return EverCachedState<T>(result);
      },
      EverCachedState<T>.empty,
      then: (object) async => _state = object,
      onStart: () {
        _isComputing = true;
        events?.onComputing?.call();
      },
      onEnd: () {
        _isComputing = false;
        events?.onComputed?.call();
      },
      onError: events?.onError,
    );
  }

  // Disposes the cache and resets the value.
  void dispose() {
    unschedule();
    disposer?.call(_state);
    _state = EverCachedState<T>.disposed();
    _isDisposed = true;
    events?.onDisposed?.call();
  }

  /// Invalidates the cached value.
  void invalidate() {
    _state = EverCachedState<T>.empty();
    unschedule();
    events?.onInvalidated?.call();
  }

  @override
  String toString() {
    return 'EverCache<$T>(computed: $computed, computing: $computing, disposed: $disposed, scheduled: $scheduled)';
  }

  /// Unschedules the timer for invalidation (based on TTL).
  void unschedule() {
    _timer?.cancel();
    _timer = null;
  }

  void _scheduleInvalidation() {
    if (ttl == null) {
      return;
    }

    if (scheduled) {
      unschedule();
    }

    _timer = Timer(ttl!.value, invalidate);
  }

  /// Executes the [callback] function with the value of type [T] and returns the result.
  ///
  /// If the value is locked, an [EverStateException] is thrown.
  static Future<R?> synced<R, T>(
    ILockable<T> lockable,
    Future<R> Function(EverCachedState<T> value) callback, {
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    return lockable.use<R>(
      callback,
      onError: onError,
    );
  }
}
