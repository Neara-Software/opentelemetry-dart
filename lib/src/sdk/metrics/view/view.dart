// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'instrument_selector.dart';

/// Aggregation specification for a View.
abstract class ViewAggregation {
  const ViewAggregation();

  factory ViewAggregation.drop() = DropAggregation;
  factory ViewAggregation.defaultAggregation() = DefaultAggregation;
  factory ViewAggregation.sum() = SumAggregation;
  factory ViewAggregation.lastValue() = LastValueAggregation;
  factory ViewAggregation.explicitBucketHistogram({List<num>? boundaries}) =
      ExplicitBucketHistogramAggregation;
}

class DropAggregation extends ViewAggregation {
  const DropAggregation();
}

class DefaultAggregation extends ViewAggregation {
  const DefaultAggregation();
}

class SumAggregation extends ViewAggregation {
  const SumAggregation();
}

class LastValueAggregation extends ViewAggregation {
  const LastValueAggregation();
}

class ExplicitBucketHistogramAggregation extends ViewAggregation {
  final List<num>? boundaries;

  const ExplicitBucketHistogramAggregation({this.boundaries});
}

/// A View defines how measurements are aggregated and exported.
class View {
  final InstrumentSelector selector;
  final String? name;
  final String? description;
  final Set<String>? attributeKeys;
  final ViewAggregation? aggregation;

  View({
    required this.selector,
    this.name,
    this.description,
    this.attributeKeys,
    this.aggregation,
  });
}
