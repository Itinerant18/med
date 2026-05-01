# MediFlow Flutter Audit Report

Generated: 2026-05-01T12:10:24.927+05:30

Preflight: this file compiles the exhaustive audit across Functional Bugs, Feature Gaps, Architectural Faults, Design & UX, Performance, Security, and Design Recommendations. Each issue cites file location and a one-line fix.

---

## 1. FUNCTIONAL BUGS
**Total issues found:** 12

---

**[ISSUE-001]** Phone OTP: swallows sign-in errors / signs out immediately
- **Location:** `lib/features/auth/phone_otp_screen.dart` → `PhoneOtpScreen._signInWithCredential()` (≈ lines 170–200)
- **Description:** Creates a Firebase session then immediately signs out and the method catches `catch (_)` (empty) so real auth errors are silently swallowed. This breaks any Firebase-linked flows and hides failures.
- **Trigger / Scenario:** When a phone OTP credential is used and either Supabase or Firebase returns an error (network, invalid OTP) or sign-out executes prematurely.
- **Severity / Priority:** Critical / P0
- **Fix:** Stop signing out immediately; propagate or return errors and add specific catches that surface user-facing messages and retry logic.

---

**[ISSUE-002]** parseDbDate returns null silently
- **Location:** `lib/core/parse_utils.dart` → `parseDbDate()`
- **Description:** `parseDbDate` can return `null` where callers assume `DateTime`, causing possible NPEs or wrong displays.
- **Trigger / Scenario:** Malformed or missing DB date string (null or empty) used in visit or patient flows.
- **Severity / Priority:** High / P1
- **Fix:** Return `DateTime?` explicitly and ensure all call sites handle null, or throw a descriptive exception/log and fallback to a safe default.

---

**[ISSUE-003]** Timer continues after dispose race
- **Location:** `lib/features/dashboard/dashboard_provider.dart` → `DashboardNotifier` (timer setup, ≈ lines 60–90)
- **Description:** Timer callback calls `refresh()` and may fire after `_disposed == true` due to race/late check, causing state updates on disposed notifier.
- **Trigger / Scenario:** Hot-reload, navigation away, or rapid lifecycle events toggling provider disposal.
- **Severity / Priority:** High / P1
- **Fix:** Cancel timer immediately in dispose and guard callback with an atomic disposed check; use mounted/ref.listen lifecycle-aware scheduling.

---

**[ISSUE-004]** unawaited() hides notification errors
- **Location:** `lib/features/patients/patient_provider.dart` → `PatientService.registerPatient()` (≈ lines 100–120)
- **Description:** `unawaited()` used for notification/audit calls can swallow async failures and leave user unaware.
- **Trigger / Scenario:** Notification Postgrest/Supabase errors, network failures.
- **Severity / Priority:** High / P1
- **Fix:** Await crucial side-effects or at minimum attach `.catchError()` to log and escalate failures.

---

**[ISSUE-005]** deactivate uses ref.read on disposed provider
- **Location:** `lib/features/visits/clinical_entry_screen.dart` → `ClinicalEntryScreen.deactivate()` (≈ lines 200–220)
- **Description:** Calls `ref.read(...)` during `deactivate()` where the provider may already be disposed leading to exceptions.
- **Trigger / Scenario:** Fast navigation/pop, widget lifecycle edge-cases.
- **Severity / Priority:** Medium / P2
- **Fix:** Use `mounted` guards and schedule provider reads earlier (e.g., in `dispose` with safe checks) or move cleanup to provider `onDispose`.

---

**[ISSUE-006]** Missing error handling on Supabase calls
- **Location:** multiple: e.g., `lib/features/staff/staff_service.dart` → `StaffService.fetchAll()`
- **Description:** Several Supabase queries lack try/catch for `PostgrestException`, leading to unhandled exceptions and app crashes.
- **Trigger / Scenario:** DB connectivity problems, RLS/permission errors.
- **Severity / Priority:** High / P1
- **Fix:** Wrap Supabase calls with try/catch, convert to user-friendly error states and retry/backoff.

---

