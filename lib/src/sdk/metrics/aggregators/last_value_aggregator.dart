// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:opentelemetry/api.dart' as api;
import '../data/point_data.dart';
import 'aggregator.dart';

/// Aggregator that stores the most recent recorded value.
class LastValueAggregator<T extends num> implements Aggregator<T> {
  T? _lastValue;

  @override
  void record(T value) {
    _lastValue = value;
  }

  NumberPointData<T> toPoint(
    DateTime startTime,
    DateTime endTime, {
    List<api.Attribute> attributes = const [],
  }) {
    return NumberPointData<T>(
      startTime: startTime,
      endTime: endTime,
      value: _lastValue,
      attributes: attributes,
    );
  }
}
