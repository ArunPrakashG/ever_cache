import 'ever_cached_state.dart';

abstract class IEverValue<T> {
  T get value;

  EverCachedState<T> get state;
}
