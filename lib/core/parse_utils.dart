import 'package:flutter/foundation.dart';

// lib/core/parse_utils.dart
//
// Tiny helpers for tolerantly parsing values that come back from Supabase
// or Firebase APIs. Keeps `.fromJson` constructors and UI date formatters
// from crashing when a row is missing or has an unexpected shape.

/// Parses a Supabase value into a [DateTime].
///
/// Accepts:
///  * `DateTime` (passes through),
///  * date-only strings like `2025-01-15`,
///  * full ISO timestamps,
///  * `int` Unix milliseconds.
///
/// Returns `null` if the value cannot be parsed. UI formatters that need a
/// guaranteed DateTime should use [parseDbDateOr].
DateTime? parseDbDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  final str = value.toString().trim();
  if (str.isEmpty) return null;

  // DATE-only payloads: handle without going through DateTime.parse so
  // we don't crash on locale-specific edge cases.
  if (str.length == 10 && str[4] == '-' && str[7] == '-') {
    final parts = str.split('-');
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year != null && month != null && day != null) {
      return DateTime(year, month, day);
    }
  }

  final parsed = DateTime.tryParse(str);
  if (parsed == null) {
    debugPrint('parseDbDate failed for raw value: $str');
  }
  return parsed;
}

/// Same as [parseDbDate] but falls back to [fallback] when parsing fails.
DateTime parseDbDateOr(dynamic value, DateTime fallback) {
  return parseDbDate(value) ?? fallback;
}

/// Returns a non-null trimmed string from [value], or [fallback] if the
/// value is null/empty.
String parseDbString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  final str = value.toString();
  return str.isEmpty ? fallback : str;
}

/// Reads [value] as a [Map<String, dynamic>], deeply normalising key types
/// so callers can safely use `[]` access on payloads coming from Supabase
/// (which sometimes returns `Map<dynamic, dynamic>` for nested JSON).
Map<String, dynamic>? parseDbMap(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return null;
}