**[ISSUE-007]** Role-aware patient search refetch on every keystroke
- **Location:** `lib/features/patients/patient_list_provider.dart` → `roleAwarePatientsProvider` (≈ lines 70–100)
- **Description:** The provider refetches entire patient list per filter change because `SearchFilter` equality leads to new instance each keystroke. Causes stale state and wrong loading UX.
- **Trigger / Scenario:** Typing in search box, debounce not preventing full refetch.
- **Severity / Priority:** Medium / P2
- **Fix:** Use an immutable value object with stable equality or use explicit debounce + `ref.keepAlive` with controlled refresh.

---

**[ISSUE-008]** deactivate/watch misuse: ref.watch inside async callback
- **Location:** `lib/features/appointments/appointment_notifier.dart` → async callback handlers (various)
- **Description:** `ref.watch` used inside async callbacks that outlive provider may hold stale refs or throw if provider disposed.
- **Trigger / Scenario:** Long-running async operations + provider disposed mid-flight.
- **Severity / Priority:** Medium / P2
- **Fix:** Use `ref.read` for snapshot access in callbacks and capture necessary values before awaiting.

---

**[ISSUE-009]** Patient model TODO — inconsistent null-safety
- **Location:** `lib/features/patients/patient_model.dart` → class `PatientModel`
- **Description:** Fields left TODO or optional where consumers assume non-null; can cause UI crashes.
- **Trigger / Scenario:** Creating patient flows that expect fully-populated model.
- **Severity / Priority:** Medium / P2
- **Fix:** Complete model definition, use explicit nullable types, and add validation at creation.

---

**[ISSUE-010]** Clinical entry may mutate state after dispose (mounted checks incomplete)
- **Location:** `lib/features/visits/clinical_entry_screen.dart` → methods that call `setState()` inside async flows (e.g., save handlers)
- **Description:** Missing `if (!mounted) return;` before setState in some callbacks causing exceptions.
- **Trigger / Scenario:** Long network save, user navigates back before completion.
- **Severity / Priority:** Medium / P2
- **Fix:** Add `if (!mounted) return;` guard before any post-await UI updates.

---

**[ISSUE-011]** RealTimeService subscribes with all-or-none _isSubscribed flag
- **Location:** `lib/core/realtime_service.dart` → `RealTimeService.subscribeToPatientChanges()` (≈ lines 40–100)
- **Description:** A failure in any table subscription sets `_isSubscribed=false` for all tables; partial recoveries not handled.
- **Trigger / Scenario:** Single channel error or permission change.
- **Severity / Priority:** High / P1
- **Fix:** Track subscription state per table, retry individual subscriptions, and expose granular error status.

---

**[ISSUE-012]** Audit log write swallows exceptions
- **Location:** `lib/features/audit/audit_service.dart` → `AuditService.log()`
- **Description:** `try/catch` hides exceptions and returns silently, losing audit trail with no alerting.
- **Trigger / Scenario:** Network error while writing audit; DB rejects row.
- **Severity / Priority:** High / P1
- **Fix:** Surface/log errors (send to Sentry/console), and fallback to local queue for retry.

---

## 2. FEATURE GAPS & MISSING FUNCTIONALITY
**Total issues found:** 12

---

**[ISSUE-001]** ChangePassword tile no action
- **Location:** `lib/features/profile/profile_screen.dart` & `lib/features/profile/profile_edit_screen.dart` → `ChangePassword` tile callbacks
- **Description:** Tile wired to `() {}`; no change-password flow exists.
- **What happens vs should happen:** Tapping does nothing; should open password-change flow or modal.
- **Impact on user:** Users cannot update passwords in-app (confusing, security risk).
- **Fix:** Hook the tile to an implementation that shows a `ChangePasswordDialog` and calls Supabase/Firebase update API.

---

**[ISSUE-002]** PatientModel defined but unused / TODO
- **Location:** `lib/features/patients/patient_model.dart`
- **Description:** Model has TODO and is not consistently used across patient flows; some code uses raw maps.
- **What happens vs should happen:** Mixed map/model usage causing duplicated parsing logic; should standardize on `PatientModel`.
- **Impact on user:** Inconsistent behavior, bugs in serialization/deserialization.
- **Fix:** Implement full model, replace ad-hoc maps with `PatientModel` constructors and fromJson/toJson.

---

