cat > /home/claude/mediflow_fix_guide.md << 'ENDOFFILE'

# MediFlow — Sprint Fix Playbook

## Tool-by-Tool Prompts for Every Issue in the Audit Report

---

## TOOL SELECTION LOGIC

| Tool | Model | Best for |
|------|-------|---------|
| **Claude Code** (terminal) | claude-sonnet-4-5 | Multi-file refactors, architecture changes, automated test runs, complex Dart rewrites with full repo context |
| **Claude.ai chat** (Sonnet 4.5) | claude-sonnet-4-5 | Single-file fixes, logic bugs, explaining what to change and why, generating replacement code snippets |
| **Gemini 2.5 Pro** (in AI Studio) | gemini-2.5-pro | Large context analysis (paste entire files), performance pattern review, security audit cross-check |
| **Claude Haiku 3.5** | claude-haiku-3-5 | Fast mechanical fixes: rename tokens, swap icon names, find/replace color constants across many files |

**Rule of thumb:**

- **Crashes / async bugs / architecture** → Claude Code (has full repo, can run `flutter analyze`)
- **Single function rewrite** → Claude.ai Sonnet
- **Security/performance review** → Gemini 2.5 Pro (large context window)
- **Token/color replacement sweep** → Haiku (cheap, fast, pattern matching)

---

## PHASE 1 — CRITICAL / P0 FIXES (Do these first, in order)

---

### FIX-C1 · Remove hardcoded Supabase anon key

**Issue:** SEC-001 + ARCH-010  
**Tool:** Claude Code  
**Model:** claude-sonnet-4-5  

**Open Claude Code in your repo root, then run:**

```
I need you to fix a critical security issue in our Flutter app.

PROBLEM:
`lib/core/app_config.dart` has a hardcoded Supabase anon key as a `defaultValue` in a `String.fromEnvironment()` call. This gets compiled into the APK binary.

WHAT TO DO:
1. Remove the `defaultValue` parameter from both `supabaseUrl` and `supabaseAnonKey` in `AppConfig`.
2. Create a `scripts/check_config.sh` bash script that fails CI if either constant resolves to empty string at build time.
3. Update `README.md` with a section "Build Configuration" explaining how to pass `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` at build time.
4. Create a `.env.example` file at project root with placeholder keys.
5. Add `.env` to `.gitignore` if not already present.
6. Run `flutter analyze` and confirm no compile errors.

Do NOT add any new dependencies. Use only what already exists.
```

---

### FIX-C2 · Fix PhoneOTP credential sign-in / error swallowing

**Issue:** BUG-001 + FEAT-012 + SEC-003  
**Tool:** Claude.ai Sonnet  
**Model:** claude-sonnet-4-5  

**Paste the full contents of `lib/features/auth/phone_otp_screen.dart` into Claude.ai and send this prompt:**

```
You are a Flutter/Firebase/Supabase expert. I'm sharing `phone_otp_screen.dart` from our app.

PROBLEMS TO FIX (all in `_signInWithCredential()`):
1. The method creates a real Firebase Auth session then immediately calls `await FirebaseAuth.instance.signOut()` with a bare `catch (_)` that swallows all errors. This creates a timing window where Firebase session exists without Supabase session, and hides real auth failures from the user.
2. If the credential is invalid the user sees nothing.

WHAT TO DO:
1. Remove the `try/catch (_)` that silently eats errors from `signInWithCredential`.
2. The purpose of this Firebase sign-in is ONLY to verify the phone number (OTP). After the OTP is confirmed valid, do NOT create a persistent Firebase session. Use `PhoneAuthProvider.credential()` purely for verification without calling `FirebaseAuth.instance.signInWithCredential()`.
3. If the phone verification truly needs a Firebase credential internally, sign out immediately BUT surface any error from `signOut` to debugPrint at minimum.
4. Add proper error handling: if `signInWithCredential` throws a `FirebaseAuthException`, surface it via the existing `_friendlyError()` method.
5. The `onVerified` callback should only be called after successful verification with no pending errors.

Return the complete rewritten `_signInWithCredential()` method and `_verifyOtp()` method.
```

---

### FIX-C3 · Fix ConfirmDialog — standardize destructive action dialogs

**Issue:** REC-010  
**Tool:** Claude Code  
**Model:** claude-sonnet-4-5  

```
Create a shared `ConfirmDialog` utility in our Flutter app (MediFlow) that replaces the 6+ bespoke AlertDialog implementations across screens.

STEP 1 — Create `lib/core/confirm_dialog.dart`:
- Static `Future<bool> show(BuildContext context, { required String title, required String body, String confirmLabel = 'Confirm', String cancelLabel = 'Cancel', bool isDangerous = false })` method.
- If `isDangerous` is true, the confirm button uses `AppTheme.errorColor` text.
- Uses `RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))` to match existing alert styling.
- Returns `false` if user taps outside or presses cancel.

STEP 2 — Find and replace all occurrences:
Search for `showDialog` + `AlertDialog` in these files and replace with `ConfirmDialog.show()`:
- `lib/features/patients/patient_detail_screen.dart` → `_confirmDelete()`
- `lib/features/staff/staff_management_screen.dart` → `_confirmAction()`
- `lib/features/dashboard/main_screen.dart` → `_confirmLogout()`
- `lib/features/dr_visits/dr_visit_detail_screen.dart` → the "Mark Not Interested" dialog
- `lib/features/approval/pending_approvals_screen.dart` → `_showRejectDialog()` (keep the text field — just replace the wrapper)

STEP 3 — Run `flutter analyze` and fix any errors.
```

