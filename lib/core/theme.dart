import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mediflow/core/organic_tokens.dart';

class AppTheme {
  // ── Organic Design Tokens ──
  static const Color bgColor = Color(0xFFF7FAF3);
  static const Color foreground = Color(0xFF263129);
  static const Color primaryTeal = Color(0xFF708269);
  static const Color primaryTealLight = Color(0xFF8D9A84);
  static const Color primaryForeground = Color(0xFFF8FBF4);
  static const Color secondary = Color(0xFFC8B79A);
  static const Color secondaryForeground = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFFE9EFE2);
  static const Color accentForeground = Color(0xFF4B5649);
  static const Color textMuted = Color(0xFF6D7A69);
  static const Color textColor = Color(0xFF2C2C24); // Same as foreground
  static const Color border = Color(0xFFD9E3D0);
  static const Color errorColor = Color(0xFFC46A5A);
  static const Color successColor = Color(0xFF708269);
  static const Color warningColor = Color(0xFFC09A64);
  static const Color infoColor = Color(0xFF7E9A79);
  static const Color cardBg = Color(0xFFFCFDF8);

  // ── Role-specific accents (organic palette, not Material) ──
  // Slate Blue — replaces Colors.blue for the Doctor role.
  static const Color doctorAccent = Color(0xFF6B8EC4);
  // Warm Amber / clay — replaces Colors.amber.shade700 for the Assistant role.
  static const Color assistantAccent = Color(0xFFB89257);

  // ── Neutral utilities (replace Colors.grey variants) ──
  static const Color neutralLight = Color(0xFFF1F5EB);
  static const Color neutralDivider = Color(0xFFD9E3D0);

  // ── Navigation tile accents (replace Colors.deepPurple/orange/blueGrey) ──
  static const Color analyticsAccent = Color(0xFF7F8EA1);
  static const Color staffAccent = Color(0xFFC8B79A);
  static const Color auditAccent = Color(0xFF6E8898);

  // ── Neumorphic/Organic surface and shadow tokens ──
  static const Color neuShadowLight = Color(0x60D9E3D0);
  static const Color neuShadowDark = Color(0x26708269);
  static const Color surfaceFill = Color(0xF7FFFFFF);
  static const Color surfaceWhite = Color(0xFFFFFFFF);

  // ── Section header label (replaces Color(0xFF718096)) ──
  static const Color sectionLabel = textMuted;
  static TextStyle headingFont({
    double size = 24,
    FontWeight weight = FontWeight.w700,
    Color color = foreground,
  }) =>
      OrganicTokens.heading(size: size, weight: weight, color: color);

  static TextStyle bodyFont({
    double size = 14,
    FontWeight weight = FontWeight.w600,
    Color color = foreground,
  }) =>
      OrganicTokens.body(size: size, weight: weight, color: color);

  static const BoxShadow shadowSoft = OrganicTokens.shadowSoft;
  static const BoxShadow shadowFloat = OrganicTokens.shadowFloat;
  static const BoxShadow shadowHover = OrganicTokens.shadowHover;
  static const double radiusStandard = OrganicTokens.radiusStandard;
  static const double radiusLarge = OrganicTokens.radiusLarge;
  static const double radiusPill = OrganicTokens.radiusPill;
  static const List<BorderRadius> radiusOrganic = OrganicTokens.radiusOrganic;
  static const Duration durationGentle = OrganicTokens.durationGentle;
  static const Duration durationFloat = OrganicTokens.durationFloat;
  static const Curve curveOrganic = OrganicTokens.curveOrganic;

  static ThemeData get neumorphicTheme =>
      organicTheme; // Backward compatibility

  static ThemeData get organicTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bgColor,
      fontFamily: GoogleFonts.manrope().fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        primary: primaryTeal,
        onPrimary: primaryForeground,
        secondary: secondary,
        onSecondary: secondaryForeground,
        surface: bgColor,
        onSurface: foreground,
        error: errorColor,
        onError: Colors.white,
      ),

      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: foreground,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          color: foreground,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: foreground),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
          side: const BorderSide(color: neuShadowLight, width: 1),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide:
              BorderSide(color: primaryTeal.withValues(alpha: 0.3), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        labelStyle: const TextStyle(
            color: textMuted, fontSize: 14, fontWeight: FontWeight.w600),
        hintStyle:
            TextStyle(color: textMuted.withValues(alpha: 0.5), fontSize: 14),
        errorStyle: const TextStyle(color: errorColor, fontSize: 12),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTeal,
          foregroundColor: primaryForeground,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // TextButton Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryTeal,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: bgColor,
        selectedColor: primaryTeal.withValues(alpha: 0.12),
        labelStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: foreground),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        side: const BorderSide(color: border),
      ),

      // NavigationBar Theme
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardBg.withValues(alpha: 0.92),
        elevation: 0,
        indicatorColor: primaryTeal.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: primaryTeal);
          }
          return const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: textMuted);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryForeground, size: 22);
          }
          return const IconThemeData(color: textMuted, size: 22);
        }),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardBg.withValues(alpha: 0.92),
        selectedItemColor: primaryTeal,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:
            OrganicTokens.body(size: 11, weight: FontWeight.w800),
        unselectedLabelStyle: OrganicTokens.body(
          size: 11,
          weight: FontWeight.w600,
          color: textMuted,
        ),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryTeal;
          return border;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryTeal.withValues(alpha: 0.3);
          }
          return neutralLight;
        }),
      ),
    );
  }
}
