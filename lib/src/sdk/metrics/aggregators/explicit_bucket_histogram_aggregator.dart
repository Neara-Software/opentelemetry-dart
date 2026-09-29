// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:opentelemetry/api.dart' as api;
import '../data/aggregation_temporality.dart';
import '../data/point_data.dart';
import 'aggregator.dart';

/// Aggregator that groups recorded values into explicit buckets.
class ExplicitBucketHistogramAggregator implements Aggregator<num> {
  static const List<double> defaultBoundaries = [
    0.0,
    5.0,
    10.0,
    25.0,
    50.0,
    75.0,
    100.0,
    250.0,
    500.0,
    750.0,
    1000.0,
    2500.0,
    5000.0,
    7500.0,
    10000.0
  ];

  final List<double> boundaries;

  int _cumulativeCount = 0;
  num _cumulativeSum = 0;
  num? _cumulativeMin;
  num? _cumulativeMax;
  late final List<int> _cumulativeBucketCounts;

  int _deltaCount = 0;
  num _deltaSum = 0;
  num? _deltaMin;
  num? _deltaMax;
  late final List<int> _deltaBucketCounts;

  ExplicitBucketHistogramAggregator({List<num>? boundaries})
      : boundaries = boundaries != null
            ? (boundaries.map((e) => e.toDouble()).toList()..sort())
            : defaultBoundaries {
    _cumulativeBucketCounts = List.filled(this.boundaries.length + 1, 0);
    _deltaBucketCounts = List.filled(this.boundaries.length + 1, 0);
  }

  @override
  void record(num value) {
    _cumulativeCount++;
    _cumulativeSum += value;
    _cumulativeMin = _cumulativeMin == null
        ? value
        : (_cumulativeMin! < value ? _cumulativeMin : value);
    _cumulativeMax = _cumulativeMax == null
        ? value
        : (_cumulativeMax! > value ? _cumulativeMax : value);

    _deltaCount++;
    _deltaSum += value;
    _deltaMin =
        _deltaMin == null ? value : (_deltaMin! < value ? _deltaMin : value);
    _deltaMax =
        _deltaMax == null ? value : (_deltaMax! > value ? _deltaMax : value);

    final bucketIdx = _findBucketIndex(value);
    _cumulativeBucketCounts[bucketIdx]++;
    _deltaBucketCounts[bucketIdx]++;
  }

  int _findBucketIndex(num value) {
    var low = 0;
    var high = boundaries.length - 1;
    var index = boundaries.length;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (value <= boundaries[mid]) {
        index = mid;
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }
    return index;
  }

  HistogramPointData toPoint(
    DateTime startTime,
    DateTime endTime,
    AggregationTemporality temporality, {
    List<api.Attribute> attributes = const [],
  }) {
    if (temporality == AggregationTemporality.cumulative) {
      return HistogramPointData(
        startTime: startTime,
        endTime: endTime,
        count: _cumulativeCount,
        sum: _cumulativeSum,
        min: _cumulativeMin,
        max: _cumulativeMax,
        bucketCounts: List<int>.from(_cumulativeBucketCounts),
        explicitBounds: List<double>.unmodifiable(boundaries),
        attributes: attributes,
      );
    } else {
      final point = HistogramPointData(
        startTime: startTime,
        endTime: endTime,
        count: _deltaCount,
        sum: _deltaSum,
        min: _deltaMin,
        max: _deltaMax,
        bucketCounts: List<int>.from(_deltaBucketCounts),
        explicitBounds: List<double>.unmodifiable(boundaries),
        attributes: attributes,
      );

      // Reset delta counters
      _deltaCount = 0;
      _deltaSum = 0;
      _deltaMin = null;
      _deltaMax = null;
      _deltaBucketCounts.fillRange(0, _deltaBucketCounts.length, 0);

      return point;
    }
  }
}
