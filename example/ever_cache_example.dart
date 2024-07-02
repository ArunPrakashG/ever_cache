// ignore_for_file: avoid_print

import 'package:ever_cache/ever_cache.dart';

void main() {
  final cache = EverCache<String>(
    () async {
      await Future.delayed(const Duration(seconds: 1));
      return 'test';
    },
    placeholder: () => 'placeholder',
    events: EverEvents(
      onComputing: () => print('Computing...'),
      onComputed: () => print('Computed!'),
    ),
    earlyCompute: true,
  );

  print(cache.value);
}