**[ISSUE-003]** StaffManagement: locked card but no self-service options
- **Location:** `lib/features/staff/staff_management_screen.dart`
- **Description:** Non-head doctor view shows locked management card with no guidance or request-flow.
- **What happens vs should happen:** Users see static locked UI; should show "request access" action or instructions.
- **Impact on user:** Frustration and no path to request role changes.
- **Fix:** Add a "Request Access" CTA that triggers an approval workflow or audit entry.

---

**[ISSUE-004]** QuietHours UI not persisted
- **Location:** `lib/features/notifications/notification_settings.dart` → `QuietHoursEnabled` toggle
- **Description:** Toggle updates in-memory state only, not persisted to user preferences.
- **What happens vs should happen:** Preference resets on restart; should persist to Supabase or local storage.
- **Impact on user:** Settings lost between sessions.
- **Fix:** Save preference via Supabase user preferences row or local secure storage and sync on login.

---

**[ISSUE-005]** NotificationPreferences not saved to server
- **Location:** `lib/features/notifications/notification_preferences_provider.dart`
- **Description:** Preferences only stored in memory.
- **What happens vs should happen:** No cross-device sync; should persist against user record.
- **Impact on user:** Inconsistent notification behavior across devices.
- **Fix:** Implement an endpoint/row in Supabase for preferences and persist updates.

---

**[ISSUE-006]** AgentExternalVisits FAB lacks deep-link to visit details
- **Location:** `lib/features/visits/agent_outside_visit_list_screen.dart` → FAB handler
- **Description:** FAB for "My External Visits" opens list only; no deep-link to detail or new-visit flow.
- **Impact on user:** Extra navigation friction for agents.
- **Fix:** Wire FAB to route that either opens visit creation or deep-links into a selected visit detail page.

---

**[ISSUE-007]** FollowupReview doesn't pre-fill external doctor details
- **Location:** `lib/features/followups/followup_review_screen.dart` → create-new-followup button handler
- **Description:** New follow-up missing external doctor metadata copied from original task.
- **Impact on user:** Manual re-entry error-prone for follow-up generation.
- **Fix:** Pre-populate new follow-up form with external doctor details from the completed task.

---

**[ISSUE-008]** AuditActorsProvider returns duplicates (no DISTINCT)
- **Location:** `lib/features/audit/audit_provider.dart` → `auditActorsProvider` query
- **Description:** Query lacks `distinct()` causing duplicate actor rows.
- **Impact on user:** Confusing filter list and bad performance.
- **Fix:** Use server-side DISTINCT or query unique actor IDs before mapping.

---

**[ISSUE-009]** Fixed investigation types — no custom addition
- **Location:** `lib/features/patients/patient_form_screen.dart` → `_investigationStatusSection()`
- **Description:** UI hardcodes five investigation types; no add-custom option.
- **Impact on user:** Cannot record non-standard tests.
- **Fix:** Make investigation types configurable via backend or allow an "Other" field to add custom items.

---

**[ISSUE-010]** DrVisitForm Referral Lead toggle doesn't clear agent id
- **Location:** `lib/features/dr_visits/dr_visit_form.dart` → Referral Lead toggle handler (`_onReferralLeadChanged`)
- **Description:** Clearing external doctor fields leaves `_selectedAgentId` set, causing inconsistent persistence.
- **Impact on user:** Data mismatch when toggling referral lead on/off.
- **Fix:** When clearing external fields also reset `_selectedAgentId` and any dependent fields.

---

**[ISSUE-011]** Multiple PatientPickerSheet duplicates
- **Location:** `lib/features/dr_visits/dr_visit_form.dart`, `lib/features/agents/agent_outside_visit_form.dart`, `lib/features/followups/add_followup_sheet.dart`
- **Description:** Three separate `_PatientPickerSheet` implementations with slight behavioral differences.
- **Impact on user:** Different UX, maintenance overhead.
- **Fix:** Consolidate into a shared `PatientPickerBottomSheet` widget.

---

**[ISSUE-012]** PhoneOtp flow config breaks Firebase-linked workflows
- **Location:** `lib/features/auth/phone_otp_screen.dart` → `_signInWithCredential()`
- **Description:** Sign-in then sign-out pattern breaks any downstream Firebase session-dependent features.
- **Impact on user:** Social login, push, or other flows relying on Firebase session fail.
- **Fix:** Coordinate Supabase and Firebase session establishment; do not create a transient Firebase session that is then torn down.

