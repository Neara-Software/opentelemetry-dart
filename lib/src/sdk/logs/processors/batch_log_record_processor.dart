// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'dart:async';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:opentelemetry/sdk.dart' as sdk;

class BatchLogRecordProcessor extends sdk.LogRecordProcessor {
  static const OTEL_BLRP_MAX_EXPORT_BATCH_SIZE = 512;
  static const OTEL_BLRP_MAX_QUEUE_SIZE = 2048;
  static const OTEL_BLRP_SCHEDULE_DELAY = 5000;
  static const OTEL_BLRP_EXPORT_TIMEOUT = 30000;

  final int maxExportBatchSize;
  final int scheduledDelayMillis;
  final int exportTimeoutMillis;
  final int maxQueueSize;
  final sdk.LogRecordExporter exporter;

  final _finishedLogRecords = <sdk.ReadableLogRecord>[];

  bool _isShutDown = false;
  Timer? _timer;

  /// Whether a flush is currently scheduled. An idle or shut down processor
  /// must not hold a pending timer.
  @visibleForTesting
  bool get hasPendingTimer => _timer != null;

  BatchLogRecordProcessor({
    required this.exporter,
    this.maxExportBatchSize = OTEL_BLRP_MAX_EXPORT_BATCH_SIZE,
    this.scheduledDelayMillis = OTEL_BLRP_SCHEDULE_DELAY,
    this.exportTimeoutMillis = OTEL_BLRP_EXPORT_TIMEOUT,
    this.maxQueueSize = OTEL_BLRP_MAX_QUEUE_SIZE,
  }) : assert(
          maxQueueSize >= maxExportBatchSize,
          'BatchLogRecordProcessor: maxExportBatchSize must be smaller or equal to maxQueueSize',
        );

  @override
  void onEmit(sdk.ReadableLogRecord logRecord) {
    if (_isShutDown) return;
    _addToBuffer(logRecord);
  }

  @override
  Future<void> forceFlush() async {
    if (_isShutDown) return;
    await _flushAll();
  }

  @override
  Future<void> shutdown() async {
    _isShutDown = true;
    await _flushAll();
    await exporter.shutdown();
  }

  void _addToBuffer(sdk.ReadableLogRecord logRecord) {
    if (_finishedLogRecords.length >= maxQueueSize) {
      return;
    }
    _finishedLogRecords.add(logRecord);
    _maybeStartTimer();
  }

  Future<void> _flushAll() async {
    // Cancel unconditionally: with an empty buffer no batch runs below, and the
    // pending timer would otherwise outlive a shutdown.
    _clearTimer();

    final promises = <Future<void>>[];
    final batchCount = (_finishedLogRecords.length / maxExportBatchSize).ceil();

    for (var i = 0; i < batchCount; i++) {
      promises.add(_flushOneBatch());
    }

    await Future.wait(promises);
  }

  Future<void> _flushOneBatch() async {
    _clearTimer();
    if (_finishedLogRecords.isEmpty) return;
    final result = _finishedLogRecords.sublist(0, min(maxExportBatchSize, _finishedLogRecords.length));
    _finishedLogRecords.removeRange(0, result.length);
    await exporter.export(result);
  }

  void _maybeStartTimer() {
    if (_timer != null || _isShutDown) return;
    _timer = Timer(Duration(milliseconds: scheduledDelayMillis), () async {
      await _flushOneBatch();
      // Only keep the timer alive while there is still buffered work; otherwise
      // an idle processor would reschedule itself forever.
      if (_finishedLogRecords.isNotEmpty) _maybeStartTimer();
    });
  }

  void _clearTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
