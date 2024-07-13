import 'dart:async';

import '../ever_cache.dart';

abstract base class ILockable<T> extends IEverValue<T> {
  bool _isLocked = false;

  bool get locked => _isLocked;

  /// Locks the value.
  void lock() {
    _isLocked = true;
  }

  /// Unlocks the value.
  void unlock() {
    _isLocked = false;
  }

  /// Executes the [callback] function with the value of type [T] and returns the result.
  ///
  /// If the value is locked, an [EverStateException] is thrown.
  Future<R?> use<R>(
    Future<R> Function(EverBaseState<T> value) callback, {
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    if (locked) {
      throw const EverStateException('Value is locked.');
    }

    return guard<R?>(
      () async => callback(state),
      () => null,
      onStart: lock,
      onEnd: unlock,
      onError: onError,
    );
  }
}
