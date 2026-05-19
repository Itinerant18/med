# Codebase Analysis Report – MediFlow

> **Domain:** Clinical workflow management (patients, visits, follow-ups, staff)  
> **Platform:** Flutter (mobile + desktop + web)  
> **Backend:** Supabase (PostgreSQL, Auth, Realtime, Edge Functions)  
> **Push:** Firebase Cloud Messaging (FCM) ↔ Supabase Edge ↔ Flutter  
> **State Management:** Riverpod (`Provider`, `AsyncNotifierProvider`)  
> **Routing:** GoRouter (declarative routes, auth guards)  
> **Design System:** "Serene Clinical" – sage-green accents, soft neumorphic surfaces  

---

## 1️⃣ Project Overview

| Aspect | Detail |
|--------|--------|
| **Frontend** | Flutter using Riverpod for state, GoRouter for navigation, custom Neumorphic theme. |
| **Backend** | Supabase (PostgreSQL, Auth, Realtime, Storage, Edge Functions). |
| **Push** | Firebase Cloud Messaging (FCM) for real-time alerts, orchestrated via Supabase Edge Functions. |
| **Auth** | Supabase Auth with email/password, phone-OTP, and Google Sign-In; role-based access (`assistant`, `doctor`, `head_doctor`). |
| **Key Packages** | `supabase_flutter`, `flutter_riverpod`, `go_router`, `firebase_messaging`, `flutter_local_notifications`, `google_sign_in`, `intl`, `cached_network_image`, `fl_chart`, `font_awesome_flutter`, `shared_preferences`. |
| **Configuration** | Runtime secrets loaded from `.env.local` via `flutter_dotenv`; **must stay out of Git** (`.gitignore` contains `*.env*`). |
| **Testing** | Minimal placeholder widget test (`test/widget_test.dart`). |
| **Generated Artifacts** | Android/ios/web build folders, Gradle/Gradle-wrapper, Xcode project files – excluded from source analysis. |

---

## 2️⃣ Architecture Diagram (ASCII)

```text
+-------------------+       Riverpod (providers)        +-------------------+
|   UI Layer        | <------------------------------>  |   Provider Layer   |
| (Screens/Widgets) |   (ref.watch, ref.read, notify)   | (AsyncNotifier,   |
+--------+----------+                                   |  StateNotifier)   |
         |                                              +--------+----------+
         | (Triggers actions: CRUD, Auth)                        |
         v                                                       |
+-------------------+      Supabase Client (Dart)               |
|   SupabaseClient  | <-----------------------------------------+
|   (Singleton)     |   (Retry Extension, Auth Session Mgmt)
+--------+----------+
         |
         | (REST / RPC / Realtime Subscriptions)
         v
+-------------------+    Edge Functions (Deno/TS)    +---------------------------+
|   Supabase DB     | <--------------------------->  |  notify-status-change.ts  |
|   (PostgreSQL)    |   (Triggers / HTTP calls)      |  stale-patient-reminder.ts|
| - doctors         |                                +-------------+-------------+
| - patients        |                                              |
| - visits          |   (Sends Push Payload via HTTP)              |
+-------------------+                                              v
                                                     +---------------------------+
                                                     |   Firebase Cloud Msg (FCM)|
                                                     +-------------+-------------+
                                                                   |
                                                                   v
                                                     +---------------------------+
                                                     |   FcmService (Dart)       |
                                                     | - Foreground handler      |
                                                     | - Token sync              |
                                                     | - Quiet hours logic       |
                                                     +-------------+-------------+
                                                                   |
                                                                   v
                                                     +---------------------------+
                                                     |   Local Notification Svc  |
                                                     | (flutter_local_notif)     |
                                                     +-------------+-------------+
                                                                   |
                                                                   v (Tap)
                                                     +---------------------------+
                                                     |   Navigation Service      |
                                                     | (appNavigatorKey -> Route)|
                                                     +---------------------------+
```

---

## 3️⃣ File-by-File Reference

### 📂 Core Infrastructure (`lib/core/`)

