import 'dart:async';
import 'dart:developer';

void backgrounded<T>(
  FutureOr<T> Function() callback, {
  FutureOr<void> Function(T object)? then,
  bool debug = false,
}) {
  Timer.run(() async {
    await guardAsync<void>(
      function: () async {
        final result = await callback();

        if (then != null) {
          await then(result);
        }
      },
      onError: (error, stackTrace) async {
        if (!debug) {
          return;
        }

        log(
          error.toString(),
          time: DateTime.now(),
          name: 'backgrounded()',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  });
}

Future<T> guardAsync<T>({
  required Future<T> Function() function,
  required Future<T> Function(Object error, StackTrace stackTrace) onError,
}) async {
  try {
    return await function();
  } catch (error, stackTrace) {
    return onError(error, stackTrace);
  }
}
