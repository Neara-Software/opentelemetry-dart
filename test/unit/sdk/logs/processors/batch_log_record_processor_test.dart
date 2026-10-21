// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

@TestOn('vm')
import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:mocktail/mocktail.dart';
import 'package:opentelemetry/api.dart' as api;
import 'package:opentelemetry/sdk.dart' as sdk;
import 'package:opentelemetry/src/sdk/common/export_backoff.dart';
import 'package:opentelemetry/src/sdk/logs/log_record_limit.dart';
import 'package:test/test.dart';

import '../../../mocks.dart';

void main() {
  test('test processor', () async {
    final exporter = MockLogRecordExporter();
    when(() => exporter.export(any())).thenAnswer((_) async => sdk.ExportResult(code: sdk.ExportResultCode.success));
    final processor = sdk.BatchLogRecordProcessor(
      exporter: exporter,
      scheduledDelayMillis: Duration.zero.inMilliseconds,
    );

    final tracer = sdk.TracerProviderBase().getTracer('test');
    final parent = tracer.startSpan('parent');
    final context = api.contextWithSpan(api.Context.current, parent);
    final logRecord = sdk.LogRecord(
        instrumentationScope: sdk.InstrumentationScope('library_name', 'library_version', 'url://schema', []),
        logRecordLimits: LogRecordLimits(),
        context: context,
        timeProvider: FakeTimeProvider(now: Int64(123)));
    final logRecordA = logRecord
      ..body = 'test log'
      ..severityNumber = api.Severity.fatal3;
    processor.onEmit(logRecordA);

    await Future.delayed(const Duration(milliseconds: 100));
    verify(() => exporter.export(any<List<sdk.ReadableLogRecord>>(
          that: predicate<List<sdk.ReadableLogRecord>>((a) {
            final first = a.first;
            return first.body == 'test log' &&
                first.spanContext.spanId == parent.spanContext.spanId &&
                first.severityNumber == api.Severity.fatal3;
          }),
        ))).called(1);
  });

  test('processor shut down', () async {
    final exporter = MockLogRecordExporter();
    when(exporter.shutdown).thenAnswer((_) async => sdk.ExportResult(code: sdk.ExportResultCode.success));

    final processor = sdk.BatchLogRecordProcessor(
      exporter: exporter,
      scheduledDelayMillis: Duration.zero.inMilliseconds,
    );

    await processor.shutdown();

    verify(exporter.shutdown).called(1);
  });

  test('processor shut down will not emit log', () async {
    final exporter = MockLogRecordExporter();
    when(exporter.shutdown).thenAnswer((_) async => sdk.ExportResult(code: sdk.ExportResultCode.success));

    final processor = sdk.BatchLogRecordProcessor(
      exporter: exporter,
      scheduledDelayMillis: Duration.zero.inMilliseconds,
    );

    await processor.shutdown();
    final logRecord = sdk.LogRecord(
      instrumentationScope: sdk.InstrumentationScope('library_name', 'library_version', 'url://schema', []),
      logRecordLimits: LogRecordLimits(),
    );
    final logRecordA = logRecord
      ..body = 'test log'
      ..severityNumber = api.Severity.fatal3;
    processor.onEmit(logRecordA);

    await Future.delayed(const Duration(milliseconds: 100));

    verifyNever(() => exporter.export(any()));
  });

  test('processor force flush', () async {
    final exporter = MockLogRecordExporter();
    when(() => exporter.export(any())).thenAnswer((_) async => sdk.ExportResult(code: sdk.ExportResultCode.success));

    final processor = sdk.BatchLogRecordProcessor(
      exporter: exporter,
      scheduledDelayMillis: Duration(seconds: 5).inMilliseconds,
    );

    final logRecord = sdk.LogRecord(
      instrumentationScope: sdk.InstrumentationScope('library_name', 'library_version', 'url://schema', []),
      logRecordLimits: LogRecordLimits(),
    );
    final logRecordA = logRecord
      ..body = 'test log'
      ..severityNumber = api.Severity.fatal3;
    processor.onEmit(logRecordA);

    await processor.forceFlush();

    verify(() => exporter.export(any<List<sdk.ReadableLogRecord>>(
          that: predicate<List<sdk.ReadableLogRecord>>((a) {
            final first = a.first;
            return first.body == 'test log' && first.severityNumber == api.Severity.fatal3;
          }),
        ))).called(1);
  });

  group('scheduled timer', () {
    sdk.LogRecord newRecord() => sdk.LogRecord(
          instrumentationScope: sdk.InstrumentationScope('library_name', 'library_version', 'url://schema', []),
          logRecordLimits: LogRecordLimits(),
        )..body = 'test log';

    sdk.BatchLogRecordProcessor newProcessor(sdk.LogRecordExporter exporter) => sdk.BatchLogRecordProcessor(
          exporter: exporter,
          scheduledDelayMillis: 20,
        );

    test('is not rescheduled once the buffer drains', () async {
      final exporter = MockLogRecordExporter();
      when(() => exporter.export(any())).thenAnswer((_) async => sdk.ExportResult(code: sdk.ExportResultCode.success));
      final processor = newProcessor(exporter);

      processor.onEmit(newRecord());
      expect(processor.hasPendingTimer, isTrue);

      await Future.delayed(const Duration(milliseconds: 100));

      // Previously the timer callback unconditionally rearmed itself, leaving an
      // idle processor waking up every scheduledDelayMillis forever.
      expect(processor.hasPendingTimer, isFalse);
      verify(() => exporter.export(any())).called(1);
    });

    test('is rearmed by a subsequent emit', () async {
      final exporter = MockLogRecordExporter();
      when(() => exporter.export(any())).thenAnswer((_) async => sdk.ExportResult(code: sdk.ExportResultCode.success));
      final processor = newProcessor(exporter);

      processor.onEmit(newRecord());
      await Future.delayed(const Duration(milliseconds: 100));
      expect(processor.hasPendingTimer, isFalse);

      processor.onEmit(newRecord());
      expect(processor.hasPendingTimer, isTrue);

      await Future.delayed(const Duration(milliseconds: 100));
      verify(() => exporter.export(any())).called(2);
    });

    test('does not outlive shutdown', () async {
      final exporter = MockLogRecordExporter();
      when(() => exporter.export(any())).thenAnswer((_) async => sdk.ExportResult(code: sdk.ExportResultCode.success));
      when(() => exporter.shutdown()).thenAnswer((_) async {});
      final processor = newProcessor(exporter);

      processor.onEmit(newRecord());
      expect(processor.hasPendingTimer, isTrue);

      await processor.shutdown();

      expect(processor.hasPendingTimer, isFalse);
    });

    test('shutdown with an empty buffer still cancels a pending timer', () async {
      final exporter = MockLogRecordExporter();
      when(() => exporter.export(any())).thenAnswer((_) async => sdk.ExportResult(code: sdk.ExportResultCode.success));
      when(() => exporter.shutdown()).thenAnswer((_) async {});
      final processor = newProcessor(exporter);

      processor.onEmit(newRecord());
      await processor.forceFlush();
      expect(processor.hasPendingTimer, isFalse);

      await processor.shutdown();
      expect(processor.hasPendingTimer, isFalse);
    });
  });

  group('backpressure', () {
    sdk.ExportResult result(sdk.ExportResultCode code) => sdk.ExportResult(code: code);

    test('waits for a pending export before starting another', () async {
      final pending = Completer<sdk.ExportResult>();
      final h = _BackpressureHarness(answer: () => pending.future);
      expect(await h.emitAndCountExports(), 1);
      expect(await h.emitAndCountExports(), 0);

      pending.complete(result(sdk.ExportResultCode.success));
      await _BackpressureHarness.waitTicks(5);
      expect(h.takeExportCount(), 1);
    });

    for (final row in [
      [sdk.ExportResultCode.success, 1],
      [sdk.ExportResultCode.failed, 0],
    ]) {
      test('after a ${(row[0] as sdk.ExportResultCode).name} export, sends ${row[1]} more', () async {
        final h = _BackpressureHarness(answer: () async => result(row[0] as sdk.ExportResultCode));
        expect(await h.emitAndCountExports(), 1);
        expect(await h.emitAndCountExports(), row[1]);
      });
    }

    test('backs off after an export times out', () async {
      final h = _BackpressureHarness(
          answer: () => Completer<sdk.ExportResult>().future, exportTimeoutMillis: _BackpressureHarness.tickMillis);
      expect(await h.emitAndCountExports(), 1);
      expect(await h.emitAndCountExports(), 0);
    });
  });
}

