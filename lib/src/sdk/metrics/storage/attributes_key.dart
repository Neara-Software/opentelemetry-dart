// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:collection/collection.dart';
import 'package:opentelemetry/api.dart' as api;

/// A canonical, sort-normalized key representing a unique attribute set.
class AttributesKey {
  static final AttributesKey empty = AttributesKey(const []);
  static final AttributesKey overflow = AttributesKey([
    api.Attribute.fromBoolean('otel.metric.overflow', true),
  ]);

  final List<api.Attribute> attributes;
  final int _hashCode;

  factory AttributesKey(
    List<api.Attribute> rawAttributes, {
    Set<String>? allowedKeys,
  }) {
    var filtered = rawAttributes;
    if (allowedKeys != null) {
      filtered = rawAttributes.where((a) => allowedKeys.contains(a.key)).toList();
    }

    // Sort by key name so attribute order doesn't affect key equality
    final sorted = List<api.Attribute>.from(filtered)
      ..sort((a, b) => a.key.compareTo(b.key));

    final hashCode = const DeepCollectionEquality().hash(
      sorted.map((a) => '${a.key}=${a.value}').toList(),
    );

    return AttributesKey._(List.unmodifiable(sorted), hashCode);
  }

  AttributesKey._(this.attributes, this._hashCode);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AttributesKey) return false;
    if (_hashCode != other._hashCode) return false;
    if (attributes.length != other.attributes.length) return false;

    for (var i = 0; i < attributes.length; i++) {
      if (attributes[i].key != other.attributes[i].key ||
          attributes[i].value != other.attributes[i].value) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => _hashCode;
}
