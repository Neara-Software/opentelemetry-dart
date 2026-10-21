// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'dart:async';
import 'dart:math';

import 'package:fixnum/fixnum.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:opentelemetry/api.dart' as api;
import 'package:opentelemetry/sdk.dart' as sdk;

import '../../proto/opentelemetry/proto/collector/metrics/v1/metrics_service.pb.dart'
    as pb_metric_service;
import '../../proto/opentelemetry/proto/common/v1/common.pb.dart' as pb_common;
import '../../proto/opentelemetry/proto/metrics/v1/metrics.pb.dart'
    as pb_metrics;
import '../../proto/opentelemetry/proto/metrics/v1/metrics.pbenum.dart'
    as pb_metrics_enum;
import '../../proto/opentelemetry/proto/resource/v1/resource.pb.dart'
    as pb_resource;
import '../data/aggregation_temporality.dart';
import '../data/metric_data.dart';
import '../data/point_data.dart';
import 'metric_exporter.dart';

class OTLPMetricExporter implements MetricExporter {
  final Logger _log = Logger('opentelemetry.MetricCollectorExporter');

  final Uri uri;
  final http.Client client;
  final Map<String, String> headers;
  final int timeoutMilliseconds;
  var _isShutdown = false;

  OTLPMetricExporter(
    this.uri, {
    http.Client? httpClient,
    this.headers = const {},
    this.timeoutMilliseconds = 10000,
  }) : client = httpClient ?? http.Client();

