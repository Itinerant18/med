In lib/features/clinical/clinical_entry_screen.dart, update initState() to reset the search provider when the screen is opened as a standalone tab (no patientId):

Replace the existing initState() with:

```dart
@override
void initState() {
  super.initState();
  if (widget.patientId != null) {
    _selectedPatientId = widget.patientId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadPatientInfo();
    });
  } else {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(patientSearchQueryProvider.notifier).state = '';
        _searchController.clear();
      }
    });
  }
}
```
