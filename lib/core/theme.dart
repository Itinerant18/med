import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mediflow/core/organic_tokens.dart';

class AppTheme {
  // ── Organic Design Tokens ──
  static const Color bgColor = Color(0xFFF8FAFC);
  static const Color foreground = Color(0xFF0F172A);
  static const Color primaryTeal = Color(0xFF0F766E);
  static const Color primaryTealLight = Color(0xFF14B8A6);
  static const Color primaryForeground = Color(0xFFFFFFFF);
  static const Color secondary = Color(0xFF10B981);
  static const Color secondaryForeground = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFFCCFBF1);
  static const Color accentForeground = Color(0xFF0F766E);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textColor = Color(0xFF0F172A); // Same as foreground
  static const Color border = Color(0xFFE2E8F0);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color infoColor = Color(0xFF3B82F6);
  static const Color cardBg = Color(0xFFFFFFFF);

  // ── Role-specific accents (organic palette, not Material) ──
  // Slate Blue — replaces Colors.blue for the Doctor role.
  static const Color doctorAccent = Color(0xFF1E3A8A);
  // Warm Amber / clay — replaces Colors.amber.shade700 for the Assistant role.
  static const Color assistantAccent = Color(0xFFFB923C);

  // ── Neutral utilities (replace Colors.grey variants) ──
  static const Color neutralLight = Color(0xFFF1F5F9);
  static const Color neutralDivider = Color(0xFFE2E8F0);

  // ── Navigation tile accents (replace Colors.deepPurple/orange/blueGrey) ──
  static const Color analyticsAccent = Color(0xFF6366F1);
  static const Color staffAccent = Color(0xFF10B981);
  static const Color auditAccent = Color(0xFF0EA5E9);

  // ── Neumorphic/Organic surface and shadow tokens ──
  static const Color neuShadowLight = Color(0x1A0F172A); // Diffused soft shadow
  static const Color neuShadowDark = Color(0x330F172A);
  static const Color surfaceFill = Color(0xFFF8FAFC);
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
        elevation: 2,
        shadowColor: neuShadowLight,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.transparent, width: 0),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.transparent, width: 0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.transparent, width: 0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: primaryTeal, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        errorStyle: const TextStyle(
          color: errorColor,
          fontWeight: FontWeight.w500,
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
