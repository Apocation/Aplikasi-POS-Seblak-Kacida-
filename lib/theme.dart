import 'package:flutter/material.dart';

// ============================================================
//  SEBLAK POS — Design Tokens
//  Light theme, clean & professional
//  Referensi: seblak-prasmanan.lovable.app
// ============================================================

class PosColors {
  // Brand
  static const Color primary       = Color(0xFFE53E3E); // Red utama
  static const Color primaryDark   = Color(0xFFC53030);
  static const Color primaryLight  = Color(0xFFFEB2B2);
  static const Color primaryBg     = Color(0xFFFFF5F5); // Bg merah sangat pudar

  // Neutrals
  static const Color background    = Color(0xFFF7F8FA); // Abu terang
  static const Color surface       = Color(0xFFFFFFFF); // Putih card
  static const Color surfaceAlt    = Color(0xFFF0F2F5); // Chip / badge bg
  static const Color border        = Color(0xFFE8ECF0);
  static const Color borderLight   = Color(0xFFF0F3F6);

  // Sidebar
  static const Color sidebarBg     = Color(0xFF1A1A2E); // Navy gelap
  static const Color sidebarActive = Color(0xFFE53E3E);
  static const Color sidebarText   = Color(0xFFB0B8C8);
  static const Color sidebarTextActive = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary   = Color(0xFF1A202C);
  static const Color textSecondary = Color(0xFF718096);
  static const Color textMuted     = Color(0xFFA0AEC0);
  static const Color textOnRed     = Color(0xFFFFFFFF);

  // Status
  static const Color success       = Color(0xFF38A169);
  static const Color successBg     = Color(0xFFF0FFF4);
  static const Color warning       = Color(0xFFD69E2E);
  static const Color warningBg     = Color(0xFFFFFBEB);
  static const Color error         = Color(0xFFE53E3E);
  static const Color errorBg       = Color(0xFFFFF5F5);
  static const Color info          = Color(0xFF3182CE);
  static const Color infoBg        = Color(0xFFEBF8FF);

  // Shadow
  static const Color shadow        = Color(0x0D000000);
  static const Color shadowMd      = Color(0x1A000000);
}

class PosShadows {
  static const BoxShadow sm = BoxShadow(
    color: PosColors.shadow,
    blurRadius: 4,
    offset: Offset(0, 1),
  );
  static const BoxShadow md = BoxShadow(
    color: PosColors.shadowMd,
    blurRadius: 12,
    offset: Offset(0, 4),
  );
  static const BoxShadow lg = BoxShadow(
    color: PosColors.shadowMd,
    blurRadius: 24,
    offset: Offset(0, 8),
  );
  static const BoxShadow card = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  );
}

class PosRadius {
  static const double xs  = 6;
  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 20;
  static const double xxl = 24;
}

class PosSpacing {
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;
}

// ============================================================
//  THEME DATA
// ============================================================

final posTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  fontFamily: 'Roboto',

  colorScheme: const ColorScheme.light(
    primary:    PosColors.primary,
    onPrimary:  Colors.white,
    secondary:  Color(0xFF3182CE),
    onSecondary: Colors.white,
    surface:    PosColors.surface,
    onSurface:  PosColors.textPrimary,
    error:      PosColors.error,
    onError:    Colors.white,
  ),

  scaffoldBackgroundColor: PosColors.background,

  // AppBar
  appBarTheme: const AppBarTheme(
    backgroundColor: PosColors.surface,
    foregroundColor: PosColors.textPrimary,
    elevation: 0,
    scrolledUnderElevation: 1,
    shadowColor: PosColors.border,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: PosColors.textPrimary,
      letterSpacing: -0.3,
    ),
    iconTheme: IconThemeData(color: PosColors.textPrimary),
  ),

  // Card
  cardTheme: const CardThemeData(
    color: PosColors.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(PosRadius.lg)),
      side: BorderSide(color: PosColors.border, width: 1),
    ),
    margin: EdgeInsets.zero,
    shadowColor: Colors.transparent,
  ),

  // ElevatedButton
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: PosColors.primary,
      foregroundColor: Colors.white,
      disabledBackgroundColor: const Color(0xFFE2E8F0),
      disabledForegroundColor: PosColors.textMuted,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosRadius.md),
      ),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),
  ),

  // OutlinedButton
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: PosColors.textPrimary,
      side: const BorderSide(color: PosColors.border, width: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosRadius.md),
      ),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),

  // TextButton
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: PosColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),

  // Input
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: PosColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(PosRadius.md),
      borderSide: const BorderSide(color: PosColors.border, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(PosRadius.md),
      borderSide: const BorderSide(color: PosColors.border, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(PosRadius.md),
      borderSide: const BorderSide(color: PosColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(PosRadius.md),
      borderSide: const BorderSide(color: PosColors.error, width: 1.5),
    ),
    labelStyle: const TextStyle(
      color: PosColors.textSecondary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    hintStyle: const TextStyle(
      color: PosColors.textMuted,
      fontSize: 14,
    ),
    prefixIconColor: PosColors.textMuted,
  ),

  // Chip
  chipTheme: ChipThemeData(
    backgroundColor: PosColors.surfaceAlt,
    selectedColor: PosColors.primary,
    labelStyle: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: PosColors.textSecondary,
    ),
    secondaryLabelStyle: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(PosRadius.xxl),
      side: BorderSide.none,
    ),
  ),

  // Divider
  dividerTheme: const DividerThemeData(
    color: PosColors.borderLight,
    space: 1,
    thickness: 1,
  ),

  // ListTile
  listTileTheme: const ListTileThemeData(
    tileColor: Colors.transparent,
    textColor: PosColors.textPrimary,
    iconColor: PosColors.textSecondary,
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  ),

  // Text Theme
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      fontSize: 36, fontWeight: FontWeight.w800,
      color: PosColors.textPrimary, letterSpacing: -1,
    ),
    headlineLarge: TextStyle(
      fontSize: 28, fontWeight: FontWeight.w700,
      color: PosColors.textPrimary, letterSpacing: -0.5,
    ),
    headlineMedium: TextStyle(
      fontSize: 22, fontWeight: FontWeight.w700,
      color: PosColors.textPrimary, letterSpacing: -0.3,
    ),
    headlineSmall: TextStyle(
      fontSize: 18, fontWeight: FontWeight.w700,
      color: PosColors.textPrimary, letterSpacing: -0.2,
    ),
    titleLarge: TextStyle(
      fontSize: 16, fontWeight: FontWeight.w600,
      color: PosColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontSize: 14, fontWeight: FontWeight.w600,
      color: PosColors.textPrimary,
    ),
    titleSmall: TextStyle(
      fontSize: 13, fontWeight: FontWeight.w600,
      color: PosColors.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontSize: 15, fontWeight: FontWeight.w400,
      color: PosColors.textPrimary,
    ),
    bodyMedium: TextStyle(
      fontSize: 14, fontWeight: FontWeight.w400,
      color: PosColors.textSecondary,
    ),
    bodySmall: TextStyle(
      fontSize: 12, fontWeight: FontWeight.w400,
      color: PosColors.textMuted,
    ),
    labelLarge: TextStyle(
      fontSize: 14, fontWeight: FontWeight.w600,
      color: PosColors.textPrimary,
    ),
    labelSmall: TextStyle(
      fontSize: 11, fontWeight: FontWeight.w500,
      color: PosColors.textMuted,
      letterSpacing: 0.5,
    ),
  ),
);

// ============================================================
//  REUSABLE DECORATION HELPERS
// ============================================================

/// Card standar dengan border tipis
BoxDecoration posCardDecoration({
  Color? color,
  double radius = PosRadius.lg,
  bool withShadow = true,
}) {
  return BoxDecoration(
    color: color ?? PosColors.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: PosColors.border, width: 1),
    boxShadow: withShadow ? const [PosShadows.card] : null,
  );
}

/// Badge / chip status
BoxDecoration posStatusDecoration(Color bg, {double radius = PosRadius.xxl}) {
  return BoxDecoration(
    color: bg,
    borderRadius: BorderRadius.circular(radius),
  );
}

/// Highlight merah muda (untuk selected state)
BoxDecoration posHighlightDecoration({double radius = PosRadius.md}) {
  return BoxDecoration(
    color: PosColors.primaryBg,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: PosColors.primaryLight, width: 1.5),
  );
}