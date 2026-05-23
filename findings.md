# Findings & Decisions

## Requirements
- **Log Visit page:**
  - Add field: `Post Op Refered To (Radiation Oncology) :`
  - Remove field: `Prescriptions` (or similar prescription field)
  - Remove section: `Vitals` (the whole section)
- **Add External Visit page:**
  - Add field: `District Dopdown`
  - Add field: `Type Of Doctor`
- **New External Visit page:**
  - Remove all doctors data except:
    - `Hospital/Clinic`
    - `How Many Time Visited`
  - Add field: `No of Patient Recived`
  - Add field: `Work Pending`
  - Remove field: `Prescriptions`
  - Remove field: `Diagonsis`
  - Remove field: `Chief complaint`

## Research Findings
- **Log Visit:** Implemented in `lib/features/clinical/clinical_entry_screen.dart` (`ClinicalEntryScreen`).
  - Vitals section is built by `_buildVitalsSection()` (lines 564-640) and placed on line 328 in `build()`.
  - Prescriptions field is `_prescriptionsController` and built inside `_buildClinicalNotesSection()` (lines 850-855).
  - Database table `visits` contains `prescriptions`, `final_diagnosis`, `chief_complaint`, and vitals columns.
- **Add External Doctor (directory and picker forms):**
  - Managed directory entries are in `_AddExternalDoctorSheet` (`lib/features/staff/network_directory_screen.dart`).
  - Picker sheet form is `_ExternalDoctorPickerSheet` (`lib/features/agent_visits/agent_outside_visit_form.dart`).
  - Provider class is `externalDoctorsProvider` in `lib/features/staff/external_doctors_provider.dart`.
- **New External Visit:** Implemented in `lib/features/agent_visits/agent_outside_visit_form.dart` (`AgentOutsideVisitForm`).
  - Inputs for doctor name, specialization, phone, district, and type of doctor are built in the "External Doctor" section.
  - Visit outcomes (complaint, prescriptions, diagnosis, notes) are built in the "Visit Outcome" section.
  - DB table `agent_outside_visits` stores the record.
- **Database Schema Sync:**
  - Remote `visits` table altered: added `post_op_referred_to` text column.
  - Remote `external_doctors` table altered: added `area_district` and `meet_dr_type` text columns.
  - Remote `agent_outside_visits` table altered: added `no_of_patients_received` integer and `work_pending` text columns.

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Use planning-with-files | Follow constraints of the slash command |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| | |

## Resources
- Workspace directory: `C:\workspace\profile\med`

## Visual/Browser Findings
- None yet.
