import 'package:flutter/material.dart';
import 'package:mediflow/core/theme.dart';

/// A centralized shimmer effect provider for all skeleton widgets.
/// Uses a single animation to keep multiple skeletons in sync.
class ShimmerProvider extends StatefulWidget {
  final Widget child;
  const ShimmerProvider({super.key, required this.child});

  static ShimmerProviderState? of(BuildContext context) {
    return context.findAncestorStateOfType<ShimmerProviderState>();
  }

  @override
  State<ShimmerProvider> createState() => ShimmerProviderState();
}

class ShimmerProviderState extends State<ShimmerProvider>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> get animation => _controller;

  @override
  Widget build(BuildContext context) => widget.child;
}

class SkeletonBase extends StatelessWidget {
  const SkeletonBase({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final shimmer = ShimmerProvider.of(context);
    final animation = shimmer?.animation ?? const AlwaysStoppedAnimation(0.0);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            shape: shape,
            borderRadius: shape == BoxShape.circle ? null : borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                animation.value - 0.3,
                animation.value,
                animation.value + 0.3,
              ],
              colors: [
                AppTheme.neutralLight,
                AppTheme.accent.withValues(alpha: 0.5),
                AppTheme.neutralLight,
              ],
            ),
          ),
        );
      },
    );
  }
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    this.width = double.infinity,
    this.height = 100,
    this.borderRadius,
    this.margin,
    this.padding,
    this.child,
  });

  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.radiusStandard),
        border: Border.all(color: AppTheme.neuShadowLight),
      ),
      child: child ?? const SkeletonBase(width: double.infinity, height: double.infinity),
    );
  }
}

class SkeletonText extends StatelessWidget {
  const SkeletonText({
    super.key,
    this.width = double.infinity,
    this.height = 12,
    this.borderRadius,
  });

  final double width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return SkeletonBase(
      width: width,
      height: height,
      borderRadius: borderRadius ?? BorderRadius.circular(4),
    );
  }
}

class SkeletonAvatar extends StatelessWidget {
  const SkeletonAvatar({
    super.key,
    this.size = 40,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return SkeletonBase(
      width: size,
      height: size,
      shape: BoxShape.circle,
    );
  }
}

// ── Specific Layouts ──────────────────────────────────────────────────────────

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerProvider(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats horizontal list
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, __) => const SkeletonCard(width: 130, height: 100, borderRadius: BorderRadius.all(Radius.circular(16))),
              ),
            ),
            const SizedBox(height: 32),
            const SkeletonText(width: 150, height: 16),
            const SizedBox(height: 16),
            // High priority cards
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 2,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, __) => const SkeletonCard(width: 160, height: 100, borderRadius: BorderRadius.all(Radius.circular(14))),
              ),
            ),
            const SizedBox(height: 32),
            const SkeletonText(width: 120, height: 16),
            const SizedBox(height: 16),
            // Visit list
            for (int i = 0; i < 3; i++) ...[
              const SkeletonCard(height: 90, margin: EdgeInsets.only(bottom: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

class PatientListSkeleton extends StatelessWidget {
  const PatientListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerProvider(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SkeletonCard(
            height: 110,
            borderRadius: BorderRadius.circular(16),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonAvatar(size: 44),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonText(width: 140, height: 16),
                        SizedBox(height: 8),
                        SkeletonText(width: 80, height: 10),
                        SizedBox(height: 4),
                        SkeletonText(width: 100, height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FollowupListSkeleton extends StatelessWidget {
  const FollowupListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerProvider(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: 5,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: SkeletonCard(
            height: 120,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
    );
  }
}
