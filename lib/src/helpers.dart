import 'dart:async';

/// Runs a function in the background.
void backgrounded<T>(
  FutureOr<T> Function() callback, {
  FutureOr<void> Function(T object)? then,
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
      onStart: onStart,
      onEnd: onEnd,
      onError: onError,
    );
  });
}

/// Guards an asynchronous function.
FutureOr<T?> guard<T>(
  FutureOr<T> Function() function, {
  void Function(Object error, StackTrace stackTrace)? onError,
  void Function()? onStart,
  void Function()? onEnd,
}) async {
  try {
    onStart?.call();
    return await function();
  } catch (error, stackTrace) {
    onError?.call(error, stackTrace);
    return null;
  } finally {
    onEnd?.call();
  }
}
