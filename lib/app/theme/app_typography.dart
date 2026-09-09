/// Typography system for Follow My Life.
/// Uses Space Grotesk as primary font with Google Fonts fallback.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  AppTypography._();

  // ─── Display ──────────────────────────────────────────────────
  static TextStyle displayLarge({Color? color}) => GoogleFonts.spaceGrotesk(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
        height: 1.1,
        color: color,
      );

  static TextStyle displayMedium({Color? color}) => GoogleFonts.spaceGrotesk(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        height: 1.15,
        color: color,
      );

  static TextStyle displaySmall({Color? color}) => GoogleFonts.spaceGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.2,
        color: color,
      );

  // ─── Headlines ────────────────────────────────────────────────
  static TextStyle headlineLarge({Color? color}) => GoogleFonts.spaceGrotesk(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.25,
        color: color,
      );

  static TextStyle headlineMedium({Color? color}) => GoogleFonts.spaceGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
        color: color,
      );

  static TextStyle headlineSmall({Color? color}) => GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.35,
        color: color,
      );

  // ─── Body ─────────────────────────────────────────────────────
  static TextStyle bodyLarge({Color? color}) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.5,
        color: color,
      );

  static TextStyle bodyMedium({Color? color}) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        height: 1.5,
        color: color,
      );

  static TextStyle bodySmall({Color? color}) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        height: 1.5,
        color: color,
      );

  // ─── Labels ───────────────────────────────────────────────────
  static TextStyle labelLarge({Color? color}) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.4,
        color: color,
      );

  static TextStyle labelMedium({Color? color}) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        height: 1.4,
        color: color,
      );

  static TextStyle labelSmall({Color? color}) => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        height: 1.4,
        color: color,
      );

  // ─── Money Display ────────────────────────────────────────────
  static TextStyle moneyLarge({Color? color}) => GoogleFonts.spaceGrotesk(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.1,
        color: color,
      );

  static TextStyle moneyMedium({Color? color}) => GoogleFonts.spaceGrotesk(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.2,
        color: color,
      );

  static TextStyle moneySmall({Color? color}) => GoogleFonts.spaceGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.3,
        color: color,
      );

  static TextStyle moneyCurrency({Color? color}) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.3,
        color: color,
      );

  // ─── TextTheme ────────────────────────────────────────────────
  static TextTheme textTheme(Color textColor) => TextTheme(
        displayLarge: displayLarge(color: textColor),
        displayMedium: displayMedium(color: textColor),
        displaySmall: displaySmall(color: textColor),
        headlineLarge: headlineLarge(color: textColor),
        headlineMedium: headlineMedium(color: textColor),
        headlineSmall: headlineSmall(color: textColor),
        bodyLarge: bodyLarge(color: textColor),
        bodyMedium: bodyMedium(color: textColor),
        bodySmall: bodySmall(color: textColor),
        labelLarge: labelLarge(color: textColor),
        labelMedium: labelMedium(color: textColor),
        labelSmall: labelSmall(color: textColor),
      );
}