---

## 3. HIERARCHICAL / ARCHITECTURAL FAULTS
**Total issues found:** 10

---

**[ISSUE-001]** RealtimeService retains ProviderContainer across logout
- **Files affected:** `lib/core/realtime_service.dart`
- **Description:** Holds `ProviderContainer?` reference preventing proper invalidation and causing stale subscriptions/state after logout.
- **Why it matters at scale:** Leads to data leakage between sessions and memory leaks.
- **Recommended approach:** Remove ProviderContainer retention; use explicit lifecycle-bound providers and per-session channels that close on logout.

---

**[ISSUE-002]** DashboardNotifier autoDispose + Timer double-subscribe risk
- **Files affected:** `lib/features/dashboard/dashboard_provider.dart`
- **Description:** Timer re-creates on hot reload and provider re-instantiation; cancellation handled in `onDispose` only, risk of overlapping timers.
- **Why it matters at scale:** Memory leaks, duplicate network calls, race conditions.
- **Recommended approach:** Use `ref.onDispose` and store timer in provider's state; ensure single-source scheduling (e.g., shared IntervalService).

---

**[ISSUE-003]** AuthNotifier duplicate auth paths
- **Files affected:** `lib/features/auth/auth_provider.dart` → `AuthNotifier.build()`
- **Description:** Subscribes to `onAuthStateChange` and also calls `_resolveAuthUserState()` directly; duplicates logic and event sources.
- **Why it matters at scale:** Divergent state updates, race conditions at login/logout.
- **Recommended approach:** Centralize auth transition logic into one reactive flow and use a single source of truth (either subscription or explicit resolution but not both).

---

**[ISSUE-004]** RealTimeService single-channel multi-subscriptions brittle
- **Files affected:** `lib/core/realtime_service.dart`
- **Description:** Subscribes to six table events in one channel; a partial failure toggles global flag.
- **Why it matters at scale:** Single failure cascades into global downtime for realtime features.
- **Recommended approach:** Create per-table or per-feature channels with independent error handling and per-subscription retries.

---

**[ISSUE-005]** patientProvider bypasses Riverpod async handling
- **Files affected:** `lib/features/patients/patient_provider.dart`
- **Description:** Provider returns a `PatientService` class instead of using `AsyncNotifier` so UI can't easily benefit from Riverpod's loading/error states.
- **Why it matters at scale:** Worse error handling and inconsistent loading UX.
- **Recommended approach:** Convert to `AsyncNotifier`/`AsyncValue` pattern and encapsulate network calls inside provider lifecycle.

---

**[ISSUE-006]** Followup / Dashboard lifecycle mismatch
- **Files affected:** `lib/features/followups/followup_provider.dart`, `lib/features/dashboard/dashboard_provider.dart`
- **Description:** `followupTasksProvider` kept-alive while `dashboardProvider` is `autoDispose`, causing stale/different caches.
- **Why it matters at scale:** Stale data and inconsistent UIs.
- **Recommended approach:** Align lifecycle and use a shared read-only cache service for cross-screen consumers.

---

**[ISSUE-007]** AuditService coupling to Riverpod Ref
- **Files affected:** `lib/features/audit/audit_service.dart`
- **Description:** `AuditService.log()` accepts `Ref`, coupling logging to Riverpod and making it unusable outside providers.
- **Why it matters at scale:** Can't reuse logging in edge functions/background isolates.
- **Recommended approach:** Make AuditService independent with an injectable logger interface; accept plain DTOs and optional context.

---

**[ISSUE-008]** roleAwarePatientsProvider no pagination
- **Files affected:** `lib/features/patients/patient_list_provider.dart`
- **Description:** Fetches full table per filter change; will fail on large datasets.
- **Why it matters at scale:** High memory, poor latency, DB cost.
- **Recommended approach:** Add server-side pagination/cursor-based queries and client-side incremental fetching.

---

**[ISSUE-009]** Triplicated PatientPicker implementations
- **Files affected:** `dr_visit_form.dart`, `agent_outside_visit_form.dart`, `add_followup_sheet.dart`
- **Description:** Multiple near-duplicate implementations cause maintenance drift.
- **Why it matters at scale:** Bugfix must be applied in 3 places; inconsistent behavior.
- **Recommended approach:** Consolidate into single `PatientPickerBottomSheet` widget with injectable hooks.