---

## PHASE 2 — HIGH PRIORITY / P1 FIXES

---

### FIX-H1 · Fix DashboardNotifier timer race condition

**Issue:** BUG-003 + ARCH-002  
**Tool:** Claude.ai Sonnet  
**Model:** claude-sonnet-4-5  

**Paste `lib/features/dashboard/dashboard_provider.dart` and send:**

```
Fix the timer race condition in `DashboardNotifier` in this Flutter Riverpod provider.

PROBLEMS:
1. `_timer` is created in `build()`. On hot-reload or provider re-instantiation a new timer is created before the old one is cancelled in `onDispose`, causing overlapping timers and duplicate network calls.
2. The timer callback checks `if (_disposed) return;` but `_disposed` is set in `onDispose` which may run AFTER the timer fires — not truly atomic.
3. `_disposed` is a plain bool field, not synchronized.

WHAT TO DO:
1. Move timer creation INSIDE `ref.onDispose` pattern — create the timer then immediately register its cancel in `ref.onDispose`:
   ```dart
   final timer = Timer.periodic(...);
   ref.onDispose(timer.cancel);
   ```

2. Remove the manual `_timer` field and `_disposed` field entirely — `ref.onDispose` guarantees the cancel runs before any new `build()`.
2. In the timer callback, use a local `bool cancelled = false` closure variable that the `onDispose` sets, rather than a class-level field.
3. Ensure `refresh()` guards against concurrent calls with a flag or by checking `state.isLoading`.

Return the complete rewritten `DashboardNotifier` class.

```

---

### FIX-H2 · Fix AuditService — surface failures, add retry queue
**Issue:** BUG-012 + ARCH-007 + SEC-004  
**Tool:** Claude Code  
**Model:** claude-sonnet-4-5  

```

Fix `lib/features/audit/audit_provider.dart` → `AuditService.log()`.

CURRENT PROBLEM:
The entire method body is wrapped in `try { ... } catch (_) {}` — all audit failures are silently swallowed. Also, `log()` requires a `Ref` parameter coupling it tightly to Riverpod.

WHAT TO DO:

1. Create a standalone `AuditLogger` class in `lib/core/audit_logger.dart` that:
   - Has an in-memory queue `List<Map<String,dynamic>> _pendingLogs = []`
   - Has a static `SupabaseClient` getter (reads from `Supabase.instance.client`)
   - Has `static Future<void> log({required String actorId, required String actorName, required String actorRole, required String action, required String targetTable, String? targetId, String? description, Map<String,dynamic>? oldData, Map<String,dynamic>? newData})` — no Ref parameter
   - Tries to write to `audit_logs` table; on failure, adds to `_pendingLogs` and calls `debugPrint('[AuditLogger] FAILED: $e — queued for retry')`
   - Has `static Future<void> flushQueue()` that retries all pending logs and clears on success

2. Update `AuditService.log()` in `audit_provider.dart` to call `AuditLogger.log(...)` and forward all params. Keep backward compatibility.

3. Update every call site that passes `ref` to `AuditService.log(ref, ...)`:
   - `lib/features/patients/patient_provider.dart`
   - `lib/features/staff/staff_provider.dart`
   - Remove the `ref` argument since `AuditLogger` no longer needs it.

4. Call `AuditLogger.flushQueue()` in `AuthNotifier.signIn()` after successful sign-in (so queued logs from the previous session flush on next login).

5. Run `flutter analyze`.

```

---

### FIX-H3 · Fix unawaited errors in PatientService
**Issue:** BUG-004  
**Tool:** Claude.ai Sonnet  
**Model:** claude-sonnet-4-5  

**Paste `lib/features/patients/patient_provider.dart` and send:**

```

Fix unsafe `unawaited()` usage in `PatientService`.

PROBLEM:
`unawaited(_triggerStatusNotification(...))` means any exception from the notification call is completely lost — no log, no retry, no user feedback.

WHAT TO DO:

1. Replace `unawaited(_triggerStatusNotification(...))` with a proper fire-and-forget that at minimum logs errors:

   ```dart
   _triggerStatusNotification(...).catchError((e) {
     debugPrint('[PatientService] notification failed: $e');
   });
   ```

2. Similarly wrap the `AuditService.log(...)` call inside `updatePatient` — it currently has no error handling.
3. Do NOT change the method signatures or make these calls blocking — they should remain non-blocking but must not silently swallow errors.

Return the fixed `registerPatient()` and `updatePatient()` methods only.

```

---

### FIX-H4 · Fix RealTimeService per-table subscription resilience
**Issue:** BUG-011 + ARCH-004  
**Tool:** Claude Code  
**Model:** claude-sonnet-4-5  