| File | Purpose & Role | Key Contents |
|------|----------------|--------------|
| `app_config.dart` | Centralized config loader. | Loads `SUPABASE_URL` & `ANON_KEY` from `.env.local`. Validates presence. |
| `app_icons.dart` | Icon mapping. | Maps `AppIcons` to `MaterialIcons` (e.g., `home`, `person`, `notifications`). |
| `app_snackbar.dart` | UI feedback utility. | `AppSnackbar.showSuccess`, `showError`, `showWarning` helpers. |
| `auth_gate.dart` | Routing guard. | Widget that checks `authStateProvider` and redirects to `/login` if null. |
| `connectivity_wrapper.dart` | Network status monitor. | Listens to `Connectivity` stream; shows offline banner if disconnected. |
| `error_handler.dart` | Error parsing. | `AppError` class to extract user-friendly messages from Supabase/Socket errors. |
| `fcm_service.dart` | Push notification manager. | Singleton handling token sync, foreground/background messages, quiet hours. |
| `google_auth_config.dart` | OAuth config. | Holds Google Client IDs (Web/iOS) for `google_sign_in`. |
| `main.dart` | App entry point. | Initializes Firebase, Supabase, DotEnv, `ProviderScope`. Runs `MediFlowApp`. |
| `navigation_service.dart` | Deep linking helper. | `openPatientDetailFromNotification` uses `GoRouter` via global key. |
| `neu_widgets.dart` | UI component library. | `NeuCard`, `NeuButton`, `NeuTextField`, `NeuShimmer` (skeuomorphic style). |
| `notification_provider.dart` | In-app notification state. | `NotificationNotifier` (StateNotifier) manages list of in-app alerts. |
| `notification_service.dart` | Local notification builder. | Creates Android/iOS notification details with channels and categories. |
| `organic_tokens.dart` | Token management (unused?). | Likely legacy or placeholder for token rotation logic. |
| `parse_utils.dart` | Data parsing helpers. | `parseDbDate`, `parseDbString`, `parseDbMap` to handle null/DB types safely. |
| `realtime_service.dart` | Supabase Realtime wrapper. | Subscribes to table changes (e.g., `patients`, `visits`) and notifies providers. |
| `role_provider.dart` | Role access control. | `isHeadDoctorProvider`, `isAdminProvider`, `isAgentProvider` derived from auth. |
| `router.dart` | GoRouter configuration. | Defines all app routes (`/`, `/login`, `/patients/:id`, `/dashboard`). |
| `string_utils.dart` | String manipulation. | Helpers for formatting names, phone numbers, or truncating text. |
| `supabase_client.dart` | DB client provider. | Provides `SupabaseClient` instance + `retry` extension for transient errors. |
| `theme.dart` | App theming. | Defines `AppTheme` (colors, text styles, shadows) — "Serene Clinical" palette. |

### 📂 Data Models (`lib/models/`)

| File | Purpose & Role | Key Contents |
|------|----------------|--------------|
| `agent_outside_visit_model.dart` | External visit data. | Model for visits recorded outside the system (e.g., by external agents). |
| `app_notification.dart` | Notification entity. | `id`, `title`, `body`, `category`, `isRead`, `timestamp`. |
| `doctor_model.dart` | Doctor profile data. | `id`, `fullName`, `role`, `specialization`, `approvalStatus`. |
| `patient_model.dart` | Patient record. | Comprehensive model: demographics, clinical data, `serviceStatus`, `isHighPriority`. |
| `user_role.dart` | Role enumeration. | `UserRole` enum (`headDoctor`, `doctor`, `assistant`) with labels/permissions. |
| `visit_model.dart` | Visit record. | `DrVisit` model: vitals, diagnosis, follow-up status, external doctor details. |

### 📂 Features (`lib/features/`)

#### 🔐 Auth (`auth/`)

| File | Purpose & Role | Key Contents |
|------|----------------|--------------|
| `auth_provider.dart` | Authentication logic. | `AuthNotifier`: handles login, signup (email/phone/Google), session sync, role lookup. |
| `login_screen.dart` | Login UI. | Email/password form, Google sign-in button, phone OTP entry link. |
| `phone_otp_screen.dart` | Phone verification UI. | Input for phone number, OTP verification flow using Firebase Auth. |
| `register_screen.dart` | Registration UI. | Form for new doctors/assistants: name, specialization, role, phone, password. |

#### 📊 Dashboard (`dashboard/`)

