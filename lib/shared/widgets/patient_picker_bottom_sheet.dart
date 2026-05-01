// lib/shared/widgets/patient_picker_bottom_sheet.dart
//
// Single, shared patient picker bottom sheet.  Replaces three private
// _PatientPickerSheet copies that lived in add_followup_sheet.dart,
// dr_visit_form.dart, and agent_outside_visit_form.dart.
//
// Usage:
//   showModalBottomSheet(
//     ...
//     builder: (_) => PatientPickerBottomSheet(
//       onSelected: (id, name) { ... },
//     ),
//   );
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/features/patients/patient_list_provider.dart';
import 'package:mediflow/models/patient_model.dart';
import 'package:mediflow/shared/widgets/empty_state.dart';
import 'package:mediflow/shared/widgets/error_boundary.dart';

/// Bottom sheet that lets the user search and pick a patient.
///
/// Returns the result via [onSelected] callback with `(id, name)` or pops
/// with a `Map {'id': ..., 'name': ...}` if no callback is provided (for
/// callers that use `.then(result)`).
class PatientPickerBottomSheet extends ConsumerStatefulWidget {
  const PatientPickerBottomSheet({
    super.key,
    this.title = 'Select Patient',
    this.searchLabel = 'Search Patient',
    this.emptyText = 'No patients found',
    this.onSelected,
  });

  /// Sheet header text.
  final String title;

  /// Label on the search field.
  final String searchLabel;

  /// Text shown when the list is empty.
  final String emptyText;

  /// Optional callback — if provided, called instead of `Navigator.pop`.
  /// The caller is responsible for closing the sheet.
  final void Function(String id, String name)? onSelected;

  @override
  ConsumerState<PatientPickerBottomSheet> createState() =>
      _PatientPickerBottomSheetState();
}

class _PatientPickerBottomSheetState
    extends ConsumerState<PatientPickerBottomSheet> {
  String _query = '';

  void _pick(PatientModel patient) {
    final id = patient.id;
    final name = patient.fullName;
    if (widget.onSelected != null) {
      widget.onSelected!(id, name);
    } else {
      Navigator.pop(context, {'id': id, 'name': name});
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(roleAwarePatientsProvider(SearchFilter(
      query: _query,
      healthScheme: HealthSchemeFilter.all,
      priority: PriorityFilter.all,
      dateRange: DateRangeFilter.allTime,
      visitType: VisitTypeFilter.all,
      sortOption: SortOption.nameAsc,
    )));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              NeuTextField(
                label: widget.searchLabel,
                prefixIcon: const Icon(AppIcons.search),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: patientsAsync.whenWithBoundary(
                  contextLabel: 'patient_picker',
                  errorTitle: 'Failed to load patients',
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  data: (patients) {
                    if (patients.isEmpty) {
                      return EmptyState(
                        icon: AppIcons.person_search_rounded,
                        title: widget.emptyText,
                        compact: true,
                      );
                    }
                    return ListView.builder(
                      itemCount: patients.length,
                      itemBuilder: (_, i) {
                        final p = patients[i];
                        return ListTile(
                          title: Text(
                            p.fullName.isEmpty ? 'Unknown' : p.fullName,
                          ),
                          subtitle: Text(p.phone ?? ''),
                          onTap: () => _pick(p),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
