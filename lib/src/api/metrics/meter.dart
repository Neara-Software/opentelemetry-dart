// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:opentelemetry/src/experimental_api.dart';

abstract class Meter {
  /// Creates a new [Counter] instrument named [name]. Additional details about
  /// this metric can be captured in [description] and units can be specified in
  /// [unit].
  ///
  /// See https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/metrics/api.md#instrument-naming-rule
  Counter<T> createCounter<T extends num>(String name,
      {String? description, String? unit});

  /// Creates a new [UpDownCounter] instrument named [name].
  UpDownCounter<T> createUpDownCounter<T extends num>(String name,
      {String? description, String? unit});

  /// Creates a new [Histogram] instrument named [name].
  Histogram<T> createHistogram<T extends num>(String name,
      {String? description, String? unit});

  /// Creates a new synchronous [Gauge] instrument named [name].
  Gauge<T> createGauge<T extends num>(String name,
      {String? description, String? unit});

  /// Creates a new [ObservableCounter] instrument named [name].
  ObservableCounter<T> createObservableCounter<T extends num>(String name,
      {ObservableCallback<T>? callback, String? description, String? unit});

  /// Creates a new [ObservableUpDownCounter] instrument named [name].
  ObservableUpDownCounter<T>
      createObservableUpDownCounter<T extends num>(String name,
          {ObservableCallback<T>? callback,
          String? description,
          String? unit});

  /// Creates a new [ObservableGauge] instrument named [name].
  ObservableGauge<T> createObservableGauge<T extends num>(String name,
      {ObservableCallback<T>? callback, String? description, String? unit});

  /// Registers a batch callback for multiple asynchronous instruments.
  void batchCallback(BatchObservableCallback callback,
      List<ObservableInstrument> instruments);
}