| File | Purpose & Role | Key Contents |
|------|----------------|--------------|
| `dashboard_provider.dart` | Dashboard data. | Fetches stats (visits, pending labs), high-priority patients, assigned tasks. |
| `dashboard_screen.dart` | Main landing page. | Greeting, "LIVE" badge, stat carousel, priority cards, visit lists. |
| `main_screen.dart` | Shell layout. | Scaffold with bottom navigation bar (Dashboard, Patients, Analytics, Profile). |
| `notification_sheet.dart` | In-app alerts UI. | Bottom sheet showing list of `AppNotification`s from `notificationProvider`. |
| `performance_dashboard_screen.dart` | Performance metrics. | Charts/graphs for doctor/assistant performance (visits, completion rates). |
| `performance_provider.dart` | Performance data. | Fetches aggregated metrics for the current user or team. |

#### 📈 Analytics (`analytics/`)

| File | Purpose & Role | Key Contents |
|------|----------------|--------------|
| `analytics_provider.dart` | Analytics data. | Fetches summary stats, visit types, 30-day activity, scheme breakdown. |
| `analytics_screen.dart` | Analytics UI. | Overview cards, visit type bars, activity chart, health scheme table, staff table. |

#### 🏥 Patients (`patients/`)

| File | Purpose & Role | Key Contents |
|------|----------------|--------------|
| `document_provider.dart` | File uploads. | Handles uploading patient documents to Supabase Storage. |
| `document_upload_widget.dart` | Upload UI. | UI for selecting and uploading files (PDF/Image) with progress. |
| `patient_detail_screen.dart` | Patient profile view. | Detailed view: demographics, history, vitals, documents, status actions. |
| `patient_form_screen.dart` | Patient creation/edit. | Form for adding/editing patient data, including clinical fields. |
| `patient_list_provider.dart` | Patient list state. | Fetches and filters patient list based on role and search query. |
| `patient_list_screen.dart` | Patient list UI. | Searchable list of patients with status badges and quick actions. |
| `patient_permissions.dart` | Access logic. | Utility to check if current user can view/edit a specific patient. |
| `patient_provider.dart` | Patient CRUD. | `AsyncNotifier` for creating, updating, and deleting patient records. |
| `visit_history_provider.dart` | Visit history. | Fetches chronological list of visits for a specific patient. |

#### 🩺 Doctor Visits (`dr_visits/`)

| File | Purpose & Role | Key Contents |
|------|----------------|--------------|
| `agents_provider.dart` | Agent assignment. | Logic for assigning agents to visits and tracking their status. |
| `dr_visit_detail_screen.dart` | Visit details. | Shows visit info, vitals, diagnosis, and allows follow-up creation. |
| `dr_visit_form.dart` | Visit entry form. | Form for doctors to record visit details, diagnosis, and prescriptions. |
| `dr_visit_provider.dart` | Visit CRUD. | Manages creation and updates of doctor visit records. |
| `dr_visit_screen.dart` | Visit list UI. | List of visits for the current doctor, filterable by date/status. |
| `external_doctor_fields.dart` | External doctor data. | UI fields for capturing external doctor info (name, hospital, phone). |
| `log_contact_sheet.dart` | Contact logging. | Bottom sheet to log contact attempts with a patient/lead. |

#### 🔄 Follow-ups (`followups/`)

| File | Purpose & Role | Key Contents |
|------|----------------|--------------|
| `add_followup_sheet.dart` | Create follow-up. | UI to schedule a follow-up with date, notes, and assigned doctor. |
| `doctor_followups_screen.dart` | Doctor's follow-up list. | List of follow-ups assigned to the current doctor. |
| `followup_provider.dart` | Follow-up state. | CRUD operations for follow-up tasks; marks as completed. |
| `followup_review_screen.dart` | Review follow-up. | Screen to review completed follow-ups and add notes. |
| `followup_task_widget.dart` | Task card UI. | Widget displaying a single follow-up task with action buttons. |
| `my_followups_screen.dart` | User's follow-up list. | List of follow-ups created by or assigned to the current user. |

#### 👥 Staff (`staff/`)

