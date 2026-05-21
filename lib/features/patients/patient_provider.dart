// lib/features/patients/patient_provider.dart
//
// AsyncNotifier-based patient CRUD provider. Exposes AsyncValue<void> so
// screens can use .when() / .isLoading / .hasError to react to mutation
// state without manual try/catch + setState boilerplate.
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/cache_service.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/sync_queue.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/core/audit_service.dart';
import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/models/patient_model.dart';

final patientProvider =
    AsyncNotifierProvider<PatientNotifier, void>(PatientNotifier.new);

const _patientDetailSelectFull =
    'id, full_name, phone, email, date_of_birth, gender, blood_group, symptoms, '
    'area_affected, existing_conditions, current_medications, allergies, addictions, '
    'health_scheme, address, referred_by, investigation_place, investigation_status, '
    'staff_comments, created_at, last_updated_at, service_status, is_high_priority, '
    'last_updated_by, created_by_id, emergency_contact_number, assigned_doctor_id';

const _patientDetailSelectCompat =
    'id, full_name, phone, email, date_of_birth, gender, blood_group, symptoms, '
    'area_affected, existing_conditions, current_medications, allergies, addictions, '
    'health_scheme, address, referred_by, investigation_place, investigation_status, '
    'staff_comments, created_at, last_updated_at, service_status, is_high_priority, '
    'last_updated_by, created_by_id, emergency_contact_number';

