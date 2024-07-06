import 'dart:async';

import 'ever_events.dart';
import 'ever_ttl.dart';
import 'exceptions/ever_state_exception.dart';
import 'helpers.dart';

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
/// - [debug]: A boolean indicating whether to log debug information.
final class EverCache<T> {
  /// Constructor for creating an instance of [EverCache].
  EverCache(
    this._fetch, {
    this.events,
    this.placeholder,
    this.ttl,
    this.disposer,
    bool earlyCompute = false,
    this.debug = false,
  }) {
    if (earlyCompute) {
      backgrounded(compute);
    }

    if (ttl != null) {
      _scheduleInvalidation();
    }
  }
  /// A function that asynchronously fetches the value to be cached.
  final Future<T> Function() _fetch;
  /// An optional function that returns a placeholder value until the actual value is fetched.
  final T Function()? placeholder;
  /// An optional function that allows to define custom disposing logic for the object.
  final void Function(T? value)? disposer;

  /// An optional instance of [EverEvents] to handle custom events.
  final EverEvents? events;

  /// An optional instance of [EverTTL] to set a TTL for the cached value.
  final EverTTL? ttl;

  /// A boolean indicating whether to log debug information.
  final bool debug;

  T? _value;

  Timer? _timer;

  bool _isComputing = false;

  bool _isDisposed = false;

  /// Indicates whether the value has been computed and cached.
  bool get computed => _value != null;

  /// Indicates whether the value is being computed.
  bool get computing => _isComputing;

  /// Indicates whether the value has been disposed.
  bool get disposed => _isDisposed;

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode {
    return _value?.hashCode ??
        computed.hashCode ^
            disposed.hashCode ^
            computing.hashCode ^
            scheduled.hashCode ^
            _fetch.hashCode;
  }

  /// Indicates whether a timer for invalidation (based on TTL) is scheduled.
  bool get scheduled => _timer != null;
  
  /// The cached value of type [T].
  ///
  /// Throws an [EverStateException] if the value has been disposed or is being evaluated.
  ///
  /// If the value is not yet computed, it will be fetched in the background as soon as possible.
  T get value {
    if (_isDisposed) {
      throw const EverStateException('Value has been disposed.');
    }

    if (_value == null) {
      backgrounded(compute, debug: debug);

      if (placeholder != null) {
        return placeholder!();
      }

      throw const EverStateException('Value is being evaluated.');
    }

    return _value!;
  }

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(covariant EverCache<T> other) {
    if (identical(this, other)) return true;

    return other._value == _value;
  }

  /// Returns the cached value of type [T] synchronously.
  ///
  /// Throws an [EverStateException] if the value is being evaluated.
  T call() => value;

  /// Fetches and caches the value asynchronously.
  ///
  /// If the value is already computed and not forced, it will return `true`.
  Future<bool> compute({bool force = false}) async {
    if (_isDisposed) {
      throw const EverStateException('Value has been disposed.');
    }

    if (_isComputing) {
      if (placeholder != null) {
        return false;
      }

      throw const EverStateException('Value is being evaluated.');
    }

    if (_value != null && !force) {
      return true;
    }

    _value = await guard(
      () async => _fetch(),
      onError: (e, s) {
        _isComputing = false;
        events?.onError?.call(e, s);
      },
      onStart: () {
        _isComputing = true;
        events?.onComputing?.call();
        final value = await _fetch();
        events?.onComputed?.call();
        return value;
      },
      onError: (_, __) async => null,
    );

    _isComputing = false;
    return computed;
  }

  /// Fetches and caches the value synchronously.
  ///
  /// If the value is already computed and not forced, it will return `true`.
  void computeSync({bool force = false}) {
    if (_isDisposed) {
      throw const EverStateException('Value has been disposed.');
    }

    if (_isComputing) {
      if (placeholder != null) {
        return;
      }

      throw const EverStateException('Value is being evaluated.');
    }

    if (_value != null && !force) {
      return;
    }

    return backgrounded(
      () async => _fetch(),
      then: (object) => _value = object,
      onStart: () {
        _isComputing = true;
        events?.onComputing?.call();
        _value = await _fetch();
        events?.onComputed?.call();
        _isComputing = false;
      },
      debug: debug,
      onError: (e, s) {
        _isComputing = false;
        events?.onError?.call(e, s);
      },
    );
  }

  // Disposes the cache and resets the value.
  void dispose() {
    unschedule();
    disposer?.call(_value);
    _value = null;
    _isDisposed = true;
    events?.onDisposed?.call();
  }

  /// Invalidates the cached value.
  void invalidate() {
    _value = null;
    unschedule();
    events?.onInvalidated?.call();
  }

  @override
  String toString() {
    return 'EverCache(_fetch: $_fetch, placeholder: $placeholder, events: $events, ttl: $ttl)';
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
}
