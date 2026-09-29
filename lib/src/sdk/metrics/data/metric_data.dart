// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:opentelemetry/sdk.dart' as sdk;
import 'aggregation_temporality.dart';

enum MetricType {
  sum,
  gauge,
  histogram,
}

/// Represents an aggregated metric stream ready for export.
class MetricData {
  final String name;
  final String? description;
  final String? unit;
  final MetricType type;
  final AggregationTemporality? temporality;
  final bool isMonotonic;
  final List<dynamic> dataPoints;

  MetricData({
    required this.name,
    this.description,
    this.unit,
    required this.type,
    this.temporality,
    this.isMonotonic = false,
    required this.dataPoints,
  });
}

/// A collection of metrics produced within an instrumentation scope.
class ScopeMetricsData {
  final sdk.InstrumentationScope scope;
  final List<MetricData> metrics;

  ScopeMetricsData({
    required this.scope,
    required this.metrics,
  });
}

/// A collection of scope metrics originating from a single resource.
class ResourceMetricsData {
  final sdk.Resource resource;
  final List<ScopeMetricsData> scopeMetrics;

  ResourceMetricsData({
    required this.resource,
    required this.scopeMetrics,
  });
}
