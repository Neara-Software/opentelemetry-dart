// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

class ExportResult {
  final ExportResultCode code;

  /// Deliberately [Object] rather than [Exception]: exporters can fail with an
  /// [Error] too, and narrowing this would turn such a failure into a second,
  /// more confusing `TypeError` when the result is constructed.
  final Object? error;

  final StackTrace? stackTrace;

  ExportResult({required this.code, this.error, this.stackTrace});
}

enum ExportResultCode {
  success,
  failed,
}
