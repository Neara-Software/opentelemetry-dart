// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:meta/meta.dart';

import '../../../sdk.dart' as sdk;
import '../../experimental_api.dart' as api;
import 'counter.dart' as sdk;
import 'data/metric_data.dart';
import 'gauge.dart' as sdk;
import 'histogram.dart' as sdk;
import 'meter_provider.dart';
import 'observable_instruments.dart';
import 'storage/instrument_storage.dart';
import 'up_down_counter.dart' as sdk;
import 'view/instrument_descriptor.dart';
import 'view/view.dart';

class RegisteredMetricStream {
  final InstrumentDescriptor descriptor;
  final InstrumentStorage storage;
  final MetricType metricType;

  RegisteredMetricStream({
    required this.descriptor,
    required this.storage,
    required this.metricType,
  });
}

class Meter implements api.Meter {
  final MeterProvider provider;
  final sdk.InstrumentationScope instrumentationScope;

  final List<RegisteredMetricStream> _streams = [];
  final List<SdkObservableInstrument> _observableInstruments = [];

  @protected
  Meter(this.provider, this.instrumentationScope);

  List<RegisteredMetricStream> get streams => _streams;
  List<SdkObservableInstrument> get observableInstruments => _observableInstruments;

  @override
  api.Counter<T> createCounter<T extends num>(String name,
      {String? description, String? unit}) {
    final descriptor = InstrumentDescriptor(
      name: name,
      type: InstrumentType.counter,
      description: description,
      unit: unit,
    );

    final viewConfigs = provider.viewRegistry.findViews(descriptor);
    final storages = <InstrumentStorage<T>>[];

    for (final config in viewConfigs) {
      if (config.isDrop) continue;
      final storage = InstrumentStorage.createCounter<T>(
        name: config.name,
        description: config.description,
        unit: config.unit,
        allowedKeys: config.attributeKeys,
      );
      storages.add(storage);
      _streams.add(RegisteredMetricStream(
        descriptor: descriptor,
        storage: storage,
        metricType: MetricType.sum,
      ));
    }

    return sdk.Counter<T>(storages);
  }

  @override
  api.UpDownCounter<T> createUpDownCounter<T extends num>(String name,
      {String? description, String? unit}) {
    final descriptor = InstrumentDescriptor(
      name: name,
      type: InstrumentType.upDownCounter,
      description: description,
      unit: unit,
    );

    final viewConfigs = provider.viewRegistry.findViews(descriptor);
    final storages = <InstrumentStorage<T>>[];

    for (final config in viewConfigs) {
      if (config.isDrop) continue;
      final storage = InstrumentStorage.createUpDownCounter<T>(
        name: config.name,
        description: config.description,
        unit: config.unit,
        allowedKeys: config.attributeKeys,
      );
      storages.add(storage);
      _streams.add(RegisteredMetricStream(
        descriptor: descriptor,
        storage: storage,
        metricType: MetricType.sum,
      ));
    }

    return sdk.UpDownCounter<T>(storages);
  }

  @override
  api.Histogram<T> createHistogram<T extends num>(String name,
      {String? description, String? unit}) {
    final descriptor = InstrumentDescriptor(
      name: name,
      type: InstrumentType.histogram,
      description: description,
      unit: unit,
    );

    final viewConfigs = provider.viewRegistry.findViews(descriptor);
    final storages = <InstrumentStorage<num>>[];

    for (final config in viewConfigs) {
      if (config.isDrop) continue;
      List<num>? boundaries;
      if (config.aggregation is ExplicitBucketHistogramAggregation) {
        boundaries = (config.aggregation as ExplicitBucketHistogramAggregation).boundaries;
      }
      final storage = InstrumentStorage.createHistogram(
        name: config.name,
        description: config.description,
        unit: config.unit,
        boundaries: boundaries,
        allowedKeys: config.attributeKeys,
      );
      storages.add(storage);
      _streams.add(RegisteredMetricStream(
        descriptor: descriptor,
        storage: storage,
        metricType: MetricType.histogram,
      ));
    }

    return sdk.Histogram<T>(storages);
  }

