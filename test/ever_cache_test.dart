import 'dart:async';

import 'package:ever_cache/ever_cache.dart';
import 'package:test/test.dart';

void main() {
  group(
    'EverCache Tests',
    () {
      EverCache<String> cache;

      test(
        'value should throw if being computed and no placeholder provided',
        () {
          cache = EverCache(
            () async {
              await delay;
              return 'test';
            },
          );

          expect(() => cache.value, throwsA(isA<EverStateException>()));
          cache.dispose();
        },
      );

      test(
        'value should return placeholder if provided and value is being computed',
        () async {
          cache = EverCache(
            () async {
              await delay;
              return 'test';
            },
            placeholder: () => 'placeholder',
          );

          expect(cache.value, equals('placeholder'));
          cache.dispose();
        },
      );

      test(
        'compute should update value and trigger events',
        () async {
          var computing = false;
          var computed = false;

          cache = EverCache(
            () async {
              await delay;
              return 'computed';
            },
            events: EverEvents(
              onComputing: () => computing = true,
              onComputed: () => computed = true,
            ),
          );

          await cache.compute();
          expect(computing, isTrue);
          expect(computed, isTrue);
          expect(cache.value, equals('computed'));
          cache.dispose();
        },
      );

      test(
        'invalidate should reset value and trigger onInvalidated event',
        () async {
          var invalidated = false;
          cache = EverCache(
            () async {
              await delay;
              return 'computed';
            },
            events: EverEvents(
              onInvalidated: () => invalidated = true,
            ),
          );

          await cache.compute();
          cache.invalidate();

          expect(invalidated, isTrue);
          expect(() => cache.value, throwsA(isA<EverStateException>()));
        },
      );

      test(
        'dispose should unschedule and reset value',
        () {
          cache = EverCache(
            () async => 'to be disposed',
          );

          cache.dispose();
          expect(cache.scheduled, isFalse);
          expect(() => cache.value, throwsA(isA<EverStateException>()));
        },
      );

      test(
        'scheduled should be true after compute if ttl is provided',
        () async {
          cache = EverCache(
            () async => 'test',
            ttl: const EverTTL(Duration(seconds: 2)),
          );

          await cache.compute();
          expect(cache.scheduled, isTrue);
          cache.dispose();
        },
      );

      test(
        'scheduled should be false after unschedule is called',
        () async {
          cache = EverCache(
            () async => 'test',
            ttl: const EverTTL(Duration(seconds: 2)),
          );

          await cache.compute();
          cache.unschedule();

          expect(cache.scheduled, isFalse);
        },
      );

      test(
        'dispose should prevent further computation',
        () async {
          cache = EverCache(
            () async => 'to be disposed',
          );

          cache.dispose();
          expect(
            () async => cache.compute(),
            throwsA(isA<EverStateException>()),
          );
        },
      );

      test(
        'compute should not update value if called with force=false when value already computed',
        () async {
          const initialValue = 'initial';
          const secondValue = 'second';
          var initialCompleted = false;

          cache = EverCache(
            () async {
              if (initialCompleted) {
                return secondValue;
              }

              return initialValue;
            },
          );

          await cache.compute();
          final first = cache.value;
          initialCompleted = true;
          await cache.compute();
          final second = cache.value;
          expect(first, equals(second));
          cache.dispose();
        },
      );

      test(
        'compute should update value if called with force=true even when value already computed',
        () async {
          const initialValue = 'initial';
          const secondValue = 'second';
          var initialCompleted = false;

          cache = EverCache(
            () async {
              if (initialCompleted) {
                return secondValue;
              }

              return initialValue;
            },
          );

          await cache.compute();
          final first = cache.value;
          initialCompleted = true;
          await cache.compute(force: true);
          final second = cache.value;
          expect(first, isNot(equals(second)));
          cache.dispose();
        },
      );

      test(
        'value should return computed value after compute is called',
        () async {
          cache = EverCache(
            () async => 'computed value',
          );

          await cache.compute();
          expect(cache.value, equals('computed value'));
        },
      );

      test(
        'computing should be true during computation',
        () async {
          cache = EverCache(
            () async {
              await delay;
              return 'computed';
            },
          );

          cache.computeSync();

          // Short breathing room so that the background operation can start
          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(cache.computing, isTrue);

          // Wait for the computation to complete
          await Future<void>.delayed(const Duration(seconds: 3));
          expect(cache.computing, isFalse);
          cache.dispose();
        },
      );

      test(
        'early compute should start computation as soon as constructor is called',
        () async {
          cache = EverCache(
            () async {
              await delay;
              return 'computed';
            },
            earlyCompute: true,
          );

          // Short breathing room so that the background operation can start
          await Future<void>.delayed(const Duration(milliseconds: 50));
          expect(cache.computing, isTrue);

          // Wait for the computation to complete
          await Future<void>.delayed(const Duration(seconds: 3));
          expect(cache.computing, isFalse);
          cache.dispose();
        },
      );

      test('TTL should expire and allow re-computation of value', () async {
        var computationCount = 0;
        cache = EverCache(
          () async {
            computationCount++;
            return 'value $computationCount';
          },
          ttl: const EverTTL(Duration(milliseconds: 100)), // Short TTL for test
        );

        await cache.compute();
        expect(cache.value, equals('value 1'));

        // Wait for TTL to expire
        await Future.delayed(const Duration(milliseconds: 150));

        // Trigger computation again after TTL expiry
        await cache.compute();
        expect(cache.value, equals('value 2'));
        expect(computationCount, equals(2));
        cache.dispose();
      });

      test(
          'Locking should prevent further access to the value during the execution time.',
          () async {
        cache = EverCache(
          () async => 'value',
          earlyCompute: true,
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));

        unawaited(
          cache.use<String>(
            (value) async {
              await delay;
              return Future.value('locked 1');
            },
          ),
        );

        expect(
          () async {
            return cache.use(
              (value) async {
                return 'locked 2';
              },
            );
          },
          throwsA(isA<EverStateException>()),
        );
      });
    },
  );
}

Future<void> get delay => Future.delayed(const Duration(seconds: 2));
