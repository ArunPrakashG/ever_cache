import 'dart:async';

import 'ever_events.dart';
import 'ever_ttl.dart';
import 'helpers.dart';

final class EverCache<T extends Object> {
  EverCache(
    this._fetch, {
    this.events,
    this.ttl,
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

  final Future<T> Function() _fetch;
  final EverEvents? events;
  final EverTTL? ttl;
  final bool debug;
  T? _value;
  Timer? _timer;

  bool get scheduled => _timer != null;
  bool get computed => _value != null;
  bool get computing => _isComputing;
  bool _isComputing = false;

  T get value {
    if (_value == null) {
      backgrounded(compute, debug: debug);
      throw StateError('Value not yet evaluated');
    }

    return _value!;
  }

  T call() => value;

  Future<bool> compute({bool force = false}) async {
    if (_isComputing) {
      return false;
    }

    if (_value != null && !force) {
      return true;
    }

    _isComputing = true;

    _value = await guardAsync(
      function: () async {
        events?.onComputing?.call();
        final value = _fetch();
        events?.onComputed?.call();
        return value;
      },
      onError: (_, __) async => null,
    );

    _isComputing = false;
    return computed;
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

  void unschedule() {
    _timer?.cancel();
    _timer = null;
  }

  void invalidate() {
    _value = null;
    unschedule();
    events?.onInvalidated?.call();
  }

  void dispose() {
    unschedule();
    _value = null;
  }
}
