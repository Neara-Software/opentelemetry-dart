// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:opentelemetry/sdk.dart' as sdk;
import '../data/metric_data.dart';
import '../data/point_data.dart';
import 'metric_exporter.dart';

/// An exporter that prints human-readable metric representations to the console.
class ConsoleMetricExporter implements MetricExporter {
  final void Function(Object?) _output;
  bool _isShutdown = false;

  ConsoleMetricExporter([void Function(Object?)? output])
      : _output = output ?? print;

  @override
  Future<sdk.ExportResult> export(List<ResourceMetricsData> metrics) async {
    if (_isShutdown) {
      return sdk.ExportResult(code: sdk.ExportResultCode.failed);
    }

    for (final rm in metrics) {
      for (final sm in rm.scopeMetrics) {
        for (final m in sm.metrics) {
          _output('Metric: ${m.name} (${m.type.name})');
          if (m.description != null) _output('  Description: ${m.description}');
          if (m.unit != null) _output('  Unit: ${m.unit}');
          for (final point in m.dataPoints) {
            if (point is NumberPointData) {
              _output('  Point: value=${point.value} attrs=${point.attributes.map((a) => "${a.key}=${a.value}").join(", ")}');
            } else if (point is HistogramPointData) {
              _output('  HistogramPoint: count=${point.count} sum=${point.sum} min=${point.min} max=${point.max} buckets=${point.bucketCounts}');
            }
          }
        }
      }
    }
    return sdk.ExportResult(code: sdk.ExportResultCode.success);
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {
    _isShutdown = true;
  }
}
