// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:quiver/core.dart';

import '../../../api.dart' as api;
import '../../../sdk.dart' as sdk;
import '../../experimental_api.dart' as api;
import '../common/instrumentation_scope.dart';
import 'data/metric_data.dart';
import 'meter.dart' as sdk;
import 'readers/metric_reader.dart';
import 'view/instrument_descriptor.dart';
import 'view/view.dart';
import 'view/view_registry.dart';

class MeterProvider implements api.MeterProvider {
  final _logger = Logger('opentelemetry.sdk.metrics.meterprovider');

  @protected
  final Map<int, sdk.Meter> meters = {};

  @visibleForTesting
  final sdk.Resource resource;

  final ViewRegistry viewRegistry;
  final List<MetricReader> readers;
  final DateTime _startTime;

  MeterProvider({
    sdk.Resource? resource,
    this.readers = const [],
    List<View> views = const [],
  })  : resource = resource ?? sdk.Resource([]),
        viewRegistry = ViewRegistry(views),
        _startTime = DateTime.now().toUtc() {
    for (final reader in readers) {
      reader.setMeterProvider(this);
    }
  }

  @override
  api.Meter get(String name,
      {String version = '',
      String schemaUrl = '',
      List<api.Attribute> attributes = const []}) {
    if (name.isEmpty) {
      _logger.warning('Invalid Meter Name', '', StackTrace.current);
    }

    return meters.putIfAbsent(
        hash3(name, version, schemaUrl),
        () => sdk.Meter(
              this,
              InstrumentationScope(name, version, schemaUrl, attributes),
            ));
  }

  List<ResourceMetricsData> collectForReader(MetricReader reader) {
    final now = DateTime.now().toUtc();
    final scopeMetricsList = <ScopeMetricsData>[];

    for (final meter in meters.values) {
      // Trigger all observable callbacks for this meter
      for (final instrument in meter.observableInstruments) {
        instrument.invokeCallback();
      }

      final metricDataList = <MetricData>[];
      for (final stream in meter.streams) {
        final temporality = reader.getTemporality(stream.descriptor.type);
        final points = stream.storage.collect(_startTime, now, temporality);

        if (points.isNotEmpty) {
          final isMonotonic = stream.descriptor.type == InstrumentType.counter ||
              stream.descriptor.type == InstrumentType.observableCounter;

          metricDataList.add(MetricData(
            name: stream.storage.name,
            description: stream.storage.description,
            unit: stream.storage.unit,
            type: stream.metricType,
            temporality: stream.metricType == MetricType.gauge ? null : temporality,
            isMonotonic: isMonotonic,
            dataPoints: points,
          ));
        }
      }

      if (metricDataList.isNotEmpty) {
        scopeMetricsList.add(ScopeMetricsData(
          scope: meter.instrumentationScope,
          metrics: metricDataList,
        ));
      }
    }

    if (scopeMetricsList.isNotEmpty) {
      return [
        ResourceMetricsData(
          resource: resource,
          scopeMetrics: scopeMetricsList,
        )
      ];
    }
    return const [];
  }

  Future<void> forceFlush() async {
    for (final reader in readers) {
      await reader.forceFlush();
    }
  }

  Future<void> shutdown() async {
    for (final reader in readers) {
      await reader.shutdown();
    }
  }
}
