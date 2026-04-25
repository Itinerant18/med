import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mediflow/core/organic_tokens.dart';
import 'package:mediflow/core/theme.dart';

enum NeuButtonVariant { primary, outline, ghost }

// OrganicBackground
class OrganicBackground extends StatelessWidget {
  final Widget child;
  const OrganicBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: AppTheme.bgColor)),
        Positioned(
          top: -50,
          left: -80,
          child: OrganicBlob(
            color: AppTheme.primaryTeal.withValues(alpha: 0.08),
            size: 280,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(120),
              topRight: Radius.circular(80),
              bottomLeft: Radius.circular(60),
              bottomRight: Radius.circular(140),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          right: -50,
          child: OrganicBlob(
            color: AppTheme.secondary.withValues(alpha: 0.06),
            size: 240,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(80),
              topRight: Radius.circular(140),
              bottomLeft: Radius.circular(120),
              bottomRight: Radius.circular(60),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: OrganicGrainPainter(),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

// OrganicBlob
class OrganicBlob extends StatelessWidget {
  final Color color;
  final double size;
  final BorderRadius borderRadius;

  const OrganicBlob({
    super.key,
    required this.color,
    required this.size,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
          child: Container(color: Colors.transparent),
        ),
      ),
    );
  }
}

// OrganicGrainPainter
class OrganicGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.foreground.withValues(alpha: 0.03)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final random = math.Random(42);
    final points = <Offset>[];
    for (int i = 0; i < (size.width * size.height * 0.02).toInt(); i++) {
      points.add(Offset(
          random.nextDouble() * size.width, random.nextDouble() * size.height));
    }
    canvas.drawPoints(PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class NeuCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final bool pressed;
  final Color? color;
  final int? asymmetricIndex;

  const NeuCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.pressed = false,
    this.color,
    this.asymmetricIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? AppTheme.cardBg,
        borderRadius: asymmetricIndex == null
            ? BorderRadius.circular(borderRadius ?? 24)
            : OrganicTokens.radiusOrganic[
                asymmetricIndex! % OrganicTokens.radiusOrganic.length],
        border: Border.all(color: const Color(0x80DED8CF), width: 1),
        boxShadow: [
          if (pressed)
            const BoxShadow(
                color: Color(0x33C18C5D),
                blurRadius: 40,
                offset: Offset(0, 10),
                spreadRadius: -10)
          else
            const BoxShadow(
                color: Color(0x265D7052),
                blurRadius: 20,
                offset: Offset(0, 4),
                spreadRadius: -2),
        ],
      ),
      child: child,
    );
  }
}

class NeuButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final Color? color;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final NeuButtonVariant variant;

  const NeuButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.color,
    this.borderRadius,
    this.padding,
    this.variant = NeuButtonVariant.primary,
  });

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final baseColor = widget.color ?? AppTheme.primaryTeal;
    final backgroundColor = switch (widget.variant) {
      NeuButtonVariant.primary =>
        isDisabled ? baseColor.withValues(alpha: 0.6) : baseColor,
      NeuButtonVariant.outline => Colors.transparent,
      NeuButtonVariant.ghost => Colors.transparent,
    };
    final foregroundColor = switch (widget.variant) {
      NeuButtonVariant.primary => AppTheme.primaryForeground,
      NeuButtonVariant.outline => baseColor,
      NeuButtonVariant.ghost => baseColor,
    };

    return Semantics(
      button: true,
      enabled: !isDisabled,
      child: GestureDetector(
        onTapDown: isDisabled ? null : (_) => _animController.forward(),
        onTapUp: isDisabled
            ? null
            : (_) {
                _animController.reverse();
                widget.onPressed?.call();
              },
        onTapCancel: () => _animController.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            height: 52,
            padding:
                widget.padding ?? const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(widget.borderRadius ?? 100),
              border: widget.variant == NeuButtonVariant.outline
                  ? Border.all(color: baseColor, width: 2)
                  : null,
              boxShadow: isDisabled
                  ? []
                  : widget.variant == NeuButtonVariant.primary
                      ? const [OrganicTokens.shadowSoft]
                      : [],
            ),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryForeground,
                        strokeWidth: 2,
                      ),
                    )
                  : DefaultTextStyle(
                      style: TextStyle(
                        color: foregroundColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                      child: widget.child,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class NeuTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final void Function(String)? onChanged;
  final String? initialValue;
  final bool readOnly;
  final void Function()? onTap;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool autocorrect;
  final bool enableSuggestions;

  const NeuTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.suffixIcon,
    this.prefixIcon,
    this.onChanged,
    this.initialValue,
    this.readOnly = false,
    this.onTap,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.onFieldSubmitted,
    this.autofocus = false,
    this.focusNode,
    this.autocorrect = true,
    this.enableSuggestions = true,
  });

  @override
  State<NeuTextField> createState() => _NeuTextFieldState();
}

