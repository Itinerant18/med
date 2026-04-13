// lib/core/app_snackbar.dart
import 'package:flutter/material.dart';

class AppSnackbar {
  static void showError(BuildContext context, String message) {
    _showSnackBar(context, message, const Color(0xFFE53E3E), Icons.error_outline);
  }

  static void showSuccess(BuildContext context, String message) {
    _showSnackBar(context, message, const Color(0xFF38A169), Icons.check_circle_outline);
  }

  static void showInfo(BuildContext context, String message) {
    _showSnackBar(context, message, const Color(0xFF3182CE), Icons.info_outline);
  }

  static void showWarning(BuildContext context, String message) {
    _showSnackBar(context, message, const Color(0xFFD69E2E), Icons.warning_amber_outlined);
  }

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
}
