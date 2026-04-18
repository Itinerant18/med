# Graph Report - .  (2026-04-18)

## Corpus Check
- 123 files · ~39,806 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 609 nodes · 742 edges · 45 communities detected
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 27 edges (avg confidence: 0.79)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Auth & Profile UI|Auth & Profile UI]]
- [[_COMMUNITY_State Management|State Management]]
- [[_COMMUNITY_Navigation & Routing|Navigation & Routing]]
- [[_COMMUNITY_UI Components|UI Components]]
- [[_COMMUNITY_Windows Platform|Windows Platform]]
- [[_COMMUNITY_Patient List UI|Patient List UI]]
- [[_COMMUNITY_Dashboard UI|Dashboard UI]]
- [[_COMMUNITY_Patient Detail UI|Patient Detail UI]]
- [[_COMMUNITY_App Shell|App Shell]]
- [[_COMMUNITY_Core Providers|Core Providers]]
- [[_COMMUNITY_Patient Form UI|Patient Form UI]]
- [[_COMMUNITY_Clinical Entry|Clinical Entry]]
- [[_COMMUNITY_Notifications|Notifications]]
- [[_COMMUNITY_Settings & About|Settings & About]]
- [[_COMMUNITY_Document Upload|Document Upload]]
- [[_COMMUNITY_Realtime Data|Realtime Data]]
- [[_COMMUNITY_Linux Platform|Linux Platform]]
- [[_COMMUNITY_Patient Domain|Patient Domain]]
- [[_COMMUNITY_Cross-Platform Entry|Cross-Platform Entry]]
- [[_COMMUNITY_Connectivity|Connectivity]]
- [[_COMMUNITY_iOS AppDelegate|iOS AppDelegate]]
- [[_COMMUNITY_macOS Window|macOS Window]]
- [[_COMMUNITY_Flutter Plugin Reg|Flutter Plugin Reg]]
- [[_COMMUNITY_iOS Tests|iOS Tests]]
- [[_COMMUNITY_LLDB Helper|LLDB Helper]]
- [[_COMMUNITY_Local Notifications|Local Notifications]]
- [[_COMMUNITY_Profile Screens|Profile Screens]]
- [[_COMMUNITY_Windows Utils|Windows Utils]]
- [[_COMMUNITY_Android Activity|Android Activity]]
- [[_COMMUNITY_Notification UI|Notification UI]]
- [[_COMMUNITY_Clinic Settings|Clinic Settings]]
- [[_COMMUNITY_RBAC|RBAC]]
- [[_COMMUNITY_Widget Tests|Widget Tests]]
- [[_COMMUNITY_Gradle Config|Gradle Config]]
- [[_COMMUNITY_Settings Gradle|Settings Gradle]]
- [[_COMMUNITY_App Build Config|App Build Config]]
- [[_COMMUNITY_iOS Headers|iOS Headers]]
- [[_COMMUNITY_Bridging Header|Bridging Header]]
- [[_COMMUNITY_User Role Model|User Role Model]]
- [[_COMMUNITY_Linux Header|Linux Header]]
- [[_COMMUNITY_Linux App Header|Linux App Header]]
- [[_COMMUNITY_Win Flutter Header|Win Flutter Header]]
- [[_COMMUNITY_Resource Header|Resource Header]]
- [[_COMMUNITY_Utils Header|Utils Header]]
- [[_COMMUNITY_Win32 Header|Win32 Header]]

## God Nodes (most connected - your core abstractions)
1. `package:flutter_riverpod/flutter_riverpod.dart` - 29 edges
2. `package:flutter/material.dart` - 21 edges
3. `package:mediflow/core/theme.dart` - 16 edges
4. `package:supabase_flutter/supabase_flutter.dart` - 12 edges
5. `package:mediflow/core/neu_widgets.dart` - 11 edges
6. `package:mediflow/features/auth/auth_provider.dart` - 10 edges
7. `package:go_router/go_router.dart` - 9 edges
8. `package:mediflow/core/supabase_client.dart` - 9 edges
9. `package:mediflow/core/app_snackbar.dart` - 9 edges
10. `User Login Screen` - 9 edges

## Surprising Connections (you probably didn't know these)
- `Android MainActivity` --semantically_similar_to--> `iOS AppDelegate`  [INFERRED] [semantically similar]
  android/app/src/main/kotlin/com/example/mediflow/MainActivity.kt → ios/Runner/AppDelegate.swift
