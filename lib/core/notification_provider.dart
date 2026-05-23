// lib/core/notification_provider.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/fcm_service.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/models/app_notification.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@immutable
class NotificationPreferencesState {
  const NotificationPreferencesState({
    required this.quietHoursEnabled,
    required this.quietHoursStart,
    required this.quietHoursEnd,
    required this.channelPreferences,
  });

  static const defaultChannels = <String, bool>{
    'patient': true,
    'visit': true,
    'followup': true,
    'system': true,
  };

  static const defaults = NotificationPreferencesState(
    quietHoursEnabled: false,
    quietHoursStart: 22,
    quietHoursEnd: 7,
    channelPreferences: defaultChannels,
  );

  final bool quietHoursEnabled;
  final int quietHoursStart;
  final int quietHoursEnd;
  final Map<String, bool> channelPreferences;

  NotificationPreferencesState copyWith({
    bool? quietHoursEnabled,
    int? quietHoursStart,
    int? quietHoursEnd,
    Map<String, bool>? channelPreferences,
  }) {
    return NotificationPreferencesState(
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      channelPreferences: channelPreferences ?? this.channelPreferences,
    );
  }

  Map<String, dynamic> toSupabaseJson(String userId) {
    return {
      'user_id': userId,
      'quiet_hours_enabled': quietHoursEnabled,
      'quiet_hours_start': quietHoursStart,
      'quiet_hours_end': quietHoursEnd,
      'notification_channels': channelPreferences,
    };
  }

  Map<String, dynamic> toCacheJson() {
    return {
      'quiet_hours_enabled': quietHoursEnabled,
      'quiet_hours_start': quietHoursStart,
      'quiet_hours_end': quietHoursEnd,
      'notification_channels': channelPreferences,
    };
  }

  factory NotificationPreferencesState.fromJson(Map<String, dynamic> json) {
    final rawChannels = json['notification_channels'];
    final parsedChannels = <String, bool>{...defaultChannels};

    if (rawChannels is Map) {
      for (final entry in rawChannels.entries) {
        final key = entry.key.toString();
        if (!defaultChannels.containsKey(key)) continue;
        parsedChannels[key] = entry.value == true;
      }
    }

    return NotificationPreferencesState(
      quietHoursEnabled: json['quiet_hours_enabled'] == true,
      quietHoursStart:
          _parseHour(json['quiet_hours_start'], fallback: defaults.quietHoursStart),
      quietHoursEnd:
          _parseHour(json['quiet_hours_end'], fallback: defaults.quietHoursEnd),
      channelPreferences: parsedChannels,
    );
  }

  static int _parseHour(dynamic value, {required int fallback}) {
    final parsed = switch (value) {
      int v => v,
      String v => int.tryParse(v),
      _ => null,
    };
    if (parsed == null) return fallback;
    return parsed.clamp(0, 23);
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, List<AppNotification>>(
  (ref) {
    final supabase = ref.read(supabaseClientProvider);
    final notifier = NotificationNotifier();
    RealtimeChannel? channel;
    var disposed = false;

    Future<void> syncNotifications() async {
      try {
        await notifier.loadFromDatabase(supabase);
        if (disposed) return;

        final user = supabase.auth.currentUser;
        if (user == null) {
          channel?.unsubscribe();
          channel = null;
          return;
        }

        channel?.unsubscribe();
        channel = supabase
            .channel('notifications:${user.id}')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'notifications',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'recipient_id',
                value: user.id,
              ),
              callback: (payload) {
                if (disposed) return;
                final row = payload.newRecord;
                final notif = AppNotification.fromJson(
                    Map<String, dynamic>.from(row as Map));
                notifier.addNotification(notif);
              },
            )
            .subscribe();
      } catch (e) {
        debugPrint('Notification realtime setup failed: $e');
      }
    }

    unawaited(syncNotifications());

    ref.onDispose(() {
      disposed = true;
      channel?.unsubscribe();
    });

    return notifier;
  },
);

final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationProvider).where((n) => !n.isRead).length;
});

