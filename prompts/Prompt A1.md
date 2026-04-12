In lib/features/clinical/clinical_entry_screen.dart, replace the Scaffold's bottomSheet property with a Stack-based layout so the form content is visible.

1. Remove the entire `bottomSheet:` property from the Scaffold.
2. Change `body:` to wrap the existing SingleChildScrollView inside a Stack.
3. Add a Positioned button at the bottom of the Stack.

The new body should be:

```dart
body: Stack(
  children: [
    SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildPatientSelector(),
            const SizedBox(height: 20),
            _buildVisitDetailsSection(),
            const SizedBox(height: 20),
            _buildOperationalTrackingSection(),
            const SizedBox(height: 20),
            _buildClinicalNotesSection(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
    Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        color: AppTheme.bgColor,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: SafeArea(
          top: false,
          child: NeuButton(
            onPressed: clinicalState.isLoading ? null : _onCompleteVisit,
            isLoading: clinicalState.isLoading,
            color: AppTheme.primaryTeal,
            child: const Text(
              'COMPLETE VISIT',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    ),
  ],
),
```

Also move `final clinicalState = ref.watch(clinicalNotifierProvider);` to the very top of the build() method, before returning the Scaffold. Remove the bottomSheet: property entirely.