- `Android MainActivity` --semantically_similar_to--> `macOS MainFlutterWindow`  [INFERRED] [semantically similar]
  android/app/src/main/kotlin/com/example/mediflow/MainActivity.kt → macos/Runner/MainFlutterWindow.swift
- `Android MainActivity` --semantically_similar_to--> `Windows FlutterWindow`  [INFERRED] [semantically similar]
  android/app/src/main/kotlin/com/example/mediflow/MainActivity.kt → windows/runner/flutter_window.cpp
- `UUID-based RBAC filtering` --conceptually_related_to--> `Patient CRUD operations`  [INFERRED]
  prompts/Prompt_A1.md → lib/features/patients/patient_provider.dart
- `Android MainActivity` --semantically_similar_to--> `Linux MyApplication`  [INFERRED] [semantically similar]
  android/app/src/main/kotlin/com/example/mediflow/MainActivity.kt → linux/runner/my_application.cc

## Hyperedges (group relationships)
- **Authentication Flow Components** — AuthGate, LoginScreen, RegisterScreen, authNotifierProvider, AuthUserState [EXTRACTED 0.95]
- **Clinical Visit Entry Workflow** — ClinicalEntryScreen, clinicalNotifierProvider, AppError, AppSnackbar, NeuTextField, NeuCard, NeuButton [EXTRACTED 0.90]
- **Dashboard Data Pipeline** — dashboardProvider, DashboardState, DashboardScreen, authNotifierProvider, isAdminProvider [EXTRACTED 0.90]
- **Patient management flow** — patient_list_screen, patient_list_provider, patient_form_screen, patient_detail_screen, patient_provider [EXTRACTED 0.85]
- **Profile management screens** — doctor_profile_screen, assistant_profile_screen, profile_provider, clinic_settings_provider [EXTRACTED 0.85]
- **Document management** — document_upload_widget, document_provider [EXTRACTED 0.90]
- **Flutter Platform Entry Points** — android_mainactivity, ios_appdelegate, macos_mainflutterwindow, linux_myapplication, windows_flutterwindow [EXTRACTED 0.90]
- **Plugin Registration Pattern** — android_pluginregistrant, ios_pluginregistrant, macos_pluginregistrant, linux_pluginregistrant, windows_pluginregistrant [EXTRACTED 0.95]

## Communities

### Community 0 - "Auth & Profile UI"
Cohesion: 0.04
Nodes (53): build, _buildLogo, Column, dispose, initState, LoginScreen, _LoginScreenState, Scaffold (+45 more)

### Community 1 - "State Management"
Cohesion: 0.07
Nodes (34): dart:async, AuthNotifier, AuthUserState, Exception, _resolveAuthUserState, ClinicalNotifier, copyWith, DashboardNotifier (+26 more)

### Community 2 - "Navigation & Routing"
Cohesion: 0.05
Nodes (38): build, ClinicalEntryScreen, GoRouter, Icon, PatientDetailScreen, PatientFormScreen, _RoleBasedProfileRouter, SizedBox (+30 more)

### Community 3 - "UI Components"
Cohesion: 0.05
Nodes (35): AppSnackbar, Color, showError, showInfo, _showSnackBar, showSuccess, showWarning, SizedBox (+27 more)

### Community 4 - "Windows Platform"
Cohesion: 0.08
Nodes (28): FlutterWindow(), OnCreate(), RegisterPlugins(), AppError, getMessage, requiresReLogin, wWinMain(), CreateAndAttachConsole() (+20 more)

### Community 5 - "Patient List UI"
Cohesion: 0.05
Nodes (37): build, _buildEmptyState, _buildError, _buildFilter, _buildFilterSection, _buildLoadingList, Center, _chip (+29 more)

### Community 6 - "Dashboard UI"
Cohesion: 0.06
Nodes (35): build, _buildEmptyVisits, _buildErrorState, _buildHeader, _buildHighPriorityList, _buildLiveBadge, _buildRoleBadge, _buildSectionHeader (+27 more)

### Community 7 - "Patient Detail UI"
Cohesion: 0.07
Nodes (26): build, _buildContent, _buildError, _buildVitals, canEdit, Center, _clinicalRow, Container (+18 more)

### Community 8 - "App Shell"
Cohesion: 0.08
Nodes (24): ../features/auth/auth_provider.dart, ../features/auth/login_screen.dart, ../features/dashboard/main_screen.dart, _AnimatedLogo, _AnimatedLogoState, AuthGate, build, dispose (+16 more)

