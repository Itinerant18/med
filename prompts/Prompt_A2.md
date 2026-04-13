In lib/features/clinical/clinical_provider.dart, the `clinicalPatientSearchProvider` uses `created_by_id` but only for assistants. This is correct — keep it. However the field name used is `created_by_id` which matches the patients table column. Verify the query is:

```dart
final clinicalPatientSearchProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final query = ref.watch(patientSearchQueryProvider);
  if (query.trim().length < 2) return [];
  final supabase = ref.watch(supabaseClientProvider);
  final userState = ref.watch(authNotifierProvider).value;

  var dbQuery = supabase
      .from('patients')
      .select('id, full_name, date_of_birth')
      .ilike('full_name', '%$query%');

  // Assistants only search within their own patients (RLS also enforces this)
  if (userState != null && userState.role == UserRole.assistant) {
    dbQuery = dbQuery.eq('created_by_id', userState.session.user.id);
  }

  final response = await dbQuery.limit(8);
  return List<Map<String, dynamic>>.from(response);
});
```

No other changes needed in this file.
