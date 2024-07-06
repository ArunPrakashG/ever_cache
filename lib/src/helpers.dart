import 'dart:async';

/// Runs a function in the background.
void backgrounded<T>(
  Future<T> Function() callback,
  T Function() orElse, {
  Future<void> Function(T object)? then,
  void Function(Object error, StackTrace stackTrace)? onError,
  void Function()? onStart,
  void Function()? onEnd,
}) {
  Timer.run(() async {
    await guard<void>(
      () async {
        final result = await callback();

        if (then != null) {
          await then(result);
        }
      },
      orElse,
      onStart: onStart,
      onEnd: onEnd,
      onError: onError,
    );
  });
}

/// Guards an asynchronous function.
Future<T> guard<T>(
  Future<T> Function() function,
  T Function() orElse, {
  void Function(Object error, StackTrace stackTrace)? onError,
  void Function()? onStart,
  void Function()? onEnd,
}) async {
  try {
    onStart?.call();
    return await function();
  } catch (error, stackTrace) {
    onError?.call(error, stackTrace);
    return orElse();
  } finally {
    onEnd?.call();
  }
}
