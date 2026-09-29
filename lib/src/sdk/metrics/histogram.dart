// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:opentelemetry/api.dart' as api;
import 'package:opentelemetry/src/experimental_api.dart' as api;
import 'storage/instrument_storage.dart';

class Histogram<T extends num> implements api.Histogram<T> {
  final List<InstrumentStorage<num>> storages;

  Histogram([this.storages = const []]);

  @override
  void record(T value, {List<api.Attribute>? attributes, api.Context? context}) {
    for (final storage in storages) {
      storage.record(value, attributes: attributes ?? const []);
    }
  }
}
