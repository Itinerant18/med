// lib/features/patients/patient_provider.dart
//
// AsyncNotifier-based patient CRUD provider. Exposes AsyncValue<void> so
// screens can use .when() / .isLoading / .hasError to react to mutation
// state without manual try/catch + setState boilerplate.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/features/audit/audit_provider.dart';
import 'package:mediflow/features/auth/auth_provider.dart';

final patientProvider =
    AsyncNotifierProvider<PatientNotifier, void>(PatientNotifier.new);

/// Provider to fetch a single patient by ID.
final patientDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  if (id.isEmpty) throw ArgumentError('Patient ID cannot be empty');
  final supabase = ref.read(supabaseClientProvider);
  final response =
      await supabase.from('patients').select().eq('id', id).maybeSingle();
  return response;
});

class PatientNotifier extends AsyncNotifier<void> {
  SupabaseClient get _supabase => ref.read(supabaseClientProvider);

  AuthUserState? get _userState => ref.read(authNotifierProvider).value;

  String get _doctorName => _userState?.doctorName ?? 'Staff';
  String? get _userId => _userState?.session.user.id;

  @override
  Future<void> build() async {
    // No initial state to load — this notifier only tracks mutation status.
  }

  // ── Register ────────────────────────────────────────────────────────────

  /// Creates a new patient row and returns its ID.
  ///
  /// Sets [state] to [AsyncLoading] then [AsyncData]/[AsyncError] so
  /// watchers get automatic loading/error feedback.
  Future<String> registerPatient(Map<String, dynamic> patientData) async {
    state = const AsyncLoading();
    String newId = '';
    state = await AsyncValue.guard(() async {
      final userId = _userId ?? Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Not authenticated. Please sign in again.');
      }

      final finalData = {...patientData};
      finalData.removeWhere((key, value) => value == null || value == '');

      finalData['created_by_id'] = userId;
      finalData['last_updated_by'] = _doctorName;
      finalData['last_updated_by_id'] = userId;
      finalData['last_updated_at'] = DateTime.now().toIso8601String();
      finalData['service_status'] = 'pending';
      finalData['created_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('patients')
          .insert(finalData)
          .select('id')
          .single();

      newId = response['id'].toString();

      await AuditService.instance.logFromAuth(
        ref: ref,
        action: 'INSERT',
        targetTable: 'patients',
        description:
            'Patient registered: ${finalData['full_name'] ?? 'Unknown Patient'}',
        newData: Map<String, dynamic>.from(finalData),
      );
    });

    // Re-throw so imperative callers still see the error.
    if (state.hasError) throw state.error!;
    return newId;
  }

  // ── Update ──────────────────────────────────────────────────────────────

  Future<void> updatePatient(
    String id,
    Map<String, dynamic> patientData,
  ) async {
    if (id.isEmpty) throw ArgumentError('Patient ID cannot be empty');

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      Map<String, dynamic>? existing;
      try {
        existing = await _supabase
            .from('patients')
            .select()
            .eq('id', id)
            .maybeSingle();
      } catch (e) {
        throw Exception('Unable to load patient: $e');
      }

      if (existing == null) {
        throw Exception(
          'Patient not found or you do not have permission to edit it.',
        );
      }

      final finalData = {
        ...patientData,
        'last_updated_by': _doctorName,
        'last_updated_by_id': _userId,
        'last_updated_at': DateTime.now().toIso8601String(),
      };
      finalData.removeWhere((key, value) => value == null);

      await _supabase.from('patients').update(finalData).eq('id', id);

      final patientName =
          (finalData['full_name'] ?? existing['full_name'] ?? 'Unknown Patient')
              .toString();
      final oldStatus = existing['service_status']?.toString();
      final newStatus = patientData['service_status']?.toString();
      final ownerId = existing['created_by_id']?.toString();

      if (newStatus != null && newStatus != oldStatus) {
        unawaited(
          _triggerStatusNotification(
            patientId: id,
            patientName: patientName,
            oldStatus: oldStatus,
            newStatus: newStatus,
            ownerId: ownerId,
          ).catchError((error, stackTrace) {
            debugPrint('patient status notification failed: $error');
          }),
        );
      }

      await AuditService.instance.logFromAuth(
        ref: ref,
        action: 'UPDATE',
        targetTable: 'patients',
        targetId: id,
        description: 'Patient updated: $patientName',
        oldData: Map<String, dynamic>.from(existing),
        newData: {
          ...Map<String, dynamic>.from(existing),
          ...finalData,
        },
      );
    });

    if (state.hasError) throw state.error!;
  }

  // ── Delete ──────────────────────────────────────────────────────────────

  Future<void> deletePatient(String id) async {
    if (id.isEmpty) throw ArgumentError('Patient ID cannot be empty');

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      Map<String, dynamic>? existing;
      try {
        existing = await _supabase
            .from('patients')
            .select()
            .eq('id', id)
            .maybeSingle();
      } catch (e) {
        throw Exception('Unable to load patient: $e');
      }

      if (existing == null) {
        throw Exception(
          'Patient not found or you do not have permission to delete it.',
        );
      }

      await _cleanupPatientStorage(id, existing);
      await _supabase.from('patients').delete().eq('id', id);

      final patientName =
          (existing['full_name'] ?? 'Unknown Patient').toString();

      await AuditService.instance.logFromAuth(
        ref: ref,
        action: 'DELETE',
        targetTable: 'patients',
        targetId: id,
        description: 'Patient deleted: $patientName',
        oldData: Map<String, dynamic>.from(existing),
      );
    });

    if (state.hasError) throw state.error!;
  }

  // ── Search ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> searchPatients(
    String query, {
    int limit = 10,
  }) async {
    if (query.trim().length < 2) return [];

    final response = await _supabase
        .from('patients')
        .select('id, full_name, date_of_birth, phone')
        .ilike('full_name', '%${query.trim()}%')
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  // ── Private helpers ─────────────────────────────────────────────────────

  Future<void> _cleanupPatientStorage(
    String patientId,
    Map<String, dynamic> existing,
  ) async {
    try {
      final urls = (existing['document_urls'] as List?)
              ?.map((u) => u?.toString() ?? '')
              .where((u) => u.isNotEmpty)
              .toList() ??
          const <String>[];

      final paths = <String>[];
      const marker = '/patient-docs/';
      for (final url in urls) {
        final idx = url.indexOf(marker);
        if (idx != -1) paths.add(url.substring(idx + marker.length));
      }

      if (paths.isNotEmpty) {
        await _supabase.storage.from('patient-docs').remove(paths);
        return;
      }

      final listed =
          await _supabase.storage.from('patient-docs').list(path: patientId);
      if (listed.isNotEmpty) {
        final toRemove =
            listed.map((e) => '$patientId/${e.name}').toList(growable: false);
        await _supabase.storage.from('patient-docs').remove(toRemove);
      }
    } catch (e) {
      debugPrint('patient storage cleanup failed: $e');
    }
  }

  Future<void> _triggerStatusNotification({
    required String patientId,
    required String patientName,
    required String? oldStatus,
    required String newStatus,
    required String? ownerId,
  }) async {
    await _supabase.functions.invoke(
      'notify-status-change',
      body: {
        'patientId': patientId,
        'patientName': patientName,
        'oldStatus': oldStatus,
        'newStatus': newStatus,
        'updaterId': _userId,
        'ownerId': ownerId,
      },
    );
  }
}