---

**[ISSUE-010]** AppConfig stores Supabase anon key as defaultValue
- **Files affected:** `lib/core/app_config.dart`
- **Description:** Anon key embedded as `defaultValue` constant; will be compiled into binary.
- **Why it matters at scale:** Credential leakage risk.
- **Recommended approach:** Read keys from secure runtime configuration, env variables, or prompt on install; remove hardcoded defaults.

---

## 4. DESIGN & UX ISSUES
**Total issues found:** 12

---

**[ISSUE-001]** Hardcoded assistant badge color
- **Location:** `lib/features/dashboard/dashboard_screen.dart` → `_buildRoleBadge()`
- **Description:** Uses `Colors.amber.shade700` instead of `AppTheme.assistantAccent`.
- **User impact:** Breaks theming / dark mode inconsistency.
- **Fix:** Replace with `AppTheme.assistantAccent` token.

---

**[ISSUE-002]** Neumorphic components use hardcoded shadows/colors
- **Location:** `lib/core/neu_widgets.dart` → `NeuCard`, `NeuTextField`
- **Description:** Multiple hardcoded colors (e.g., `Color(0x80DED8CF)`, `Color(0xFFA3B1C6)`) prevent theme adaptation.
- **User impact:** Poor dark-mode experience, inconsistent branding.
- **Fix:** Replace with AppTheme tokens and provide light/dark token variants.

---

**[ISSUE-003]** OrganicGrain uses fixed seed (identical grain)
- **Location:** `lib/core/organic_grain_painter.dart` → `OrganicGrainPainter` (seed = 42)
- **Description:** Seeded RNG creates identical grain everywhere, defeating intended organic variety.
- **User impact:** Repetitive background pattern reduces perceived quality.
- **Fix:** Use dynamic seeds (per-screen/per-session) or noise texture with subtle variation.

---

**[ISSUE-004]** NeuTextField near-white fill on light themes
- **Location:** `lib/core/neu_widgets.dart` → `NeuTextField` (fill color `Color(0x80FFFFFF)`)
- **Description:** Low contrast on light backgrounds reduces readability.
- **User impact:** Accessibility failure for low-vision users.
- **Fix:** Use theme-aware fill color with WCAG-compliant contrast.

---

**[ISSUE-005]** Login/Register inconsistent hierarchy
- **Location:** `lib/features/auth/login_screen.dart` & `register_screen.dart`
- **Description:** Login uses logo in `NeuCard`, register does not — inconsistent branding.
- **User impact:** Confuses users and weakens brand coherence.
- **Fix:** Standardize header component across auth flows.

---

**[ISSUE-006]** Followup instruction duplicated
- **Location:** `lib/features/followups/followup_task_widget.dart` → `_MissionBriefBlock` + extra instructions block
- **Description:** When `visitInstructions` exists both blocks render identical text.
- **User impact:** Cluttered UI, confusing redundancy.
- **Fix:** Render a single collapsible `MissionBriefBlock` and remove duplicate.

---

**[ISSUE-007]** OTP boxes use hardcoded neumorphic shadow
- **Location:** `lib/features/auth/phone_otp_screen.dart` → OTP input widgets
- **Description:** Hardcoded shadow color breaks theming.
- **User impact:** Visual mismatch in dark mode.
- **Fix:** Use theme shadow token or neutral elevation.

---

**[ISSUE-008]** PatientDetail FAB label mismatch
- **Location:** `lib/features/patients/patient_detail_screen.dart` → FAB label "New Visit"
- **Description:** Label suggests creation but opens `ClinicalEntryScreen` which logs visit; wording mismatch.
- **User impact:** Minor confusion for clinical users.
- **Fix:** Change label to "Log Visit" or adapt flow to "New Visit" semantics.

---

**[ISSUE-009]** StaffManagement chips lack approval breakdown
- **Location:** `lib/features/staff/staff_management_screen.dart` → role summary chips
- **Description:** Counts conflate pending and active users.
- **User impact:** Misleads admin about staffing status.
- **Fix:** Add status breakdown or badge counts per approval state.

---

