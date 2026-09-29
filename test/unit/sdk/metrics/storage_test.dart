// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

@TestOn('vm')
import 'package:opentelemetry/api.dart' as api;
import 'package:opentelemetry/src/sdk/metrics/data/aggregation_temporality.dart';
import 'package:opentelemetry/src/sdk/metrics/storage/attributes_key.dart';
import 'package:opentelemetry/src/sdk/metrics/storage/instrument_storage.dart';
import 'package:test/test.dart';

void main() {
  final t0 = DateTime.utc(2023, 1, 1, 0, 0, 0);
  final t1 = DateTime.utc(2023, 1, 1, 0, 1, 0);

  group('AttributesKey:', () {
    test('same attributes in different order are equal and have same hashCode', () {
      final key1 = AttributesKey([
        api.Attribute.fromString('status', '200'),
        api.Attribute.fromString('method', 'GET'),
      ]);
      final key2 = AttributesKey([
        api.Attribute.fromString('method', 'GET'),
        api.Attribute.fromString('status', '200'),
      ]);

      expect(key1, equals(key2));
      expect(key1.hashCode, equals(key2.hashCode));
    });

    test('attribute filter retains only allowed keys', () {
      final key = AttributesKey(
        [
          api.Attribute.fromString('status', '200'),
          api.Attribute.fromString('sensitive_user_id', '12345'),
          api.Attribute.fromString('method', 'GET'),
        ],
        allowedKeys: {'status', 'method'},
      );

      expect(key.attributes.map((a) => a.key), containsAllInOrder(['method', 'status']));
      expect(key.attributes.any((a) => a.key == 'sensitive_user_id'), isFalse);
    });
  });

  group('InstrumentStorage:', () {
    test('records measurements across different attribute sets for Counter', () {
      final storage = InstrumentStorage.createCounter<int>(
        name: 'http_requests_total',
        description: 'Total HTTP requests',
        unit: 'requests',
      );

      final attrGet = [api.Attribute.fromString('method', 'GET')];
      final attrPost = [api.Attribute.fromString('method', 'POST')];

      storage.record(5, attributes: attrGet);
      storage.record(3, attributes: attrPost);
      storage.record(2, attributes: attrGet);

      final points = storage.collect(t0, t1, AggregationTemporality.cumulative);
      expect(points.length, equals(2));

      final getPoint = points.firstWhere((p) => p.attributes.any((a) => a.value == 'GET'));
      final postPoint = points.firstWhere((p) => p.attributes.any((a) => a.value == 'POST'));

      expect(getPoint.value, equals(7));
      expect(postPoint.value, equals(3));
    });

    test('cardinality limit creates overflow bucket when limit exceeded', () {
      final storage = InstrumentStorage.createCounter<int>(
        name: 'user_events',
        maxCardinality: 2,
      );

      // Record on 2 distinct attribute sets (reaches limit)
      storage.record(1, attributes: [api.Attribute.fromString('user', 'u1')]);
      storage.record(2, attributes: [api.Attribute.fromString('user', 'u2')]);

      // Record on a 3rd distinct attribute set (exceeds limit -> overflow)
      storage.record(10, attributes: [api.Attribute.fromString('user', 'u3')]);
      // Record on a 4th distinct attribute set (exceeds limit -> overflow)
      storage.record(5, attributes: [api.Attribute.fromString('user', 'u4')]);

      final points = storage.collect(t0, t1, AggregationTemporality.cumulative);
      // Expected points: u1 (1), u2 (2), and overflow (10 + 5 = 15)
      expect(points.length, equals(3));

      final overflowPoint = points.firstWhere(
        (p) => p.attributes.any((a) => a.key == 'otel.metric.overflow' && a.value == true),
      );
      expect(overflowPoint.value, equals(15));
    });

    test('records histogram measurements across attribute sets', () {
      final storage = InstrumentStorage.createHistogram(
        name: 'request_duration',
        boundaries: [10, 50, 100],
      );

      storage.record(5, attributes: [api.Attribute.fromString('env', 'prod')]);
      storage.record(25, attributes: [api.Attribute.fromString('env', 'prod')]);
      storage.record(75, attributes: [api.Attribute.fromString('env', 'dev')]);

      final points = storage.collect(t0, t1, AggregationTemporality.cumulative);
      expect(points.length, equals(2));

      final prodPoint = points.firstWhere((p) => p.attributes.any((a) => a.value == 'prod'));
      expect(prodPoint.count, equals(2));
      expect(prodPoint.sum, equals(30));
    });
  });
}
