// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'dart:async';

import 'package:logging/logging.dart';

import '../../../../sdk.dart' as sdk;
import '../../common/export_backoff.dart';
import '../data/metric_data.dart';
import '../exporters/metric_exporter.dart';
import 'metric_reader.dart';

/// A MetricReader that periodically reads and exports metrics using an exporter.
class PeriodicExportingMetricReader extends MetricReader {
  final MetricExporter exporter;
  final Duration exportInterval;
  final Duration exportTimeout;
  final ExportBackoff _backoff;
  final Logger _log = Logger('opentelemetry.PeriodicExportingMetricReader');

  Timer? _timer;
  bool _isShutdown = false;

  /// Exports in flight. Scheduled collects wait for these, so that a stalled
  /// network does not pile up requests.
  var _pendingExports = 0;

  PeriodicExportingMetricReader(
    this.exporter, {
    this.exportInterval = const Duration(milliseconds: 60000),
    this.exportTimeout = const Duration(milliseconds: 30000),
    ExportBackoff? backoff,
  }) : _backoff = backoff ?? ExportBackoff() {
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(exportInterval, (_) {
      // Skipping a tick loses nothing: the next collect reports the values
      // accumulated meanwhile.
      if (_pendingExports > 0 || _backoff.isBackingOff) return;
      unawaited(collect());
    });
  }

  Future<void> _export(List<ResourceMetricsData> data) async {
    _pendingExports++;
    try {
      final result = await exporter.export(data).timeout(exportTimeout);
      if (result.code == sdk.ExportResultCode.success) {
        _backoff.recordSuccess();
      } else {
        _backoff.recordFailure();
      }
    } on TimeoutException {
      _log.warning('Exporting metrics timed out after $exportTimeout.');
      _backoff.recordFailure();
    } finally {
      _pendingExports--;
    }
  }

  @override
  Future<void> collect() async {
    if (_isShutdown || meterProvider == null) {
      return;
    }

    final data = meterProvider!.collectForReader(this);
    if (data.isNotEmpty) {
      await _export(data);
    }
  }

  @override
  Future<void> forceFlush() async {
    if (_isShutdown) return;
    await collect();
    await exporter.forceFlush();
  }

  @override
  Future<void> shutdown() async {
    if (_isShutdown) return;
    _isShutdown = true;
    _timer?.cancel();
    _backoff.cancel();
    if (meterProvider != null) {
      final data = meterProvider!.collectForReader(this);
      if (data.isNotEmpty) {
        await _export(data);
      }
    }
    await exporter.shutdown();
  }
}
