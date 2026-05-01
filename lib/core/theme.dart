import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mediflow/core/organic_tokens.dart';

class AppTheme {
  // ── Organic Design Tokens ──
  static const Color bgColor = Color(0xFFFDFCF8); // Rice Paper
  static const Color foreground = Color(0xFF2C2C24); // Deep Loam
  static const Color primaryTeal = Color(0xFF5D7052); // Moss Green
  static const Color primaryTealLight = Color(0xFF7A9169); // Lighter Moss
  static const Color primaryForeground = Color(0xFFF3F4F1); // Pale Mist
  static const Color secondary = Color(0xFFC18C5D); // Terracotta
  static const Color secondaryForeground = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFFE6DCCD); // Sand
  static const Color accentForeground = Color(0xFF4A4A40); // Bark
  static const Color textMuted = Color(0xFF78786C); // Dried Grass
  static const Color textColor = Color(0xFF2C2C24); // Same as foreground
  static const Color border = Color(0xFFDED8CF); // Raw Timber
  static const Color errorColor = Color(0xFFA85448); // Burnt Sienna
  static const Color successColor = Color(0xFF5D7052); // Moss
  static const Color warningColor = Color(0xFFC18C5D); // Terracotta
  static const Color infoColor = Color(0xFF7A9169); // Lighter Moss
  static const Color cardBg = Color(0xFFFEFEFA); // Slightly warmer than page bg

  // ── Role-specific accents (organic palette, not Material) ──
  // Slate Blue — replaces Colors.blue for the Doctor role.
  static const Color doctorAccent = Color(0xFF6B8EC4);
  // Warm Amber / clay — replaces Colors.amber.shade700 for the Assistant role.
  static const Color assistantAccent = Color(0xFFBE8C3C);

  // ── Neutral utilities (replace Colors.grey variants) ──
  static const Color neutralLight = Color(0xFFF0EBE5); // same as OrganicTokens.muted
  static const Color neutralDivider = Color(0xFFDED8CF); // same hue as `border`

  // ── Navigation tile accents (replace Colors.deepPurple/orange/blueGrey) ──
  static const Color analyticsAccent = Color(0xFF7B6FA0); // Muted Lavender
  static const Color staffAccent = Color(0xFFC18C5D); // matches secondary (Terracotta)
  static const Color auditAccent = Color(0xFF6E8898); // Slate Grey

  // ── Neumorphic/Organic surface and shadow tokens ──
  static const Color neuShadowLight = Color(0x80DED8CF);
  static const Color neuShadowDark = Color(0xFFA3B1C6);
  static const Color surfaceFill = Color(0x80FFFFFF);
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
      fontFamily: GoogleFonts.nunito().fontFamily,
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
        titleTextStyle: GoogleFonts.fraunces(
          color: foreground,
          fontSize: 20,
          fontWeight: FontWeight.w700,
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
          borderRadius: BorderRadius.circular(24),
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
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide:
              BorderSide(color: primaryTeal.withValues(alpha: 0.3), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
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
        backgroundColor: surfaceFill.withValues(alpha: 0.7), // with opacity for blur
        elevation: 0,
        indicatorColor: primaryTeal,
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
        backgroundColor: Colors.white.withValues(alpha: 0.72),
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