final notificationPreferencesControllerProvider = AsyncNotifierProvider<
    NotificationPreferencesController, NotificationPreferencesState>(
  NotificationPreferencesController.new,
);

final notificationPreferencesProvider = Provider<Map<String, bool>>((ref) {
  return ref.watch(notificationPreferencesControllerProvider).valueOrNull
          ?.channelPreferences ??
      NotificationPreferencesState.defaultChannels;
});

final quietHoursEnabledProvider = Provider<bool>((ref) {
  return ref.watch(notificationPreferencesControllerProvider).valueOrNull
          ?.quietHoursEnabled ??
      NotificationPreferencesState.defaults.quietHoursEnabled;
});

class NotificationPreferencesController
    extends AsyncNotifier<NotificationPreferencesState> {
  static const _cachePrefix = 'notification_preferences_v1_';

  SupabaseClient get _supabase => ref.read(supabaseClientProvider);

  @override
  Future<NotificationPreferencesState> build() async {
    // Rebuild only when the authenticated user actually changes (login/logout).
    // Watching the raw auth stream would fire on every token refresh and cause
    // a new network round-trip on each event, spamming the log with failures.
    ref.watch(authNotifierProvider.select(
      (v) => v.valueOrNull?.session.user.id,
    ));

    final preferences = await _loadPreferences();
    _applyPreferences(preferences);
    return preferences;
  }

  Future<void> setCategoryEnabled(String category, bool enabled) async {
    final current = state.valueOrNull ?? NotificationPreferencesState.defaults;
    final next = current.copyWith(
      channelPreferences: {
        ...current.channelPreferences,
        category: enabled,
      },
    );
    _setLocalState(next);
    await _persist(next);
  }

  Future<void> setQuietHoursEnabled(bool enabled) async {
    final current = state.valueOrNull ?? NotificationPreferencesState.defaults;
    final next = current.copyWith(quietHoursEnabled: enabled);
    _setLocalState(next);
    await _persist(next);
  }

  Future<void> setQuietHoursWindow({
    required int startHour,
    required int endHour,
  }) async {
    final current = state.valueOrNull ?? NotificationPreferencesState.defaults;
    final next = current.copyWith(
      quietHoursStart: startHour.clamp(0, 23),
      quietHoursEnd: endHour.clamp(0, 23),
    );
    _setLocalState(next);
    await _persist(next);
  }

  Future<void> resetToDefaults() async {
    _setLocalState(NotificationPreferencesState.defaults);
  }

  Future<NotificationPreferencesState> _loadPreferences() async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final userId = _supabase.auth.currentUser?.id;
    final cached = _readFromCache(sharedPreferences, userId);

    if (userId == null) {
      return cached ?? NotificationPreferencesState.defaults;
    }

    try {
      final response = await _supabase.retry(
        () => _supabase
            .from('user_preferences')
            .select(
                'quiet_hours_enabled, quiet_hours_start, quiet_hours_end, notification_channels')
            .eq('user_id', userId)
            .maybeSingle(),
      );

      if (response != null) {
        final serverState =
            NotificationPreferencesState.fromJson(Map<String, dynamic>.from(response));
        await _writeToCache(sharedPreferences, userId, serverState);
        return serverState;
      }

      final seedState = cached ?? NotificationPreferencesState.defaults;
      await _saveToSupabase(userId, seedState);
      await _writeToCache(sharedPreferences, userId, seedState);
      return seedState;
    } catch (e) {
      debugPrint('Notification preferences load failed, using cache: $e');
      return cached ?? NotificationPreferencesState.defaults;
    }
  }

  void _setLocalState(NotificationPreferencesState preferences) {
    _applyPreferences(preferences);
    state = AsyncData(preferences);
  }

  void _applyPreferences(NotificationPreferencesState preferences) {
    ref
        .read(notificationProvider.notifier)
        .updatePreferences(preferences.channelPreferences);
    FcmService.instance.configureQuietHours(
      enabled: preferences.quietHoursEnabled,
      startHour: preferences.quietHoursStart,
      endHour: preferences.quietHoursEnd,
    );
  }

  Future<void> _persist(NotificationPreferencesState preferences) async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final userId = _supabase.auth.currentUser?.id;

    await _writeToCache(sharedPreferences, userId, preferences);

    if (userId == null) return;

    try {
      await _saveToSupabase(userId, preferences);
    } catch (e) {
      debugPrint('Notification preferences sync failed: $e');
    }
  }

  Future<void> _saveToSupabase(
    String userId,
    NotificationPreferencesState preferences,
  ) async {
    await _supabase.retry(
      () => _supabase
          .from('user_preferences')
          .upsert(preferences.toSupabaseJson(userId), onConflict: 'user_id'),
    );
  }

  NotificationPreferencesState? _readFromCache(
    SharedPreferences sharedPreferences,
    String? userId,
  ) {
    final raw = sharedPreferences.getString(_cacheKey(userId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return NotificationPreferencesState.fromJson(decoded);
    } catch (e) {
      debugPrint('Notification preferences cache decode failed: $e');
      return null;
    }
  }

  Future<void> _writeToCache(
    SharedPreferences sharedPreferences,
    String? userId,
    NotificationPreferencesState preferences,
  ) async {
    await sharedPreferences.setString(
      _cacheKey(userId),
      jsonEncode(preferences.toCacheJson()),
    );
  }

  String _cacheKey(String? userId) => '$_cachePrefix${userId ?? 'guest'}';
}

