// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:opentelemetry/api.dart' as api;
import '../aggregators/explicit_bucket_histogram_aggregator.dart';
import '../aggregators/last_value_aggregator.dart';
import '../aggregators/sum_aggregator.dart';
import '../data/aggregation_temporality.dart';
import 'attributes_key.dart';

/// Storage managing metric aggregation per unique attribute combination.
abstract class InstrumentStorage<T extends num> {
  final String name;
  final String? description;
  final String? unit;
  final int maxCardinality;
  final Set<String>? allowedKeys;

  InstrumentStorage({
    required this.name,
    this.description,
    this.unit,
    this.maxCardinality = 2000,
    this.allowedKeys,
  });

  void record(T value, {List<api.Attribute> attributes = const []});

  List<dynamic> collect(
    DateTime startTime,
    DateTime endTime,
    AggregationTemporality temporality,
  );

  static InstrumentStorage<T> createCounter<T extends num>({
    required String name,
    String? description,
    String? unit,
    int maxCardinality = 2000,
    Set<String>? allowedKeys,
  }) {
    return _SumStorage<T>(
      name: name,
      description: description,
      unit: unit,
      monotonic: true,
      maxCardinality: maxCardinality,
      allowedKeys: allowedKeys,
    );
  }

  static InstrumentStorage<T> createUpDownCounter<T extends num>({
    required String name,
    String? description,
    String? unit,
    int maxCardinality = 2000,
    Set<String>? allowedKeys,
  }) {
    return _SumStorage<T>(
      name: name,
      description: description,
      unit: unit,
      monotonic: false,
      maxCardinality: maxCardinality,
      allowedKeys: allowedKeys,
    );
  }

  static InstrumentStorage<num> createHistogram({
    required String name,
    String? description,
    String? unit,
    List<num>? boundaries,
    int maxCardinality = 2000,
    Set<String>? allowedKeys,
  }) {
    return _HistogramStorage(
      name: name,
      description: description,
      unit: unit,
      boundaries: boundaries,
      maxCardinality: maxCardinality,
      allowedKeys: allowedKeys,
    );
  }

  static InstrumentStorage<T> createGauge<T extends num>({
    required String name,
    String? description,
    String? unit,
    int maxCardinality = 2000,
    Set<String>? allowedKeys,
  }) {
    return _GaugeStorage<T>(
      name: name,
      description: description,
      unit: unit,
      maxCardinality: maxCardinality,
      allowedKeys: allowedKeys,
    );
  }
}

class _SumStorage<T extends num> extends InstrumentStorage<T> {
  final bool monotonic;
  final Map<AttributesKey, SumAggregator<T>> _aggregators = {};
  SumAggregator<T>? _overflowAggregator;

  _SumStorage({
    required super.name,
    super.description,
    super.unit,
    super.maxCardinality,
    super.allowedKeys,
    required this.monotonic,
  });

  @override
  void record(T value, {List<api.Attribute> attributes = const []}) {
    final key = AttributesKey(attributes, allowedKeys: allowedKeys);
    var agg = _aggregators[key];
    if (agg == null) {
      if (_aggregators.length >= maxCardinality) {
        _overflowAggregator ??= SumAggregator<T>(monotonic: monotonic);
        agg = _overflowAggregator;
      } else {
        agg = SumAggregator<T>(monotonic: monotonic);
        _aggregators[key] = agg;
      }
    }
    agg!.record(value);
  }

  @override
  List<dynamic> collect(
    DateTime startTime,
    DateTime endTime,
    AggregationTemporality temporality,
  ) {
    final results = <dynamic>[];
    for (final entry in _aggregators.entries) {
      results.add(entry.value.toPoint(
        startTime,
        endTime,
        temporality,
        attributes: entry.key.attributes,
      ));
    }
    if (_overflowAggregator != null) {
      results.add(_overflowAggregator!.toPoint(
        startTime,
        endTime,
        temporality,
        attributes: AttributesKey.overflow.attributes,
      ));
    }
    return results;
  }
}

class _HistogramStorage extends InstrumentStorage<num> {
  final List<num>? boundaries;
  final Map<AttributesKey, ExplicitBucketHistogramAggregator> _aggregators = {};
  ExplicitBucketHistogramAggregator? _overflowAggregator;

  _HistogramStorage({
    required super.name,
    super.description,
    super.unit,
    super.maxCardinality,
    super.allowedKeys,
    this.boundaries,
  });

  @override
  void record(num value, {List<api.Attribute> attributes = const []}) {
    final key = AttributesKey(attributes, allowedKeys: allowedKeys);
    var agg = _aggregators[key];
    if (agg == null) {
      if (_aggregators.length >= maxCardinality) {
        _overflowAggregator ??=
            ExplicitBucketHistogramAggregator(boundaries: boundaries);
        agg = _overflowAggregator;
      } else {
        agg = ExplicitBucketHistogramAggregator(boundaries: boundaries);
        _aggregators[key] = agg;
      }
    }
    agg!.record(value);
  }

  @override
  List<dynamic> collect(
    DateTime startTime,
    DateTime endTime,
    AggregationTemporality temporality,
  ) {
    final results = <dynamic>[];
    for (final entry in _aggregators.entries) {
      results.add(entry.value.toPoint(
        startTime,
        endTime,
        temporality,
        attributes: entry.key.attributes,
      ));
    }
    if (_overflowAggregator != null) {
      results.add(_overflowAggregator!.toPoint(
        startTime,
        endTime,
        temporality,
        attributes: AttributesKey.overflow.attributes,
      ));
    }
    return results;
  }
}

class _GaugeStorage<T extends num> extends InstrumentStorage<T> {
  final Map<AttributesKey, LastValueAggregator<T>> _aggregators = {};
  LastValueAggregator<T>? _overflowAggregator;

  _GaugeStorage({
    required super.name,
    super.description,
    super.unit,
    super.maxCardinality,
    super.allowedKeys,
  });

  @override
  void record(T value, {List<api.Attribute> attributes = const []}) {
    final key = AttributesKey(attributes, allowedKeys: allowedKeys);
    var agg = _aggregators[key];
    if (agg == null) {
      if (_aggregators.length >= maxCardinality) {
        _overflowAggregator ??= LastValueAggregator<T>();
        agg = _overflowAggregator;
      } else {
        agg = LastValueAggregator<T>();
        _aggregators[key] = agg;
      }
    }
    agg!.record(value);
  }

  @override
  List<dynamic> collect(
    DateTime startTime,
    DateTime endTime,
    AggregationTemporality temporality,
  ) {
    final results = <dynamic>[];
    for (final entry in _aggregators.entries) {
      results.add(entry.value.toPoint(
        startTime,
        endTime,
        attributes: entry.key.attributes,
      ));
    }
    if (_overflowAggregator != null) {
      results.add(_overflowAggregator!.toPoint(
        startTime,
        endTime,
        attributes: AttributesKey.overflow.attributes,
      ));
    }
    return results;
  }
}
