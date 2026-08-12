// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:opentelemetry/api.dart' as api;
import 'package:opentelemetry/sdk.dart' as sdk;

/// Applications use a logger to emit log records. Getting one mirrors the
/// tracing setup: an exporter sends records to a backend, a processor decides
/// when they are handed to that exporter, and a provider ties them together.
///
/// The api and sdk libraries both export a `Logger`, and so does
/// `package:logging`, so importing them with a prefix avoids the clash.
Future<void> main(List<String> args) async {
  /// [sdk.ConsoleLogRecordExporter] prints records to the console and is meant
  /// for diagnostics. [sdk.OTLPLogExporter] sends them to a collector over
  /// OTLP/HTTP.
  final consoleExporter = sdk.ConsoleLogRecordExporter();
  final otlpExporter = sdk.OTLPLogExporter(Uri.parse('https://my-collector.com/v1/logs'));

  /// [sdk.SimpleLogRecordProcessor] forwards every record as it is emitted.
  /// [sdk.BatchLogRecordProcessor] buffers records and flushes them on an
  /// interval, which is what you usually want against a real collector.
  final provider = sdk.LoggerProvider(
    resource: sdk.Resource([api.Attribute.fromString('service.name', 'my-service')]),
    processors: [
      sdk.SimpleLogRecordProcessor(exporter: consoleExporter),
      sdk.BatchLogRecordProcessor(exporter: otlpExporter),
    ],
  );

  /// Registering the provider globally lets other libraries emit records
  /// through [api.globalLogProvider] without being handed the provider.
  api.registerGlobalLogProvider(provider);

  final logger = api.globalLogProvider.get('logger-name');

  logger.emit(
    body: 'Hello World!',
    severityNumber: api.Severity.info,
    severityText: 'INFO',
    attributes: [api.Attribute.fromString('user.id', '42')],
  );

  /// A record emitted inside an active span carries that span's trace and span
  /// ids, which is what correlates logs with traces in a backend.
  final tracer = sdk.TracerProviderBase().getTracer('tracer-name');
  api.traceSync('my-operation', () {
    logger.emit(body: 'correlated with the enclosing span');
  }, tracer: tracer);

  /// Both are awaitable: flush before the process exits, or records buffered by
  /// the batch processor are lost.
  await provider.shutdown();
}