```

Refactor `lib/core/realtime_service.dart` to use per-table channels instead of one channel for all subscriptions.

CURRENT PROBLEM:
All 6 table subscriptions share a single `_channel`. If any one fails, `_isSubscribed = false` for everything. There is no per-table retry.

WHAT TO DO:

1. Replace the single `RealtimeChannel? _channel` with a `Map<String, RealtimeChannel> _channels = {}` keyed by table name.

2. Create a private `_subscribeTable(String tableName, PostgresChangeEvent event, void Function(PostgresChangePayload) callback)` helper that:
   - Creates a new channel named `'mediflow:$tableName:${userId}'`
   - Sets up the `.onPostgresChanges()` listener
   - Calls `.subscribe()` with a status callback that retries after 5 seconds on error using `Future.delayed`
   - Stores the channel in `_channels[tableName]`

3. Rewrite `subscribeToPatientChanges()` to call `_subscribeTable()` 6 times (once per table: patients INSERT, patients UPDATE, visits UPDATE, dr_visits INSERT, followup_tasks INSERT, followup_tasks UPDATE).

4. Update `dispose()` to iterate `_channels.values` and call `.unsubscribe()` on each, then clear the map.

5. Remove the global `_isSubscribed` flag — it's no longer meaningful. Replace with `bool get isFullySubscribed => _channels.length == 6`.

6. Keep all existing callback handler methods (`_handlePatientUpdate`, `_handleDrVisitInsert`, etc.) unchanged.

Run `flutter analyze` after.

```

---

### FIX-H5 · Fix missing Supabase error handling
**Issue:** BUG-006  
**Tool:** Gemini 2.5 Pro (AI Studio)  
**Model:** gemini-2.5-pro  

**Why Gemini here:** Large context — paste multiple provider files at once.

```

You are a Flutter/Supabase expert. I'm sharing multiple Dart provider files from a Flutter app.

TASK:
Find every Supabase query (calls to `.from()`, `.select()`, `.insert()`, `.update()`, `.delete()`, `.rpc()`) that is NOT wrapped in a try/catch block catching `PostgrestException`.

For each one found:

1. Show the file name and method name.
2. Show the current code.
3. Show the fixed code with proper try/catch that catches `PostgrestException` and rethrows a user-friendly `Exception('...')` using the pattern already in `lib/core/error_handler.dart` → `AppError.getMessage(e)`.

Files to audit:
[PASTE THE CONTENTS OF THESE FILES:]

- lib/features/staff/staff_provider.dart
- lib/features/patients/patient_provider.dart  
- lib/features/followups/followup_provider.dart
- lib/features/dr_visits/dr_visit_provider.dart
- lib/features/analytics/analytics_provider.dart

Only fix unhandled calls. Don't change already-wrapped calls.

```

---

### FIX-H6 · Fix PatientService → convert to AsyncNotifier
**Issue:** ARCH-005  
**Tool:** Claude Code  
**Model:** claude-sonnet-4-5  

```

Refactor `lib/features/patients/patient_provider.dart`.

CURRENT PROBLEM:
`patientProvider` is a plain `Provider<PatientService>` returning a service class. This bypasses Riverpod's AsyncValue loading/error state machine. UI consumers can't show loading or error states from patient operations without manual state tracking.

WHAT TO DO:

1. Keep `PatientService` class as-is — it's a service object, not state.
2. Instead of changing patientProvider (which would require 20+ call site updates), create a new `AsyncNotifier` called `PatientOperationsNotifier` that wraps the critical mutating operations:
   - `registerPatient(Map data)` → sets `state = AsyncLoading()` before, `AsyncData(patientId)` or `AsyncError` after
   - `updatePatient(String id, Map data)` → same pattern
   - `deletePatient(String id)` → same pattern
3. Create `final patientOperationsProvider = AsyncNotifierProvider<PatientOperationsNotifier, void>(...)`.
4. Update `PatientFormScreen._submitForm()` and `PatientDetailScreen._confirmDelete()` to use `patientOperationsProvider.notifier` instead of `patientProvider`.
5. Keep `patientProvider` and `patientDetailProvider` exactly as-is for reads — only writes move to the new notifier.
6. Run `flutter analyze`.

```

---

### FIX-H7 · Fix ProfileStats and Dashboard sequential queries
**Issue:** PERF-006 + PERF-007  
**Tool:** Claude Haiku 3.5 (fast mechanical fix)  
**Model:** claude-haiku-3-5  

**Paste both files and send:**

```

I have two Dart Riverpod provider files. In each, Supabase queries are run sequentially with multiple `await` calls one after another. Replace them with `Future.wait([...])` to run them in parallel.

FILE 1: lib/features/profile/profile_provider.dart → `profileStatsProvider`
Current pattern:
  final visitsRes = await supabase.from('visits')...
  final patientsRes = await supabase.from('patients')...

Replace with:
  final results = await Future.wait([
    supabase.from('visits')...,
    supabase.from('patients')...,
  ]);
  final visitsRes = results[0];
  final patientsRes = results[1];

FILE 2: lib/features/dashboard/dashboard_provider.dart → `DashboardNotifier._fetch()`
Find all sequential `await supabase.from(...)` calls that are independent of each other and wrap in a single `Future.wait([...])`.

Return only the changed method bodies for each file. Preserve all existing logic.

```

---

## PHASE 3 — ARCHITECTURAL REFACTORS

---

### FIX-A1 · Consolidate PatientPickerBottomSheet
**Issue:** ARCH-009 + FEAT-011 + REC-001  
**Tool:** Claude Code  
**Model:** claude-sonnet-4-5  