### Community 9 - "Core Providers"
Cohesion: 0.16
Nodes (25): Error Message Handler, Snackbar Display Utility, Neumorphic Theme Configuration, Authentication Gate, Authenticated User State Model, Clinical Visit Entry Form, Network Connectivity Wrapper, Dashboard Main View (+17 more)

### Community 10 - "Patient Form UI"
Cohesion: 0.08
Nodes (23): AnimatedContainer, _bloodGroupDropdown, build, _buildSection, _consentCheckbox, _datePicker, didChangeDependencies, dispose (+15 more)

### Community 11 - "Clinical Entry"
Cohesion: 0.09
Nodes (22): build, _buildClinicalNotesSection, _buildOperationalTrackingSection, _buildPatientSelector, _buildSwitchRow, _buildVisitDetailsSection, _buildVitalsSection, ClinicalEntryScreen (+14 more)

### Community 12 - "Notifications"
Cohesion: 0.09
Nodes (20): addNotification, clearAll, dismiss, markAllRead, markOneRead, NotificationNotifier, build, Container (+12 more)

### Community 13 - "Settings & About"
Cohesion: 0.1
Nodes (20): AboutScreen, _AboutScreenState, build, _buildFeatureRow, _buildSectionCard, _buildSectionHeader, _buildTechChip, Chip (+12 more)

### Community 14 - "Document Upload"
Cohesion: 0.11
Nodes (18): build, _buildLoadingSlot, Column, _confirmDelete, DocumentUploadWidget, _DocumentUploadWidgetState, FullScreenImageViewer, GestureDetector (+10 more)

### Community 15 - "Realtime Data"
Cohesion: 0.11
Nodes (14): dispose, _handlePatientInsert, _handlePatientUpdate, _handleVisitUpdate, RealtimeService, subscribeToPatientChanges, AppNotification, copyWith (+6 more)

### Community 16 - "Linux Platform"
Cohesion: 0.13
Nodes (6): fl_register_plugins(), dispose, main(), my_application_activate(), my_application_dispose(), my_application_new()

### Community 17 - "Patient Domain"
Cohesion: 0.15
Nodes (14): DocumentNotifier, Document upload flow, DocumentUploadWidget, Patient CRUD operations, PatientDetailScreen, Patient filtering and sorting, PatientFormScreen, patient_list_provider (+6 more)

### Community 18 - "Cross-Platform Entry"
Cohesion: 0.17
Nodes (12): Android MainActivity, Android GeneratedPluginRegistrant, iOS AppDelegate, iOS GeneratedPluginRegistrant, Linux MyApplication, Linux GeneratedPluginRegistrant, LLDB RX Page Helper, macOS MainFlutterWindow (+4 more)

### Community 19 - "Connectivity"
Cohesion: 0.2
Nodes (9): build, ConnectivityWrapper, _ConnectivityWrapperState, Directionality, dispose, initState, SizedBox, _updateConnectionStatus (+1 more)

### Community 20 - "iOS AppDelegate"
Cohesion: 0.29
Nodes (2): AppDelegate, FlutterAppDelegate

### Community 21 - "macOS Window"
Cohesion: 0.33
Nodes (3): RegisterGeneratedPlugins(), MainFlutterWindow, NSWindow

### Community 22 - "Flutter Plugin Reg"
Cohesion: 0.4
Nodes (2): GeneratedPluginRegistrant, -registerWithRegistry

### Community 23 - "iOS Tests"
Cohesion: 0.4
Nodes (2): RunnerTests, XCTestCase

