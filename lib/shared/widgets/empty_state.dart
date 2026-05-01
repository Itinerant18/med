// lib/shared/widgets/empty_state.dart
//
// Shared empty-state placeholder used across all list screens. Replaces
// bespoke per-screen empty states so visual treatment, spacing, and
// animation stay consistent.
//
// Use AppTheme tokens only — no hardcoded colors.
import 'package:flutter/material.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';

class EmptyState extends StatefulWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.ctaLabel,
    this.onCta,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? ctaLabel;
  final VoidCallback? onCta;

  /// When true, shrinks the icon and removes vertical padding so the widget
  /// fits inside an existing card. Default is the full-screen layout.
  final bool compact;

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppTheme.durationFloat,
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: AppTheme.curveOrganic,
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(_opacity);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.compact ? 40.0 : 64.0;
    final titleStyle = AppTheme.bodyFont(
      size: widget.compact ? 14 : 16,
      weight: FontWeight.w800,
      color: AppTheme.textColor,
    );
    final subtitleStyle = AppTheme.bodyFont(
      size: 13,
      weight: FontWeight.w600,
      color: AppTheme.textMuted,
    );

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 24,
              vertical: widget.compact ? 12 : 32,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  size: iconSize,
                  color: AppTheme.textMuted.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: titleStyle,
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.subtitle!,
                    textAlign: TextAlign.center,
                    style: subtitleStyle,
                  ),
                ],
                if (widget.ctaLabel != null && widget.onCta != null) ...[
                  const SizedBox(height: 18),
                  NeuButton(
                    onPressed: widget.onCta,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 24,
                    ),
                    child: Text(
                      widget.ctaLabel!,
                      style: const TextStyle(
                        color: AppTheme.primaryForeground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