```

Three files in our Flutter app each have a private `_PatientPickerSheet` widget with nearly identical implementations. Consolidate them into one shared widget.

DUPLICATE LOCATIONS:

1. `lib/features/dr_visits/dr_visit_form.dart` → `_PatientPickerSheet`
2. `lib/features/agent_visits/agent_outside_visit_form.dart` → `_PatientPickerSheet`
3. `lib/features/followups/add_followup_sheet.dart` → `_PatientPickerSheet`

STEP 1 — Create `lib/widgets/patient_picker_bottom_sheet.dart`:

- A `ConsumerStatefulWidget` called `PatientPickerBottomSheet`
- Constructor: `const PatientPickerBottomSheet({super.key, this.title = 'Select Patient'})`
- Returns `Map<String,dynamic>? result` via `Navigator.pop(context, {'id': ..., 'name': ...})`
- Uses `roleAwarePatientsProvider` with `SearchFilter` (same as all three current implementations)
- Has a search `NeuTextField` and `ListView` result list — identical to the current best implementation
- Uses `SizedBox(height: MediaQuery.of(context).size.height * 0.8)`

STEP 2 — Create a static helper `PatientPickerBottomSheet.show(BuildContext context)` that shows the sheet as a `showModalBottomSheet` and returns the selected map.

STEP 3 — Replace all three private sheet implementations:

- In each of the 3 files, delete the private `_PatientPickerSheet` class
- Replace the `showModalBottomSheet(...builder: (_) => const _PatientPickerSheet())` call with `PatientPickerBottomSheet.show(context)`
- Update the `.then((result) { ... })` handler — the callback signature stays the same

STEP 4 — Run `flutter analyze` and fix import errors.

```

---

### FIX-A2 · Fix AuthNotifier duplicate auth paths
**Issue:** ARCH-003  
**Tool:** Claude.ai Sonnet  
**Model:** claude-sonnet-4-5  

**Paste `lib/features/auth/auth_provider.dart` and send:**

```

The `AuthNotifier.build()` method in this file has two divergent auth paths:

1. It subscribes to `_supabase.auth.onAuthStateChange` stream and calls `_resolveAuthUserState(event.session)` in the listener.
2. It ALSO directly calls `_resolveAuthUserState(_supabase.auth.currentSession)` at the end of `build()`.

PROBLEMS:

- Two paths can emit different states, causing race conditions especially at login/logout.
- The `_resolveAuthUserState` can be called twice on initial load.

WHAT TO DO:

1. Keep the stream subscription as the single source of truth for auth transitions.
2. The initial call at the end of `build()` is correct for loading the current session on app start — keep it, but wrap it so its result is only used if the stream hasn't emitted yet.
3. Add a `bool _streamHasEmitted = false` flag. In the stream listener, set it to `true` before updating state. In the initial `build()` call, only set state from the direct `_resolveAuthUserState` call if `!_streamHasEmitted`.
4. Ensure FCM token sync (`_syncFcmToken()`) is only called once per sign-in event — remove the duplicate call at the bottom of `build()` and keep only the one inside the `AuthChangeEvent.signedIn` branch.

Return the rewritten `build()` method only.

```

---

### FIX-A3 · Fix RealtimeService ProviderContainer retention
**Issue:** ARCH-001  
**Tool:** Claude.ai Sonnet  
**Model:** claude-sonnet-4-5  

**Paste `lib/core/realtime_service.dart` and send:**

```

`RealtimeService` holds a `ProviderContainer? _container` reference. This is retained across logout/login cycles, causing stale state and memory leaks.

PROBLEMS:

1. After logout, the old container is still referenced. New login may re-subscribe with stale container.
2. `subscribeToPatientChanges()` checks `_currentDoctorName == currentDoctorName` to avoid re-subscribing, but the container may be from the previous session.

WHAT TO DO:

1. In `dispose()`, set `_container = null` explicitly — already done, good.
2. In `subscribeToPatientChanges()`, remove the early return that skips re-subscribing when `_currentDoctorName` matches. Always update `_container` to the passed container, even if already subscribed. The subscription itself is idempotent if the doctor name matches.
3. Add a check: if `_container != null && _container != container` (a different container is being passed, meaning a new login session), call `dispose()` first before re-subscribing.
4. Update the `_addInAppNotification` method to do a null check on `_container` and use `try/catch` around the container read — if it throws because the container was disposed, log and return silently.

Return the complete rewritten `RealtimeService` class.

```

---

### FIX-A4 · Add server-side pagination to roleAwarePatientsProvider
**Issue:** ARCH-008 + PERF-001 + BUG-007  
**Tool:** Claude Code  
**Model:** claude-sonnet-4-5  

```

Implement server-side filtering and pagination in `lib/features/patients/patient_list_provider.dart`.

CURRENT PROBLEM:
`roleAwarePatientsProvider` fetches ALL patients from Supabase then filters/sorts in Dart. With 500+ patients this will be slow and expensive.

WHAT TO DO:

1. Add a `page` parameter to `SearchFilter`:

   ```dart
   class SearchFilter {
     final int page; // default 0
     final int pageSize; // default 30
     // ... existing fields
   }
   ```

2. Rewrite the Supabase query in `roleAwarePatientsProvider` to:
   - Apply `.ilike('full_name', '%$query%')` when `query` is not empty (server-side name search)
   - Apply `.eq('health_scheme', scheme)` when healthScheme != all
   - Apply `.eq('is_high_priority', true)` when priority == highOnly
   - Apply `.gte('last_updated_at', cutoffDate.toIso8601String())` for date ranges
   - Apply `.range(page * pageSize, (page + 1) * pageSize - 1)` for pagination

3. Keep the Dart-side `_matchesFilter` as a fallback for visit type filter (which requires a join to the visits table — leave that for a future migration).

4. In `PatientListScreen`, add a `_page` state variable and a "Load More" button at the bottom of the list that increments `_page` and re-triggers the provider with the new filter.

5. Update `SearchFilter.copyWith()` to include `page` and `pageSize`.

6. Run `flutter analyze`.

```

