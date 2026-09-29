// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

@TestOn('vm')
import 'package:opentelemetry/src/sdk/metrics/aggregators/explicit_bucket_histogram_aggregator.dart';
import 'package:opentelemetry/src/sdk/metrics/aggregators/last_value_aggregator.dart';
import 'package:opentelemetry/src/sdk/metrics/aggregators/sum_aggregator.dart';
import 'package:opentelemetry/src/sdk/metrics/data/aggregation_temporality.dart';
import 'package:test/test.dart';

void main() {
  final t0 = DateTime.utc(2023, 1, 1, 0, 0, 0);
  final t1 = DateTime.utc(2023, 1, 1, 0, 1, 0);
  final t2 = DateTime.utc(2023, 1, 1, 0, 2, 0);

  group('SumAggregator:', () {
    test('monotonic int sum records and aggregates cumulatively', () {
      final aggregator = SumAggregator<int>(monotonic: true);
      aggregator.record(10);
      aggregator.record(25);

      final point1 = aggregator.toPoint(t0, t1, AggregationTemporality.cumulative);
      expect(point1.value, equals(35));
      expect(point1.startTime, equals(t0));
      expect(point1.endTime, equals(t1));

      aggregator.record(15);
      final point2 = aggregator.toPoint(t0, t2, AggregationTemporality.cumulative);
      expect(point2.value, equals(50));
    });

    test('monotonic int sum rejects negative values', () {
      final aggregator = SumAggregator<int>(monotonic: true);
      aggregator.record(10);
      aggregator.record(-5); // should be dropped/ignored

      final point = aggregator.toPoint(t0, t1, AggregationTemporality.cumulative);
      expect(point.value, equals(10));
    });

    test('non-monotonic allows negative values', () {
      final aggregator = SumAggregator<int>(monotonic: false);
      aggregator.record(10);
      aggregator.record(-4);
      aggregator.record(2);

      final point = aggregator.toPoint(t0, t1, AggregationTemporality.cumulative);
      expect(point.value, equals(8));
    });

    test('delta temporality reports change since last collection', () {
      final aggregator = SumAggregator<int>(monotonic: true);
      aggregator.record(10);
      aggregator.record(15);

      final delta1 = aggregator.toPoint(t0, t1, AggregationTemporality.delta);
      expect(delta1.value, equals(25));

      aggregator.record(5);
      final delta2 = aggregator.toPoint(t1, t2, AggregationTemporality.delta);
      expect(delta2.value, equals(5));
    });

    test('supports double values', () {
      final aggregator = SumAggregator<double>(monotonic: true);
      aggregator.record(1.5);
      aggregator.record(2.25);

      final point = aggregator.toPoint(t0, t1, AggregationTemporality.cumulative);
      expect(point.value, closeTo(3.75, 0.0001));
    });
  });

  group('LastValueAggregator:', () {
    test('records and returns last value', () {
      final aggregator = LastValueAggregator<double>();
      aggregator.record(24.5);
      aggregator.record(26.8);

      final point = aggregator.toPoint(t0, t1);
      expect(point.value, equals(26.8));
    });

    test('returns 0 or null before any record', () {
      final aggregator = LastValueAggregator<int>();
      final point = aggregator.toPoint(t0, t1);
      expect(point.value, isNull);
    });
  });

  group('ExplicitBucketHistogramAggregator:', () {
    test('classifies values into default buckets with min, max, sum and count', () {
      final aggregator = ExplicitBucketHistogramAggregator();
      // default buckets include: 0, 5, 10, 25, 50, 75, 100, 250, 500, 750, 1000, 2500, 5000, 7500, 10000
      aggregator.record(-1);  // bucket 0 (<= 0)
      aggregator.record(0);   // bucket 0 (<= 0)
      aggregator.record(3);   // bucket 1 (0 < x <= 5)
      aggregator.record(5);   // bucket 1 (0 < x <= 5)
      aggregator.record(12);  // bucket 3 (10 < x <= 25)
      aggregator.record(10001); // last bucket (> 10000)

      final point = aggregator.toPoint(t0, t1, AggregationTemporality.cumulative);
      expect(point.count, equals(6));
      expect(point.sum, equals(10020));
      expect(point.min, equals(-1));
      expect(point.max, equals(10001));

      // Bucket 0 (<= 0) has 2 items (-1, 0)
      expect(point.bucketCounts[0], equals(2));
      // Bucket 1 (<= 5) has 2 items (3, 5)
      expect(point.bucketCounts[1], equals(2));
      // Last bucket (> 10000) has 1 item
      expect(point.bucketCounts.last, equals(1));
    });

    test('supports custom boundaries', () {
      final aggregator = ExplicitBucketHistogramAggregator(boundaries: [10, 20, 30]);
      aggregator.record(5);   // <= 10 -> bucket 0
      aggregator.record(10);  // <= 10 -> bucket 0
      aggregator.record(15);  // <= 20 -> bucket 1
      aggregator.record(25);  // <= 30 -> bucket 2
      aggregator.record(35);  // > 30 -> bucket 3

      final point = aggregator.toPoint(t0, t1, AggregationTemporality.cumulative);
      expect(point.explicitBounds, equals([10.0, 20.0, 30.0]));
      expect(point.bucketCounts, equals([2, 1, 1, 1]));
      expect(point.count, equals(5));
      expect(point.min, equals(5));
      expect(point.max, equals(35));
      expect(point.sum, equals(90));
    });

    test('supports delta temporality', () {
      final aggregator = ExplicitBucketHistogramAggregator(boundaries: [10, 20]);
      aggregator.record(5);
      aggregator.record(15);

      final delta1 = aggregator.toPoint(t0, t1, AggregationTemporality.delta);
      expect(delta1.count, equals(2));
      expect(delta1.bucketCounts, equals([1, 1, 0]));

      aggregator.record(12);
      final delta2 = aggregator.toPoint(t1, t2, AggregationTemporality.delta);
      expect(delta2.count, equals(1));
      expect(delta2.bucketCounts, equals([0, 1, 0]));
      expect(delta2.sum, equals(12));
    });
  });
}
