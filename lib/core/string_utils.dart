// lib/core/string_utils.dart
//
// Tiny string helpers shared across UI components.

/// Returns a two-character uppercase initial pair for the given full name.
///
/// Rules:
///  • empty / whitespace → `fallback` (default `'DR'`).
///  • single word ≥ 2 chars → first two letters.
///  • single word of length 1 → that letter duplicated (e.g. "A" → "AA")
///    so the output is always 2 characters for consistent UI.
///  • multiple words → first letter of the first and last word.
String initialsFor(String? name, {String fallback = 'DR'}) {
  final parts = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return fallback;
  if (parts.length == 1) {
    final v = parts.first;
    if (v.length >= 2) return v.substring(0, 2).toUpperCase();
    return (v + v).toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
