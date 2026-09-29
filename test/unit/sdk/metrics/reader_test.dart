// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

@TestOn('vm')
import 'package:opentelemetry/api.dart' as api;
import 'package:opentelemetry/sdk.dart' as sdk;
import 'package:opentelemetry/src/sdk/metrics/data/metric_data.dart';
import 'package:opentelemetry/src/sdk/metrics/exporters/metric_exporter.dart';
import 'package:opentelemetry/src/sdk/metrics/readers/periodic_exporting_metric_reader.dart';
import 'package:test/test.dart';

class TestExporter implements MetricExporter {
  final List<List<ResourceMetricsData>> exportedBatches = [];
  bool isShutdown = false;

  @override
  Future<sdk.ExportResult> export(List<ResourceMetricsData> metrics) async {
    if (isShutdown) {
      return sdk.ExportResult(code: sdk.ExportResultCode.failed);
    }
    exportedBatches.add(metrics);
    return sdk.ExportResult(code: sdk.ExportResultCode.success);
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {
    isShutdown = true;
  }
}

void main() {
  group('MetricReader & Pipeline:', () {
    late TestExporter exporter;
    late sdk.MeterProvider meterProvider;
    late PeriodicExportingMetricReader reader;

    setUp(() {
      exporter = TestExporter();
      reader = PeriodicExportingMetricReader(
        exporter,
        exportInterval: Duration(milliseconds: 100),
      );
      meterProvider = sdk.MeterProvider(
        readers: [reader],
      );
    });

    tearDown(() async {
      await reader.shutdown();
    });

    test('collects metrics recorded on synchronous Counter', () async {
      final meter = meterProvider.get('test_meter');
      final counter = meter.createCounter<int>('sync_counter');
      counter.add(10, attributes: [api.Attribute.fromString('key', 'val')]);

      await reader.collect();

      expect(exporter.exportedBatches.length, equals(1));
      final batch = exporter.exportedBatches.first;
      expect(batch.isNotEmpty, isTrue);

      final scopeMetrics = batch.first.scopeMetrics;
      expect(scopeMetrics.first.scope.name, equals('test_meter'));

      final metric = scopeMetrics.first.metrics.first;
      expect(metric.name, equals('sync_counter'));
      expect(metric.dataPoints.length, equals(1));
      expect(metric.dataPoints.first.value, equals(10));
    });

    test('executes observable callbacks during collect()', () async {
      final meter = meterProvider.get('test_meter');
      var observedValue = 42;
      meter.createObservableGauge<int>(
        'async_gauge',
        callback: (observer) {
          observer.observe(observedValue,
              attributes: [api.Attribute.fromString('source', 'sensor')]);
        },
      );

      await reader.collect();

      expect(exporter.exportedBatches.length, equals(1));
      final metric =
          exporter.exportedBatches.first.first.scopeMetrics.first.metrics.first;
      expect(metric.name, equals('async_gauge'));
      expect(metric.dataPoints.first.value, equals(42));

      // Change value for next collection
      observedValue = 100;
      await reader.collect();

      expect(exporter.exportedBatches.length, equals(2));
      final secondMetric =
          exporter.exportedBatches[1].first.scopeMetrics.first.metrics.first;
      expect(secondMetric.dataPoints.first.value, equals(100));
    });

    test('shutdown flushes and marks exporter as shutdown', () async {
      final meter = meterProvider.get('test_meter');
      final counter = meter.createCounter<int>('final_counter');
      counter.add(5);

      await reader.shutdown();
      expect(exporter.isShutdown, isTrue);
      expect(exporter.exportedBatches.length, equals(1));
    });
  });
}
