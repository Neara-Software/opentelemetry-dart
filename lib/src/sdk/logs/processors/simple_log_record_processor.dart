// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'dart:async';

import 'package:logging/logging.dart' as logging;
import 'package:meta/meta.dart';
import 'package:opentelemetry/sdk.dart' as sdk;

class SimpleLogRecordProcessor implements sdk.LogRecordProcessor {
  final logger = logging.Logger('opentelemetry.sdk.logs.simplelogrecordprocessor');
  final sdk.LogRecordExporter exporter;
  bool _shutDownOnce = false;

  @visibleForTesting
  final exportsCompletion = <Completer>[];

  SimpleLogRecordProcessor({required this.exporter});

  @override
  void onEmit(sdk.ReadableLogRecord logRecord) {
    if (_shutDownOnce) return;
    final completer = Completer();
    exportsCompletion.add(completer);
    exporter.export([logRecord]).then((result) {
      if (result.code != sdk.ExportResultCode.success) {
        logger.shout('SimpleLogRecordProcessor: log record export failed', result.error, result.stackTrace);
      }
    }).whenComplete(() {
      completer.complete();
      exportsCompletion.remove(completer);
    });
  }

  @override
  Future<void> forceFlush() async {
    // Snapshot: `exportsCompletion` is mutated as exports settle, and `onEmit`
    // may append to it while we await. Iterating it directly would risk a
    // ConcurrentModificationError and would never terminate under load.
    await Future.wait(exportsCompletion.toList().map((c) => c.future));
  }

  @override
  Future<void> shutdown() async {
    _shutDownOnce = true;
    // Let in-flight exports settle before the exporter tears down its transport.
    await forceFlush();
    await exporter.shutdown();
  }
}
