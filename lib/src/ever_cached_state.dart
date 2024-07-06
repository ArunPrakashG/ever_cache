// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

final class EverCachedState<T> {
  factory EverCachedState(T value) {
    return EverCachedState._(
      value: value,
      computedAt: DateTime.now(),
    );
  }

  factory EverCachedState.empty() {
    return EverCachedState._(
      computedAt: DateTime.now(),
      isEmpty: true,
    );
  }

  factory EverCachedState.placeholder(T value) {
    return EverCachedState._(
      value: value,
      computedAt: DateTime.now(),
      isPlaceholder: true,
    );
  }

  factory EverCachedState.disposed() {
    return const EverCachedState._(
      disposed: true,
    );
  }

  const EverCachedState._({
    this.value,
    this.computedAt,
    this.isPlaceholder = false,
    this.isEmpty = false,
    this.disposed = false,
  });

  final T? value;
  final DateTime? computedAt;
  final bool isPlaceholder;
  final bool isEmpty;
  final bool disposed;

  bool get hasValue {
    return !isEmpty && value != null;
  }

  bool get hasComputedValue {
    return hasValue && computedAt != null && !isPlaceholder;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  bool operator ==(covariant EverCachedState<T> other) {
    if (identical(this, other)) return true;

    return other.value == value;
  }
}
