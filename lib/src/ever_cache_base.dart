import 'dart:async';

import '../ever_cache.dart';

typedef AsyncComputationDelegate<T> = Future<T> Function();
typedef SyncComputationDelegate<T> = T Function();
typedef EverComputationDelegate<T> = FutureOr<T> Function();
typedef DisposerDelegate<T> = void Function(EverBaseState<T> value);
typedef PlaceholderDelegate<T> = T Function();

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
  factory EverCache(
    AsyncComputationDelegate<T> computation, {
    PlaceholderDelegate? placeholder,
    DisposerDelegate<T>? disposer,
    EverEvents? events,
    EverTTL? ttl,
    bool earlyCompute = false,
  }) {
    return EverCache._(
      () async => computation(),
      placeholder: placeholder,
      disposer: disposer,
      events: events,
      ttl: ttl,
      earlyCompute: earlyCompute,
    );
  }

  EverCache._(
    this._computation, {
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
  }

  /// Constructor for creating an instance of [EverCache] with synchronous computation.
  factory EverCache.sync(
    SyncComputationDelegate<T> computation, {
    PlaceholderDelegate? placeholder,
    DisposerDelegate<T>? disposer,
    EverEvents? events,
    EverTTL? ttl,
    bool earlyCompute = false,
  }) {
    return EverCache._(
      computation,
      placeholder: placeholder,
      disposer: disposer,
      events: events,
      ttl: ttl,
      earlyCompute: earlyCompute,
    );
  }

  /// A function that asynchronously or synchronously fetches the value to be cached.
  final EverComputationDelegate<T> _computation;

  /// An optional function that returns a placeholder value until the actual value is fetched.
  final PlaceholderDelegate? placeholder;

  /// An optional function that allows to define custom disposing logic for the object.
  final DisposerDelegate<T>? disposer;

  /// An optional instance of [EverEvents] to handle custom events.
  final EverEvents? events;

  /// An optional instance of [EverTTL] to set a TTL for the cached value.
  final EverTTL? ttl;

  EverBaseState<T> _state = EverEmptyState<T>();
  Timer? _timer;

  /// Indicates whether the value has been computed and cached.
  bool get computed => _state is EverValueState<T>;

  bool get disposed => _state is EverDisposedState<T>;

  bool get isSyncComputation => _computation is SyncComputationDelegate<T>;

  /// Indicates whether the value is being computed.
  bool get computing => _state is EverComputingState<T>;

  /// Indicates whether a timer for invalidation (based on TTL) is scheduled.
  bool get scheduled => _timer != null;

  /// Returns the current state of the `EverBaseState` object.
  ///
  /// If the state has not been computed yet and is not currently being computed,
  /// this method will trigger a synchronous computation of the state by calling
  /// the `computeSync()` method.
  ///
  /// Returns the current state of the `EverBaseState` object.
  @override
  EverBaseState<T> get state {
    if (!disposed && !computed && !computing) {
      computeSync();
    }

    return _state;
  }

  /// Returns the value of the cache.
  ///
  /// If the value has not been computed yet, it will be computed synchronously.
  /// If the value is still being computed, it will throw an exception.
  /// If the computation resulted in a null value, it will throw an exception.
  /// If a placeholder function is provided, it will return the result of the placeholder function.
  ///
  /// Throws an [EverStateException] if the value is being computed or if the computation resulted in a null value.
  T get value {
    if (disposed) {
      throw const EverStateException('Value is disposed.');
    }

    if (!computed && !computing) {
      computeSync();
    }

    if (!computed) {
      // value is still not computed, that means it is running in the background
      // return placeholder if it is provided
      if (placeholder != null) {
        return placeholder!();
      }

      // else throw an exception
      throw const EverStateException('Value is being computed.');
    }

    // if the value is null, throw an exception
    if (state is EverNullState<T>) {
      throw const EverStateException(
        'The computation resulted in a null value. Please use `placeholder()` to provide a default value to safely access the value.',
      );
    }

    return (state as EverValueState<T>).value;
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
      throw const EverStateException('Value is disposed.');
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

    try {
      events?.onComputing?.call();
      _state = EverComputingState<T>();

      final value = await _computation();

      if (value == null) {
        _state = EverNullState<T>(DateTime.now());
        return false;
      }

      _state = EverValueState<T>(value, DateTime.now());
    } catch (e, s) {
      _state = EverErrorState<T>(e, s);
      events?.onError?.call(e, s);
    } finally {
      if (_state is EverComputingState<T>) {
        _state = EverEmptyState<T>();
      }

      events?.onComputed?.call();
    }

    return computed;
  }

  /// Fetches and caches the value synchronously.
  ///
  /// If the value is already computed and not forced, it will return `true`.
  void computeSync({bool force = false}) {
    if (disposed) {
      throw const EverStateException('Value is disposed.');
    }

    if (computed && !force) {
      return;
    }

    if (computing) {
      if (placeholder != null) {
        return;
      }

      throw const EverStateException('Value is being evaluated.');
    }

    if (isSyncComputation) {
      try {
        events?.onComputing?.call();
        _state = EverComputingState<T>();

        final value = (_computation as SyncComputationDelegate<T>)();

        if (value == null) {
          _state = EverNullState<T>(DateTime.now());
          return;
        }

        _state = EverValueState<T>(value, DateTime.now());
      } catch (e, s) {
        _state = EverErrorState<T>(e, s);
        events?.onError?.call(e, s);
      } finally {
        if (_state is EverComputingState<T>) {
          _state = EverEmptyState<T>();
        }

        events?.onComputed?.call();
      }

      return;
    }

    Timer.run(
      () async {
        try {
          events?.onComputing?.call();
          _state = EverComputingState<T>();

          final value = await _computation();

          if (value == null) {
            _state = EverNullState<T>(DateTime.now());
            return;
          }

          _state = EverValueState<T>(value, DateTime.now());
        } catch (e, s) {
          _state = EverErrorState<T>(e, s);
          events?.onError?.call(e, s);
        } finally {
          if (_state is EverComputingState<T>) {
            _state = EverEmptyState<T>();
          }

          events?.onComputed?.call();
        }
      },
    );
  }

  // Disposes the cache and resets the value.
  void dispose() {
    unschedule();
    disposer?.call(_state);
    _state = EverDisposedState<T>();
    events?.onDisposed?.call();
  }

  /// Invalidates the cached value.
  void invalidate() {
    _state = EverEmptyState<T>();
    unschedule();
    events?.onInvalidated?.call();
  }

  @override
  String toString() {
    return 'EverCache<$T>(value: $value)';
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
    Future<R> Function(EverBaseState<T> value) callback, {
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    return lockable.use<R>(
      callback,
      onError: onError,
    );
  }
}
