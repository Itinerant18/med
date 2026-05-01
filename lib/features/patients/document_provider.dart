import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediflow/core/supabase_client.dart';

class PatientDocument {
  final String url;
  final String storagePath;
  final DateTime? createdAt;

  const PatientDocument({
    required this.url,
    required this.storagePath,
    this.createdAt,
  });
}

class DocumentNotifier
    extends FamilyAsyncNotifier<List<PatientDocument>, String> {
  SupabaseClient get _supabase => ref.read(supabaseClientProvider);

  Future<List<PatientDocument>> _fetchDocuments(String patientId) async {
    final response = await _supabase.retry(() => _supabase
        .from('patient_documents')
        .select('public_url, storage_path, created_at')
        .eq('patient_id', patientId)
        .order('created_at', ascending: false));

    return (response as List)
        .map((row) {
          final map = Map<String, dynamic>.from(row as Map);
          return PatientDocument(
            url: (map['public_url'] ?? '').toString(),
            storagePath: (map['storage_path'] ?? '').toString(),
            createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()),
          );
        })
        .where((doc) => doc.url.isNotEmpty && doc.storagePath.isNotEmpty)
        .toList(growable: false);
  }

  @override
  FutureOr<List<PatientDocument>> build(String arg) async {
    try {
      return _fetchDocuments(arg);
    } catch (e) {
      throw Exception(AppError.getMessage(e));
    }
  }

  Future<void> uploadDocument(XFile file) async {
    final patientId = arg;

    // Check file size (5MB limit)
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      throw Exception('Image too large. Maximum size is 5MB.');
    }

    final path = '$patientId/${DateTime.now().millisecondsSinceEpoch}.jpg';

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        // 1. Upload to Storage
        await _supabase.storage.from('patient-docs').uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );

        // 2. Get Public URL
        final newUrl = _supabase.storage.from('patient-docs').getPublicUrl(path);

        // 3. Save canonical metadata row (single-row insert; no array rewrite).
        await _supabase.retry(() => _supabase.from('patient_documents').insert({
              'patient_id': patientId,
              'public_url': newUrl,
              'storage_path': path,
              'created_at': DateTime.now().toIso8601String(),
            }));

        return _fetchDocuments(patientId);
      } catch (e) {
        throw Exception(AppError.getMessage(e));
      }
    });
  }

  Future<void> deleteDocument(PatientDocument doc) async {
    final patientId = arg;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        // 1. Remove from Storage via canonical saved path (no URL parsing).
        await _supabase.storage.from('patient-docs').remove([doc.storagePath]);

        // 2. Delete single metadata row (no full-array rewrite).
        await _supabase.retry(() => _supabase
            .from('patient_documents')
            .delete()
            .eq('patient_id', patientId)
            .eq('storage_path', doc.storagePath));

        return _fetchDocuments(patientId);
      } catch (e) {
        throw Exception(AppError.getMessage(e));
      }
    });
  }
}

final documentNotifierProvider =
    AsyncNotifierProviderFamily<DocumentNotifier, List<PatientDocument>, String>(
  () => DocumentNotifier(),
);
