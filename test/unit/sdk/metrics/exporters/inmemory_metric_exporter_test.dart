// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

@TestOn('vm')
import 'package:opentelemetry/sdk.dart' as sdk;
import 'package:opentelemetry/src/sdk/metrics/data/metric_data.dart';
import 'package:opentelemetry/src/sdk/metrics/exporters/inmemory_metric_exporter.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryMetricExporter:', () {
    test('records exported metric batches and resets', () async {
      final exporter = InMemoryMetricExporter();
      final resource = sdk.Resource([]);
      final batch1 = [
        ResourceMetricsData(resource: resource, scopeMetrics: []),
      ];

      final result = await exporter.export(batch1);
      expect(result.code, equals(sdk.ExportResultCode.success));
      expect(exporter.batches.length, equals(1));

      exporter.reset();
      expect(exporter.batches, isEmpty);
    });

    test('fails export after shutdown', () async {
      final exporter = InMemoryMetricExporter();
      await exporter.shutdown();

      final result = await exporter.export([]);
      expect(result.code, equals(sdk.ExportResultCode.failed));
    });
  });
}
