import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/staff/external_doctors_provider.dart';

const List<String> westBengalDistricts = [
  'Alipurduar',
  'Bankura',
  'Birbhum',
  'Cooch Behar',
  'Dakshin Dinajpur',
  'Darjeeling',
  'Hooghly',
  'Howrah',
  'Jalpaiguri',
  'Jhargram',
  'Kalimpong',
  'Kolkata',
  'Malda',
  'Murshidabad',
  'Nadia',
  'North 24 Parganas',
  'Paschim Bardhaman',
  'Paschim Medinipur',
  'Purba Bardhaman',
  'Purba Medinipur',
  'Purulia',
  'South 24 Parganas',
  'Uttar Dinajpur',
];

class ExternalDoctorPickerSheet extends ConsumerStatefulWidget {
  /// Called with the selected (or newly created) doctor.
  final void Function(ExternalDoctor doctor) onSelected;

  const ExternalDoctorPickerSheet({super.key, required this.onSelected});

  @override
  ConsumerState<ExternalDoctorPickerSheet> createState() =>
      _ExternalDoctorPickerSheetState();
}

class _ExternalDoctorPickerSheetState
    extends ConsumerState<ExternalDoctorPickerSheet> {
  // ── search mode ──
  final _searchCtrl = TextEditingController();
  String _query = '';

  // ── add-new mode ──
  bool _isAddingNew = false;
  final _addFormKey = GlobalKey<FormState>();
  final _addNameCtrl = TextEditingController();
  final _addSpecCtrl = TextEditingController();
  final _addHospCtrl = TextEditingController();
  final _addPhoneCtrl = TextEditingController();
  final _addEmailCtrl = TextEditingController();
  String? _addAreaDistrict;
  String? _addMeetDrType;
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _addNameCtrl.dispose();
    _addSpecCtrl.dispose();
    _addHospCtrl.dispose();
    _addPhoneCtrl.dispose();
    _addEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveNewDoctor() async {
    if (!(_addFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await ref.read(externalDoctorsProvider.notifier).add(
            name: _addNameCtrl.text.trim(),
            specialization: _addSpecCtrl.text.trim(),
            hospital: _addHospCtrl.text.trim(),
            phone: _addPhoneCtrl.text.trim(),
            email: _addEmailCtrl.text.trim(),
            areaDistrict: _addAreaDistrict,
            meetDrType: _addMeetDrType,
          );
      // Find the newly added doctor in the refreshed list and pass it back.
      final doctors = ref.read(externalDoctorsProvider).valueOrNull ?? [];
      final nameLower = _addNameCtrl.text.trim().toLowerCase();
      ExternalDoctor? added;
      try {
        added = doctors.firstWhere((d) => d.name.toLowerCase() == nameLower);
      } catch (_) {
        // Fallback: build a transient object so the visit form still fills.
        added = ExternalDoctor(
          id: 'new_${DateTime.now().millisecondsSinceEpoch}',
          name: _addNameCtrl.text.trim(),
          specialization: _addSpecCtrl.text.trim().isEmpty
              ? null
              : _addSpecCtrl.text.trim(),
          hospital:
              _addHospCtrl.text.trim().isEmpty ? null : _addHospCtrl.text.trim(),
          phone:
              _addPhoneCtrl.text.trim().isEmpty ? null : _addPhoneCtrl.text.trim(),
          areaDistrict: _addAreaDistrict,
          meetDrType: _addMeetDrType,
        );
      }
      if (mounted) widget.onSelected(added);
    } catch (e) {
      if (mounted) setState(() => _saveError = AppError.getMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: _isAddingNew ? 0.75 : 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // ── Handle bar ──
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // ── Header ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (_isAddingNew)
                    IconButton(
                      icon: const Icon(AppIcons.arrow_back_ios_rounded,
                          size: 16, color: AppTheme.textMuted),
                      tooltip: 'Back to search',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() {
                        _isAddingNew = false;
                        _saveError = null;
                      }),
                    ),
                  if (_isAddingNew) const SizedBox(width: 8),
                  Text(
                    _isAddingNew ? 'Add New Doctor' : 'Select External Doctor',
                    style:
                        AppTheme.bodyFont(size: 16, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // ── Body ──
            Expanded(
              child: _isAddingNew
                  ? _buildAddForm(scrollController)
                  : _buildSearchList(scrollController),
            ),
            // ── Fixed footer: "Add new doctor" button (search mode only) ──
            if (!_isAddingNew)
              SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _isAddingNew = true),
                      icon: const Icon(AppIcons.add_rounded, size: 16),
                      label: const Text('Add new doctor to directory'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryTeal,
                        side: const BorderSide(color: AppTheme.primaryTeal),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSearchList(ScrollController scrollController) {
    final directoryAsync = ref.watch(externalDoctorsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search by name or hospital...',
              prefixIcon: const Icon(AppIcons.search_rounded, size: 16),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(AppIcons.clear_rounded, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (v) =>
                setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: directoryAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load directory.\nYou can still add a new doctor below.',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyFont(
                      size: 13, color: AppTheme.textMuted),
                ),
              ),
            ),
            data: (doctors) {
              final filtered = _query.isEmpty
                  ? doctors
                  : doctors
                      .where((d) =>
                          d.name.toLowerCase().contains(_query) ||
                          (d.hospital
                                  ?.toLowerCase()
                                  .contains(_query) ??
                              false))
                      .toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _query.isEmpty
                          ? 'No doctors in directory yet.\nUse the button below to add one.'
                          : 'No match for "$_query".\nUse the button below to add them.',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodyFont(
                          size: 13, color: AppTheme.textMuted),
                    ),
                  ),
                );
              }

              return ListView.builder(
                controller: scrollController,
                itemCount: filtered.length,
                itemBuilder: (context, index) => DoctorPickerTile(
                  doctor: filtered[index],
                  onTap: () => widget.onSelected(filtered[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddForm(ScrollController scrollController) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _addFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NeuTextField(
              controller: _addNameCtrl,
              label: 'Doctor Name *',
              hint: 'Dr. Full Name',
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            NeuTextField(
              controller: _addSpecCtrl,
              label: 'Specialization',
              hint: 'e.g. Cardiology, Orthopedics',
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            NeuTextField(
              controller: _addHospCtrl,
              label: 'Hospital / Clinic',
              hint: 'Hospital or clinic name',
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            NeuTextField(
              controller: _addPhoneCtrl,
              label: 'Phone',
              hint: 'Contact number',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            NeuTextField(
              controller: _addEmailCtrl,
              label: 'Email',
              hint: 'Email address',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _addAreaDistrict,
              decoration: const InputDecoration(
                labelText: 'Area (District)',
                hintText: 'Select district',
              ),
              items: westBengalDistricts
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) => setState(() => _addAreaDistrict = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _addMeetDrType,
              decoration: const InputDecoration(
                labelText: 'Type of Doctor',
                hintText: 'Select doctor type',
              ),
              items: ['Dental', 'ENT', 'General Surgeon', 'GP', 'RMP', 'MDS']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _addMeetDrType = v),
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.errorColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(AppIcons.error_outline_rounded,
                        color: AppTheme.errorColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _saveError!,
                        style: AppTheme.bodyFont(
                            size: 13, color: AppTheme.errorColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: NeuButton(
                onPressed: _saving ? null : _saveNewDoctor,
                isLoading: _saving,
                child: const Text('Save & Select'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DoctorPickerTile extends StatelessWidget {
  final ExternalDoctor doctor;
  final VoidCallback onTap;

  const DoctorPickerTile({super.key, required this.doctor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.12),
        child: const Icon(AppIcons.local_hospital_outlined,
            size: 16, color: AppTheme.primaryTeal),
      ),
      title: Text(
        doctor.name,
        style: AppTheme.bodyFont(size: 14, weight: FontWeight.w600),
      ),
      subtitle: (doctor.specialization?.isNotEmpty == true ||
              doctor.hospital?.isNotEmpty == true)
          ? Text(
              [
                if (doctor.specialization?.isNotEmpty == true)
                  doctor.specialization!,
                if (doctor.hospital?.isNotEmpty == true) doctor.hospital!,
              ].join(' · '),
              style: AppTheme.bodyFont(size: 12, color: AppTheme.textMuted),
            )
          : null,
      trailing: doctor.fromHistory
          ? Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'From visits',
                style: AppTheme.bodyFont(
                    size: 10, color: AppTheme.infoColor),
              ),
            )
          : null,
    );
  }
}
