// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:opentelemetry/sdk.dart' as sdk;
import '../data/metric_data.dart';

/// An interface for exporting telemetry metrics.
abstract class MetricExporter {
  /// Exports a batch of metric data.
  Future<sdk.ExportResult> export(List<ResourceMetricsData> metrics);

  /// Flushes any buffered metrics.
  Future<void> forceFlush();

  /// Shuts down the exporter and releases resources.
  Future<void> shutdown();
}
