// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

@TestOn('vm')
import 'package:opentelemetry/src/sdk/metrics/view/instrument_descriptor.dart';
import 'package:opentelemetry/src/sdk/metrics/view/instrument_selector.dart';
import 'package:opentelemetry/src/sdk/metrics/view/view.dart';
import 'package:opentelemetry/src/sdk/metrics/view/view_registry.dart';
import 'package:test/test.dart';

void main() {
  group('InstrumentSelector:', () {
    test('matches exact name and wildcard pattern', () {
      final exactSelector = InstrumentSelector(name: 'http.server.duration');
      final wildcardSelector = InstrumentSelector(name: 'http.*');
      final matchAllSelector = InstrumentSelector(name: '*');

      final descriptor = InstrumentDescriptor(
        name: 'http.server.duration',
        type: InstrumentType.histogram,
        unit: 'ms',
      );

      final otherDescriptor = InstrumentDescriptor(
        name: 'db.client.duration',
        type: InstrumentType.histogram,
        unit: 'ms',
      );

      expect(exactSelector.matches(descriptor), isTrue);
      expect(exactSelector.matches(otherDescriptor), isFalse);

      expect(wildcardSelector.matches(descriptor), isTrue);
      expect(wildcardSelector.matches(otherDescriptor), isFalse);

      expect(matchAllSelector.matches(descriptor), isTrue);
      expect(matchAllSelector.matches(otherDescriptor), isTrue);
    });

    test('matches instrument type', () {
      final counterSelector = InstrumentSelector(type: InstrumentType.counter);
      final histogramSelector =
          InstrumentSelector(type: InstrumentType.histogram);

      final counterDesc = InstrumentDescriptor(
        name: 'requests',
        type: InstrumentType.counter,
      );

      expect(counterSelector.matches(counterDesc), isTrue);
      expect(histogramSelector.matches(counterDesc), isFalse);
    });
  });

  group('ViewRegistry:', () {
    test('returns default stream when no views match', () {
      final registry = ViewRegistry([]);
      final descriptor = InstrumentDescriptor(
        name: 'requests',
        type: InstrumentType.counter,
        description: 'request counter',
        unit: 'req',
      );

      final streamConfigs = registry.findViews(descriptor);
      expect(streamConfigs.length, equals(1));
      expect(streamConfigs.first.name, equals('requests'));
      expect(streamConfigs.first.description, equals('request counter'));
      expect(streamConfigs.first.attributeKeys, isNull);
      expect(streamConfigs.first.isDrop, isFalse);
    });

    test(
        'applies matching view with renamed stream, attribute filter, and custom histogram buckets',
        () {
      final view = View(
        selector: InstrumentSelector(
            name: 'http.server.duration', type: InstrumentType.histogram),
        name: 'http.server.latency',
        description: 'Server latency in ms',
        attributeKeys: {'http.status_code', 'http.method'},
        aggregation:
            ViewAggregation.explicitBucketHistogram(boundaries: [5, 25, 100]),
      );

      final registry = ViewRegistry([view]);
      final descriptor = InstrumentDescriptor(
        name: 'http.server.duration',
        type: InstrumentType.histogram,
        description: 'original description',
      );

      final streamConfigs = registry.findViews(descriptor);
      expect(streamConfigs.length, equals(1));
      final config = streamConfigs.first;
      expect(config.name, equals('http.server.latency'));
      expect(config.description, equals('Server latency in ms'));
      expect(config.attributeKeys, equals({'http.status_code', 'http.method'}));
      expect(config.aggregation, isA<ExplicitBucketHistogramAggregation>());
      final agg = config.aggregation as ExplicitBucketHistogramAggregation;
      expect(agg.boundaries, equals([5, 25, 100]));
    });

    test('drop view marks stream as dropped', () {
      final view = View(
        selector: InstrumentSelector(name: 'noisy.metric.*'),
        aggregation: ViewAggregation.drop(),
      );

      final registry = ViewRegistry([view]);
      final descriptor = InstrumentDescriptor(
        name: 'noisy.metric.debug',
        type: InstrumentType.counter,
      );

      final streamConfigs = registry.findViews(descriptor);
      expect(streamConfigs.length, equals(1));
      expect(streamConfigs.first.isDrop, isTrue);
    });
  });
}
