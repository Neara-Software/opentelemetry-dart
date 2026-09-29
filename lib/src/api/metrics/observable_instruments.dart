// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:opentelemetry/api.dart';

/// Base class for asynchronous instruments.
abstract class ObservableInstrument<T extends num> {}

/// An asynchronous instrument that reports monotonically increasing values.
abstract class ObservableCounter<T extends num>
    implements ObservableInstrument<T> {}

/// An asynchronous instrument that reports additive values that can increase or decrease.
abstract class ObservableUpDownCounter<T extends num>
    implements ObservableInstrument<T> {}

/// An asynchronous instrument that reports non-additive instantaneous values.
abstract class ObservableGauge<T extends num>
    implements ObservableInstrument<T> {}

/// The callback observer used to record individual asynchronous measurements.
abstract class Observer<T extends num> {
  /// Observes a value with optional attributes.
  void observe(T value, {List<Attribute>? attributes});
}

/// The callback observer used to record observations across multiple asynchronous instruments.
abstract class BatchObserver {
  /// Observes a value for a specific instrument with optional attributes.
  void observe<T extends num>(ObservableInstrument<T> instrument, T value,
      {List<Attribute>? attributes});
}

typedef ObservableCallback<T extends num> = void Function(Observer<T> observer);
typedef BatchObservableCallback = void Function(BatchObserver observer);
