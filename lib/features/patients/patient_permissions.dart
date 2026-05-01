// lib/features/patients/patient_permissions.dart
//
// Single source of truth for "who can do what" with patient records, mapped
// directly from the implementation plan's role matrix:
//
//   | Action                     | Head Doctor | Doctor | Agent     |
//   | Upload New Patient Data    | ❌          | ❌     | ✅        |
//   | Edit Patient Record        | ✅          | ✅     | own only  |
//   | Delete Patient Record      | ✅          | ❌     | ❌        |
//   | Assign Follow-Up to Agent  | ✅          | ✅     | ❌        |
//   | View All Patients          | ✅          | ✅     | ❌        |
//   | View Own Uploaded Patients | ✅          | ✅     | ✅        |
//
// Centralising this here means the patient list, patient card, and patient
// detail screens can't drift apart on permissions.

import 'package:mediflow/features/auth/auth_provider.dart';
import 'package:mediflow/models/patient_model.dart';
import 'package:mediflow/models/user_role.dart';

class PatientPermissions {
  PatientPermissions._();

  /// Agents are the only role allowed to register new patients.
  static bool canCreatePatient(AuthUserState? auth) {
    return auth?.role == UserRole.assistant;
  }

  /// Doctors and head doctors can edit any patient. Agents can edit only
  /// patients they personally created (matches RLS in Supabase).
  static bool canEditPatient(
    AuthUserState? auth,
    PatientModel? patient,
  ) {
    if (auth == null) return false;
    final role = auth.role;
    if (role == UserRole.doctor || role == UserRole.headDoctor) return true;
    if (patient == null) return false;
    return patient.createdById == auth.session.user.id;
  }

  /// Per the plan, hard-deleting a patient record is a Head Doctor–only
  /// platform-admin action. Doctors finalise records but don't remove them;
  /// Agents enter data but never delete.
  static bool canDeletePatient(AuthUserState? auth) {
    return auth?.role == UserRole.headDoctor;
  }

  /// Only Doctors and Head Doctors assign follow-up tasks. Agents *receive*
  /// follow-ups, they never create them.
  static bool canAssignFollowup(AuthUserState? auth) {
    if (auth == null) return false;
    return auth.role == UserRole.doctor || auth.role == UserRole.headDoctor;
  }
}
