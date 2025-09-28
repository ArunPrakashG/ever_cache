import 'ever_cache_base.dart';
import 'ever_cached_state.dart';
import 'ever_events.dart';
import 'ever_ttl.dart';

/// A simple multi-key cache built on top of EverCache.
/// Each key manages its own EverCache instance and shares options like TTL and events.
class EverCacheMap<K, V> {
  EverCacheMap(
    this._factory, {
    this.placeholder,
    this.disposer,
    this.baseEvents,
    this.ttl,
  });

  final Future<V> Function(K key) _factory;
  final V Function()? placeholder;
  final void Function(EverBaseState<V> value)? disposer;
  final EverEvents? baseEvents;
  final EverTTL? ttl;

  final Map<K, EverCache<V>> _caches = <K, EverCache<V>>{};

  EverCache<V> _getCache(K key) {
    return _caches.putIfAbsent(
      key,
      () => EverCache<V>(
        () => _factory(key),
        placeholder: placeholder,
        disposer: disposer,
        events: baseEvents,
        ttl: ttl,
      ),
    );
  }

  /// Returns current snapshot state for a key without triggering compute.
  EverBaseState<V> stateFor(K key) => _getCache(key).snapshot;

  /// Returns value or placeholder/null for a key; may trigger compute if accessed via .value.
  V getValue(K key) => _getCache(key).value;

  V? getValueOrNull(K key) => _getCache(key).valueOrNull;

  Future<V> ensure(K key) => _getCache(key).ensure();

  Future<V> computeAndGet(K key, {bool force = false}) =>
      _getCache(key).computeAndGet(force: force);

  void invalidate(K key, {bool disposeValue = false}) =>
      _getCache(key).invalidate(disposeValue: disposeValue);

  void disposeKey(K key) => _getCache(key).dispose();

  void disposeAll() {
    for (final cache in _caches.values) {
      cache.dispose();
    }
    _caches.clear();
  }
}
