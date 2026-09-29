// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:opentelemetry/sdk.dart' as sdk;
import '../data/metric_data.dart';
import 'metric_exporter.dart';

/// An in-memory metric exporter useful for unit testing.
class InMemoryMetricExporter implements MetricExporter {
  final List<List<ResourceMetricsData>> batches = [];
  bool _isShutdown = false;

  @override
  Future<sdk.ExportResult> export(List<ResourceMetricsData> metrics) async {
    if (_isShutdown) {
      return sdk.ExportResult(code: sdk.ExportResultCode.failed);
    }
    batches.add(List.unmodifiable(metrics));
    return sdk.ExportResult(code: sdk.ExportResultCode.success);
  }

  void reset() {
    batches.clear();
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {
    _isShutdown = true;
  }
}