class NotificationNotifier extends StateNotifier<List<AppNotification>> {
  NotificationNotifier() : super([]);

  Map<String, bool> _preferences = NotificationPreferencesState.defaultChannels;

  /// Loads up to 50 most recent notifications from the `notifications` table.
  /// Best-effort — failures are silently ignored.
  Future<void> loadFromDatabase(SupabaseClient supabase) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase.retry(() => supabase
          .from('notifications')
          .select()
          .eq('recipient_id', user.id)
          .order('created_at', ascending: false)
          .limit(50));

      final loaded = (response as List).map((json) =>
          AppNotification.fromJson(
              Map<String, dynamic>.from(json as Map))).toList();

      final merged = <String, AppNotification>{};
      for (final notif in state) {
        merged[notif.id] = notif;
      }
      for (final notif in loaded) {
        merged[notif.id] = notif;
      }

      final next = merged.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      state = next;
    } catch (e) {
      debugPrint('loadFromDatabase: non-fatal error — $e');
    }
  }

  void updatePreferences(Map<String, bool> preferences) {
    _preferences = preferences;
  }

  void addNotification(AppNotification notification) {
    if (!(_preferences[notification.category] ?? true)) return;
    // Avoid duplicate notifications with same ID
    if (state.any((n) => n.id == notification.id)) return;
    state = [notification, ...state];
  }

  Future<void> markOneRead(SupabaseClient supabase, String id) async {
    state = [
      for (final notif in state)
        if (notif.id == id) notif.copyWith(isRead: true) else notif,
    ];
    try {
      await supabase.from('notifications').update({
        'is_read': true,
      }).eq('id', id);
    } catch (e) {
      debugPrint('Failed to mark notification read in database: $e');
    }
  }

  Future<void> markAllRead(SupabaseClient supabase) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    state = [for (final notif in state) notif.copyWith(isRead: true)];
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('recipient_id', user.id)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Failed to mark all notifications read in database: $e');
    }
  }

  Future<void> dismiss(SupabaseClient supabase, String id) async {
    state = state.where((n) => n.id != id).toList();
    try {
      await supabase.from('notifications').delete().eq('id', id);
    } catch (e) {
      debugPrint('Failed to delete notification in database: $e');
    }
  }

  Future<void> clearAll(SupabaseClient supabase) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    state = [];
    try {
      await supabase.from('notifications').delete().eq('recipient_id', user.id);
    } catch (e) {
      debugPrint('Failed to clear all notifications in database: $e');
    }
  }
}
