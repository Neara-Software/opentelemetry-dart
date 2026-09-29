// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

@TestOn('vm')
import 'package:opentelemetry/api.dart' as api;
import 'package:opentelemetry/src/experimental_api.dart' as api;
import 'package:test/test.dart';

void main() {
  group('Metrics API Instruments:', () {
    late api.Meter meter;

    setUp(() {
      meter = api.NoopMeter();
    });

    test('can create and record on UpDownCounter', () {
      final counter = meter.createUpDownCounter<int>('queue_size',
          description: 'current items in queue', unit: 'items');
      expect(counter, isA<api.UpDownCounter<int>>());
      counter.add(5);
      counter.add(-2, attributes: [api.Attribute.fromString('queue', 'jobs')]);
    });

    test('can create and record on Histogram', () {
      final histogram = meter.createHistogram<double>('http_request_duration',
          description: 'duration of http requests', unit: 'ms');
      expect(histogram, isA<api.Histogram<double>>());
      histogram.record(123.45);
      histogram.record(456.78,
          attributes: [api.Attribute.fromString('http.method', 'GET')]);
    });

    test('can create and record on Gauge', () {
      final gauge = meter.createGauge<double>('cpu_temperature',
          description: 'current cpu temp', unit: 'celsius');
      expect(gauge, isA<api.Gauge<double>>());
      gauge.record(42.5);
      gauge.record(43.1,
          attributes: [api.Attribute.fromString('core', 'core-0')]);
    });

    test('can create ObservableCounter', () {
      final observableCounter = meter.createObservableCounter<int>(
        'page_faults',
        description: 'number of page faults',
        unit: 'faults',
        callback: (observer) {
          observer.observe(10);
        },
      );
      expect(observableCounter, isA<api.ObservableCounter<int>>());
    });

    test('can create ObservableUpDownCounter', () {
      final observableUpDownCounter = meter.createObservableUpDownCounter<int>(
        'process_threads',
        description: 'current thread count',
        unit: 'threads',
        callback: (observer) {
          observer.observe(8);
        },
      );
      expect(observableUpDownCounter, isA<api.ObservableUpDownCounter<int>>());
    });

    test('can create ObservableGauge', () {
      final observableGauge = meter.createObservableGauge<double>(
        'memory_utilization',
        description: 'current memory utilization ratio',
        unit: 'ratio',
        callback: (observer) {
          observer.observe(0.65);
        },
      );
      expect(observableGauge, isA<api.ObservableGauge<double>>());
    });
  });
}
