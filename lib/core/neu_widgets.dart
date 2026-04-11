import 'package:flutter/material.dart';

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

class NeuCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final bool pressed;

  const NeuCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.pressed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgColor,
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

  const NeuButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.color,
  });

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (!widget.isLoading) widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: widget.color ?? const Color(0xFF1A6B5A),
          borderRadius: BorderRadius.circular(12),
          boxShadow: _pressed
              ? const [_pressedLight, _pressedDark]
              : const [_lightShadow, _darkShadow],
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

class NeuTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final Widget? suffixIcon;
  final void Function(String)? onChanged;
  final String? initialValue;

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
    this.onChanged,
    this.initialValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [_lightShadow, _darkShadow],
      ),
      child: TextFormField(
        controller: controller,
        initialValue: initialValue,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: _bgColor,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
}
