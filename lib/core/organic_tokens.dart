import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OrganicTokens {
  const OrganicTokens._();

  static const background = Color(0xFFFDFCF8);
  static const foreground = Color(0xFF2C2C24);
  static const primary = Color(0xFF5D7052);
  static const primaryLight = Color(0xFF7A9169);
  static const primaryForeground = Color(0xFFF3F4F1);
  static const secondary = Color(0xFFC18C5D);
  static const secondaryForeground = Color(0xFFFFFFFF);
  static const accent = Color(0xFFE6DCCD);
  static const accentForeground = Color(0xFF4A4A40);
  static const muted = Color(0xFFF0EBE5);
  static const mutedForeground = Color(0xFF78786C);
  static const border = Color(0xFFDED8CF);
  static const destructive = Color(0xFFA85448);
  static const card = Color(0xFFFEFEFA);

  static const shadowSoft = BoxShadow(
    color: Color(0x265D7052),
    blurRadius: 20,
    offset: Offset(0, 4),
    spreadRadius: -2,
  );

  static const shadowFloat = BoxShadow(
    color: Color(0x33C18C5D),
    blurRadius: 40,
    offset: Offset(0, 10),
    spreadRadius: -10,
  );

  static const shadowHover = BoxShadow(
    color: Color(0x335D7052),
    blurRadius: 40,
    offset: Offset(0, 20),
    spreadRadius: -10,
  );

  static const radiusStandard = 24.0;
  static const radiusLarge = 32.0;
  static const radiusPill = 100.0;

  static const radiusOrganic = <BorderRadius>[
    BorderRadius.only(
      topLeft: Radius.circular(48),
      topRight: Radius.circular(24),
      bottomLeft: Radius.circular(28),
      bottomRight: Radius.circular(56),
    ),
    BorderRadius.only(
      topLeft: Radius.circular(24),
      topRight: Radius.circular(56),
      bottomLeft: Radius.circular(48),
      bottomRight: Radius.circular(28),
    ),
    BorderRadius.only(
      topLeft: Radius.circular(60),
      topRight: Radius.circular(32),
      bottomLeft: Radius.circular(32),
      bottomRight: Radius.circular(44),
    ),
    BorderRadius.only(
      topLeft: Radius.circular(32),
      topRight: Radius.circular(60),
      bottomLeft: Radius.circular(44),
      bottomRight: Radius.circular(32),
    ),
    BorderRadius.only(
      topLeft: Radius.circular(44),
      topRight: Radius.circular(44),
      bottomLeft: Radius.circular(24),
      bottomRight: Radius.circular(60),
    ),
    BorderRadius.only(
      topLeft: Radius.circular(28),
      topRight: Radius.circular(48),
      bottomLeft: Radius.circular(60),
      bottomRight: Radius.circular(24),
    ),
  ];

  static const durationGentle = Duration(milliseconds: 300);
  static const durationFloat = Duration(milliseconds: 500);
  static const curveOrganic = Curves.easeInOutCubic;

  static TextStyle heading({
    double size = 24,
    FontWeight weight = FontWeight.w700,
    Color color = foreground,
  }) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: -0.3,
      );

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w600,
    Color color = foreground,
  }) =>
      GoogleFonts.nunito(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.45,
      );
}
