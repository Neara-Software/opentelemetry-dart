// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'instrument_descriptor.dart';

/// Predicate used by Views to select instruments.
class InstrumentSelector {
  final String? name;
  final InstrumentType? type;
  final String? unit;
  final String? meterName;
  final String? meterVersion;
  final String? meterSchemaUrl;

  final RegExp? _nameRegex;

  InstrumentSelector({
    this.name,
    this.type,
    this.unit,
    this.meterName,
    this.meterVersion,
    this.meterSchemaUrl,
  }) : _nameRegex = _compilePattern(name);

  static RegExp? _compilePattern(String? pattern) {
    if (pattern == null) return null;
    if (pattern == '*') return RegExp(r'^.*$');
    if (!pattern.contains('*') && !pattern.contains('?')) {
      return RegExp('^${RegExp.escape(pattern)}\$');
    }

    final buffer = StringBuffer('^');
    for (var i = 0; i < pattern.length; i++) {
      final char = pattern[i];
      if (char == '*') {
        buffer.write('.*');
      } else if (char == '?') {
        buffer.write('.');
      } else {
        buffer.write(RegExp.escape(char));
      }
    }
    buffer.write(r'$');
    return RegExp(buffer.toString());
  }

  bool matches(
    InstrumentDescriptor descriptor, {
    String? meterName,
    String? meterVersion,
    String? meterSchemaUrl,
  }) {
    if (_nameRegex != null && !_nameRegex!.hasMatch(descriptor.name)) {
      return false;
    }
    if (type != null && descriptor.type != type) {
      return false;
    }
    if (unit != null && descriptor.unit != unit) {
      return false;
    }
    if (this.meterName != null && this.meterName != meterName) {
      return false;
    }
    if (this.meterVersion != null && this.meterVersion != meterVersion) {
      return false;
    }
    if (this.meterSchemaUrl != null && this.meterSchemaUrl != meterSchemaUrl) {
      return false;
    }
    return true;
  }
}
