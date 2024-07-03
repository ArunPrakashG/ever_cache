import 'dart:async';

import '../ever_cache.dart';

/// Executes the [callback] function with the value of type [T] and returns the result.
///
/// If the value is locked, an [EverStateException] is thrown.
FutureOr<R?> lock<R, T>(
  ILockable<T> lockable,
  FutureOr<R> Function(T value) callback, {
  void Function(Object error, StackTrace stackTrace)? onError,
}) async {
  if (lockable._isLocked) {
    throw const EverStateException('Value is locked.');
  }

  return await guard<R>(
    () async => callback(lockable.value),
    onStart: lockable._lock,
    onEnd: lockable._unlock,
    onError: onError,
  );
}

abstract class ILockable<T> extends IEverValue<T> {
  bool _isLocked = false;

  /// Locks the value.
  void _lock() {
    _isLocked = true;
  }

  /// Unlocks the value.
  void _unlock() {
    _isLocked = false;
  }
}

extension LockableExtension<T> on ILockable<T> {
  /// Indicates whether the value is locked.
  bool get locked => _isLocked;

  /// Executes the [callback] function with the value of type [T] and returns the result.
  ///
  /// If the value is locked, an [EverStateException] is thrown.
  FutureOr<R?> lock<R>(
    FutureOr<R> Function(T value) callback, {
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    if (_isLocked) {
      throw const EverStateException('Value is locked.');
    }

    return await guard<R>(
      () async => callback(value),
      onStart: _lock,
      onEnd: _unlock,
      onError: onError,
    );
  }
}
