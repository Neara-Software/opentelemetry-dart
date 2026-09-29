// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'dart:async';

import '../exporters/metric_exporter.dart';
import 'metric_reader.dart';

/// A MetricReader that periodically reads and exports metrics using an exporter.
class PeriodicExportingMetricReader extends MetricReader {
  final MetricExporter exporter;
  final Duration exportInterval;
  final Duration exportTimeout;

  Timer? _timer;
  bool _isShutdown = false;

  PeriodicExportingMetricReader(
    this.exporter, {
    this.exportInterval = const Duration(milliseconds: 60000),
    this.exportTimeout = const Duration(milliseconds: 30000),
  }) {
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(exportInterval, (_) {
      unawaited(collect());
    });
  }

  @override
  Future<void> collect() async {
    if (_isShutdown || meterProvider == null) {
      return;
    }

    final data = meterProvider!.collectForReader(this);
    if (data.isNotEmpty) {
      await exporter.export(data);
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
    if (meterProvider != null) {
      final data = meterProvider!.collectForReader(this);
      if (data.isNotEmpty) {
        await exporter.export(data);
      }
    }
    await exporter.shutdown();
  }
}
