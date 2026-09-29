// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:meta/meta.dart';

import '../../../sdk.dart' as sdk;
import '../../experimental_api.dart' as api;
import '../../experimental_sdk.dart' as sdk;

class Meter implements api.Meter {
  final sdk.Resource _resource; // ignore: unused_field
  final sdk.InstrumentationScope _instrumentationScope; // ignore: unused_field

  @protected
  Meter(this._resource, this._instrumentationScope);

  @override
  api.Counter<T> createCounter<T extends num>(String name,
      {String? description, String? unit}) {
    return sdk.Counter<T>();
  }

  @override
  api.UpDownCounter<T> createUpDownCounter<T extends num>(String name,
      {String? description, String? unit}) {
    return api.NoopUpDownCounter<T>();
  }

  @override
  api.Histogram<T> createHistogram<T extends num>(String name,
      {String? description, String? unit}) {
    return api.NoopHistogram<T>();
  }

  @override
  api.Gauge<T> createGauge<T extends num>(String name,
      {String? description, String? unit}) {
    return api.NoopGauge<T>();
  }

  @override
  api.ObservableCounter<T> createObservableCounter<T extends num>(String name,
      {api.ObservableCallback<T>? callback,
      String? description,
      String? unit}) {
    return api.NoopObservableCounter<T>();
  }

  @override
  api.ObservableUpDownCounter<T>
      createObservableUpDownCounter<T extends num>(String name,
          {api.ObservableCallback<T>? callback,
          String? description,
          String? unit}) {
    return api.NoopObservableUpDownCounter<T>();
  }

  @override
  api.ObservableGauge<T> createObservableGauge<T extends num>(String name,
      {api.ObservableCallback<T>? callback,
      String? description,
      String? unit}) {
    return api.NoopObservableGauge<T>();
  }

  @override
  void batchCallback(api.BatchObservableCallback callback,
      List<api.ObservableInstrument> instruments) {}
}
