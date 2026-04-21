// lib/core/neu_widgets.dart
import 'package:flutter/material.dart';
import 'package:mediflow/core/theme.dart';

const _bgColor = Color(0xFFE8EDF2);

const _lightShadow = BoxShadow(
  color: Colors.white,
  offset: Offset(-4, -4),
  blurRadius: 10,
);
const _darkShadow = BoxShadow(
  color: Color(0xFFA3B1C6),
  offset: Offset(4, 4),
  blurRadius: 10,
);
const _pressedLight = BoxShadow(
  color: Colors.white,
  offset: Offset(2, 2),
  blurRadius: 5,
);
const _pressedDark = BoxShadow(
  color: Color(0xFFA3B1C6),
  offset: Offset(-2, -2),
  blurRadius: 5,
);

// Dimmed shadows used when a [NeuButton] is disabled so it reads as clearly
// inactive rather than mimicking a "pressed but enabled" look.
final _disabledLightShadow = BoxShadow(
  color: Colors.white.withValues(alpha: 0.4),
  offset: const Offset(-4, -4),
  blurRadius: 10,
);
final _disabledDarkShadow = BoxShadow(
  color: const Color(0xFFA3B1C6).withValues(alpha: 0.4),
  offset: const Offset(4, 4),
  blurRadius: 10,
);

class NeuCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final bool pressed;
  final Color? color;

  const NeuCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.pressed = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? _bgColor,
        borderRadius: BorderRadius.circular(borderRadius ?? 16),
        boxShadow: pressed
            ? const [_pressedLight, _pressedDark]
            : const [_lightShadow, _darkShadow],
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

  const NeuButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.color,
    this.borderRadius,
    this.padding,
  });

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: isDisabled
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onPressed?.call();
            },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: widget.padding ??
            const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: isDisabled
              ? (widget.color ?? AppTheme.primaryTeal).withValues(alpha: 0.6)
              : (widget.color ?? AppTheme.primaryTeal),
          borderRadius: BorderRadius.circular(widget.borderRadius ?? 12),
          boxShadow: isDisabled
              ? [_disabledLightShadow, _disabledDarkShadow]
              : (_pressed
                  ? const [_pressedLight, _pressedDark]
                  : const [_lightShadow, _darkShadow]),
        ),
        child: Center(
          child: widget.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : widget.child,
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
          color: _bgColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: _isFocused
              ? [
                  const BoxShadow(color: Colors.white, offset: Offset(-3, -3), blurRadius: 6),
                  BoxShadow(color: AppTheme.primaryTeal.withValues(alpha: 0.2), offset: const Offset(3, 3), blurRadius: 6),
                ]
              : const [_lightShadow, _darkShadow],
        ),
        child: TextFormField(
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
          style: const TextStyle(
            color: AppTheme.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            suffixIcon: widget.suffixIcon,
            prefixIcon: widget.prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: widget.prefixIcon,
                  )
                : null,
            prefixIconConstraints: widget.prefixIcon != null
                ? const BoxConstraints(minWidth: 40, minHeight: 40)
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: _bgColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }
}

/// Section title used across forms.
class SectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;

  const SectionTitle({super.key, required this.title, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppTheme.primaryTeal),
            const SizedBox(width: 8),
          ],
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textMuted,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
    this.borderRadius = 12,
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
    )..repeat();
    _animation = Tween<double>(begin: -1.5, end: 1.5).animate(
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
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: const [
                Color(0xFFE8EDF2),
                Color(0xFFF5F8FC),
                Color(0xFFE8EDF2),
              ],
            ),
          ),
        );
      },
    );
  }
}
