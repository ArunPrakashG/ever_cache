import '../ever_cache.dart';

extension StateExtensions<T> on EverBaseState<T> {
  R to<R>({
    required R Function(EverValueState<T> state) value,
    required R Function(EverErrorState<T> state) error,
    required R Function(EverEmptyState<T> state) empty,
    required R Function(EverDisposedState<T> state) disposed,
    required R Function(EverNullState<T> state) nullState,
  }) {
    if (this is EverValueState<T>) {
      return value(this as EverValueState<T>);
    }

    if (this is EverErrorState<T>) {
      return error(this as EverErrorState<T>);
    }

    if (this is EverEmptyState<T>) {
      return empty(this as EverEmptyState<T>);
    }

    if (this is EverDisposedState<T>) {
      return disposed(this as EverDisposedState<T>);
    }

    if (this is EverNullState<T>) {
      return nullState(this as EverNullState<T>);
    }

    throw StateError('Unknown state: $this');
  }

  R? toOrNull<R>({
    required R Function(EverValueState<T> state)? value,
    required R Function(EverErrorState<T> state)? error,
    required R Function(EverEmptyState<T> state)? empty,
    required R Function(EverDisposedState<T> state)? disposed,
    required R Function(EverNullState<T> state)? nullState,
  }) {
    if (this is EverValueState<T>) {
      return value?.call(this as EverValueState<T>);
    }

    if (this is EverErrorState<T>) {
      return error?.call(this as EverErrorState<T>);
    }

    if (this is EverEmptyState<T>) {
      return empty?.call(this as EverEmptyState<T>);
    }

    if (this is EverDisposedState<T>) {
      return disposed?.call(this as EverDisposedState<T>);
    }

    if (this is EverNullState<T>) {
      return nullState?.call(this as EverNullState<T>);
    }

    return null;
  }
}
