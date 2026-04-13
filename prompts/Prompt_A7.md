In lib/features/dashboard/main_screen.dart, update the AppBar title Row to show the role badge. Replace the existing title Row with:

```dart
title: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    const Text('MediFlow', style: TextStyle(fontWeight: FontWeight.w700)),
    const SizedBox(width: 6),
    Consumer(
      builder: (context, ref, _) {
        final isAdmin = ref.watch(isAdminProvider);
        return Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: isAdmin ? const Color(0xFF2E9E5B) : Colors.amber.shade600,
            shape: BoxShape.circle,
          ),
        );
      },
    ),
  ],
),
```

Add the import at the top:

```dart
import 'package:mediflow/core/role_provider.dart';
```
