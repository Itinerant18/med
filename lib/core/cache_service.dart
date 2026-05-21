import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent TTL-aware key-value cache backed by SharedPreferences.
///
/// Call [init] once in main() before runApp. All keys are namespaced
/// with [_prefix] to avoid collisions with other SharedPreferences entries.
/// Call [clearAll] on logout to prevent data leakage between users.
class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  static const _prefix = 'mf:';
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Returns cached data for [key], or `null` if expired / not found.
  /// Synchronous once [init] has completed.
  dynamic getRaw(String key) {
    final raw = _prefs?.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      final entry = jsonDecode(raw) as Map<String, dynamic>;
      final expiry = entry['expiry'] as String?;
      if (expiry != null && DateTime.now().isAfter(DateTime.parse(expiry))) {
        _prefs?.remove('$_prefix$key');
        return null;
      }
      return entry['data'];
    } catch (_) {
      return null;
    }
  }

  /// Stores [data] under [key]. The entry expires after [ttl] if provided.
  /// [data] must be JSON-serializable (Map, List, String, num, bool, null).
  Future<void> putRaw(String key, dynamic data, {Duration? ttl}) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final entry = <String, dynamic>{
      'data': data,
      if (ttl != null) 'expiry': DateTime.now().add(ttl).toIso8601String(),
    };
    await prefs.setString('$_prefix$key', jsonEncode(entry));
  }

  Future<void> invalidate(String key) async => _prefs?.remove('$_prefix$key');

  Future<void> invalidatePrefix(String prefix) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith('$_prefix$prefix'))
        .toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  Future<void> clearAll() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
