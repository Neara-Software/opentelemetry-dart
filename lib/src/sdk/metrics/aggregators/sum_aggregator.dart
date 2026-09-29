// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:logging/logging.dart';
import 'package:opentelemetry/api.dart' as api;
import '../data/aggregation_temporality.dart';
import '../data/point_data.dart';
import 'aggregator.dart';

/// Aggregator that computes the sum of recorded values.
class SumAggregator<T extends num> implements Aggregator<T> {
  final Logger _logger = Logger('opentelemetry.sdk.metrics.sum_aggregator');
  final bool monotonic;

  num _currentSum = 0;
  num _lastReportedSum = 0;

  SumAggregator({required this.monotonic});

  @override
  void record(T value) {
    if (monotonic && value < 0) {
      _logger.warning('Monotonic counter received negative value: $value');
      return;
    }
    _currentSum += value;
  }

  NumberPointData<T> toPoint(
    DateTime startTime,
    DateTime endTime,
    AggregationTemporality temporality, {
    List<api.Attribute> attributes = const [],
  }) {
    num reportValue;
    if (temporality == AggregationTemporality.cumulative) {
      reportValue = _currentSum;
    } else {
      reportValue = _currentSum - _lastReportedSum;
      _lastReportedSum = _currentSum;
    }

    final T finalValue = (T == int ? reportValue.toInt() : reportValue.toDouble()) as T;

    return NumberPointData<T>(
      startTime: startTime,
      endTime: endTime,
      value: finalValue,
      attributes: attributes,
    );
  }
}
