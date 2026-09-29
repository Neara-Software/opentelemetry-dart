// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

/// The type of OpenTelemetry instrument.
enum InstrumentType {
  counter,
  upDownCounter,
  histogram,
  gauge,
  observableCounter,
  observableUpDownCounter,
  observableGauge,
}

/// Metadata describing an instrument.
class InstrumentDescriptor {
  final String name;
  final InstrumentType type;
  final String? description;
  final String? unit;

  InstrumentDescriptor({
    required this.name,
    required this.type,
    this.description,
    this.unit,
  });
}
