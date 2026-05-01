import 'package:flutter/material.dart';
import 'package:mediflow/core/theme.dart';

class ServiceStatusBadge extends StatelessWidget {
  const ServiceStatusBadge({
    super.key,
    required this.status,
    this.size = 10,
    this.uppercase = true,
  });

  final String status;
  final double size;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    final color = ServiceStatusColor.of(status);
    final text = uppercase ? status.toUpperCase() : status;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class ServiceStatusColor {
  static Color of(String rawStatus) {
    final status = rawStatus.trim().toLowerCase();
    switch (status) {
      case 'active':
      case 'completed':
      case 'converted':
      case 'discharged':
        return AppTheme.successColor;
      case 'pending':
      case 'in_progress':
      case 'under observation':
      case 'admitted':
        return AppTheme.warningColor;
      case 'rejected':
      case 'overdue':
      case 'not_interested':
        return AppTheme.errorColor;
      case 'referred':
      case 'contacted':
        return AppTheme.doctorAccent;
      case 'cancelled':
        return AppTheme.textMuted;
      default:
        return AppTheme.primaryTeal;
    }
  }
}