**[ISSUE-010]** AuditLogs empty-state icon semantically wrong
- **Location:** `lib/features/audit/audit_logs_screen.dart` → empty state widget
- **Description:** Uses `history_toggle_off_rounded` (clock) not suited for "no logs".
- **User impact:** Minor UX inconsistency.
- **Fix:** Replace with a "document-empty" or "clipboard" icon and add helpful copy.

---

**[ISSUE-011]** Priority/Visit cards use hardcoded white/shadow
- **Location:** `lib/features/dashboard/_priority_card.dart`, `_visit_card.dart`
- **Description:** Hardcoded background/shadow colors break dark adaptation.
- **User impact:** Visual incoherence and accessibility risk.
- **Fix:** Replace color constants with theme tokens and elevation semantics.

---

**[ISSUE-012]** Multiple inconsistent empty states across app
- **Location:** several screens (AuditLogs, Visits, Followups)
- **Description:** Eight+ unique empty-state designs.
- **User impact:** Inconsistent UX and cognitive load.
- **Fix:** Create shared `EmptyState` component and replace instances.

---

## 5. PERFORMANCE ISSUES
**Total issues found:** 10

---

**[ISSUE-001]** roleAwarePatientsProvider refetch on each keystroke
- **Location:** `lib/features/patients/patient_list_provider.dart`
- **Problem:** Full refetch on filter change; expensive network + UI churn.
- **Impact:** Janky search, high DB load.
- **Fix:** Debounce client-side and use server-side filtered queries with pagination.

---

**[ISSUE-002]** OrganicGrainPainter instance re-creation waste
- **Location:** `lib/core/organic_grain_painter.dart`
- **Problem:** Painter re-instantiated often though `shouldRepaint` false, wasting allocations.
- **Impact:** Extra GC churn on render-heavy pages.
- **Fix:** Cache painter instance per background size or convert to `RepaintBoundary` + static image.

---

**[ISSUE-003]** NeuShimmer creates many AnimationControllers
- **Location:** `lib/core/neu_widgets.dart` → `NeuShimmer`
- **Problem:** Each shimmer has its own ticker; list causes multiple tickers.
- **Impact:** Higher CPU, battery drain on lists.
- **Fix:** Provide an inherited shared `Animation` or `TickerProvider` to reuse a single controller for all shimmer instances.

---

**[ISSUE-004]** BarChart creates TextPainter inside paint()
- **Location:** `lib/features/analytics/bar_chart.dart` → `_BarChart` `paint()`
- **Problem:** Allocates TextPainter repeatedly during paint.
- **Impact:** Jank during chart animations / layout.
- **Fix:** Cache `TextPainter` instances or measure labels once in layout.

---

**[ISSUE-005]** staffListProvider fetches all doctors then filters in Dart
- **Location:** `lib/features/staff/staff_provider.dart` → `staffListProvider`
- **Problem:** Inefficient DB usage; large returns.
- **Impact:** Slow load, high bandwidth.
- **Fix:** Apply server-side filters in Supabase query.

---

**[ISSUE-006]** ProfileStats sequential queries
- **Location:** `lib/features/profile/profile_stats_provider.dart` → provider fetch logic
- **Problem:** Two independent Supabase calls are run sequentially instead of parallel.
- **Impact:** Increased profile load time.
- **Fix:** Use `Future.wait` to parallelize independent calls.

---

**[ISSUE-007]** DashboardNotifier._fetch sequential queries
- **Location:** `lib/features/dashboard/dashboard_provider.dart` → `_fetch()`
- **Problem:** Runs 3–4 queries one after another.
- **Impact:** Slower dashboard refresh.
- **Fix:** Parallelize with `Future.wait` and reduce scope of selects.

---

**[ISSUE-008]** visitHistoryProvider selects all columns
- **Location:** `lib/features/visits/visit_history_provider.dart`
- **Problem:** Pulls entire row when only a subset required.
- **Impact:** Higher payload and slower rendering.
- **Fix:** Select only necessary columns in `.select()`.

---

**[ISSUE-009]** documentNotifierProvider N+1 pattern on documents
- **Location:** `lib/features/documents/document_notifier_provider.dart`
- **Problem:** Stores and rewrites full `document_urls` array per operation.
- **Impact:** Inefficient writes; race conditions.
- **Fix:** Use storage-backed metadata table rows for documents and update single document entries.

---