---

## PHASE 4 — FEATURE GAPS

---

### FIX-F1 · Wire ChangePassword tile
**Issue:** FEAT-001  
**Tool:** Claude.ai Sonnet  
**Model:** claude-sonnet-4-5  

**Paste both profile screens and `change_password_sheet.dart`, then send:**

```

In both `lib/features/profile/doctor_profile_screen.dart` and `lib/features/profile/assistant_profile_screen.dart`, the "Change Password" list tile has an empty `onTap: () {}` callback.

The `ChangePasswordSheet` widget already exists in `lib/features/profile/change_password_sheet.dart`.

WHAT TO DO:

1. In both profile screens, find the "Change Password" `_tile()` / `ListTile` widget.
2. Replace the `() {}` callback with:

   ```dart
   () => showModalBottomSheet<void>(
     context: context,
     isScrollControlled: true,
     backgroundColor: AppTheme.bgColor,
     shape: const RoundedRectangleBorder(
       borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
     ),
     builder: (_) => const ChangePasswordSheet(),
   )
   ```

3. Also fix `main_screen.dart` → `_openChangePassword()` — check if this is already wired; if the method exists but isn't called from the drawer "Change Password" item, wire it.

Return only the changed lines for each file.

```

---

### FIX-F2 · Persist QuietHours and NotificationPreferences
**Issue:** FEAT-004 + FEAT-005  
**Tool:** Claude Code  
**Model:** claude-sonnet-4-5  

```

Notification preferences and quiet hours settings are lost when the app restarts. Persist them using `shared_preferences`.

STEP 1 — Add `shared_preferences` to `pubspec.yaml` if not already present.

STEP 2 — Create `lib/core/preferences_service.dart`:

```dart
class PreferencesService {
  static const _quietHoursKey = 'pref_quiet_hours_enabled';
  static const _notifCategoryPrefix = 'pref_notif_';

  static Future<bool> getQuietHours() async { ... }
  static Future<void> setQuietHours(bool value) async { ... }
  static Future<Map<String, bool>> getNotifCategories() async { ... }
  static Future<void> setNotifCategory(String category, bool value) async { ... }
}
```

STEP 3 — Update `lib/core/notification_provider.dart`:

- In `NotificationPreferencesNotifier.build()`, load initial state from `PreferencesService.getNotifCategories()` (make `build` async).
- In `setCategoryEnabled()`, also call `await PreferencesService.setNotifCategory(category, enabled)`.

STEP 4 — Update `lib/features/profile/notification_preferences_screen.dart`:

- In the `quietHoursEnabledProvider`, initialize from `PreferencesService.getQuietHours()`.
- On toggle, call `PreferencesService.setQuietHours(value)`.

STEP 5 — In `AuthNotifier` (after sign-in), load preferences from local storage and push them into providers.

Run `flutter analyze` and `flutter pub get`.

```

---

### FIX-F3 · Fix AuditActors duplicates (DISTINCT)
**Issue:** FEAT-008  
**Tool:** Claude Haiku 3.5  
**Model:** claude-haiku-3-5  

```

In `lib/features/audit/audit_provider.dart`, the `auditActorsProvider` FutureProvider fetches actor data with duplicates.

Current query:
  var query = supabase.from('audit_logs').select('actor_id, actor_name');

PROBLEM: Multiple audit log rows for the same actor return duplicate entries. The current code deduplicates in Dart with a `Set<String> seen` which works but is inefficient.

FIX:
The Dart deduplication is actually fine since Supabase's PostgREST doesn't expose DISTINCT directly. But the query fetches ALL rows just to get unique actor names — this is an N×M waste.

Replace with:

1. Add `.limit(1000)` to bound the query size.
2. Add `.order('actor_name')` so the Dart dedup keeps the alphabetically first entry per actor.
3. Add a comment explaining why server-side DISTINCT isn't used.

Also: the `auditActorsProvider` currently loads on every filter sheet open. Add `.autoDispose` with a `keepAlive` duration of 5 minutes using `ref.keepAlive()`.

Return only the changed `auditActorsProvider` provider body.

```

---

### FIX-F4 · Fix DrVisitForm referral lead toggle clears agent ID
**Issue:** FEAT-010  
**Tool:** Claude Haiku 3.5  
**Model:** claude-haiku-3-5  

```

In `lib/features/dr_visits/dr_visit_form.dart`, the referral lead toggle `Switch` onChange handler clears external doctor fields when switching off, but forgets to reset `_selectedAgentId`.

Find this in the Switch `onChanged`:

```dart
onChanged: (value) {
  setState(() {
    _isExternal = value;
    if (!value) {
      _extNameCtrl.clear();
      _extSpecCtrl.clear();
      // ...
    } else {
      _selectedPatientId = null;
      _selectedPatientName = null;
    }
  });
},
```

FIX: When `!value` (switching referral off), also add:

```dart
_selectedAgentId = null;
```

When `value` (switching referral ON), also clear:

```dart
_selectedPatientId = null;
_selectedPatientName = null;
```

(this part may already be there — confirm and keep it)

Return only the `onChanged` closure body.

```

---

### FIX-F5 · FollowupReview pre-fill external doctor details
**Issue:** FEAT-007  
**Tool:** Claude.ai Sonnet  
**Model:** claude-sonnet-4-5  

**Paste `lib/features/followups/followup_review_screen.dart` and `lib/features/followups/add_followup_sheet.dart`, then send:**

