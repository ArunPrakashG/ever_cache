import 'dart:async';

import '../ever_cache.dart';

typedef AsyncComputationDelegate<T> = Future<T> Function();
typedef SyncComputationDelegate<T> = T Function();
typedef EverComputationDelegate<T> = FutureOr<T> Function();
typedef DisposerDelegate<T> = void Function(EverBaseState<T> value);
typedef PlaceholderDelegate<T> = T Function();

/// Controls how errors thrown during computation are handled.
///
/// - [none]: Errors are not cached. Subsequent accesses may retry computation.
/// - [cacheUntilInvalidate]: The first error is cached and rethrown on `value`
///   access until `invalidate()` is called (similar to C# Lazy<T> default behavior).
enum EverErrorCachingMode {
  none,
  cacheUntilInvalidate,
}

/// Controls how new computations are published relative to existing values.
///
/// - [singlePublisher]: Default. Only one computation at a time; errors replace state.
/// - [publicationOnly]: When a value is already present and a refresh occurs, keep the
///   old value visible until a new successful value arrives; errors during refresh do
///   not overwrite the current value.
enum EverPublishMode {
  singlePublisher,
  publicationOnly,
}

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
    EverErrorCachingMode errorCaching = EverErrorCachingMode.none,
    bool allowNull = false,
    T Function()? onNull,
    bool earlyCompute = false,
    EverPublishMode publishMode = EverPublishMode.singlePublisher,
  }) {
    return EverCache._(
      () async => computation(),
      placeholder: placeholder,
      disposer: disposer,
      events: events,
      ttl: ttl,
      errorCaching: errorCaching,
      allowNull: allowNull,
      onNull: onNull,
      earlyCompute: earlyCompute,
      publishMode: publishMode,
    );
  }

  EverCache._(
    this._computation, {
    this.events,
    this.placeholder,
    this.ttl,
    this.disposer,
    this.errorCaching = EverErrorCachingMode.none,
    this.publishMode = EverPublishMode.singlePublisher,
    bool allowNull = false,
    T Function()? onNull,
    bool earlyCompute = false,
  }) {
    _allowNullFlag = allowNull;
    _onNullCallback = onNull;
    if (earlyCompute) {
      computeSync();
    }
  }

  /// Constructor for creating an instance of [EverCache] with synchronous computation.
  factory EverCache.sync(
    SyncComputationDelegate<T> computation, {
    PlaceholderDelegate? placeholder,
    DisposerDelegate<T>? disposer,
    EverEvents? events,
    EverTTL? ttl,
    EverErrorCachingMode errorCaching = EverErrorCachingMode.none,
    bool allowNull = false,
    T Function()? onNull,
    bool earlyCompute = false,
    EverPublishMode publishMode = EverPublishMode.singlePublisher,
  }) {
    return EverCache._(
      computation,
      placeholder: placeholder,
      disposer: disposer,
      events: events,
      ttl: ttl,
      errorCaching: errorCaching,
      allowNull: allowNull,
      onNull: onNull,
      earlyCompute: earlyCompute,
      publishMode: publishMode,
    );
  }

  /// Creates an EverCache with a pre-computed value.
  factory EverCache.value(
    T value, {
    DisposerDelegate<T>? disposer,
    EverEvents? events,
    EverTTL? ttl,
    EverPublishMode publishMode = EverPublishMode.singlePublisher,
  }) {
    final cache = EverCache._(
      () => value,
      disposer: disposer,
      events: events,
      ttl: ttl,
      publishMode: publishMode,
    );

    cache._state = EverValueState<T>(value, DateTime.now());
    cache._scheduleInvalidation();
    return cache;
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
  Timer? _prefetchTimer;
  Completer<void>? _inflight; // used to await ongoing computations
  int _computeCount = 0;
  DateTime? _lastComputedAt;
  Object? _lastError;
  StackTrace? _lastErrorStack;
  int _cancelToken = 0; // increments on cancel; computations capture token
  DateTime? _nextExpiryAt;
  DateTime? _nextPrefetchAt;

  /// Error caching mode that controls how errors are surfaced.
  final EverErrorCachingMode errorCaching;

  /// Publishing behavior for refreshes
  final EverPublishMode publishMode;

  /// Indicates whether the value has been computed and cached.
  bool get computed => _state is EverValueState<T>;

  /// Mirrors C# Lazy<T>.IsValueCreated for familiarity.
  bool get isValueCreated => computed;

  bool get disposed => _state is EverDisposedState<T>;

  bool get isSyncComputation => _computation is SyncComputationDelegate<T>;

  /// Indicates whether the value is being computed.
  bool get computing => _state is EverComputingState<T>;

  /// Indicates whether a timer for invalidation (based on TTL) is scheduled.
  bool get scheduled => _timer != null;

  /// Returns the current state without triggering computation.
  EverBaseState<T> get snapshot => _state;

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

    // Sliding TTL: on access, if mode is sliding and slideOnAccess=true, reschedule TTL.
    if ((ttl?.mode == EverTTLMode.sliding) && ttl!.slideOnAccess && _state is EverValueState<T>) {
      _scheduleInvalidation();
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

    // If error caching is enabled and we previously failed, rethrow the stored error.
    if (errorCaching == EverErrorCachingMode.cacheUntilInvalidate &&
        _state is EverErrorState<T>) {
      final s = _state as EverErrorState<T>;
      Error.throwWithStackTrace(s.error, s.stackTrace);
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

    // Sliding TTL reschedule on successful value access
    if ((ttl?.mode == EverTTLMode.sliding) && ttl!.slideOnAccess) {
      _scheduleInvalidation();
    }

    // if the value is null, throw an exception
    if (state is EverNullState<T>) {
      throw const EverStateException(
        'The computation resulted in a null value. Please use `placeholder()` to provide a default value to safely access the value.',
      );
    }

    return (state as EverValueState<T>).value;
  }

  /// Returns the value if available, otherwise returns `null` (or placeholder if provided).
  /// This never throws and does not start a new computation unless already running.
  T? get valueOrNull {
    if (disposed) return null;

    if (computed) {
      if ((ttl?.mode == EverTTLMode.sliding) && ttl!.slideOnAccess) {
        _scheduleInvalidation();
      }
      return (snapshot as EverValueState<T>).value;
    }

    if (computing) {
      return placeholder?.call();
    }

    // Do not auto-start computation; just return placeholder or null.
    return placeholder?.call();
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

    final myToken = _cancelToken;
    try {
  events?.onComputing?.call();
  _emitEvent(EverEvent<T>(_evtComputing, state: _state));
      final hadValue = computed; // capture whether a value already exists before computing
      if (!(publishMode == EverPublishMode.publicationOnly && hadValue)) {
        _state = EverComputingState<T>();
      }
      _inflight = Completer<void>();

  final value = await _computation();

      // if cancelled in-between, ignore publish
      if (myToken != _cancelToken) {
        return false;
      }

      if (value == null) {
        if (_allowNull) {
          _state = EverValueState<T?>(null as T?, DateTime.now()) as EverBaseState<T>;
        } else if (_onNull != null) {
          final fallback = _onNull!.call();
          _state = EverValueState<T>(fallback, DateTime.now());
        } else {
          if (publishMode == EverPublishMode.publicationOnly && hadValue) {
            // Keep old value; treat as refresh failure without overwriting state
            events?.onError?.call(ArgumentError('Null value in refresh'), StackTrace.current);
            _emitEvent(EverEvent<T>(_evtError, state: _state, error: ArgumentError('Null value in refresh'), stackTrace: StackTrace.current));
            return false;
          } else {
            _state = EverNullState<T>(DateTime.now());
            return false;
          }
        }
      }
      _state = EverValueState<T>(value, DateTime.now());
      _scheduleInvalidation();
      _computeCount++;
      _lastComputedAt = DateTime.now();
      _lastError = null;
      _lastErrorStack = null;
    } catch (e, s) {
      if (publishMode == EverPublishMode.publicationOnly && computed) {
        // Do not overwrite existing value during refresh
        events?.onError?.call(e, s);
        _emitEvent(EverEvent<T>(_evtError, state: _state, error: e, stackTrace: s));
        _lastError = e;
        _lastErrorStack = s;
      } else {
        _state = EverErrorState<T>(e, s);
        events?.onError?.call(e, s);
        _emitEvent(EverEvent<T>(_evtError, state: _state, error: e, stackTrace: s));
        _lastError = e;
        _lastErrorStack = s;
      }
    } finally {
      if (_state is EverComputingState<T>) {
        _state = EverEmptyState<T>();
      }

      events?.onComputed?.call();
      _emitEvent(EverEvent<T>(_evtComputed, state: _state));
      _inflight?.complete();
      _inflight = null;
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
  _emitEvent(EverEvent<T>(_evtComputing, state: _state));
        final hadValue = computed;
        if (!(publishMode == EverPublishMode.publicationOnly && hadValue)) {
          _state = EverComputingState<T>();
        }
        _inflight = Completer<void>();

  final value = (_computation as SyncComputationDelegate<T>)();

        if (value == null) {
          if (_allowNull) {
            _state = EverValueState<T?>(null as T?, DateTime.now()) as EverBaseState<T>;
          } else if (_onNull != null) {
            final fallback = _onNull!.call();
            _state = EverValueState<T>(fallback, DateTime.now());
          } else {
            if (publishMode == EverPublishMode.publicationOnly && hadValue) {
              events?.onError?.call(ArgumentError('Null value in refresh'), StackTrace.current);
              _emitEvent(EverEvent<T>(_evtError, state: _state, error: ArgumentError('Null value in refresh'), stackTrace: StackTrace.current));
              return;
            } else {
              _state = EverNullState<T>(DateTime.now());
              return;
            }
          }
        }

        _state = EverValueState<T>(value, DateTime.now());
        _scheduleInvalidation();
        _computeCount++;
        _lastComputedAt = DateTime.now();
        _lastError = null;
        _lastErrorStack = null;
      } catch (e, s) {
        if (publishMode == EverPublishMode.publicationOnly && computed) {
          events?.onError?.call(e, s);
          _emitEvent(EverEvent<T>(_evtError, state: _state, error: e, stackTrace: s));
          _lastError = e;
          _lastErrorStack = s;
        } else {
          _state = EverErrorState<T>(e, s);
          events?.onError?.call(e, s);
          _emitEvent(EverEvent<T>(_evtError, state: _state, error: e, stackTrace: s));
          _lastError = e;
          _lastErrorStack = s;
        }
      } finally {
        if (_state is EverComputingState<T>) {
          _state = EverEmptyState<T>();
        }

        events?.onComputed?.call();
        _emitEvent(EverEvent<T>(_evtComputed, state: _state));
        _inflight?.complete();
        _inflight = null;
      }

      return;
    }

    Timer.run(
      () async {
        try {
          events?.onComputing?.call();
          _emitEvent(EverEvent<T>(_evtComputing, state: _state));
          final hadValue = computed;
          if (!(publishMode == EverPublishMode.publicationOnly && hadValue)) {
            _state = EverComputingState<T>();
          }
          _inflight = Completer<void>();

          final value = await _computation();

          if (value == null) {
            if (_allowNull) {
              _state = EverValueState<T?>(null as T?, DateTime.now()) as EverBaseState<T>;
            } else if (_onNull != null) {
              final fallback = _onNull!.call();
              _state = EverValueState<T>(fallback, DateTime.now());
            } else {
              if (publishMode == EverPublishMode.publicationOnly && hadValue) {
                events?.onError?.call(ArgumentError('Null value in refresh'), StackTrace.current);
                _emitEvent(EverEvent<T>(_evtError, state: _state, error: ArgumentError('Null value in refresh'), stackTrace: StackTrace.current));
                return;
              } else {
                _state = EverNullState<T>(DateTime.now());
                return;
              }
            }
          }

          _state = EverValueState<T>(value, DateTime.now());
          _scheduleInvalidation();
          _computeCount++;
          _lastComputedAt = DateTime.now();
          _lastError = null;
          _lastErrorStack = null;
        } catch (e, s) {
          if (publishMode == EverPublishMode.publicationOnly && computed) {
            events?.onError?.call(e, s);
            _emitEvent(EverEvent<T>(_evtError, state: _state, error: e, stackTrace: s));
            _lastError = e;
            _lastErrorStack = s;
          } else {
            _state = EverErrorState<T>(e, s);
            events?.onError?.call(e, s);
            _emitEvent(EverEvent<T>(_evtError, state: _state, error: e, stackTrace: s));
            _lastError = e;
            _lastErrorStack = s;
          }
        } finally {
          if (_state is EverComputingState<T>) {
            _state = EverEmptyState<T>();
          }

          events?.onComputed?.call();
          _emitEvent(EverEvent<T>(_evtComputed, state: _state));
          _inflight?.complete();
          _inflight = null;
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
    _emitEvent(EverEvent<T>(_evtDisposed, state: _state));
  }

  /// Invalidates the cached value.
  void invalidate({bool disposeValue = false}) {
    if (disposeValue && _state is EverValueState<T>) {
      disposer?.call(_state);
    }
    _state = EverEmptyState<T>();
    unschedule();
    events?.onInvalidated?.call();
    _emitEvent(EverEvent<T>(_evtInvalidated, state: _state));
  }

  @override
  String toString() {
    // Do not force computation or throw; provide a lightweight summary.
    final s = snapshot;
    final stateLabel = switch (s) {
      EverValueState<T>() => 'value',
      EverComputingState<T>() => 'computing',
      EverErrorState<T>() => 'error',
      EverDisposedState<T>() => 'disposed',
      EverNullState<T>() => 'null',
      EverEmptyState<T>() => 'empty',
      _ => 'unknown',
    };
    return 'EverCache<$T>(state: $stateLabel)';
  }

  /// Unschedules the timer for invalidation (based on TTL).
  void unschedule() {
    _timer?.cancel();
    _timer = null;
    _prefetchTimer?.cancel();
    _prefetchTimer = null;
    _nextExpiryAt = null;
    _nextPrefetchAt = null;
  }

  void _scheduleInvalidation() {
    if (ttl == null) {
      return;
    }

    if (scheduled) {
      unschedule();
    }

    // Schedule main expiry
    final now = DateTime.now();
    _nextExpiryAt = now.add(ttl!.value);
    _timer = Timer(ttl!.value, () {
      // If prefetch is configured, run SWR and then invalidate (if compute fails, keep stale until next access)
      if (ttl!.prefetchBeforeExpiry != null) {
        // start background recompute; do not force exceptions to overwrite
        _schedulePrefetch();
      }
      invalidate();
    });

    // Schedule prefetch ahead of expiry (if configured and earlier than value)
    _schedulePrefetch();
  }

  /// Compute and return the value; coalesces concurrent callers.
  Future<T> computeAndGet({bool force = false}) async {
    if (computed && !force) {
      return (snapshot as EverValueState<T>).value;
    }
    if (computing) {
      await _inflight?.future;
      if (computed) return (snapshot as EverValueState<T>).value;
      if (snapshot is EverErrorState<T>) {
        final s = snapshot as EverErrorState<T>;
        Error.throwWithStackTrace(s.error, s.stackTrace);
      }
      throw const EverStateException('Value is being computed.');
    }
    await compute(force: force);
    if (computed) return (snapshot as EverValueState<T>).value;
    if (snapshot is EverErrorState<T>) {
      final s = snapshot as EverErrorState<T>;
      Error.throwWithStackTrace(s.error, s.stackTrace);
    }
    throw const EverStateException('Value is being computed.');
  }

  /// Cancels the in-flight computation (if any). Future computes will proceed.
  void cancel() {
    if (!computing) return;
    _cancelToken++;
  }

  // Internal flags derived from constructor
  bool _allowNullFlag = false;
  T Function()? _onNullCallback;

  bool get _allowNull => _allowNullFlag;
  T Function()? get _onNull => _onNullCallback;

  void _schedulePrefetch() {
    if (ttl?.prefetchBeforeExpiry == null) {
      return;
    }
    final prefetch = ttl!.prefetchBeforeExpiry!;
    if (prefetch <= Duration.zero || prefetch >= ttl!.value) {
      return;
    }
    _prefetchTimer?.cancel();
    final delay = ttl!.value - prefetch;
    final now = DateTime.now();
    _nextPrefetchAt = now.add(delay);
    _prefetchTimer = Timer(delay, () async {
      // If disposed or already computing, skip
      if (disposed || computing || _inflight != null) return;
      // Try background recompute but don't throw
      try {
        await compute(force: true);
      } catch (_) {
        // ignore
      }
    });
  }

  // --- Null handling options are configured via constructor and stored in *_Flag/callback.

  // Public diagnostics
  int get computeCount => _computeCount;
  DateTime? get lastComputedAt => _lastComputedAt;
  Object? get lastError => _lastError;
  StackTrace? get lastErrorStackTrace => _lastErrorStack;
  DateTime? get nextExpiryAt => _nextExpiryAt;
  DateTime? get nextPrefetchAt => _nextPrefetchAt;
  bool get prefetchScheduled => _prefetchTimer != null;

  // --- Event stream ---
  static const _evtComputing = 'computing';
  static const _evtComputed = 'computed';
  static const _evtInvalidated = 'invalidated';
  static const _evtDisposed = 'disposed';
  static const _evtError = 'error';

  final StreamController<EverEvent<T>> _eventsCtrl =
      StreamController<EverEvent<T>>.broadcast();

  Stream<EverEvent<T>> get eventStream => _eventsCtrl.stream;

  void _emitEvent(EverEvent<T> e) {
    if (!_eventsCtrl.hasListener) return;
    _eventsCtrl.add(e);
  }

  /// Ensures a value is available and returns it as a Future.
  ///
  /// - If already computed, returns immediately.
  /// - If a computation is in-flight, waits for it to finish.
  /// - Otherwise, starts an asynchronous computation.
  Future<T> ensure() async {
    if (disposed) {
      throw const EverStateException('Value is disposed.');
    }

    if (computed) {
      return (snapshot as EverValueState<T>).value;
    }

    if (errorCaching == EverErrorCachingMode.cacheUntilInvalidate &&
        snapshot is EverErrorState<T>) {
      final s = snapshot as EverErrorState<T>;
      Error.throwWithStackTrace(s.error, s.stackTrace);
    }

    if (!computing) {
      // Kick off async computation
      // We ignore the result; we will await _inflight below.
      // Any exceptions are handled via state and rethrown if caching mode requires.
      unawaited(compute());
    }

    // Wait for current computation to complete.
    // If, for some reason, _inflight is null, create a microtask to yield.
    final inflight = _inflight;
    if (inflight != null) {
      await inflight.future;
    } else {
      await Future<void>.delayed(Duration.zero);
    }

    // After completion, return or throw accordingly.
    if (computed) {
      return (snapshot as EverValueState<T>).value;
    }

    if (snapshot is EverNullState<T>) {
      throw const EverStateException(
        'The computation resulted in a null value.',
      );
    }

    if (snapshot is EverErrorState<T>) {
      final s = snapshot as EverErrorState<T>;
      Error.throwWithStackTrace(s.error, s.stackTrace);
    }

    // If we reached here, treat as empty and try again next call.
    throw const EverStateException('Value is being computed.');
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
