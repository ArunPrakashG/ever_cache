import 'ever_cached_state.dart';

abstract class IEverValue<T> {
  T get value;

  EverBaseState<T> get state;
}
