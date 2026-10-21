// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

@TestOn('vm')
import 'dart:async';

import 'package:opentelemetry/api.dart' as api;
import 'package:opentelemetry/sdk.dart' as sdk;
import 'package:opentelemetry/src/sdk/common/export_backoff.dart';
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

  group('backpressure', () {
    sdk.ExportResult result(sdk.ExportResultCode code) =>
        sdk.ExportResult(code: code);

    test('waits for a pending export before starting another', () async {
      final pending = Completer<sdk.ExportResult>();
      final h = _BackpressureHarness(answer: () => pending.future);
      expect(await h.countExportsOverTicks(5), 1);

      pending.complete(result(sdk.ExportResultCode.success));
      expect(await h.countExportsOverTicks(5), greaterThan(1));
    });

    for (final row in [
      [sdk.ExportResultCode.success, greaterThan(1)],
      [sdk.ExportResultCode.failed, 1],
    ]) {
      test('keeps exporting after ${(row[0] as sdk.ExportResultCode).name}: '
          '${row[1]}', () async {
        final h = _BackpressureHarness(
            answer: () async => result(row[0] as sdk.ExportResultCode));
        expect(await h.countExportsOverTicks(5), row[1]);
      });
    }

    test('backs off after an export times out', () async {
      final h = _BackpressureHarness(
          answer: () => Completer<sdk.ExportResult>().future,
          exportTimeout: _BackpressureHarness.tick);
      expect(await h.countExportsOverTicks(8), 1);
    });
  });
}

/// A reader collecting a recorded counter every [tick], whose exports answer
/// with [answer], torn down with the test.
class _BackpressureHarness {
  static const tick = Duration(milliseconds: 10);

  final _backoff = ExportBackoff(minDelay: const Duration(minutes: 1));
  late final PeriodicExportingMetricReader _reader;
  var _exports = 0;

  _BackpressureHarness(
      {required Future<sdk.ExportResult> Function() answer,
      Duration exportTimeout = const Duration(seconds: 30)}) {
    _reader = PeriodicExportingMetricReader(
        _AnsweringExporter(() {
          _exports++;
          return answer();
        }),
        exportInterval: tick,
        exportTimeout: exportTimeout,
        backoff: _backoff);
    sdk.MeterProvider(readers: [_reader])
        .get('test_meter')
        .createCounter<int>('counter')
        .add(1);
    // Shut down first: once the backoff is cancelled, a live reader would
    // export into whichever test runs next.
    addTearDown(_backoff.cancel);
    addTearDown(_reader.shutdown);
  }

  /// Returns the number of exports made over the next [ticks] ticks.
  Future<int> countExportsOverTicks(int ticks) async {
    _exports = 0;
    await Future.delayed(tick * ticks);
    return _exports;
  }
}

class _AnsweringExporter implements MetricExporter {
  final Future<sdk.ExportResult> Function() _answer;

  _AnsweringExporter(this._answer);

  @override
  Future<sdk.ExportResult> export(List<ResourceMetricsData> metrics) =>
      _answer();

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {}
}