| File | Purpose & Role | Key Contents |
|------|----------------|--------------|
| `staff_management_screen.dart` | Staff admin UI. | List of staff accounts, approval/rejection, role changes, suspension. |
| `staff_provider.dart` | Staff data. | Fetches staff list, handles approval status updates and role changes. |

#### 📋 Approval (`approval/`)

| File | Purpose & Role | Key Contents |
|------|----------------|--------------|
| `approval_provider.dart` | Approval workflow. | Logic for approving/rejecting new registrations or status changes. |
| `awaiting_approval_screen.dart` | Pending approvals. | UI showing items waiting for head doctor approval. |
| `pending_approvals_screen.dart` | Approval dashboard. | Summary of pending approvals with quick action buttons. |
| `rejected_screen.dart` | Rejected items. | List of rejected items with reasons and option to reinstate. |

#### 🏥 Clinical (`clinical/`)

| File | Purpose & Role | Key Contents |
|------|----------------|--------------|
| `clinical_entry_screen.dart` | Clinical data entry. | Screen for entering detailed clinical notes, lab results, etc. |
| `clinical_provider.dart` | Clinical data state. | Manages saving and retrieving clinical entries for patients. |

#### 👤 Profile (`profile/`)

| File | Purpose & Role | Key Contents |
|------|----------------|--------------|
| `about_screen.dart` | App info. | Version info, licenses, contact details. |
| `assistant_profile_screen.dart` | Assistant profile. | Editable profile for assistants (phone, notification prefs). |
| `change_password_dialog.dart` | Password change. | Dialog to update password (requires current password). |
| `change_password_sheet.dart` | Password change UI. | Bottom sheet variant for changing password. |
| `clinic_settings_provider.dart` | Clinic config. | Manages clinic-wide settings (name, logo, working hours). |
| `doctor_profile_screen.dart` | Doctor profile. | Editable profile for doctors (specialization, bio, contact). |
| `notification_preferences_screen.dart` | Notif settings. | UI to toggle notification channels and quiet hours. |
| `profile_provider.dart` | Profile data. | Fetches and updates user profile data in Supabase. |

#### 🕵️ Agent Visits (`agent_visits/`)

| File | Purpose & Role | Key Contents |
|------|----------------|--------------|
| `agent_outside_visit_form.dart` | External visit form. | Form for agents to log visits outside the clinic. |
| `agent_outside_visit_list_screen.dart` | External visit list. | List of outside visits recorded by agents. |
| `agent_outside_visit_provider.dart` | External visit state. | CRUD for agent outside visits. |

### 📂 Shared Widgets (`lib/shared/widgets/`)

| File | Purpose & Role | Key Contents |
|------|----------------|--------------|
| `confirm_dialog.dart` | Confirmation prompt. | Reusable dialog for destructive actions (delete, suspend). |
| `dashboard_stat_carousel.dart` | Stat carousel. | Horizontal scrolling list of stat cards used in Dashboard/Analytics. |
| `empty_state.dart` | Empty view. | Standardized empty state widget with icon and message. |
| `error_boundary.dart` | Error catching. | `ErrorBoundary` widget to catch render errors and show fallback UI. |
| `patient_picker_bottom_sheet.dart` | Patient selection. | Bottom sheet to search and select a patient from the list. |
| `service_status_badge.dart` | Status indicator. | Colored badge showing patient status (e.g., "Admitted", "Discharged"). |
| `skeleton_loader.dart` | Loading placeholder. | `NeuShimmer` and skeleton widgets for loading states. |

### 📂 Supabase Backend (`supabase/`)

| File | Purpose & Role | Key Contents |
|------|----------------|--------------|
| `config.toml` | Supabase CLI config. | Local dev settings (ports, project ID). |
| `migrations/*.sql` | DB schema & policies. | Tables (`patients`, `visits`, `doctors`), RLS policies, indexes. |
| `functions/notify-status-change/index.ts` | Status change hook. | Sends FCM push when patient status changes (e.g., Admitted → Discharged). |
| `functions/stale-patient-reminder/index.ts` | Stale patient alert. | Cron job to notify doctors about patients not updated in 2+ days. |
| `functions/send-fcm-notification/index.ts` | FCM dispatcher. | Generic function to send push notification to a specific FCM token. |

---

## 4️⃣ Data & Control Flow

