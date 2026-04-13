In lib/core/router.dart:

1. Add imports for both new profile screens:

```dart
import 'package:mediflow/features/profile/doctor_profile_screen.dart';
import 'package:mediflow/features/profile/assistant_profile_screen.dart';
import 'package:mediflow/core/role_provider.dart';
```

2. Replace the existing '/profile' route builder with a role-aware one:

```dart
GoRoute(
  path: '/profile',
  builder: (context, state) {
    // Read role from ProviderScope — use a Consumer wrapper trick
    return _RoleBasedProfileRouter();
  },
),
```

3. Add this private widget class at the bottom of router.dart (outside the Provider):

```dart
class _RoleBasedProfileRouter extends ConsumerWidget {
  const _RoleBasedProfileRouter();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    return isAdmin
        ? const DoctorProfileScreen()
        : const AssistantProfileScreen();
  }
}
```

4. Remove the old import of profile_screen.dart from router.dart if it is no longer used:

```dart
// Remove this line:
// import 'package:mediflow/features/profile/profile_screen.dart';
```