  @override
  Future<sdk.ExportResult> export(List<ResourceMetricsData> metrics) async {
    if (_isShutdown) {
      return sdk.ExportResult(code: sdk.ExportResultCode.failed);
    }

    if (metrics.isEmpty) {
      return sdk.ExportResult(code: sdk.ExportResultCode.success);
    }

    try {
      await _sendWithRetry(uri, metrics);
      return sdk.ExportResult(code: sdk.ExportResultCode.success);
    } catch (e, st) {
      return sdk.ExportResult(
        code: sdk.ExportResultCode.failed,
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _sendWithRetry(
      Uri uri, List<ResourceMetricsData> metrics) async {
    const maxRetries = 3;
    var retries = 0;
    const retryableCodes = [429, 502, 503, 504];

    final body = pb_metric_service.ExportMetricsServiceRequest(
      resourceMetrics: _metricsToProtobuf(metrics),
    ).writeToBuffer();
    final reqHeaders = {'Content-Type': 'application/x-protobuf'}
      ..addAll(headers);

    // Only an overloaded collector is retried here. A network failure or
    // timeout fails at once: retrying would only add requests to a stalled
    // network, and the caller backs off instead.
    while (true) {
      var requestFuture = client.post(uri, body: body, headers: reqHeaders);
      if (timeoutMilliseconds > 0) {
        requestFuture =
            requestFuture.timeout(Duration(milliseconds: timeoutMilliseconds));
      }

      final http.Response response;
      try {
        response = await requestFuture;
      } on Exception catch (e) {
        _log.warning('Failed to export metrics.', e);
        rethrow;
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      if (retryableCodes.contains(response.statusCode) &&
          retries < maxRetries) {
        retries++;
        final backoff = min(100 * pow(2, retries), 2000).toInt();
        await Future.delayed(Duration(milliseconds: backoff));
        continue;
      }

      throw Exception(
          'Collector responded with HTTP status code ${response.statusCode}');
    }
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {
    _isShutdown = true;
    client.close();
  }

  List<pb_metrics.ResourceMetrics> _metricsToProtobuf(
      List<ResourceMetricsData> metrics) {
    final results = <pb_metrics.ResourceMetrics>[];

    for (final rm in metrics) {
      final resourceAttrs = <pb_common.KeyValue>[];
      for (final key in rm.resource.attributes.keys) {
        resourceAttrs.add(pb_common.KeyValue(
          key: key,
          value: _attributeValueToProtobuf(rm.resource.attributes.get(key)!),
        ));
      }

      final pbResource = pb_resource.Resource(attributes: resourceAttrs);
      final pbScopeMetricsList = <pb_metrics.ScopeMetrics>[];

      for (final sm in rm.scopeMetrics) {
        final pbMetricsList = <pb_metrics.Metric>[];

        for (final m in sm.metrics) {
          final pbMetric = pb_metrics.Metric(
            name: m.name,
            description: m.description ?? '',
            unit: m.unit ?? '',
          );

          switch (m.type) {
            case MetricType.sum:
              pbMetric.sum = pb_metrics.Sum(
                aggregationTemporality: _temporalityToProtobuf(m.temporality),
                isMonotonic: m.isMonotonic,
                dataPoints: _numberDataPointsToProtobuf(m.dataPoints),
              );
              break;
            case MetricType.gauge:
              pbMetric.gauge = pb_metrics.Gauge(
                dataPoints: _numberDataPointsToProtobuf(m.dataPoints),
              );
              break;
            case MetricType.histogram:
              pbMetric.histogram = pb_metrics.Histogram(
                aggregationTemporality: _temporalityToProtobuf(m.temporality),
                dataPoints: _histogramDataPointsToProtobuf(m.dataPoints),
              );
              break;
          }
          pbMetricsList.add(pbMetric);
        }

        pbScopeMetricsList.add(pb_metrics.ScopeMetrics(
          scope: pb_common.InstrumentationScope(
            name: sm.scope.name,
            version: sm.scope.version,
          ),
          schemaUrl: sm.scope.schemaUrl,
          metrics: pbMetricsList,
        ));
      }

      results.add(pb_metrics.ResourceMetrics(
        resource: pbResource,
        scopeMetrics: pbScopeMetricsList,
      ));
    }

    return results;
  }

  pb_metrics_enum.AggregationTemporality _temporalityToProtobuf(
      AggregationTemporality? temporality) {
    if (temporality == AggregationTemporality.delta) {
      return pb_metrics_enum
          .AggregationTemporality.AGGREGATION_TEMPORALITY_DELTA;
    }
    return pb_metrics_enum
        .AggregationTemporality.AGGREGATION_TEMPORALITY_CUMULATIVE;
  }

  List<pb_metrics.NumberDataPoint> _numberDataPointsToProtobuf(
      List<dynamic> points) {
    final results = <pb_metrics.NumberDataPoint>[];
    for (final p in points) {
      if (p is! NumberPointData) continue;
      final dp = pb_metrics.NumberDataPoint(
        startTimeUnixNano: _toUnixNano(p.startTime),
        timeUnixNano: _toUnixNano(p.endTime),
        attributes: _attributesToProtobuf(p.attributes),
      );
      final val = p.value;
      if (val is int) {
        dp.asInt = Int64(val);
      } else if (val is double) {
        dp.asDouble = val;
      }
      results.add(dp);
    }
    return results;
  }

  List<pb_metrics.HistogramDataPoint> _histogramDataPointsToProtobuf(
      List<dynamic> points) {
    final results = <pb_metrics.HistogramDataPoint>[];
    for (final p in points) {
      if (p is! HistogramPointData) continue;
      final dp = pb_metrics.HistogramDataPoint(
        startTimeUnixNano: _toUnixNano(p.startTime),
        timeUnixNano: _toUnixNano(p.endTime),
        count: Int64(p.count),
        bucketCounts: p.bucketCounts.map((c) => Int64(c)),
        explicitBounds: p.explicitBounds,
        attributes: _attributesToProtobuf(p.attributes),
      );
      if (p.sum != null) dp.sum = p.sum!.toDouble();
      if (p.min != null) dp.min = p.min!.toDouble();
      if (p.max != null) dp.max = p.max!.toDouble();
      results.add(dp);
    }
    return results;
  }

  List<pb_common.KeyValue> _attributesToProtobuf(
      List<api.Attribute> attributes) {
    return attributes
        .map((a) => pb_common.KeyValue(
              key: a.key,
              value: _attributeValueToProtobuf(a.value),
            ))
        .toList();
  }

  static Int64 _toUnixNano(DateTime time) =>
      Int64(time.microsecondsSinceEpoch) * 1000;

  pb_common.AnyValue _attributeValueToProtobuf(Object value) {
    if (value is String) {
      return pb_common.AnyValue(stringValue: value);
    }
    if (value is bool) {
      return pb_common.AnyValue(boolValue: value);
    }
    if (value is double) {
      return pb_common.AnyValue(doubleValue: value);
    }
    if (value is int) {
      return pb_common.AnyValue(intValue: Int64(value));
    }
    if (value is List) {
      final output = <pb_common.AnyValue>[];
      for (final i in value) {
        output.add(_attributeValueToProtobuf(i as Object));
      }
      return pb_common.AnyValue(
          arrayValue: pb_common.ArrayValue(values: output));
    }
    return pb_common.AnyValue(stringValue: value.toString());
  }
}
