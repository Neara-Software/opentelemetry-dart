// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

@TestOn('vm')
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:opentelemetry/api.dart' as api;
import 'package:opentelemetry/sdk.dart' as sdk;
import 'package:opentelemetry/src/sdk/metrics/data/aggregation_temporality.dart';
import 'package:opentelemetry/src/sdk/metrics/data/metric_data.dart';
import 'package:opentelemetry/src/sdk/metrics/data/point_data.dart';
import 'package:opentelemetry/src/sdk/metrics/exporters/otlp_metric_exporter.dart';
import 'package:opentelemetry/src/sdk/proto/opentelemetry/proto/collector/metrics/v1/metrics_service.pb.dart'
    as pb_metric_service;
import 'package:test/test.dart';

import '../../../mocks.dart';

void main() {
  late MockHttpClient mockClient;
  final uri = Uri.parse('https://collector.example.com/v1/metrics');

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    mockClient = MockHttpClient();
  });

  tearDown(() {
    reset(mockClient);
  });

  test('serializes and exports metrics over OTLP Protobuf HTTP', () async {
    final t0 = DateTime.utc(2023, 1, 1, 0, 0, 0);
    final t1 = DateTime.utc(2023, 1, 1, 0, 1, 0);

    final resource =
        sdk.Resource([api.Attribute.fromString('service.name', 'test_app')]);
    final scope = sdk.InstrumentationScope(
        'my_library', '1.0.0', 'https://opentelemetry.io/schemas/1.20.0', []);

    final sumMetric = MetricData(
      name: 'requests_total',
      description: 'Total HTTP requests',
      unit: 'req',
      type: MetricType.sum,
      temporality: AggregationTemporality.cumulative,
      isMonotonic: true,
      dataPoints: [
        NumberPointData<int>(
          startTime: t0,
          endTime: t1,
          value: 42,
          attributes: [api.Attribute.fromString('http.method', 'GET')],
        ),
      ],
    );

    final histogramMetric = MetricData(
      name: 'request_duration_ms',
      description: 'Request duration',
      unit: 'ms',
      type: MetricType.histogram,
      temporality: AggregationTemporality.cumulative,
      dataPoints: [
        HistogramPointData(
          startTime: t0,
          endTime: t1,
          count: 5,
          sum: 150.5,
          min: 10.0,
          max: 50.0,
          bucketCounts: [2, 3],
          explicitBounds: [25.0],
          attributes: [api.Attribute.fromString('env', 'prod')],
        ),
      ],
    );

    final metricsBatch = [
      ResourceMetricsData(
        resource: resource,
        scopeMetrics: [
          ScopeMetricsData(
            scope: scope,
            metrics: [sumMetric, histogramMetric],
          ),
        ],
      ),
    ];

    List<int>? capturedBody;
    when(() => mockClient.post(
          any(),
          body: any(named: 'body'),
          headers: any(named: 'headers'),
        )).thenAnswer((invocation) async {
      capturedBody = invocation.namedArguments[#body] as List<int>;
      return http.Response('{"partialSuccess":{}}', 200);
    });

    final exporter = OTLPMetricExporter(uri, httpClient: mockClient);
    final result = await exporter.export(metricsBatch);

    expect(result.code, equals(sdk.ExportResultCode.success));
    expect(capturedBody, isNotNull);

    // Parse back the protobuf to verify wire correctness
    final request =
        pb_metric_service.ExportMetricsServiceRequest.fromBuffer(capturedBody!);
    expect(request.resourceMetrics.length, equals(1));

    final rm = request.resourceMetrics.first;
    expect(rm.resource.attributes.first.key, equals('service.name'));
    expect(rm.resource.attributes.first.value.stringValue, equals('test_app'));

    final sm = rm.scopeMetrics.first;
    expect(sm.scope.name, equals('my_library'));
    expect(sm.scope.version, equals('1.0.0'));
    expect(sm.metrics.length, equals(2));

    // Verify Sum Metric
    final sum = sm.metrics.firstWhere((m) => m.name == 'requests_total');
    expect(sum.description, equals('Total HTTP requests'));
    expect(sum.unit, equals('req'));
    expect(sum.sum.isMonotonic, isTrue);
    expect(sum.sum.dataPoints.first.asInt.toInt(), equals(42));
    expect(
        sum.sum.dataPoints.first.attributes.first.key, equals('http.method'));
    expect(sum.sum.dataPoints.first.attributes.first.value.stringValue,
        equals('GET'));

    // Verify Histogram Metric
    final hist = sm.metrics.firstWhere((m) => m.name == 'request_duration_ms');
    expect(hist.histogram.dataPoints.first.count.toInt(), equals(5));
    expect(hist.histogram.dataPoints.first.sum, equals(150.5));
    expect(hist.histogram.dataPoints.first.min, equals(10.0));
    expect(hist.histogram.dataPoints.first.max, equals(50.0));
    expect(hist.histogram.dataPoints.first.explicitBounds, equals([25.0]));
  });
}