/// A processor exporting every [tickMillis] whose exports answer with
/// [answer], torn down with the test.
class _BackpressureHarness {
  static const tickMillis = 10;

  static Future<void> waitTicks(int n) => Future.delayed(const Duration(milliseconds: tickMillis) * n);

  final _backoff = ExportBackoff(minDelay: const Duration(minutes: 1));
  late final sdk.BatchLogRecordProcessor _processor;
  var _exports = 0;

  _BackpressureHarness({required Future<sdk.ExportResult> Function() answer, int exportTimeoutMillis = 30000}) {
    final exporter = MockLogRecordExporter();
    when(() => exporter.export(any())).thenAnswer((_) {
      _exports++;
      return answer();
    });
    when(exporter.shutdown).thenAnswer((_) async {});
    _processor = sdk.BatchLogRecordProcessor(
        exporter: exporter,
        scheduledDelayMillis: tickMillis,
        exportTimeoutMillis: exportTimeoutMillis,
        backoff: _backoff);
    // Shut down first: once the backoff is cancelled, a live processor would
    // flush its buffer into whichever test runs next.
    addTearDown(_backoff.cancel);
    addTearDown(_processor.shutdown);
  }

  /// Emits a record, gives the processor time to export it, and returns the
  /// number of exports made since the previous count.
  Future<int> emitAndCountExports() async {
    _processor.onEmit(sdk.LogRecord(
      instrumentationScope: sdk.InstrumentationScope('library_name', 'library_version', 'url://schema', []),
      logRecordLimits: LogRecordLimits(),
    ));
    await waitTicks(5);
    return takeExportCount();
  }

  int takeExportCount() {
    final count = _exports;
    _exports = 0;
    return count;
  }
}
