# Implementation Plan: Medical Visit and External Doctor Customizations

This plan details the modifications to the "Log Visit" page, the "Add External Doctor" form/sheets, and the "New External Visit" form. The changes include adding new custom fields, deleting outdated fields, and reorganizing layout elements.

## User Review Required

> [!IMPORTANT]
>
> - **Log Visit Page:** The `Vitals` section and the `Prescriptions` field will be completely removed from the UI. A new text field `Post Op Referred To (Radiation Oncology) :` will be added.
> - **Add External Doctor:** The "Add External Doctor" bottom sheets (in both the network directory and the external doctor picker) will be expanded with `District Dropdown` and `Type Of Doctor` dropdowns.
> - **New External Visit Page:** This form will be heavily simplified. In the doctor details section, all input fields will be removed **except** `Hospital/Clinic` and `How Many Times Visited`. In the outcome section, the `Prescriptions`, `Diagnosis`, and `Chief complaint` fields will be removed, and two new fields, `No of Patients Received` and `Work Pending`, will be added.

## Proposed Changes

---

### Component 1: Log Visit (`ClinicalEntryScreen`)

#### [MODIFY] [clinical_entry_screen.dart](file:///C:/workspace/profile/med/lib/features/clinical/clinical_entry_screen.dart)

- Remove `_buildVitalsSection()` from UI.
- Remove `Prescriptions` field from UI (under `_buildClinicalNotesSection()`).
- Add a new `Post Op Referred To (Radiation Oncology) :` text field using `NeuTextField`.
- Bind it to `_postOpReferredToController = TextEditingController()`, clear it in `_resetForm()`, and dispose it in `dispose()`.
- Add `'post_op_referred_to': _postOpReferredToController.text.trim()` to the `visitData` object.

---

### Component 2: External Doctor Directory & Providers

#### [MODIFY] [external_doctors_provider.dart](file:///C:/workspace/profile/med/lib/features/staff/external_doctors_provider.dart)

- Update `ExternalDoctor` model class to support `areaDistrict` and `meetDrType` fields.
- Update `ExternalDoctor.fromJson()` to parse `area_district` and `meet_dr_type`.
- Modify `ExternalDoctorsNotifier.add()` to accept optional parameters `areaDistrict` and `meetDrType` and save them to Supabase.

#### [MODIFY] [network_directory_screen.dart](file:///C:/workspace/profile/med/lib/features/staff/network_directory_screen.dart)

- Add dropdown fields for `District` and `Type Of Doctor` inside `_AddExternalDoctorSheetState`'s build method.
- Update `_save()` to pass the selected `areaDistrict` and `meetDrType` to the provider.

---

### Component 3: New External Visit Form

#### [MODIFY] [agent_outside_visit_model.dart](file:///C:/workspace/profile/med/lib/models/agent_outside_visit_model.dart)

- Add `noOfPatientsReceived` (int?) and `workPending` (String?) fields.
- Update constructor and `AgentOutsideVisit.fromJson()` mapping.

#### [MODIFY] [agent_outside_visit_provider.dart](file:///C:/workspace/profile/med/lib/features/agent_visits/agent_outside_visit_provider.dart)

- Update `createVisit` and `updateVisit` methods to accept `noOfPatientsReceived` and `workPending` parameters, saving them into `no_of_patients_received` and `work_pending` db columns.
- Update select columns list to include `no_of_patients_received` and `work_pending`.

#### [MODIFY] [agent_outside_visit_form.dart](file:///C:/workspace/profile/med/lib/features/agent_visits/agent_outside_visit_form.dart)

- Add `_noOfPatientsCtrl` and `_workPendingCtrl` text controllers.
- Inside `_ExternalDoctorPickerSheetState._buildAddForm()` (Add Doctor in Picker), add the `District Dropdown` and `Type of Doctor` fields so the directory additions contain them.
- In the main form (`_AgentOutsideVisitFormState`):
  - In the **External Doctor** section, remove `Doctor Name`, `Specialization`, `Doctor Phone`, `Area (District)`, and `Type of Doctor` input fields from UI, keeping only `Hospital / Clinic` and `How Many Times Visited`.
  - In the **Visit Outcome** section, remove `Chief Complaint`, `Diagnosis`, and `Prescriptions` input fields, keeping only `Visit Notes`.
  - Add two new fields: `No of Patients Received` (numeric keyboard) and `Work Pending` (text input).
  - Modify `_submit()` to send `noOfPatientsReceived` and `workPending`. Since `extDoctorName` is mandatory in the database but removed from this screen, we will default it to `Hospital/Clinic`'s value or a generic `"External Doctor"`.

## Verification Plan

### Automated Tests

- Run `flutter analyze` to ensure there are no syntax, type mismatch, or compilation issues.

### Manual Verification

- The user can verify the form layouts visually by launching the application.