```

In `FollowupReviewScreen`, the "Create new follow-up from this" button opens `AddFollowupSheet` but passes only `preselectedPatientId` and `preselectedPatientName`. It doesn't pre-fill the external doctor details from the completed task.

WHAT TO DO:

1. `AddFollowupSheet` already accepts `targetExtDoctorName`, `targetExtDoctorHospital`, etc. as constructor parameters — check if they exist; if not, add them.
2. In `FollowupReviewScreen._chainFollowup(FollowupTask task)`, update the `showModalBottomSheet` builder to pass the task's target doctor fields to `AddFollowupSheet`:

   ```dart
   builder: (_) => AddFollowupSheet(
     preselectedPatientId: task.patientId,
     preselectedPatientName: task.patientName,
     prefillExtDoctorName: task.targetExtDoctorName,
     prefillExtDoctorHospital: task.targetExtDoctorHospital,
     prefillExtDoctorSpecialization: task.targetExtDoctorSpecialization,
     prefillExtDoctorPhone: task.targetExtDoctorPhone,
     prefillVisitInstructions: task.visitInstructions,
   ),
   ```

3. In `AddFollowupSheet.initState()`, initialize the controllers with the prefill values if provided.

Return the changed `_chainFollowup` method and the updated `AddFollowupSheet` constructor + `initState`.

```

---

## PHASE 5 — DESIGN & PERFORMANCE

---

### FIX-D1 · Replace all hardcoded colors/shadows with AppTheme tokens
**Issue:** UX-001 + UX-002 + UX-007 + UX-011  
**Tool:** Claude Code (multi-file sweep)  
**Model:** claude-sonnet-4-5  

```

Replace hardcoded color constants with AppTheme tokens across multiple files. This is a find-and-replace sweep — be precise.

FILE: lib/core/neu_widgets.dart

- Replace `Color(0x80DED8CF)` → `AppTheme.border.withValues(alpha: 0.5)` (NeuCard border)
- Replace `Color(0x80FFFFFF)` → `Colors.white.withValues(alpha: 0.5)` (NeuTextField fill — keep as-is but add a comment that dark-mode variant is needed)
- Replace `Color(0x265D7052)` → `AppTheme.shadowSoft.color` or keep the constant but reference via `OrganicTokens.shadowSoft`

FILE: lib/features/dashboard/dashboard_screen.dart

- Replace `Colors.amber.shade700` in `_buildRoleBadge()` → `AppTheme.assistantAccent`
- Replace `Color(0xFFA3B1C6)` in `_StatCard`, `_PriorityCard`, `_VisitCard` box shadows → `AppTheme.shadowSoft`
- Replace `Colors.white` in those same box shadows → keep as `Colors.white` (neumorphic highlight — it's intentional)

FILE: lib/features/auth/phone_otp_screen.dart

- Replace hardcoded `BoxShadow(color: Colors.white, ...)` and `BoxShadow(color: Color(0xFFA3B1C6), ...)` in OTP box decoration → reference `AppTheme.shadowSoft`

FILE: lib/features/dashboard/main_screen.dart → `_buildDrawer()`

- Replace `Colors.amber.shade700` in `avatarColor` switch → `AppTheme.assistantAccent`

After changes, run:
  flutter analyze
  flutter test (if tests exist)

List every changed line with before/after.

```

---

### FIX-D2 · Fix duplicate instructions in FollowupTaskWidget
**Issue:** UX-006 + REC-007  
**Tool:** Claude.ai Sonnet  
**Model:** claude-sonnet-4-5  

**Paste `lib/features/followups/followup_task_widget.dart` and send:**

```

In `FollowupTaskWidget.build()`, when `visitInstructions` is not empty, the same text is rendered TWICE:

1. Inside `_MissionBriefBlock` (which already includes a `visitInstructions` section at the bottom)
2. In a second standalone instructions block below `_MissionBriefBlock`

WHAT TO DO:

1. In `_MissionBriefBlock`, confirm it already renders `task.visitInstructions` — it does (inside the amber-bordered container at the bottom of the block).
2. In `FollowupTaskWidget.build()`, find the second standalone instructions block (the one after `_MissionBriefBlock`) and DELETE it entirely.
3. The remaining `// ── Doctor's instructions ──` comment block that appears AFTER `_MissionBriefBlock` — remove it.
4. Keep the `// ── Doctor review (when present) ──` block — that's different content (doctor's review notes after completion).

Return the `build()` method with the duplicate block removed.

```

---

### FIX-D3 · Fix NeuShimmer multiple AnimationControllers
**Issue:** PERF-003  
**Tool:** Claude.ai Sonnet  
**Model:** claude-sonnet-4-5  

**Paste the `NeuShimmer` class from `lib/core/neu_widgets.dart` and send:**

```

`NeuShimmer` currently creates one `AnimationController` per instance. When a ListView shows 5 shimmer cards, that's 5 separate animation tickers running simultaneously.

WHAT TO DO:

1. Create a new `InheritedWidget` called `ShimmerAnimation` in `lib/core/neu_widgets.dart` that:
   - Holds a single `AnimationController` and `Animation<double>`
   - Is a `StatefulWidget` wrapper that creates and disposes the controller
   - Exposes a static `ShimmerAnimation.of(context)` accessor

2. Rewrite `NeuShimmer` to:
   - Remove its own `AnimationController` and `AnimationController.dispose()`
   - Look up the animation via `ShimmerAnimation.of(context)?.animation`
   - Fall back to a local controller if no `ShimmerAnimation` is found in the tree (backward compat)