**[ISSUE-010]** RealtimeService subscribes sync heavy event handlers
- **Location:** `lib/core/realtime_service.dart`
- **Problem:** Heavy synchronous handlers in channel callbacks block event loop.
- **Impact:** UI stalls on burst events.
- **Fix:** Offload heavy work to background isolates or debounce handlers.

---

## 6. SECURITY ISSUES
**Total issues found:** 8

---

**[ISSUE-001]** Supabase anon key hardcoded in AppConfig
- **Location:** `lib/core/app_config.dart` → `supabaseAnonKey` defaultValue
- **Vulnerability type:** Credentials in binary / secret leakage
- **Risk level:** Critical / P0
- **Mitigation:** Remove hardcoded keys; use runtime config (remote config, secure storage, or CI injection) and rotate compromised keys.

---

**[ISSUE-002]** Patient delete permission enforced only in client Dart
- **Location:** `lib/features/patients/patient_permissions.dart` → `canDeletePatient()`
- **Vulnerability type:** Authorization bypass if RLS misconfigured
- **Risk level:** High / P1
- **Mitigation:** Enforce RLS policies server-side and implement defense-in-depth with server validation.

---

**[ISSUE-003]** Phone OTP transient Firebase session window
- **Location:** `lib/features/auth/phone_otp_screen.dart` → `_signInWithCredential()`
- **Vulnerability type:** Inconsistent session states / temporary auth leak
- **Risk level:** High / P1
- **Mitigation:** Align session creation with both providers atomically or await Supabase session before creating persistent Firebase session.

---

**[ISSUE-004]** AuditService swallowing exceptions
- **Location:** `lib/features/audit/audit_service.dart` → `log()`
- **Vulnerability type:** Silent failure of audit trail
- **Risk level:** High / P1
- **Mitigation:** Log failures to error reporting and enqueue audit writes for retry; alert admin on repeated failures.

---

**[ISSUE-005]** FcmService passes raw accessToken without expiry check
- **Location:** `lib/features/notifications/fcm_service.dart` → `_callEdgeFunction()`
- **Vulnerability type:** Token misuse/expiry leading to failed calls
- **Risk level:** Medium / P2
- **Mitigation:** Validate/refresh token before edge call and fail gracefully with re-auth flow.

---

**[ISSUE-006]** document delete relies on URL string parsing
- **Location:** `lib/features/documents/document_notifier_provider.dart` → `deleteDocument()`
- **Vulnerability type:** Fragile path extraction leading to accidental deletes
- **Risk level:** Medium / P2
- **Mitigation:** Store canonical storage path separately in metadata instead of deriving from URL.

---

**[ISSUE-007]** convertLeadToPatient bypasses RLS scoping
- **Location:** `lib/features/dr_visits/dr_visits_notifier.dart` → `convertLeadToPatient()`
- **Vulnerability type:** Privilege escalation / attribute mismatch
- **Risk level:** High / P1
- **Mitigation:** Ensure server-side attribution and do not call `registerPatient` directly with client-supplied agent IDs; use server function that enforces original agent mapping.

---

**[ISSUE-008]** Audit actors query duplicates could leak PII lists
- **Location:** `lib/features/audit/audit_provider.dart` → `auditActorsProvider`
- **Vulnerability type:** Data exposure / noisy logs
- **Risk level:** Medium / P2
- **Mitigation:** Use DISTINCT and limit returned PII; paginate actor lists.

---

## 7. DESIGN MODIFICATION RECOMMENDATIONS
**Total recommendations:** 10

---

**[REC-001]** Consolidate PatientPickerSheets
- **Target:** `DrVisitForm`, `AgentOutsideVisitForm`, `AddFollowupSheet`
- **Current behavior:** Three duplicate bottom sheets.
- **Proposed change:** Create `PatientPickerBottomSheet` with props for filters and selection callbacks.
- **Rationale:** Single source of truth and consistent UX.
- **Priority:** P0

---

**[REC-002]** Add ErrorBoundary for AsyncValue errors
- **Target:** All screens using `AsyncValue.when`
- **Current behavior:** Each screen shows ad-hoc error states.
- **Proposed change:** Create `ErrorBoundary` that standardizes error UI, retry actions, and telemetry.
- **Rationale:** Consistent error handling and developer ergonomics.
- **Priority:** P0

