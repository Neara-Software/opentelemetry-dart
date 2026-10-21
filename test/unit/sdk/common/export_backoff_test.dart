// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

@TestOn('vm')
import 'package:opentelemetry/src/sdk/common/export_backoff.dart';
import 'package:test/test.dart';

void main() {
  test('delay doubles per failure up to the cap', () {
    final backoff = ExportBackoff(
        minDelay: Duration(seconds: 5), maxDelay: Duration(minutes: 1));
    expect([1, 2, 3, 4, 5, 6, 1000].map(backoff.delayAfter).toList(), [
      Duration(seconds: 5),
      Duration(seconds: 10),
      Duration(seconds: 20),
      Duration(seconds: 40),
      Duration(minutes: 1),
      Duration(minutes: 1),
      Duration(minutes: 1),
    ]);
  });

  test('backs off after a failure until the delay elapses', () async {
    final backoff = ExportBackoff(minDelay: Duration(milliseconds: 20));
    addTearDown(backoff.cancel);
    expect(backoff.isBackingOff, isFalse);

    backoff.recordFailure();
    expect(backoff.isBackingOff, isTrue);

    await Future.delayed(Duration(milliseconds: 60));
    expect(backoff.isBackingOff, isFalse);
  });

  test('success ends the backoff and resets the delay', () {
    final backoff = ExportBackoff()
      ..recordFailure()
      ..recordFailure()
      ..recordSuccess();
    expect(backoff.isBackingOff, isFalse);
    expect(backoff.failureCount, 0);
  });
}
