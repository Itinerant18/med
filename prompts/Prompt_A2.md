In lib/features/clinical/clinical_entry_screen.dart, inside the \_onCompleteVisit() method, find this block:

```dart
} else {
  AppSnackbar.showSuccess(context, 'Visit saved successfully');
  _resetForm();
}
```

Replace it with:

```dart
} else {
  AppSnackbar.showSuccess(context, 'Visit saved successfully');
  if (widget.patientId != null) {
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) Navigator.of(context).pop();
  } else {
    _resetForm();
  }
}
```

This makes the screen navigate back to PatientDetailScreen after saving when accessed via the "New Visit" FAB, while keeping the reset-form behaviour for the standalone Clinical tab.