### Community 24 - "LLDB Helper"
Cohesion: 0.5
Nodes (2): handle_new_rx_page(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.

### Community 25 - "Local Notifications"
Cohesion: 0.67
Nodes (2): NotificationService, package:flutter_local_notifications/flutter_local_notifications.dart

### Community 26 - "Profile Screens"
Cohesion: 0.67
Nodes (3): AssistantProfileScreen, DoctorProfileScreen, ProfileNotifier

### Community 27 - "Windows Utils"
Cohesion: 0.67
Nodes (3): UTF-16 to UTF-8 Converter, Win32Window, Win32Window Theme Handler

### Community 28 - "Android Activity"
Cohesion: 1.0
Nodes (1): MainActivity

### Community 29 - "Notification UI"
Cohesion: 1.0
Nodes (2): AppNotification, NotificationSheet

### Community 30 - "Clinic Settings"
Cohesion: 1.0
Nodes (2): AboutScreen, ClinicSettingsNotifier

### Community 31 - "RBAC"
Cohesion: 1.0
Nodes (2): Role-based access control, Supabase RLS policies

### Community 32 - "Widget Tests"
Cohesion: 1.0
Nodes (2): MediFlowApp, MediFlow Widget Test

### Community 33 - "Gradle Config"
Cohesion: 1.0
Nodes (0): 

### Community 34 - "Settings Gradle"
Cohesion: 1.0
Nodes (0): 

### Community 35 - "App Build Config"
Cohesion: 1.0
Nodes (0): 

### Community 36 - "iOS Headers"
Cohesion: 1.0
Nodes (0): 

### Community 37 - "Bridging Header"
Cohesion: 1.0
Nodes (0): 

### Community 38 - "User Role Model"
Cohesion: 1.0
Nodes (0): 

### Community 39 - "Linux Header"
Cohesion: 1.0
Nodes (0): 

### Community 40 - "Linux App Header"
Cohesion: 1.0
Nodes (0): 

### Community 41 - "Win Flutter Header"
Cohesion: 1.0
Nodes (0): 

### Community 42 - "Resource Header"
Cohesion: 1.0
Nodes (0): 

### Community 43 - "Utils Header"
Cohesion: 1.0
Nodes (0): 

### Community 44 - "Win32 Header"
Cohesion: 1.0
Nodes (0): 

## Knowledge Gaps
- **419 isolated node(s):** `MainActivity`, `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `-registerWithRegistry`, `MediFlowApp`, `SystemUiOverlayStyle` (+414 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Android Activity`** (2 nodes): `MainActivity.kt`, `MainActivity`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Notification UI`** (2 nodes): `AppNotification`, `NotificationSheet`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Clinic Settings`** (2 nodes): `AboutScreen`, `ClinicSettingsNotifier`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `RBAC`** (2 nodes): `Role-based access control`, `Supabase RLS policies`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Widget Tests`** (2 nodes): `MediFlowApp`, `MediFlow Widget Test`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Gradle Config`** (1 nodes): `build.gradle.kts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Settings Gradle`** (1 nodes): `settings.gradle.kts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `App Build Config`** (1 nodes): `build.gradle.kts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `iOS Headers`** (1 nodes): `GeneratedPluginRegistrant.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Bridging Header`** (1 nodes): `Runner-Bridging-Header.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `User Role Model`** (1 nodes): `user_role.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Linux Header`** (1 nodes): `generated_plugin_registrant.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Linux App Header`** (1 nodes): `my_application.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Win Flutter Header`** (1 nodes): `generated_plugin_registrant.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Resource Header`** (1 nodes): `resource.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Utils Header`** (1 nodes): `utils.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Win32 Header`** (1 nodes): `win32_window.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter_riverpod/flutter_riverpod.dart` connect `State Management` to `Auth & Profile UI`, `Navigation & Routing`, `UI Components`, `Patient List UI`, `Dashboard UI`, `Patient Detail UI`, `App Shell`, `Patient Form UI`, `Clinical Entry`, `Notifications`, `Settings & About`, `Document Upload`?**
  _High betweenness centrality (0.165) - this node is a cross-community bridge._
- **Why does `package:flutter/material.dart` connect `UI Components` to `Auth & Profile UI`, `Navigation & Routing`, `Patient List UI`, `Dashboard UI`, `Patient Detail UI`, `App Shell`, `Patient Form UI`, `Clinical Entry`, `Notifications`, `Settings & About`, `Document Upload`, `Connectivity`?**
  _High betweenness centrality (0.154) - this node is a cross-community bridge._
- **Why does `package:mediflow/core/theme.dart` connect `App Shell` to `Auth & Profile UI`, `Navigation & Routing`, `UI Components`, `Patient List UI`, `Dashboard UI`, `Patient Detail UI`, `Patient Form UI`, `Clinical Entry`, `Settings & About`, `Document Upload`?**
  _High betweenness centrality (0.083) - this node is a cross-community bridge._
- **What connects `MainActivity`, `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `-registerWithRegistry` to the rest of the system?**
  _419 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Auth & Profile UI` be split into smaller, more focused modules?**
  _Cohesion score 0.04 - nodes in this community are weakly interconnected._
- **Should `State Management` be split into smaller, more focused modules?**
  _Cohesion score 0.07 - nodes in this community are weakly interconnected._
- **Should `Navigation & Routing` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._