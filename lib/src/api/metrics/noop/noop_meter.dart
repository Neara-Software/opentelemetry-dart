// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:opentelemetry/src/experimental_api.dart';

/// A no-op instance of a [Meter]
class NoopMeter implements Meter {
  @override
  Counter<T> createCounter<T extends num>(String name,
      {String? description, String? unit}) {
    return NoopCounter<T>();
  }

  @override
  UpDownCounter<T> createUpDownCounter<T extends num>(String name,
      {String? description, String? unit}) {
    return NoopUpDownCounter<T>();
  }

  @override
  Histogram<T> createHistogram<T extends num>(String name,
      {String? description, String? unit}) {
    return NoopHistogram<T>();
  }

  @override
  Gauge<T> createGauge<T extends num>(String name,
      {String? description, String? unit}) {
    return NoopGauge<T>();
  }

  @override
  ObservableCounter<T> createObservableCounter<T extends num>(String name,
      {ObservableCallback<T>? callback, String? description, String? unit}) {
    return NoopObservableCounter<T>();
  }

  @override
  ObservableUpDownCounter<T>
      createObservableUpDownCounter<T extends num>(String name,
          {ObservableCallback<T>? callback,
          String? description,
          String? unit}) {
    return NoopObservableUpDownCounter<T>();
  }

  @override
  ObservableGauge<T> createObservableGauge<T extends num>(String name,
      {ObservableCallback<T>? callback, String? description, String? unit}) {
    return NoopObservableGauge<T>();
  }

  @override
  void batchCallback(BatchObservableCallback callback,
      List<ObservableInstrument> instruments) {}
}
