// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:opentelemetry/api.dart' as api;
import 'storage/instrument_storage.dart';

abstract class SdkObservableInstrument<T extends num>
    implements api.ObservableInstrument<T> {
  void invokeCallback();
}

class _ObserverImpl<T extends num> implements api.Observer<T> {
  final List<InstrumentStorage<T>> storages;

  _ObserverImpl(this.storages);

  @override
  void observe(T value, {List<api.Attribute>? attributes}) {
    for (final storage in storages) {
      storage.record(value, attributes: attributes ?? const []);
    }
  }
}

class SdkObservableCounter<T extends num>
    implements SdkObservableInstrument<T>, api.ObservableCounter<T> {
  final api.ObservableCallback<T>? callback;
  final List<InstrumentStorage<T>> storages;

  SdkObservableCounter(this.storages, {this.callback});

  @override
  void invokeCallback() {
    if (callback != null) {
      callback!(_ObserverImpl<T>(storages));
    }
  }
}

class SdkObservableUpDownCounter<T extends num>
    implements SdkObservableInstrument<T>, api.ObservableUpDownCounter<T> {
  final api.ObservableCallback<T>? callback;
  final List<InstrumentStorage<T>> storages;

  SdkObservableUpDownCounter(this.storages, {this.callback});

  @override
  void invokeCallback() {
    if (callback != null) {
      callback!(_ObserverImpl<T>(storages));
    }
  }
}

class SdkObservableGauge<T extends num>
    implements SdkObservableInstrument<T>, api.ObservableGauge<T> {
  final api.ObservableCallback<T>? callback;
  final List<InstrumentStorage<T>> storages;

  SdkObservableGauge(this.storages, {this.callback});

  @override
  void invokeCallback() {
    if (callback != null) {
      callback!(_ObserverImpl<T>(storages));
    }
  }
}
