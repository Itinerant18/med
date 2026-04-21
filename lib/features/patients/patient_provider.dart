// lib/features/patients/patient_provider.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediflow/core/supabase_client.dart';
import 'package:mediflow/features/audit/audit_provider.dart';
import 'package:mediflow/features/auth/auth_provider.dart';

final patientProvider = Provider((ref) => PatientService(ref));

/// Provider to fetch a single patient by ID
final patientDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  if (id.isEmpty) throw ArgumentError('Patient ID cannot be empty');
  final supabase = ref.read(supabaseClientProvider);
  final response =
      await supabase.from('patients').select().eq('id', id).maybeSingle();
  return response;
});

class PatientService {
  final Ref _ref;
  PatientService(this._ref);

  SupabaseClient get _supabase => _ref.read(supabaseClientProvider);

  AuthUserState? get _userState => _ref.read(authNotifierProvider).value;

  String get _doctorName => _userState?.doctorName ?? 'Staff';
  String? get _userId => _userState?.session.user.id;

  Future<void> registerPatient(Map<String, dynamic> patientData) async {
    final userId = _userId ?? Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated. Please sign in again.');

    final finalData = {...patientData};
    // Remove null values to avoid unnecessary DB errors
    finalData.removeWhere((key, value) => value == null || value == '');

    finalData['created_by_id'] = userId;
    finalData['last_updated_by'] = _doctorName;
    finalData['last_updated_by_id'] = userId;
    finalData['last_updated_at'] = DateTime.now().toIso8601String();
    finalData['service_status'] = 'pending';
    finalData['created_at'] = DateTime.now().toIso8601String();

    await _supabase.from('patients').insert(finalData);

    await AuditService.log(
      ref: _ref,
      action: 'INSERT',
      targetTable: 'patients',
      description:
          'Patient registered: ${finalData['full_name'] ?? 'Unknown Patient'}',
      newData: Map<String, dynamic>.from(finalData),
    );
  }

  Future<void> updatePatient(
      String id, Map<String, dynamic> patientData) async {
    final existing = await _supabase
        .from('patients')
        .select()
        .eq('id', id)
        .maybeSingle();

    final finalData = {
      ...patientData,
      'last_updated_by': _doctorName,
      'last_updated_by_id': _userId,
      'last_updated_at': DateTime.now().toIso8601String(),
    };

    // Remove null values
    finalData.removeWhere((key, value) => value == null);

    await _supabase.from('patients').update(finalData).eq('id', id);

    final patientName = (finalData['full_name'] ??
            existing?['full_name'] ??
            'Unknown Patient')
        .toString();
    final oldStatus = existing?['service_status']?.toString();
    final newStatus = patientData['service_status']?.toString();
    final ownerId = existing?['created_by_id']?.toString();

    if (newStatus != null && newStatus != oldStatus) {
      unawaited(
        _triggerStatusNotification(
          patientId: id,
          patientName: patientName,
          oldStatus: oldStatus,
          newStatus: newStatus,
          ownerId: ownerId,
        ),
      );
    }

    await AuditService.log(
      ref: _ref,
      action: 'UPDATE',
      targetTable: 'patients',
      targetId: id,
      description: 'Patient updated: $patientName',
      oldData: existing == null ? null : Map<String, dynamic>.from(existing),
      newData: {
        ...(existing == null ? <String, dynamic>{} : Map<String, dynamic>.from(existing)),
        ...finalData,
      },
    );
  }

  Future<void> deletePatient(String id) async {
    if (id.isEmpty) throw ArgumentError('Patient ID cannot be empty');
    final existing = await _supabase
        .from('patients')
        .select()
        .eq('id', id)
        .maybeSingle();
    await _supabase.from('patients').delete().eq('id', id);

    final patientName =
        (existing?['full_name'] ?? 'Unknown Patient').toString();

    await AuditService.log(
      ref: _ref,
      action: 'DELETE',
      targetTable: 'patients',
      targetId: id,
      description: 'Patient deleted: $patientName',
      oldData: existing == null ? null : Map<String, dynamic>.from(existing),
    );
  }

  Future<List<Map<String, dynamic>>> searchPatients(String query,
      {int limit = 10}) async {
    if (query.trim().length < 2) return [];
    
    final response = await _supabase
        .from('patients')
        .select('id, full_name, date_of_birth, phone')
        .ilike('full_name', '%${query.trim()}%')
        .limit(limit);
    
    return List<Map<String, dynamic>>.from(response);
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
    } catch (_) {
      // Best-effort only. Patient updates should not fail if notification fails.
    }
  }
}
