// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import '../data/aggregation_temporality.dart';
import '../meter_provider.dart';
import '../view/instrument_descriptor.dart';

/// Base class for metric readers.
abstract class MetricReader {
  MeterProvider? _meterProvider;

  void setMeterProvider(MeterProvider provider) {
    _meterProvider = provider;
  }

  MeterProvider? get meterProvider => _meterProvider;

  /// Returns the preferred temporality for the instrument type.
  AggregationTemporality getTemporality(InstrumentType kind) {
    return AggregationTemporality.cumulative;
  }

  /// Collects all metrics from the attached MeterProvider.
  Future<void> collect();

  /// Forces any uncollected metrics to be processed.
  Future<void> forceFlush();

  /// Shuts down the reader.
  Future<void> shutdown();
}
