import 'package:flutter/material.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:mediflow/core/theme.dart';

class AppSnackbar {
  static void showError(BuildContext context, String message) {
    _showSnackBar(
      context,
      message,
      const Color(0xFFA85448),
      AppIcons.error_outline_rounded,
    );
  }

  static void showSuccess(BuildContext context, String message) {
    _showSnackBar(
      context,
      message,
      const Color(0xFF5D7052),
      AppIcons.check_circle_outline_rounded,
    );
  }

  static void showInfo(BuildContext context, String message) {
    _showSnackBar(
      context,
      message,
      const Color(0xFF7A9169),
      AppIcons.info_outline_rounded,
    );
  }

  static void showWarning(BuildContext context, String message) {
    _showSnackBar(
      context,
      message,
      const Color(0xFFC18C5D),
      AppIcons.warning_amber_rounded,
    );
  }

  static void _showSnackBar(
    BuildContext context,
    String message,
    Color bgColor,
    IconData icon,
  ) {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: AppTheme.border.withValues(alpha: 0.35)),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 4),
        elevation: 0,
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white.withValues(alpha: 0.85),
          onPressed: () => messenger.hideCurrentSnackBar(),
        ),
      ),
    );
  }
}
