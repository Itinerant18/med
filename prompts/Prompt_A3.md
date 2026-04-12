In lib/core/app_snackbar.dart, replace the entire \_showSnackBar static method with this version that captures the messenger reference once to avoid nested Scaffold context issues:

```dart
static void _showSnackBar(
  BuildContext context,
  String message,
  Color bgColor,
  IconData icon,
) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: bgColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'Dismiss',
        textColor: Colors.white,
        onPressed: () => messenger.hideCurrentSnackBar(),
      ),
    ),
  );
}
```
