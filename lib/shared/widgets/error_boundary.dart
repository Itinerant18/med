// lib/shared/widgets/error_boundary.dart
//
// Standardized AsyncValue error UI. Replaces ad-hoc error widgets scattered
// across the app so error treatment, retry affordances, and logging stay
// consistent.
//
// Provides:
//   • ErrorBoundary widget — drop-in for AsyncValue.when(error: ...)
//   • AsyncValue.whenWithBoundary(...) extension — auto-handles errors.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediflow/core/app_icons.dart';
import 'package:mediflow/core/error_handler.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';

/// Optional global telemetry hook. Apps can wire this to Sentry, Crashlytics,
/// or any custom logger. No-op by default.
typedef ErrorTelemetry = void Function(
  Object error,
  StackTrace? stackTrace, {
  String? context,
});

class ErrorBoundary extends StatelessWidget {
  const ErrorBoundary({
    super.key,
    required this.error,
    this.stackTrace,
    this.onRetry,
    this.retryLabel = 'Retry',
    this.title,
    this.contextLabel,
    this.compact = false,
  });

  final Object error;
  final StackTrace? stackTrace;
  final FutureOr<void> Function()? onRetry;
  final String retryLabel;

  /// Heading shown above the message. Defaults to "Something went wrong".
  final String? title;

  /// Optional short label describing where the error happened. Used in logs.
  final String? contextLabel;

  /// Use compact layout when embedded in a card or small slot.
  final bool compact;

  static ErrorTelemetry? telemetry;

  void _logOnce() {
    debugPrint(
      '[ErrorBoundary${contextLabel == null ? '' : ' · $contextLabel'}] '
      '$error',
    );
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
    telemetry?.call(error, stackTrace, context: contextLabel);
  }

  @override
  Widget build(BuildContext context) {
    _logOnce();

    final friendly = AppError.getMessage(error);
    final headingStyle = AppTheme.bodyFont(
      size: compact ? 14 : 16,
      weight: FontWeight.w800,
      color: AppTheme.textColor,
    );
    final bodyStyle = AppTheme.bodyFont(
      size: 12,
      weight: FontWeight.w600,
      color: AppTheme.textMuted,
    );
    final iconSize = compact ? 28.0 : 40.0;

    final card = NeuCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.error_outline_rounded,
            size: iconSize,
            color: AppTheme.errorColor,
          ),
          const SizedBox(height: 12),
          Text(
            title ?? 'Something went wrong',
            style: headingStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            friendly,
            style: bodyStyle,
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            NeuButton(
              onPressed: () async => await onRetry!(),
              padding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 24,
              ),
              child: Text(
                retryLabel,
                style: const TextStyle(
                  color: AppTheme.primaryForeground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 24),
        child: card,
      ),
    );
  }
}

extension AsyncValueErrorBoundary<T> on AsyncValue<T> {
  /// AsyncValue.when() with automatic ErrorBoundary handling.
  ///
  /// Pass `onRetry` to render a retry button on error states. The optional
  /// `errorTitle` and `contextLabel` are forwarded to ErrorBoundary.
  Widget whenWithBoundary({
    required Widget Function(T data) data,
    required Widget Function() loading,
    FutureOr<void> Function()? onRetry,
    String? errorTitle,
    String? contextLabel,
    bool compact = false,
  }) {
    return when(
      data: data,
      loading: loading,
      error: (err, stack) => ErrorBoundary(
        error: err,
        stackTrace: stack,
        onRetry: onRetry,
        title: errorTitle,
        contextLabel: contextLabel,
        compact: compact,
      ),
    );
  }
}
