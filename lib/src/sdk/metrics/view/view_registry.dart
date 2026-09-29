// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'instrument_descriptor.dart';
import 'view.dart';

/// The resolved configuration for a metric stream produced by an instrument.
class MetricStreamConfig {
  final String name;
  final String? description;
  final String? unit;
  final Set<String>? attributeKeys;
  final ViewAggregation aggregation;
  final bool isDrop;

  MetricStreamConfig({
    required this.name,
    this.description,
    this.unit,
    this.attributeKeys,
    required this.aggregation,
    this.isDrop = false,
  });
}

/// Registry matching instruments to views.
class ViewRegistry {
  final List<View> views;

  ViewRegistry(this.views);

  List<MetricStreamConfig> findViews(
    InstrumentDescriptor descriptor, {
    String? meterName,
    String? meterVersion,
    String? meterSchemaUrl,
  }) {
    final matches = views.where((v) => v.selector.matches(
          descriptor,
          meterName: meterName,
          meterVersion: meterVersion,
          meterSchemaUrl: meterSchemaUrl,
        ));

    if (matches.isEmpty) {
      return [
        MetricStreamConfig(
          name: descriptor.name,
          description: descriptor.description,
          unit: descriptor.unit,
          attributeKeys: null,
          aggregation: const DefaultAggregation(),
          isDrop: false,
        )
      ];
    }

    return matches.map((view) {
      final isDrop = view.aggregation is DropAggregation;
      return MetricStreamConfig(
        name: view.name ?? descriptor.name,
        description: view.description ?? descriptor.description,
        unit: descriptor.unit,
        attributeKeys: view.attributeKeys,
        aggregation: view.aggregation ?? const DefaultAggregation(),
        isDrop: isDrop,
      );
    }).toList();
  }
}