  @override
  api.Gauge<T> createGauge<T extends num>(String name,
      {String? description, String? unit}) {
    final descriptor = InstrumentDescriptor(
      name: name,
      type: InstrumentType.gauge,
      description: description,
      unit: unit,
    );

    final viewConfigs = provider.viewRegistry.findViews(descriptor);
    final storages = <InstrumentStorage<T>>[];

    for (final config in viewConfigs) {
      if (config.isDrop) continue;
      final storage = InstrumentStorage.createGauge<T>(
        name: config.name,
        description: config.description,
        unit: config.unit,
        allowedKeys: config.attributeKeys,
      );
      storages.add(storage);
      _streams.add(RegisteredMetricStream(
        descriptor: descriptor,
        storage: storage,
        metricType: MetricType.gauge,
      ));
    }

    return sdk.Gauge<T>(storages);
  }

  @override
  api.ObservableCounter<T> createObservableCounter<T extends num>(String name,
      {api.ObservableCallback<T>? callback,
      String? description,
      String? unit}) {
    final descriptor = InstrumentDescriptor(
      name: name,
      type: InstrumentType.observableCounter,
      description: description,
      unit: unit,
    );

    final viewConfigs = provider.viewRegistry.findViews(descriptor);
    final storages = <InstrumentStorage<T>>[];

    for (final config in viewConfigs) {
      if (config.isDrop) continue;
      final storage = InstrumentStorage.createCounter<T>(
        name: config.name,
        description: config.description,
        unit: config.unit,
        allowedKeys: config.attributeKeys,
      );
      storages.add(storage);
      _streams.add(RegisteredMetricStream(
        descriptor: descriptor,
        storage: storage,
        metricType: MetricType.sum,
      ));
    }

    final instrument = SdkObservableCounter<T>(storages, callback: callback);
    _observableInstruments.add(instrument);
    return instrument;
  }

  @override
  api.ObservableUpDownCounter<T>
      createObservableUpDownCounter<T extends num>(String name,
          {api.ObservableCallback<T>? callback,
          String? description,
          String? unit}) {
    final descriptor = InstrumentDescriptor(
      name: name,
      type: InstrumentType.observableUpDownCounter,
      description: description,
      unit: unit,
    );

    final viewConfigs = provider.viewRegistry.findViews(descriptor);
    final storages = <InstrumentStorage<T>>[];

    for (final config in viewConfigs) {
      if (config.isDrop) continue;
      final storage = InstrumentStorage.createUpDownCounter<T>(
        name: config.name,
        description: config.description,
        unit: config.unit,
        allowedKeys: config.attributeKeys,
      );
      storages.add(storage);
      _streams.add(RegisteredMetricStream(
        descriptor: descriptor,
        storage: storage,
        metricType: MetricType.sum,
      ));
    }

    final instrument = SdkObservableUpDownCounter<T>(storages, callback: callback);
    _observableInstruments.add(instrument);
    return instrument;
  }

  @override
  api.ObservableGauge<T> createObservableGauge<T extends num>(String name,
      {api.ObservableCallback<T>? callback,
      String? description,
      String? unit}) {
    final descriptor = InstrumentDescriptor(
      name: name,
      type: InstrumentType.observableGauge,
      description: description,
      unit: unit,
    );

    final viewConfigs = provider.viewRegistry.findViews(descriptor);
    final storages = <InstrumentStorage<T>>[];

    for (final config in viewConfigs) {
      if (config.isDrop) continue;
      final storage = InstrumentStorage.createGauge<T>(
        name: config.name,
        description: config.description,
        unit: config.unit,
        allowedKeys: config.attributeKeys,
      );
      storages.add(storage);
      _streams.add(RegisteredMetricStream(
        descriptor: descriptor,
        storage: storage,
        metricType: MetricType.gauge,
      ));
    }

    final instrument = SdkObservableGauge<T>(storages, callback: callback);
    _observableInstruments.add(instrument);
    return instrument;
  }

  @override
  void batchCallback(api.BatchObservableCallback callback,
      List<api.ObservableInstrument> instruments) {}
}