class _NeuTextFieldState extends State<NeuTextField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          boxShadow: _isFocused
              ? [
                  BoxShadow(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                  child: CustomPaint(painter: OrganicGrainPainter())),
            ),
            TextFormField(
              controller: widget.controller,
              initialValue: widget.initialValue,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              validator: widget.validator,
              maxLines: widget.obscureText ? 1 : widget.maxLines,
              onChanged: widget.onChanged,
              readOnly: widget.readOnly,
              onTap: widget.onTap,
              textCapitalization: widget.textCapitalization,
              textInputAction: widget.textInputAction,
              onFieldSubmitted: widget.onFieldSubmitted,
              autofocus: widget.autofocus,
              focusNode: widget.focusNode,
              autocorrect: widget.autocorrect,
              enableSuggestions: widget.enableSuggestions,
              style: TextStyle(
                color: AppTheme.textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: GoogleFonts.nunito().fontFamily,
              ),
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: widget.hint,
                suffixIcon: widget.suffixIcon,
                prefixIcon: widget.prefixIcon != null
                    ? Padding(
                        padding: const EdgeInsets.only(left: 16, right: 8),
                        child: widget.prefixIcon,
                      )
                    : null,
                prefixIconConstraints: widget.prefixIcon != null
                    ? const BoxConstraints(minWidth: 48, minHeight: 48)
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide:
                      const BorderSide(color: AppTheme.border, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide:
                      const BorderSide(color: AppTheme.border, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: BorderSide(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.3),
                      width: 2),
                ),
                filled: true,
                fillColor: const Color(0x80FFFFFF),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section title used across forms.
class SectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? iconWidget;

  const SectionTitle(
      {super.key, required this.title, this.icon, this.iconWidget});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          if (iconWidget != null || icon != null) ...[
            iconWidget ?? Icon(icon, size: 16, color: AppTheme.primaryTeal),
            const SizedBox(width: 8),
          ],
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textMuted,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              fontFamily: GoogleFonts.nunito().fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

class OrganicIconContainer extends StatefulWidget {
  const OrganicIconContainer({
    super.key,
    required this.icon,
    this.size = 56,
    this.iconSize = 22,
    this.color = AppTheme.primaryTeal,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color color;

  @override
  State<OrganicIconContainer> createState() => _OrganicIconContainerState();
}

class _OrganicIconContainerState extends State<OrganicIconContainer> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: OrganicTokens.durationGentle,
        curve: OrganicTokens.curveOrganic,
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: _hovered ? widget.color : widget.color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          boxShadow: _hovered ? const [OrganicTokens.shadowSoft] : const [],
        ),
        child: Icon(
          widget.icon,
          color: _hovered ? AppTheme.primaryForeground : widget.color,
          size: widget.iconSize,
        ),
      ),
    );
  }
}

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 28,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
            boxShadow: const [OrganicTokens.shadowSoft],
          ),
          child: child,
        ),
      ),
    );
  }
}

class OrganicDivider extends StatelessWidget {
  const OrganicDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: AppTheme.border.withValues(alpha: 0.5),
    );
  }
}

/// A shimmer loading placeholder.
class NeuShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const NeuShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 24,
  });

  @override
  State<NeuShimmer> createState() => _NeuShimmerState();
}

class _NeuShimmerState extends State<NeuShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            color: Color.lerp(
              const Color(0xFFF0EBE5), // Stone
              const Color(0xFFE6DCCD), // Sand
              _animation.value,
            ),
          ),
        );
      },
    );
  }
}
