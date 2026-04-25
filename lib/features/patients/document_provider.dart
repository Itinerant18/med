import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mediflow/core/supabase_client.dart';

class DocumentNotifier extends FamilyAsyncNotifier<List<String>, String> {
  @override
  FutureOr<List<String>> build(String arg) async {
    final supabase = ref.watch(supabaseClientProvider);
    final response = await supabase
        .from('patients')
        .select('document_urls')
        .eq('id', arg)
        .maybeSingle();
    
if (response == null) return const <String>[]; final urls = response['document_urls'] as List?;
    return urls?.map((e) => e.toString()).toList() ?? [];
  }

  Future<void> uploadDocument(XFile file) async {
    final patientId = arg;
    final supabase = ref.read(supabaseClientProvider);
    
    // Check file size (5MB limit)
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      throw Exception('Image too large. Maximum size is 5MB.');
    }

    final path = '$patientId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    // 1. Upload to Storage
    await supabase.storage.from('patient-docs').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(contentType: 'image/jpeg'),
    );

    // 2. Get Public URL
    final newUrl = supabase.storage.from('patient-docs').getPublicUrl(path);

    // 3. Update Patient Table
    final currentUrls = state.value ?? [];
    final updatedUrls = [...currentUrls, newUrl];

    await supabase.from('patients').update({
      'document_urls': updatedUrls,
    }).eq('id', patientId);

    // 4. Update local state
    state = AsyncData(updatedUrls);
  }

  Future<void> deleteDocument(String url) async {
    final patientId = arg;
    final supabase = ref.read(supabaseClientProvider);

    // 1. Extract path from URL
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    // Assuming URL format like .../storage/v1/object/public/patient-docs/patientId/filename.jpg
    final storagePath = pathSegments.skip(pathSegments.indexOf('patient-docs') + 1).join('/');

    // 2. Remove from Storage
    await supabase.storage.from('patient-docs').remove([storagePath]);

    // 3. Update Patient Table
    final currentUrls = state.value ?? [];
    final updatedUrls = currentUrls.where((e) => e != url).toList();

    await supabase.from('patients').update({
      'document_urls': updatedUrls,
    }).eq('id', patientId);

    // 4. Update local state
    state = AsyncData(updatedUrls);
  }
}

final documentNotifierProvider = AsyncNotifierProviderFamily<DocumentNotifier, List<String>, String>(
  () => DocumentNotifier(),
);
