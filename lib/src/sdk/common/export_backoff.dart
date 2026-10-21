// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'dart:async';
import 'dart:math';

/// Spaces out exports after consecutive failures, so that an unresponsive
/// collector does not receive a new request on every scheduled tick.
class ExportBackoff {
  static const defaultMinDelay = Duration(seconds: 5);
  static const defaultMaxDelay = Duration(minutes: 1);

  /// Caps the doubling exponent so the delay cannot overflow.
  static const _maxExponent = 16;

  final Duration minDelay;
  final Duration maxDelay;

  var _failureCount = 0;
  Timer? _timer;

  ExportBackoff(
      {this.minDelay = defaultMinDelay, this.maxDelay = defaultMaxDelay});

  /// Whether exports should be skipped because a recent one failed.
  bool get isBackingOff => _timer != null;

  int get failureCount => _failureCount;

  void recordSuccess() {
    _failureCount = 0;
    cancel();
  }

  void recordFailure() {
    _failureCount++;
    _timer?.cancel();
    _timer = Timer(delayAfter(_failureCount), () => _timer = null);
  }

  /// The backoff after [failureCount] consecutive failures: [minDelay],
  /// doubling with each further failure, capped at [maxDelay].
  Duration delayAfter(int failureCount) {
    final delay = minDelay * pow(2, min(failureCount - 1, _maxExponent));
    return delay > maxDelay ? maxDelay : delay;
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
