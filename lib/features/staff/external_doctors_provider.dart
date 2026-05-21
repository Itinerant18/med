import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/core/sync_queue.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@immutable
class ExternalDoctor {
  const ExternalDoctor({
    required this.id,
    required this.name,
    this.specialization,
    this.hospital,
    this.phone,
    this.email,
    this.addedBy,
    this.createdAt,
    this.fromHistory = false,
  });

  final String id;
  final String name;
  final String? specialization;
  final String? hospital;
  final String? phone;
  final String? email;
  final String? addedBy;
  final DateTime? createdAt;
  // True when sourced from known_external_doctors view (agent visit history)
  // rather than an explicit entry in the external_doctors table.
  final bool fromHistory;

  factory ExternalDoctor.fromJson(Map<String, dynamic> json) {
    return ExternalDoctor(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      specialization: json['specialization']?.toString(),
      hospital: json['hospital']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      addedBy: json['added_by']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  factory ExternalDoctor.fromHistoryJson(Map<String, dynamic> json) {
    return ExternalDoctor(
      id: 'history_${json['ext_doctor_name']?.toString() ?? ''}',
      name: json['ext_doctor_name']?.toString() ?? '',
      specialization: json['ext_doctor_specialization']?.toString(),
      hospital: json['ext_doctor_hospital']?.toString(),
      phone: json['ext_doctor_phone']?.toString(),
      fromHistory: true,
    );
  }
}

final externalDoctorsProvider =
    AsyncNotifierProvider<ExternalDoctorsNotifier, List<ExternalDoctor>>(
        ExternalDoctorsNotifier.new);

class ExternalDoctorsNotifier extends AsyncNotifier<List<ExternalDoctor>> {
  SupabaseClient get _supabase => ref.read(supabaseClientProvider);

  @override
  Future<List<ExternalDoctor>> build() async {
    final supabase = ref.read(supabaseClientProvider);

    // Subscribe before fetching so no INSERT that arrives during the initial
    // network round-trip is missed.
    final channel = supabase
        .channel('directory_live')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'agent_outside_visits',
          callback: (payload) {
            final name =
                payload.newRecord['ext_doctor_name']?.toString() ?? '';
            if (name.isNotEmpty) refresh();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'agent_outside_visits',
          callback: (_) => refresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'external_doctors',
          callback: (_) => refresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'external_doctors',
          callback: (_) => refresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'external_doctors',
          callback: (_) => refresh(),
        )
        .subscribe();

    ref.onDispose(channel.unsubscribe);

    return _fetch();
  }

  Future<List<ExternalDoctor>> _fetch() async {
    // Explicit entries added via the Directory form.
    final explicitResponse = await _supabase.retry(
      () => _supabase.from('external_doctors').select().order('name'),
    );
    final explicitList = (explicitResponse as List)
        .map((json) =>
            ExternalDoctor.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();

    // History entries derived from agent outside-visit records.
    // Non-fatal: if the view is unavailable we still show explicit entries.
    final historyList = <ExternalDoctor>[];
    try {
      final historyResponse = await _supabase.retry(
        () => _supabase.from('known_external_doctors').select(),
      );
      final explicitNamesLower =
          explicitList.map((d) => d.name.toLowerCase()).toSet();
      for (final row in historyResponse as List) {
        final entry = ExternalDoctor.fromHistoryJson(
            Map<String, dynamic>.from(row as Map));
        if (entry.name.isNotEmpty &&
            !explicitNamesLower.contains(entry.name.toLowerCase())) {
          historyList.add(entry);
        }
      }
    } catch (_) {
      // View unavailable — proceed with explicit list only.
    }

    final merged = [...explicitList, ...historyList]
      ..sort((a, b) => a.name.compareTo(b.name));
    return merged;
  }

  Future<void> updateDoctor({
    required String id,
    required String name,
    String? specialization,
    String? hospital,
    String? phone,
    String? email,
  }) async {
    String? trim(String? v) => v?.trim().isEmpty == true ? null : v?.trim();
    final payload = <String, dynamic>{
      'name': name.trim(),
      'specialization': trim(specialization),
      'hospital': trim(hospital),
      'phone': trim(phone),
      'email': trim(email),
    };
    try {
      await _supabase.retry(
        () => _supabase.from('external_doctors').update(payload).eq('id', id),
      );
      state = await AsyncValue.guard(_fetch);
      if (state.hasError) throw state.error!;
    } catch (e) {
      throw Exception(AppError.getMessage(e));
    }
  }

  Future<void> delete(String id) async {
    try {
      await _supabase.retry(
        () => _supabase.from('external_doctors').delete().eq('id', id),
      );
      // Optimistic removal so the UI responds immediately.
      final current = state.valueOrNull ?? [];
      state = AsyncData(current.where((d) => d.id != id).toList());
    } catch (e) {
      throw Exception(AppError.getMessage(e));
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> add({
    required String name,
    String? specialization,
    String? hospital,
    String? phone,
    String? email,
  }) async {
    final userState = ref.read(authNotifierProvider).valueOrNull;
    if (userState == null) throw Exception('Not authenticated');

    final trimmedName = name.trim();
    final payload = <String, dynamic>{
      'name': trimmedName,
      'added_by': userState.session.user.id,
      if (specialization?.trim().isNotEmpty == true)
        'specialization': specialization!.trim(),
      if (hospital?.trim().isNotEmpty == true) 'hospital': hospital!.trim(),
      if (phone?.trim().isNotEmpty == true) 'phone': phone!.trim(),
      if (email?.trim().isNotEmpty == true) 'email': email!.trim(),
    };

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      final tempId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
      await SyncQueue.instance.enqueue(SyncAction(
        id: tempId,
        table: 'external_doctors',
        operation: SyncOperation.insert,
        data: payload,
        timestamp: DateTime.now(),
        retryCount: 0,
      ));
      final optimistic = ExternalDoctor(
        id: tempId,
        name: trimmedName,
        specialization: specialization?.trim(),
        hospital: hospital?.trim(),
        phone: phone?.trim(),
        email: email?.trim(),
        addedBy: userState.session.user.id,
        createdAt: DateTime.now(),
      );
      final updated = List<ExternalDoctor>.from(state.valueOrNull ?? [])
        ..add(optimistic)
        ..sort((a, b) => a.name.compareTo(b.name));
      state = AsyncData(updated);
      return;
    }

    try {
      await _supabase.retry(
        () => _supabase.from('external_doctors').insert(payload),
      );
      state = await AsyncValue.guard(_fetch);
      if (state.hasError) throw state.error!;
    } catch (e) {
      throw Exception(AppError.getMessage(e));
    }
  }
}
