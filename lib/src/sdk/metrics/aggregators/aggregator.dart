// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

// Base interface for aggregators.
abstract class Aggregator<T extends num> {
  /// Records a measurement.
  void record(T value);
}
