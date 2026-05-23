import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mediflow/core/organic_tokens.dart';

class AppTheme {
  // ── Clinical Trust & Vitality Palette ──────────────────────────────────────
  // Primary: Deep Teal — trust, cleanliness, medical authority
  static const Color bgColor = Color(0xFFF0F4F8);
  static const Color foreground = Color(0xFF0D1B2A);
  static const Color primaryTeal = Color(0xFF0F766E);
  static const Color primaryTealLight = Color(0xFF14B8A6);
  static const Color primaryForeground = Color(0xFFFFFFFF);

  // Secondary: Emerald Mint — vitality, action, health progress
  static const Color secondary = Color(0xFF059669);
  static const Color secondaryForeground = Color(0xFFFFFFFF);

  // Accent: Soft Teal Wash
  static const Color accent = Color(0xFFCCFBF1);
  static const Color accentForeground = Color(0xFF0F766E);

  // Text tokens
  static const Color textMuted = Color(0xFF64748B);
  static const Color textColor = Color(0xFF0D1B2A);

  // Surface & border
  static const Color border = Color(0xFFDDE3EE);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color surfaceFill = Color(0xFFF4F7FA);
  static const Color surfaceWhite = Color(0xFFFFFFFF);

  // Status colours
  static const Color errorColor = Color(0xFFDC2626);
  static const Color successColor = Color(0xFF059669);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color infoColor = Color(0xFF2563EB);

  // ── Role-specific accents ──────────────────────────────────────────────────
  static const Color doctorAccent = Color(0xFF1D4ED8);   // Royal Blue
  static const Color assistantAccent = Color(0xFFEA580C); // Deep Orange

  // ── Navigation tile accents ────────────────────────────────────────────────
  static const Color analyticsAccent = Color(0xFF7C3AED); // Deep Violet
  static const Color staffAccent = Color(0xFF059669);
  static const Color auditAccent = Color(0xFF0284C7);

  // ── Neutral utilities ──────────────────────────────────────────────────────
  static const Color neutralLight = Color(0xFFEEF2F7);
  static const Color neutralDivider = Color(0xFFDDE3EE);

  // ── Shadow tokens ──────────────────────────────────────────────────────────
  static const Color neuShadowLight = Color(0x140F172A);
  static const Color neuShadowDark = Color(0x260D1B2A);

  // ── Section header label ───────────────────────────────────────────────────
  static const Color sectionLabel = textMuted;

  static String? get fontFamily => GoogleFonts.manrope().fontFamily;

  // ── Typography helpers ─────────────────────────────────────────────────────
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

  // ── Design token pass-throughs ─────────────────────────────────────────────
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

  // ── Gradient helpers ───────────────────────────────────────────────────────
  static LinearGradient get primaryGradient => const LinearGradient(
        colors: [Color(0xFF0F766E), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get heroGradient => const LinearGradient(
        colors: [Color(0xFF0D4F4A), Color(0xFF0F766E), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: [0.0, 0.55, 1.0],
      );

  static LinearGradient get subtleGradient => LinearGradient(
        colors: [
          primaryTeal.withValues(alpha: 0.06),
          secondary.withValues(alpha: 0.03),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // ── Backward compat ────────────────────────────────────────────────────────
  static ThemeData get neumorphicTheme => organicTheme;

  // ── Master ThemeData ───────────────────────────────────────────────────────
  static ThemeData get organicTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bgColor,
      fontFamily: GoogleFonts.manrope().fontFamily,

      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        brightness: Brightness.light,
        primary: primaryTeal,
        onPrimary: primaryForeground,
        primaryContainer: accent,
        onPrimaryContainer: accentForeground,
        secondary: secondary,
        onSecondary: secondaryForeground,
        surface: bgColor,
        onSurface: foreground,
        surfaceContainerHighest: surfaceFill,
        error: errorColor,
        onError: Colors.white,
        outline: border,
        outlineVariant: neutralDivider,
      ),

      // ── AppBar ─────────────────────────────────────────────────────────────
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
        iconTheme: const IconThemeData(color: foreground, size: 22),
      ),

      // ── Cards ──────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),

      // ── Input Decoration ───────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        labelStyle: const TextStyle(
          color: textMuted,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        floatingLabelStyle: const TextStyle(
          color: primaryTeal,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryTeal, width: 2),
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
          fontSize: 12,
        ),
        helperStyle: const TextStyle(
          color: textMuted,
          fontSize: 12,
        ),
      ),

      // ── Elevated Button (48 px tall, pill-shaped, gradient-ready) ──────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTeal,
          foregroundColor: primaryForeground,
          disabledBackgroundColor: primaryTeal.withValues(alpha: 0.45),
          disabledForegroundColor: primaryForeground.withValues(alpha: 0.7),
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // ── Outlined Button ────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryTeal,
          side: const BorderSide(color: primaryTeal, width: 1.5),
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // ── Text Button ────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryTeal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),

      // ── Divider ────────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),

      // ── Chip ───────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: surfaceFill,
        selectedColor: primaryTeal.withValues(alpha: 0.12),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
        side: const BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      // ── Navigation Bar (bottom) ────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardBg.withValues(alpha: 0.95),
        elevation: 0,
        height: 68,
        indicatorColor: primaryTeal.withValues(alpha: 0.13),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: primaryTeal,
            );
          }
          return GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryTeal, size: 22);
          }
          return const IconThemeData(color: textMuted, size: 22);
        }),
      ),

      // ── Legacy Bottom Nav Bar ─────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardBg.withValues(alpha: 0.95),
        selectedItemColor: primaryTeal,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),

      // ── Switch ────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryTeal;
          return neutralDivider;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryTeal.withValues(alpha: 0.28);
          }
          return neutralLight;
        }),
      ),

      // ── List Tile ─────────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        dense: false,
        minVerticalPadding: 8,
      ),

      // ── Progress Indicator ────────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryTeal,
        linearTrackColor: neutralLight,
      ),

      // ── Floating Action Button ────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryTeal,
        foregroundColor: primaryForeground,
        elevation: 4,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // ── Snack Bar ─────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: foreground,
        contentTextStyle: GoogleFonts.manrope(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Dialog ────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: cardBg,
        elevation: 8,
        shadowColor: neuShadowDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: foreground,
          letterSpacing: -0.2,
        ),
        contentTextStyle: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textMuted,
          height: 1.5,
        ),
      ),
    );
  }
}
