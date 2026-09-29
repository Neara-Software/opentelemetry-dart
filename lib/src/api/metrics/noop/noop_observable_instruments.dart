// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:opentelemetry/src/experimental_api.dart';

/// A no-op instance of an [ObservableCounter].
class NoopObservableCounter<T extends num> implements ObservableCounter<T> {}

/// A no-op instance of an [ObservableUpDownCounter].
class NoopObservableUpDownCounter<T extends num>
    implements ObservableUpDownCounter<T> {}

/// A no-op instance of an [ObservableGauge].
class NoopObservableGauge<T extends num> implements ObservableGauge<T> {}