/// Provider to fetch a single patient by ID.
final patientDetailProvider =
    FutureProvider.family<PatientModel?, String>((ref, id) async {
  if (id.isEmpty) throw ArgumentError('Patient ID cannot be empty');
  final supabase = ref.read(supabaseClientProvider);
  final cacheKey = 'patient_detail_$id';

  PatientModel? fromCache() {
    final cached =
        CacheService.instance.getRaw(cacheKey) as Map<String, dynamic>?;
    return cached != null ? PatientModel.fromJson(cached) : null;
  }

  try {
    final response = await supabase.retry(() => supabase
        .from('patients')
        .select(_patientDetailSelectFull)
        .eq('id', id)
        .maybeSingle());
    if (response == null) return null;
    CacheService.instance
        .putRaw(cacheKey, Map<String, dynamic>.from(response),
            ttl: const Duration(minutes: 30))
        .ignore();
    return PatientModel.fromJson(Map<String, dynamic>.from(response));
  } on PostgrestException catch (e) {
    // assigned_doctor_id column may not exist yet if the migration hasn't run.
    // Fall back to the compat select so the rest of the screen still loads.
    if (e.code == '42703' ||
        (e.message.toLowerCase().contains('assigned_doctor_id'))) {
      try {
        final fallback = await supabase.retry(() => supabase
            .from('patients')
            .select(_patientDetailSelectCompat)
            .eq('id', id)
            .maybeSingle());
        if (fallback == null) return null;
        CacheService.instance
            .putRaw(cacheKey, Map<String, dynamic>.from(fallback),
                ttl: const Duration(minutes: 30))
            .ignore();
        return PatientModel.fromJson(Map<String, dynamic>.from(fallback));
      } catch (fallbackError) {
        return fromCache() ??
            (throw Exception(AppError.getMessage(fallbackError)));
      }
    }
    return fromCache() ?? (throw Exception(AppError.getMessage(e)));
  } catch (e) {
    return fromCache() ?? (throw Exception(AppError.getMessage(e)));
  }
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
    final userId = _userId ?? Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated. Please sign in again.');

    final finalData = {...patientData};
    finalData.removeWhere((key, value) => value == null || value == '');
    finalData['created_by_id'] = userId;
    finalData['last_updated_by'] = _doctorName;
    finalData['last_updated_by_id'] = userId;
    finalData['last_updated_at'] = DateTime.now().toIso8601String();
    finalData['service_status'] ??= 'pending';
    finalData['created_at'] = DateTime.now().toIso8601String();

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      final tempId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
      finalData['id'] = tempId;
      await SyncQueue.instance.enqueue(SyncAction(
        id: tempId,
        table: 'patients',
        operation: SyncOperation.insert,
        data: finalData,
        timestamp: DateTime.now(),
        retryCount: 0,
      ));
      return tempId;
    }

    state = const AsyncLoading();
    String newId = '';
    state = await AsyncValue.guard(() async {
      try {
        final response = await _supabase.retry(() => _supabase
            .from('patients')
            .insert(finalData)
            .select('id')
            .single());

        newId = response['id'].toString();

        unawaited(
          AuditService.instance.logFromAuth(
            ref: ref,
            action: 'INSERT',
            targetTable: 'patients',
            description:
                'Patient registered: ${finalData['full_name'] ?? 'Unknown Patient'}',
            newData: Map<String, dynamic>.from(finalData),
          ).catchError((e) {
            debugPrint('Audit log failed silently: $e');
          }),
        );
      } catch (e) {
        throw Exception(AppError.getMessage(e));
      }
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

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      final finalData = {
        ...patientData,
        'last_updated_by': _doctorName,
        'last_updated_by_id': _userId,
        'last_updated_at': DateTime.now().toIso8601String(),
      };
      finalData.removeWhere((key, value) => value == null);
      await SyncQueue.instance.enqueue(SyncAction(
        id: 'offline_${DateTime.now().millisecondsSinceEpoch}',
        table: 'patients',
        operation: SyncOperation.update,
        data: finalData,
        matchColumn: 'id',
        matchValue: id,
        timestamp: DateTime.now(),
        retryCount: 0,
      ));
      CacheService.instance.invalidate('patient_detail_$id').ignore();
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        Map<String, dynamic>? existing;
        try {
          existing = await _supabase.retry(() => _supabase
              .from('patients')
              .select()
              .eq('id', id)
              .maybeSingle());
        } catch (e) {
          throw Exception('Unable to load patient: ${AppError.getMessage(e)}');
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

        await _supabase.retry(() => _supabase.from('patients').update(finalData).eq('id', id));

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

        unawaited(
          AuditService.instance.logFromAuth(
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
          ).catchError((e) {
            debugPrint('Audit log failed silently: $e');
          }),
        );
      } catch (e) {
        throw Exception(AppError.getMessage(e));
      }
    });

    if (state.hasError) throw state.error!;
  }

  // ── Delete ──────────────────────────────────────────────────────────────

  Future<void> deletePatient(String id) async {
    if (id.isEmpty) throw ArgumentError('Patient ID cannot be empty');

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      throw Exception(
          'Cannot delete patient while offline. Please try again when connected.');
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        Map<String, dynamic>? existing;
        try {
          existing = await _supabase.retry(() => _supabase
              .from('patients')
              .select()
              .eq('id', id)
              .maybeSingle());
        } catch (e) {
          throw Exception('Unable to load patient: ${AppError.getMessage(e)}');
        }

        if (existing == null) {
          throw Exception(
            'Patient not found or you do not have permission to delete it.',
          );
        }

        await _cleanupPatientStorage(id, existing);
        await _supabase.retry(() => _supabase.from('patients').delete().eq('id', id));

        final patientName =
            (existing['full_name'] ?? 'Unknown Patient').toString();

        unawaited(
          AuditService.instance.logFromAuth(
            ref: ref,
            action: 'DELETE',
            targetTable: 'patients',
            targetId: id,
            description: 'Patient deleted: $patientName',
            oldData: Map<String, dynamic>.from(existing),
          ).catchError((e) {
            debugPrint('Audit log failed silently: $e');
          }),
        );
      } catch (e) {
        throw Exception(AppError.getMessage(e));
      }
    });

    if (state.hasError) throw state.error!;
  }

  // ── Search ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> searchPatients(
    String query, {
    int limit = 10,
  }) async {
    if (query.trim().length < 2) return [];

    try {
      final response = await _supabase.retry(() => _supabase
          .from('patients')
          .select('id, full_name, date_of_birth, phone')
          .ilike('full_name', '%${query.trim()}%')
          .limit(limit));

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Patient search failed: $e');
      
      final userState = ref.read(authNotifierProvider).value;
      if (userState != null) {
        final cacheKey = 'patients_${userState.role.name}_${userState.session.user.id}';
        final cached = CacheService.instance.getRaw(cacheKey);
        if (cached != null) {
          final queryLower = query.trim().toLowerCase();
          final List<Map<String, dynamic>> results = [];
          for (final row in cached as List) {
            final fullName = row['full_name']?.toString() ?? '';
            if (fullName.toLowerCase().contains(queryLower)) {
              results.add({
                'id': row['id'],
                'full_name': row['full_name'],
                'date_of_birth': row['date_of_birth'],
                'phone': row['phone'],
              });
              if (results.length >= limit) break;
            }
          }
          return results;
        }
      }
      
      // Return empty list on error for better UX in search fields.
      return [];
    }
  }

  // ── Private helpers ─────────────────────────────────────────────────────

  Future<void> _cleanupPatientStorage(
    String patientId,
    Map<String, dynamic> existing,
  ) async {
    try {
      // Preferred path: canonical storage metadata table.
      final docs = await _supabase
          .from('patient_documents')
          .select('storage_path')
          .eq('patient_id', patientId);
      final canonicalPaths = (docs as List)
          .map((e) => (e as Map)['storage_path']?.toString() ?? '')
          .where((p) => p.isNotEmpty)
          .toList(growable: false);
      if (canonicalPaths.isNotEmpty) {
        await _supabase.storage.from('patient-docs').remove(canonicalPaths);
        await _supabase
            .from('patient_documents')
            .delete()
            .eq('patient_id', patientId);
        return;
      }

      // Legacy fallback: parse URLs when old metadata is all we have.
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
    try {
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
    } catch (e) {
      debugPrint('Failed to trigger status notification: $e');
    }
  }
}