3. Wrap the `ListView.builder` in `PatientListScreen`, `DashboardScreen._buildLoadingList()`, and `AuditLogsScreen._AuditLoadingList` with `ShimmerAnimation(child: ...)` so all child shimmers share one ticker.

Return the `ShimmerAnimation` class, the updated `NeuShimmer`, and the wrapper usage in `PatientListScreen`.

```

---

### FIX-D4 · Fix visitHistoryProvider column selection
**Issue:** PERF-008  
**Tool:** Claude Haiku 3.5  
**Model:** claude-haiku-3-5  

```

In `lib/features/patients/visit_history_provider.dart`, the Supabase query uses `.select()` with no arguments, fetching ALL columns.

Current:
  final response = await supabase
      .from('visits')
      .select()
      .eq('patient_id', patientId)
      .order('visit_date', ascending: false);

FIX: Replace `.select()` with a specific column list. Based on what `_TimelineItem` in `patient_detail_screen.dart` actually uses, select only:
'id, visit_date, visit_type, chief_complaint, chief_complaint_custom, tests_performed, ot_required, patient_flow_status, final_diagnosis, prescriptions, last_updated_by, bp_systolic, bp_diastolic, pulse, temperature, spo2, respiratory_rate'

Return only the changed `.select(...)` line.

```

---

### FIX-D5 · Create shared EmptyState widget
**Issue:** UX-012 + REC-009  
**Tool:** Claude Code  
**Model:** claude-sonnet-4-5  

```

Create a shared `EmptyState` widget and replace 6+ different empty-state implementations across the app.

STEP 1 — Create `lib/widgets/empty_state.dart`:

```dart
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.cta,       // Optional NeuButton label
    this.onCta,     // Optional callback
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? cta;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) { ... }
  // Use icon at 64px in AppTheme.textMuted, title in 16/w700, subtitle in 13/textMuted
  // CTA as NeuButton with padding symmetric(vertical:12, horizontal:24)
}
```

STEP 2 — Replace empty states in these files with `EmptyState(...)`:

- `lib/features/patients/patient_list_screen.dart` → `_buildEmptyState()`
- `lib/features/followups/my_followups_screen.dart` → `_buildEmptyState()`
- `lib/features/followups/doctor_followups_screen.dart` → `_buildEmptyState()`
- `lib/features/dr_visits/dr_visit_screen.dart` → `_buildEmptyState()`
- `lib/features/agent_visits/agent_outside_visit_list_screen.dart` → empty visits block
- `lib/features/audit/audit_logs_screen.dart` → `_EmptyAuditView` (fix icon to `AppIcons.description_outlined`)

STEP 3 — Run `flutter analyze`.

```

---

### FIX-D6 · Fix login/register visual hierarchy inconsistency
**Issue:** UX-005  
**Tool:** Claude.ai Sonnet  
**Model:** claude-sonnet-4-5  

**Paste `lib/features/auth/login_screen.dart`'s `_buildLogo()` method and send:**

```

The login screen wraps its logo in a `NeuCard` container but the register screen does not use the same pattern, creating inconsistent branding between the two screens.

WHAT TO DO:

1. Extract the `_buildLogo()` widget from `login_screen.dart` into a shared `AuthLogo` widget in `lib/widgets/auth_logo.dart`.
2. The `AuthLogo` widget should render exactly what `_buildLogo()` currently returns — the NeuCard + colored container + hospital icon + "MediFlow" text + "Smart Clinic Management" subtitle.
3. In `login_screen.dart`, replace `_buildLogo()` call with `const AuthLogo()`.
4. In `register_screen.dart`, add `const AuthLogo()` at the top of the scroll view body, before the "Join MediFlow" heading — with a `const SizedBox(height: 24)` separator.
5. Remove the manual heading row ("Join MediFlow" + subtitle text) from register screen since `AuthLogo` provides the brand anchor.

Return `auth_logo.dart`, the changed section of `login_screen.dart`, and the changed section of `register_screen.dart`.

```

---

## PHASE 6 — SECURITY HARDENING

---

### FIX-S1 · Add server-side document path storage
**Issue:** SEC-006  
**Tool:** Claude Code  
**Model:** claude-sonnet-4-5  

```

In `lib/features/patients/document_provider.dart`, `deleteDocument()` parses a storage path from a URL string. This is fragile — a CDN URL change or malformed URL could delete the wrong file.

CURRENT:
  final uri = Uri.parse(url);
  final pathSegments = uri.pathSegments;
  final storagePath = pathSegments.skip(pathSegments.indexOf('patient-docs') + 1).join('/');

WHAT TO DO:

1. Add a new column approach: Instead of storing only `document_urls` (public URLs) in the patients table, also store `document_paths` (storage paths).

2. Update `uploadDocument()` in `DocumentNotifier`:
   - After getting `newUrl`, also track `path` (the storage path used for upload)
   - Store both: update patients table with `document_urls` AND a parallel `document_paths` array

3. Update `deleteDocument(String url)` signature to `deleteDocument(String url, String storagePath)`:
   - Use the passed `storagePath` directly instead of parsing it from the URL
   - Remove the URL-parsing logic entirely

4. Update `DocumentUploadWidget`:
   - Store `(url, path)` pairs instead of just urls
   - Pass both to `deleteDocument(url, path)` on long-press

5. Add a migration note comment at top of file explaining the `document_paths` column must be added to the patients table.

