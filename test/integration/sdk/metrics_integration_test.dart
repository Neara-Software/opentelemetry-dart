// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

@TestOn('vm')
import 'package:opentelemetry/api.dart' as api;
import 'package:opentelemetry/sdk.dart' as sdk;
import 'package:test/test.dart';

void main() {
  group('Metrics SDK End-to-End Integration:', () {
    test(
        'records across sync and async instruments, applies views, and exports via reader',
        () async {
      final exporter = sdk.InMemoryMetricExporter();
      final reader = sdk.PeriodicExportingMetricReader(
        exporter,
        exportInterval: Duration(hours: 1), // manual collect in test
      );

      final view = sdk.View(
        selector: sdk.InstrumentSelector(
          name: 'http.server.request.duration',
          type: sdk.InstrumentType.histogram,
        ),
        name: 'http.server.duration.custom',
        attributeKeys: {'http.method', 'http.status_code'},
        aggregation: sdk.ViewAggregation.explicitBucketHistogram(
          boundaries: [10, 50, 200, 1000],
        ),
      );

      final resource = sdk.Resource([
        api.Attribute.fromString('service.name', 'order-service'),
        api.Attribute.fromString('service.version', '1.2.3'),
      ]);

      final meterProvider = sdk.MeterProvider(
        resource: resource,
        readers: [reader],
        views: [view],
      );

      final meter =
          meterProvider.get('order_checkout_module', version: '2.0.0');

      // 1. Synchronous Counter
      final ordersCounter = meter.createCounter<int>(
        'orders_placed_total',
        description: 'Total placed orders',
        unit: 'orders',
      );
      ordersCounter
          .add(3, attributes: [api.Attribute.fromString('currency', 'USD')]);
      ordersCounter
          .add(2, attributes: [api.Attribute.fromString('currency', 'EUR')]);
      ordersCounter
          .add(1, attributes: [api.Attribute.fromString('currency', 'USD')]);

      // 2. Synchronous UpDownCounter
      final activeConnections = meter.createUpDownCounter<int>(
        'active_connections',
        description: 'Current active connections',
        unit: 'connections',
      );
      activeConnections.add(10);
      activeConnections.add(-3);

      // 3. Synchronous Histogram (with View applied: renamed, filtered attrs, custom buckets)
      final requestDuration = meter.createHistogram<double>(
        'http.server.request.duration',
        description: 'Request duration in ms',
        unit: 'ms',
      );
      requestDuration.record(25.0, attributes: [
        api.Attribute.fromString('http.method', 'POST'),
        api.Attribute.fromInt('http.status_code', 200),
        api.Attribute.fromString(
            'sensitive.cookie', 'session123'), // should be dropped by View
      ]);
      requestDuration.record(150.0, attributes: [
        api.Attribute.fromString('http.method', 'POST'),
        api.Attribute.fromInt('http.status_code', 200),
      ]);

      // 4. Synchronous Gauge
      final memoryGauge = meter.createGauge<double>(
        'system.memory.usage',
        description: 'Current memory usage ratio',
        unit: 'ratio',
      );
      memoryGauge.record(0.72);
      memoryGauge.record(0.75);

      // 5. Asynchronous Gauge
      meter.createObservableGauge<int>(
        'system.cpu.load',
        description: 'Current CPU load percent',
        unit: '%',
        callback: (observer) {
          observer.observe(38);
        },
      );

      // Collect metrics
      await reader.collect();

      expect(exporter.batches.length, equals(1));
      final batch = exporter.batches.first;
      expect(batch.length, equals(1));

      final rm = batch.first;
      expect(
          rm.resource.attributes.get('service.name'), equals('order-service'));

      final sm = rm.scopeMetrics.first;
      expect(sm.scope.name, equals('order_checkout_module'));
      expect(sm.scope.version, equals('2.0.0'));

      final metricMap = {for (var m in sm.metrics) m.name: m};

      // Verify orders_placed_total
      expect(metricMap.containsKey('orders_placed_total'), isTrue);
      final ordersMetric = metricMap['orders_placed_total']!;
      expect(ordersMetric.dataPoints.length, equals(2));
      final usdPoint = ordersMetric.dataPoints
          .firstWhere((p) => p.attributes.any((a) => a.value == 'USD'));
      expect(usdPoint.value, equals(4));

      // Verify active_connections
      expect(metricMap.containsKey('active_connections'), isTrue);
      final connMetric = metricMap['active_connections']!;
      expect(connMetric.dataPoints.first.value, equals(7));

      // Verify http.server.duration.custom (View applied)
      expect(metricMap.containsKey('http.server.duration.custom'), isTrue);
      final durationMetric = metricMap['http.server.duration.custom']!;
      final histPoint =
          durationMetric.dataPoints.first as sdk.HistogramPointData;
      expect(histPoint.count, equals(2));
      expect(histPoint.sum, equals(175.0));
      expect(histPoint.explicitBounds, equals([10.0, 50.0, 200.0, 1000.0]));
      // Verify sensitive attribute was filtered out
      expect(histPoint.attributes.any((a) => a.key == 'sensitive.cookie'),
          isFalse);
      expect(histPoint.attributes.any((a) => a.key == 'http.method'), isTrue);

      // Verify system.memory.usage (Gauge: reports latest 0.75)
      expect(metricMap.containsKey('system.memory.usage'), isTrue);
      final memMetric = metricMap['system.memory.usage']!;
      expect(memMetric.dataPoints.first.value, equals(0.75));

      // Verify system.cpu.load (Async Gauge: observed 38)
      expect(metricMap.containsKey('system.cpu.load'), isTrue);
      final cpuMetric = metricMap['system.cpu.load']!;
      expect(cpuMetric.dataPoints.first.value, equals(38));

      await reader.shutdown();
    });
  });
}
