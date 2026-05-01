import 'package:flutter/material.dart';
import 'package:mediflow/core/neu_widgets.dart';
import 'package:mediflow/core/theme.dart';

class DashboardStatItem {
  const DashboardStatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class DashboardStatCarousel extends StatelessWidget {
  const DashboardStatCarousel({
    super.key,
    required this.items,
    this.height = 114,
    this.cardWidth = 132,
    this.cardHeight = 100,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.borderRadius = 16,
    this.useNeuCard = false,
  });

  final List<DashboardStatItem> items;
  final double height;
  final double cardWidth;
  final double cardHeight;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool useNeuCard;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _StatCard(
          item: items[index],
          width: cardWidth,
          height: cardHeight,
          borderRadius: borderRadius,
          useNeuCard: useNeuCard,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.item,
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.useNeuCard,
  });

  final DashboardStatItem item;
  final double width;
  final double height;
  final double borderRadius;
  final bool useNeuCard;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(item.icon, color: item.color, size: 19),
        ),
        const Spacer(),
        Text(
          item.value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.textColor,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          item.label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    if (useNeuCard) {
      return SizedBox(
        width: width,
        height: height,
        child: NeuCard(
          borderRadius: borderRadius,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: content,
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: const [
          BoxShadow(
            color: AppTheme.surfaceWhite,
            offset: Offset(-3, -3),
            blurRadius: 8,
          ),
          BoxShadow(
            color: AppTheme.neuShadowDark,
            offset: Offset(3, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: content,
    );
  }
}
