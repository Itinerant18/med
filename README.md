# MediFlow 🏥

**A Skeuomorphic Medical Management Platform**

MediFlow is a role-based healthcare management application built with Flutter, designed to streamline patient data management, inter-team communication, and clinical workflows. The platform uses a three-tier role system to ensure secure, organized, and efficient healthcare operations.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Project Overview (Technical)](#project-overview-technical)
- [Architecture & Data Flow](#architecture--data-flow)
- [Role-Based Access Control](#role-based-access-control)
- [Tech Stack](#tech-stack)
- [Design Patterns](#design-patterns)
- [File-by-File Reference](#file-by-file-reference)
- [Risks, Bugs & Tech Debt](#risks-bugs--tech-debt)
- [Getting Started](#getting-started)
- [Development Guidelines](#development-guidelines)
- [Database & Backend](#database--backend)
- [Security](#security)
- [Testing](#testing)
- [Deployment](#deployment)

---

## 🎯 Overview

MediFlow is a comprehensive healthcare management system that bridges the gap between patients, medical professionals, and healthcare administrators. It provides a unified platform where:

- **Head Doctors** manage user approvals and maintain oversight
- **Doctors** review patient data and assign clinical follow-ups
- **Agents** handle patient data entry and task management

The application features a **skeuomorphic design** with organic shapes, natural colors, and a warm, human-centered interface that brings familiarity and trust to healthcare management.

---

## 📊 Project Overview (Technical)

| Aspect | Detail |
|---|---|
| **Domain** | Clinical workflow management (patients, visits, follow-ups, staff). |
| **Frontend** | Flutter (mobile + desktop + web) using Riverpod for state, GoRouter for navigation, a custom “Serene Clinical” UI theme. |
| **Backend** | Supabase (PostgreSQL, Auth, Realtime, Storage, Edge Functions). |
| **Push** | Firebase Cloud Messaging (FCM) ↔ Supabase Edge Functions ↔ Flutter (local notifications). |
| **Auth** | Supabase Auth with email/password, phone-OTP, and Google Sign-In; role-based access (`assistant`, `doctor`, `head_doctor`). |
| **Key Packages** | `supabase_flutter`, `flutter_riverpod`, `go_router`, `firebase_messaging`, `flutter_local_notifications`, `google_sign_in`, `intl`, `cached_network_image`, `fl_chart`, `font_awesome_flutter`, `shared_preferences`. |
| **Configuration** | Runtime secrets loaded from `.env.local` via `flutter_dotenv`; must stay out of Git (`.gitignore` contains `*.env*`). |
| **Testing** | Only a placeholder widget test (`test/widget_test.dart`). |
| **Generated Artifacts** | Android/ios/web build folders, Gradle/Gradle-wrapper, Xcode project files – excluded from source analysis. |

---

## 🏗️ Architecture & Data Flow

### Architecture Diagram

```
+-------------------+       Riverpod (providers)        +-------------------+
|   UI Layer        | <------------------------------>  |   Provider Layer  |
| (Screens/Widgets) |   (ref.watch, ref.read, notify)   | (AsyncNotifier,   |
+--------+----------+                                   |  StateNotifier)   |
         |                                              +--------+----------+
         | (Triggers actions: CRUD, Auth)                        |
         v                                                       |
+-------------------+      Supabase Client (Dart)                |
|   SupabaseClient  | <------------------------------------------+
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

### Typical User Flow: Patient Status Update

1. **UI Action**: Doctor taps "Discharge" on `patient_detail_screen.dart`.
2. **Provider Call**: `patient_provider.dart` calls `updatePatientStatus(patientId, 'Discharged')`.
3. **Supabase Update**: SupabaseClient executes `UPDATE patients SET service_status = 'Discharged'`.
4. **DB Trigger**: Supabase Edge Function `notify-status-change` is triggered (via webhook or polling).
5. **Edge Logic**: Function queries `doctors` table for relevant recipients (e.g., Head Doctor, assigned agent).
6. **FCM Dispatch**: Function calls `send-fcm-notification` with payload `{ type: 'status_change', patientId: '...' }`.
7. **Device Receipt**:
   - **Background**: System tray notification appears.
   - **Foreground**: `FcmService._onForegroundMessage` receives message, checks quiet hours, shows local notification via `NotificationService`.
8. **User Tap**: User taps notification.
9. **Navigation**: `FcmService._onMessageOpenedApp` extracts `patientId` and calls `NavigationService.openPatientDetailFromNotification`.
10. **Route Change**: GoRouter pushes `/patients/:id/detail`, showing updated status.

---

## 🧩 Design Patterns

| Pattern | Usage |
|---------|-------|
| **Provider Pattern** | Riverpod used extensively for state management (`AsyncNotifierProvider`, `StateNotifierProvider`). |
| **Repository Pattern** | Implicitly used via `SupabaseClient` extension; providers act as repositories for UI. |
| **Singleton** | `FcmService`, `NotificationService`, `SupabaseClient` are singletons. |
| **Retry Pattern** | `SupabaseRetry` extension automatically retries transient network errors (3 attempts). |
| **RBAC** | Role-Based Access Control enforced at DB level via RLS policies and in UI via `role_provider`. |
| **Observer Pattern** | Supabase Realtime subscriptions notify providers of DB changes. |
| **Strategy Pattern** | `AppError` handles different error types (Socket, Postgrest, Auth) with specific messages. |

---

## 🔐 Role-Based Access Control

### Access Matrix

| Feature                  | Head Doctor  | Doctor | Agent |
| ------------------------ | :----------: | :----: | :---: |
| Approve Registrations    |      ✅      |   ❌   |  ❌   |
| View All Patients        |      ✅      |   ✅   |  ❌   |
| View Own Patients        |      ✅      |   ✅   |  ✅   |
| Add Clinical Notes       |      ✅      |   ✅   |  ❌   |
| Assign Follow-Up Tasks   |      ✅      |   ✅   |  ❌   |
| Receive Follow-Up Tasks  |      ❌      |   ❌   |  ✅   |
| Upload Patient Data      |      ❌      |   ❌   |  ✅   |
| Deactivate Users         |      ✅      |   ❌   |  ❌   |
| View Registration Alerts |      ✅      |   ❌   |  ❌   |

---

## 📁 File-by-File Reference

### Core Infrastructure (`lib/core/`)

- **`app_config.dart`**: Centralized config loader (`SUPABASE_URL` & `ANON_KEY` from `.env.local`).
- **`app_icons.dart`**: Maps `AppIcons` to `MaterialIcons`.
- **`app_snackbar.dart`**: UI feedback utility (`showSuccess`, `showError`, `showWarning`).
- **`auth_gate.dart`**: Widget that checks `authStateProvider` and redirects to `/login` if null.
- **`connectivity_wrapper.dart`**: Network status monitor showing offline banner if disconnected.
- **`error_handler.dart`**: `AppError` class to extract user-friendly messages from Supabase/Socket errors.
- **`fcm_service.dart`**: Singleton handling FCM token sync, messages, quiet hours.
- **`google_auth_config.dart`**: Holds Google Client IDs for `google_sign_in`.
- **`navigation_service.dart`**: Deep linking helper using GoRouter via a global key.
- **`neu_widgets.dart`**: UI component library (skeuomorphic style).
- **`notification_provider.dart`**: StateNotifier managing list of in-app alerts.
- **`notification_service.dart`**: Local notification builder (`flutter_local_notifications`).
- **`organic_tokens.dart`**: Token management (unused?). Likely legacy or placeholder for token rotation logic.
- **`parse_utils.dart`**: Data parsing helpers (`parseDbDate`, `parseDbString`, `parseDbMap`) to handle null/DB types safely.
- **`realtime_service.dart`**: Supabase Realtime wrapper subscribing to table changes.
- **`role_provider.dart`**: Role access control logic derived from auth.
- **`router.dart`**: GoRouter configuration (routes like `/`, `/login`, `/patients/:id`).
- **`string_utils.dart`**: String manipulation helpers for formatting names, phone numbers, or truncating text.
- **`supabase_client.dart`**: Provides `SupabaseClient` instance + retry extension.
- **`theme.dart`**: Defines `AppTheme` — "Serene Clinical" palette.

### Data Models (`lib/models/`)

- **`agent_outside_visit_model.dart`**: Model for external visits by agents.
- **`app_notification.dart`**: Notification entity (`id`, `title`, `body`, `category`, `isRead`).
- **`doctor_model.dart`**: Doctor profile data.
- **`patient_model.dart`**: Comprehensive patient record model.
- **`user_role.dart`**: `UserRole` enum (`headDoctor`, `doctor`, `assistant`).
- **`visit_model.dart`**: `DrVisit` model for visit records.

### Features (`lib/features/`)

- **`auth/`**: `auth_provider.dart`, `login_screen.dart`, `phone_otp_screen.dart`, `register_screen.dart`. Handles auth and role lookup.
- **`dashboard/`**: `dashboard_provider.dart`, `dashboard_screen.dart`, `main_screen.dart`. Shows stats, priority cards, visit lists.
- **`analytics/`**: Overview cards, activity charts, scheme breakdown.
- **`patients/`**: CRUD for patients, file uploads (`document_provider.dart`), detail views, history.
- **`dr_visits/`**: Doctor visit tracking, agent assignments, contact logging.
- **`followups/`**: Follow-up creation, review, and task completion flow.
- **`staff/` & `approval/`**: Staff admin UI and approval workflows for new registrations.
- **`audit/`**: Audit trail UI displaying log of user actions for compliance.
- **`clinical/`**: Data entry for clinical notes and lab results.
- **`profile/`**: User profiles, notification preferences, and clinic settings.
- **`agent_visits/`**: Forms and lists for outside visits by agents.

### Shared Widgets (`lib/shared/widgets/`)

- **`confirm_dialog.dart`**: Confirmation prompt for destructive actions.
- **`dashboard_stat_carousel.dart`**: Horizontal scrolling stat cards.
- **`empty_state.dart`**: Standardized empty state widget.
- **`error_boundary.dart`**: Error catching widget.
- **`patient_picker_bottom_sheet.dart`**: Patient selection interface.
- **`service_status_badge.dart`**: Colored status indicator badge.
- **`skeleton_loader.dart`**: Shimmer and skeleton loading placeholders.

### Supabase Backend (`supabase/`)

- **`config.toml`**: Supabase CLI local dev settings.
- **`migrations/*.sql`**: DB schema, RLS policies, indexes.
- **Edge Functions**:
  - `notify-status-change`: Sends FCM push when patient status changes.
  - `stale-patient-reminder`: Cron job alerting about patients not updated in 2+ days.
  - `send-fcm-notification`: Generic function to dispatch push payloads to FCM.

---

## ⚠️ Risks, Bugs & Tech Debt

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

### Recommendations & Next Steps

1. **Security Audit**: Immediately verify `.env.local` is not in Git. Rotate keys if exposed.
2. **Phone Verification**: Implement proper OTP verification before marking `phone_verified`.
3. **Testing**: Write tests for `AuthNotifier`, `PatientProvider`, and critical UI flows.
4. **Error Handling**: Improve error reporting in `FcmService` and Edge Functions.
5. **Refactoring**: Consolidate providers and use `UserRole` enum consistently.
6. **Documentation**: Add comments to complex providers and Edge Functions.
7. **Monitoring**: Add Sentry or similar for crash reporting and error tracking.

---

## 💻 Tech Stack

### Mobile & Frontend

```
Flutter/Dart 3.2.0+
├── flutter_riverpod: ^2.5.1        (State management)
├── go_router: ^13.2.0              (Navigation)
├── image_picker: ^1.2.1            (Image selection)
├── cached_network_image: ^3.3.1    (Image caching)
└── google_fonts: ^6.2.1            (Typography)
```

### Backend Services

```
Supabase
├── PostgreSQL Database
└── Edge Functions (Deno)

Firebase
├── Firebase Auth
├── Firebase Messaging (FCM)
└── Cloud Functions
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.2.0+)
- Dart SDK (included with Flutter)
- XCode (for iOS development)
- Android Studio (for Android development)
- Git

### Installation

1. **Clone the repository**

```bash
git clone https://github.com/Itinerant18/med.git
cd med
```

1. **Install dependencies**

```bash
flutter pub get
```

1. **Configure environment variables**
Create a `.env.local` file in the root directory:

```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
FIREBASE_PROJECT_ID=your_firebase_project_id
```

1. **Setup Firebase**

```bash
# For iOS:
cd ios && pod install && cd ..

# Run FlutterFire CLI:
flutterfire configure
```

1. **Run the application**

```bash
flutter run
# Or specifically: flutter run -d ios / flutter run -d android
```

---

## 🎨 Design System

MediFlow implements a **skeuomorphic design system** emphasizing warmth, natural forms, and human connection.

- **Core Signature**: Soft, amorphous blob shapes with organic border radii
- **Texture**: Paper-like quality with subtle grain overlay (3-4% opacity)
- **Color Palette**: Earth-inspired palette (moss green, terracotta, stone)
- **Shadow Philosophy**: Soft, diffused shadows with natural color tints
- **Typography**: Fraunces serif (headings) + Nunito (body)

---

## ✅ Testing

```bash
# All tests
flutter test

# Specific test file
flutter test test/widget_test.dart

# With coverage
flutter test --coverage
```

---

## 📝 Contributing

We welcome contributions! Please fork the repository, create a feature branch, and open a Pull Request.

**Commit Message Format:**

```
<type>(<scope>): <subject>

<body>

Closes #<issue-number>
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

---

## 📚 Documentation

- **[Codebase Analysis Report](CODEBASE_ANALYSIS_REPORT.md)** - In-depth technical architecture and file-by-file breakdown
- **[User Roles & Permissions](user_roles_permissions.md)** - Detailed role specifications
- **[Feature Implementation Plan](feature-list-implementation-plan.md)** - User flows and feature matrix
- **[Design System](DESIGNE.md)** - Complete design specifications
- **[Security Guidelines](SECURITY.md)** - Security policies and best practices

---

## 📄 License

This project is licensed under the MIT License. See the LICENSE file for details.

---

**Developed by**: Itinerant18  
**Repository**: [Itinerant18/med](https://github.com/Itinerant18/med)  
**Last Updated**: May 18, 2026