### 🔹 Typical User Flow: Patient Status Update

1. **UI Action:** Doctor taps "Discharge" on `patient_detail_screen.dart`.
2. **Provider Call:** `patient_provider.dart` calls `updatePatientStatus(patientId, 'Discharged')`.
3. **Supabase Update:** `SupabaseClient` executes `UPDATE patients SET service_status = 'Discharged'`.
4. **DB Trigger:** Supabase Edge Function `notify-status-change` is triggered (via webhook or polling).
5. **Edge Logic:** Function queries `doctors` table for relevant recipients (e.g., Head Doctor, assigned agent).
6. **FCM Dispatch:** Function calls `send-fcm-notification` with payload `{ type: 'status_change', patientId: '...' }`.
7. **Device Receipt:**
   - **Background:** System tray notification appears.
   - **Foreground:** `FcmService._onForegroundMessage` receives message, checks quiet hours, shows local notification via `NotificationService`.
8. **User Tap:** User taps notification.
9. **Navigation:** `FcmService._onMessageOpenedApp` extracts `patientId` and calls `NavigationService.openPatientDetailFromNotification`.
10. **Route Change:** `GoRouter` pushes `/patients/:id/detail`, showing updated status.

---

## 5️⃣ Design Patterns

| Pattern | Usage |
|---------|-------|
| **Provider Pattern** | Riverpod used extensively for state management (`AsyncNotifierProvider`, `StateNotifierProvider`). |
| **Repository Pattern** | Implicitly used via `SupabaseClient` extension; providers act as repositories for UI. |
| **Singleton** | `FcmService`, `NotificationService`, `SupabaseClient` are singletons. |
| **Retry Pattern** | `SupabaseRetry` extension automatically retries transient network errors (3 attempts). |
| **RBAC (Role-Based Access Control)** | Enforced at DB level via RLS policies and in UI via `role_provider`. |
| **Observer Pattern** | Supabase Realtime subscriptions notify providers of DB changes. |
| **Strategy Pattern** | `AppError` handles different error types (Socket, Postgrest, Auth) with specific messages. |

---

## 6️⃣ Risks, Bugs & Tech Debt

| Category | Issue | Impact | Recommendation |
|----------|-------|--------|----------------|
| 🔒 **Security** | `.env.local` may be committed. | **Critical**: Leaks Supabase keys. | Ensure `.env.local` is in `.gitignore` and removed from history. |
| 🔒 **Security** | `service_role_key` in Edge Functions. | **High**: Full DB access if exposed. | Verify keys are stored in Supabase Secrets, not code. |
| 🐛 **Bug** | `AuthNotifier.signUp` sets `phone_verified = true`. | **Medium**: Bypasses phone verification. | Verify OTP token before setting flag. |
| 🐛 **Bug** | `FcmService` swallows errors silently. | **Low**: Failed notifications go unnoticed. | Add logging or retry logic for FCM failures. |
| 🐛 **Bug** | `NotificationService` ID collision. | **Low**: Notifications may overwrite each other. | Use UUID or timestamp for notification IDs. |
| 🏗️ **Tech Debt** | Duplicate provider patterns. | **Medium**: Hard to maintain. | Consolidate similar providers (e.g., `patient_provider` vs `patient_list_provider`). |
| 🏗️ **Tech Debt** | Hardcoded role checks. | **Medium**: Fragile if roles change. | Use `UserRole` enum methods instead of string comparisons. |
| 🏗️ **Tech Debt** | Minimal testing. | **High**: Regression risk. | Add unit tests for providers and integration tests for critical flows. |

---

## 7️⃣ Recommendations & Next Steps

1. **Security Audit:** Immediately verify `.env.local` is not in Git. Rotate keys if exposed.
2. **Phone Verification:** Implement proper OTP verification before marking `phone_verified`.
3. **Testing:** Write tests for `AuthNotifier`, `PatientProvider`, and critical UI flows.
4. **Error Handling:** Improve error reporting in `FcmService` and Edge Functions.
5. **Refactoring:** Consolidate providers and use `UserRole` enum consistently.
6. **Documentation:** Add comments to complex providers and Edge Functions.
7. **Monitoring:** Add Sentry or similar for crash reporting and error tracking.

---

*End of Report*