Run `flutter analyze`.

```

---

### FIX-S2 · Fix convertLeadToPatient RLS scoping
**Issue:** SEC-007  
**Tool:** Claude.ai Sonnet  
**Model:** claude-sonnet-4-5  

**Paste `lib/features/dr_visits/dr_visit_provider.dart` → `convertLeadToPatient()` and send:**

```

`convertLeadToPatient()` calls `ref.read(patientProvider).registerPatient(...)` to create a patient. The problem: `registerPatient` sets `created_by_id` to the CURRENT user (the doctor), not the original agent who created the lead.

For a lead-to-patient conversion, the patient should be attributed to the ORIGINAL agent, not the converting doctor.

WHAT TO DO:

1. Read the `dr_visits` row to get `created_by_id` (the doctor's ID) and `assigned_agent_id`.
2. When calling `registerPatient`, pass `created_by_id: visit.assignedAgentId ?? currentUserId` so the patient is attributed to the assigned agent.
3. If `assignedAgentId` is null, fall back to `currentUserId`.
4. Add a comment explaining this attribution logic.

Also: `convertLeadToPatient` passes lead patient data directly without validation. Add a guard:

```dart
if (visit.leadPatientName == null || visit.leadPatientName!.trim().isEmpty) {
  throw Exception('Lead patient name is required to convert to patient.');
}
```

Return only the rewritten `convertLeadToPatient()` method.

```

---

## MASTER EXECUTION ORDER

| Step | Fix | Tool | Model | Est. Time |
|------|-----|------|-------|-----------|
| 1 | FIX-C1 — Remove hardcoded keys | Claude Code | Sonnet 4.5 | 10 min |
| 2 | FIX-C2 — Fix PhoneOTP | Claude.ai | Sonnet 4.5 | 15 min |
| 3 | FIX-C3 — ConfirmDialog | Claude Code | Sonnet 4.5 | 20 min |
| 4 | FIX-H1 — Timer race | Claude.ai | Sonnet 4.5 | 15 min |
| 5 | FIX-H2 — AuditService | Claude Code | Sonnet 4.5 | 25 min |
| 6 | FIX-H3 — unawaited errors | Claude.ai | Sonnet 4.5 | 10 min |
| 7 | FIX-H4 — RealTimeService | Claude Code | Sonnet 4.5 | 30 min |
| 8 | FIX-H5 — Supabase error handling | Gemini 2.5 Pro | gemini-2.5-pro | 20 min |
| 9 | FIX-H6 — PatientService AsyncNotifier | Claude Code | Sonnet 4.5 | 30 min |
| 10 | FIX-H7 — Parallelize queries | Claude Haiku | haiku-3-5 | 10 min |
| 11 | FIX-A1 — PatientPickerBottomSheet | Claude Code | Sonnet 4.5 | 25 min |
| 12 | FIX-A2 — AuthNotifier paths | Claude.ai | Sonnet 4.5 | 15 min |
| 13 | FIX-A3 — RealtimeService container | Claude.ai | Sonnet 4.5 | 15 min |
| 14 | FIX-A4 — Pagination | Claude Code | Sonnet 4.5 | 40 min |
| 15 | FIX-F1 — Wire ChangePassword | Claude.ai | Sonnet 4.5 | 10 min |
| 16 | FIX-F2 — Persist preferences | Claude Code | Sonnet 4.5 | 25 min |
| 17 | FIX-F3 — Audit DISTINCT | Haiku | haiku-3-5 | 5 min |
| 18 | FIX-F4 — Referral lead toggle | Haiku | haiku-3-5 | 5 min |
| 19 | FIX-F5 — Followup pre-fill | Claude.ai | Sonnet 4.5 | 15 min |
| 20 | FIX-D1 — Color token sweep | Claude Code | Sonnet 4.5 | 20 min |
| 21 | FIX-D2 — Duplicate instructions | Claude.ai | Sonnet 4.5 | 10 min |
| 22 | FIX-D3 — NeuShimmer animation | Claude.ai | Sonnet 4.5 | 20 min |
| 23 | FIX-D4 — visitHistoryProvider select | Haiku | haiku-3-5 | 5 min |
| 24 | FIX-D5 — EmptyState widget | Claude Code | Sonnet 4.5 | 25 min |
| 25 | FIX-D6 — Auth visual consistency | Claude.ai | Sonnet 4.5 | 15 min |
| 26 | FIX-S1 — Document path storage | Claude Code | Sonnet 4.5 | 20 min |
| 27 | FIX-S2 — convertLead RLS | Claude.ai | Sonnet 4.5 | 10 min |

**Total estimated hands-on time: ~6 hours across 2 sprint days**

---

## AFTER EACH FIX — VERIFICATION CHECKLIST

Run this after every Claude Code session:
```bash
flutter analyze
flutter pub get
flutter build apk --debug   # confirms compilation
grep -r "Colors.amber.shade" lib/   # confirm no hardcoded amber left
grep -r "Color(0xFFA3B1C6)" lib/    # confirm no hardcoded shadow left
```

Run this after Phase 1 (security):

```bash
grep -r "defaultValue.*sb_" lib/    # must return 0 results
grep -r "supabaseAnonKey" lib/      # confirm key is no longer hardcoded
```

---

*End of MediFlow Sprint Fix Playbook*
ENDOFFILE
echo "Done. $(wc -l /home/claude/mediflow_fix_guide.md | cut -d' ' -f1) lines written."
Output

Done. 931 lines written.