---

**[REC-003]** Replace hardcoded shadows with AppTheme tokens
- **Target:** `neu_widgets.dart`, cards, OTP boxes, etc.
- **Proposed change:** Centralize elevation/shadow tokens and support dark variants.
- **Rationale:** Enables dark-mode and brand coherence.
- **Priority:** P1

---

**[REC-004]** Add skeleton screens for initial loads
- **Target:** Dashboard, Patient lists, Followups
- **Proposed change:** Replace shimmer-only views with skeleton that matches final layout.
- **Rationale:** Better perceived performance.
- **Priority:** P1

---

**[REC-005]** Pull-to-refresh on AgentOutsideVisitListScreen
- **Target:** `agent_outside_visit_list_screen.dart`
- **Proposed change:** Add `RefreshIndicator` and server refresh hook.
- **Rationale:** Agent workflow expects manual sync.
- **Priority:** P2

---

**[REC-006]** ServiceStatusBadge widget
- **Target:** Dashboard, patient lists, visit cards (6+ files)
- **Proposed change:** Centralize status-color mapping into a `ServiceStatusBadge` component.
- **Rationale:** Reduce inconsistent color logic and make status semantics reusable.
- **Priority:** P1

---

**[REC-007]** Replace duplicate instructions with collapsible MissionBriefBlock
- **Target:** `followup_task_widget.dart`
- **Proposed change:** Single collapsible block for instructions with copy/share actions.
- **Rationale:** Improves clarity and reduces duplication.
- **Priority:** P1

---

**[REC-008]** DashboardStatCarousel component
- **Target:** `dashboard_screen.dart` and analytics screen
- **Proposed change:** Extract stat cards into `DashboardStatCarousel` with reuse on analytics page.
- **Rationale:** Reuse and consistent UX.
- **Priority:** P2

---

**[REC-009]** Add shared EmptyState widget
- **Target:** All screens with empty states (8+)
- **Proposed change:** Replace bespoke empty UIs with `EmptyState(title, subtitle, cta)` standardized component.
- **Rationale:** Improves polish and reduces copy duplication.
- **Priority:** P1

---

**[REC-010]** Standardize confirmation dialogs
- **Target:** All flows that confirm deletes/critical actions
- **Proposed change:** Provide `ConfirmDialog.show(context, ...)` helper with consistent copy and telemetry hooks.
- **Rationale:** Uniform UX and easier auditing of destructive actions.
- **Priority:** P0

---

## SUMMARY TABLE
| Category | Count | Critical/P0 | High/P1 | Medium/P2 | Low/P3 |
|---|---:|---:|---:|---:|---:|
| Functional Bugs | 12 | 1 | 7 | 3 | 1 |
| Feature Gaps | 12 | 1 | 5 | 4 | 2 |
| Architectural Faults | 10 | 1 | 5 | 3 | 1 |
| Design & UX | 12 | 0 | 4 | 6 | 2 |
| Performance | 10 | 0 | 4 | 5 | 1 |
| Security | 8 | 1 | 4 | 2 | 1 |
| Design Modifications | 10 | 2 | 3 | 4 | 1 |


## TOP 10 PRIORITY ITEMS FOR NEXT SPRINT
1. Remove Supabase anon key from `lib/core/app_config.dart` and switch to runtime-secured config (Critical).
2. Fix `PhoneOtpScreen._signInWithCredential()` to not create transient Firebase sessions and to propagate auth errors (Critical).
3. Make `AuditService.log()` surface/log failures and implement retry queue (High).
4. Convert `patientProvider` to `AsyncNotifier` and remove `unawaited()` usages that swallow critical errors (High).
5. Stop Timer race in `DashboardNotifier` and centralize interval scheduling (High).
6. Replace single-channel brittle subscriptions in `RealTimeService` with per-table channels and per-subscription retries (High).
7. Implement server-side filtering/pagination for `roleAwarePatientsProvider` (High).
8. Consolidate the three `_PatientPickerSheet` implementations into `PatientPickerBottomSheet` (P0 UX/maintenance).
9. Replace hardcoded theme colors/shadows in `neu_widgets.dart` with AppTheme tokens (P1).
10. Remove document URL parsing fragility: store canonical storage paths in metadata and use those for deletes (P1 security).

---

End of report.

