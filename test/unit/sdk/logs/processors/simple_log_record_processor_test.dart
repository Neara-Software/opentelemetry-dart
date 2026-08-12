// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

@TestOn('vm')
import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:opentelemetry/sdk.dart' as sdk;
import 'package:opentelemetry/src/sdk/logs/log_record_limit.dart';
import 'package:test/test.dart';

import '../../../mocks.dart';

void main() {
  late sdk.LogRecordExporter exporter;
  late sdk.LogRecordProcessor processor;

  setUp(() {
    exporter = MockLogRecordExporter();
    processor = sdk.SimpleLogRecordProcessor(exporter: exporter);
    when(() => exporter.export(any())).thenAnswer((_) async => sdk.ExportResult(code: sdk.ExportResultCode.success));
    when(() => exporter.shutdown()).thenAnswer((_) => Future.value());
  });

  test('executes export', () {
    final logRecord = sdk.LogRecord(
      instrumentationScope: sdk.InstrumentationScope('library_name', 'library_version', 'url://schema', []),
      logRecordLimits: LogRecordLimits(),
    );

    processor.onEmit(logRecord);

    verify(() => exporter.export([logRecord])).called(1);
  });

  test('executes export and fail', () async {
    var errorMessage = '';
    Logger.root.onRecord.listen((data) {
      errorMessage = data.message;
    });
    final logRecord = sdk.LogRecord(
      instrumentationScope: sdk.InstrumentationScope('library_name', 'library_version', 'url://schema', []),
      logRecordLimits: LogRecordLimits(),
    );

    when(() => exporter.export(any())).thenAnswer((_) async => sdk.ExportResult(code: sdk.ExportResultCode.failed));

    processor.onEmit(logRecord);

    await Future.delayed(const Duration(milliseconds: 50));

    expect(errorMessage, 'SimpleLogRecordProcessor: log record export failed');
  });

  test('shutdown exporters on forced flush', () async {
    await processor.shutdown();

    verify(exporter.shutdown).called(1);
  });

  test('forceFlush waits for all pending exports to complete', () async {
    when(() => exporter.export(any())).thenAnswer((_) async {
      await Future.delayed(const Duration(seconds: 1));
      return sdk.ExportResult(code: sdk.ExportResultCode.success);
    });

    // Emit two log records, creating two pending exports.
    processor.onEmit(
      sdk.LogRecord(
          instrumentationScope: sdk.InstrumentationScope('library_name', 'library_version', 'url://schema', []),
          logRecordLimits: LogRecordLimits(),
          timeProvider: FakeTimeProvider(now: Int64(123))),
    );
    await Future.delayed(Duration(milliseconds: 50));
    processor.onEmit(
      sdk.LogRecord(
          instrumentationScope: sdk.InstrumentationScope('library_name', 'library_version', 'url://schema', []),
          logRecordLimits: LogRecordLimits(),
          timeProvider: FakeTimeProvider(now: Int64(123))),
    );
    expect((processor as sdk.SimpleLogRecordProcessor).exportsCompletion.length, 2);
    // Ensure the exports are pending.
    final flushFuture = processor.forceFlush();
    expect(flushFuture, completes);
  });

  test('completed exports are reclaimed, including after a forceFlush', () async {
    when(() => exporter.export(any())).thenAnswer((_) async => sdk.ExportResult(code: sdk.ExportResultCode.success));

    sdk.LogRecord newRecord() => sdk.LogRecord(
        instrumentationScope: sdk.InstrumentationScope('library_name', 'library_version', 'url://schema', []),
        logRecordLimits: LogRecordLimits(),
        timeProvider: FakeTimeProvider(now: Int64(123)));

    final simple = processor as sdk.SimpleLogRecordProcessor;

    processor.onEmit(newRecord());
    await processor.forceFlush();
    expect(simple.exportsCompletion, isEmpty);

    // A latch set by the first forceFlush used to disable reclamation
    // permanently, so every later export leaked a Completer.
    for (var i = 0; i < 5; i++) {
      processor.onEmit(newRecord());
      await processor.forceFlush();
    }
    expect(simple.exportsCompletion, isEmpty);
  });

  test('forceFlush tolerates records emitted while it is awaiting', () async {
    final simple = processor as sdk.SimpleLogRecordProcessor;
    when(() => exporter.export(any())).thenAnswer((_) async {
      await Future.delayed(const Duration(milliseconds: 20));
      return sdk.ExportResult(code: sdk.ExportResultCode.success);
    });

    sdk.LogRecord newRecord() => sdk.LogRecord(
        instrumentationScope: sdk.InstrumentationScope('library_name', 'library_version', 'url://schema', []),
        logRecordLimits: LogRecordLimits(),
        timeProvider: FakeTimeProvider(now: Int64(123)));

    processor.onEmit(newRecord());
    final flush = processor.forceFlush();
    // Emitting during the flush mutates the list the flush is waiting on.
    processor.onEmit(newRecord());

    await expectLater(flush, completes);
    await Future.delayed(const Duration(milliseconds: 60));
    expect(simple.exportsCompletion, isEmpty);
  });
}
