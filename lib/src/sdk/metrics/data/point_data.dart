// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:opentelemetry/api.dart' as api;

/// Represents a single numeric data point (Sum or Gauge).
class NumberPointData<T extends num> {
  final DateTime startTime;
  final DateTime endTime;
  final T? value;
  final List<api.Attribute> attributes;

  NumberPointData({
    required this.startTime,
    required this.endTime,
    required this.value,
    this.attributes = const [],
  });
}

/// Represents a single histogram data point.
class HistogramPointData {
  final DateTime startTime;
  final DateTime endTime;
  final int count;
  final num? sum;
  final num? min;
  final num? max;
  final List<int> bucketCounts;
  final List<double> explicitBounds;
  final List<api.Attribute> attributes;

  HistogramPointData({
    required this.startTime,
    required this.endTime,
    required this.count,
    required this.sum,
    required this.min,
    required this.max,
    required this.bucketCounts,
    required this.explicitBounds,
    this.attributes = const [],
  });
}
