// responsive.dart
import 'package:flutter/material.dart';

class Responsive {
  // BREAKPOINTS (tablet-first)
  static const double mobile = 600;
  static const double tablet = 1024;
  static const double desktop = 1440;

  // =========================
  // DEVICE TYPE
  // =========================
  static bool isMobile(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPortrait = size.height >= size.width;
    // Tablet portrait (lebar < 900) tetap pakai layout mobile,
    // karena kontennya terlalu sempit untuk layout sidebar + tabel
    return size.width < mobile || (isPortrait && size.width < 900);
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return !isMobile(context) && width >= 600 && width < 1024;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tablet;
  }

  // =========================
  // SCREEN SIZE
  // =========================
  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static double widthPercent(BuildContext context, double percent) =>
      width(context) * percent;

  static double heightPercent(BuildContext context, double percent) =>
      height(context) * percent;

  // =========================
  // PADDING & SPACING
  // =========================
  static double horizontalPadding(BuildContext context) {
    if (isMobile(context)) return 16;
    if (isTablet(context)) return 24;
    return 32;
  }

  static double verticalPadding(BuildContext context) {
    if (isMobile(context)) return 16;
    if (isTablet(context)) return 20;
    return 24;
  }

  static double spaceSmall(BuildContext context) =>
      verticalPadding(context) * 0.5;

  static double spaceMedium(BuildContext context) =>
      verticalPadding(context);

  static double spaceLarge(BuildContext context) =>
      verticalPadding(context) * 1.5;

  static EdgeInsets paddingAll(BuildContext context) {
    return EdgeInsets.all(horizontalPadding(context));
  }

  static EdgeInsets paddingHorizontal(BuildContext context) {
    return EdgeInsets.symmetric(horizontal: horizontalPadding(context));
  }

  static EdgeInsets paddingVertical(BuildContext context) {
    return EdgeInsets.symmetric(vertical: verticalPadding(context));
  }

  static EdgeInsets responsivePadding(
    BuildContext context, {
    double horizontalFactor = 1.0,
    double verticalFactor = 1.0,
  }) {
    return EdgeInsets.symmetric(
      horizontal: horizontalPadding(context) * horizontalFactor,
      vertical: verticalPadding(context) * verticalFactor,
    );
  }

  // =========================
  // FONT SCALE (biar ga kegedean di tablet)
  // =========================
  static double fontScale(BuildContext context) {
    if (isMobile(context)) return 0.9;
    if (isTablet(context)) return 1.0;
    return 1.1;
  }

  // =========================
  // CARD / CONTAINER SIZE
  // =========================
  static double cardMaxWidth(BuildContext context) {
    final w = width(context);
    if (isMobile(context)) return w * 0.95;
    if (isTablet(context)) return 500;
    return 600;
  }

  static bool isTabletCompact(BuildContext context) => width(context) < 900;

  static double cartWidth(BuildContext context) => (width(context) * 0.35).clamp(300.0, 380.0);

  static double sidebarWidth(BuildContext context) {
    if (isDesktop(context)) return 260;
    if (isTablet(context)) return 220;
    return 0; // mobile pake drawer
  }

  // =========================
  // GRID SYSTEM (SUPER PENTING BUAT KASIR)
  // =========================
  static int gridCount(BuildContext context, {double minItemWidth = 160}) {
    final w = width(context);
    return (w / minItemWidth).floor().clamp(2, 6);
  }

  static double gridAspectRatio(BuildContext context) {
    if (isMobile(context)) return 0.8;
    if (isTablet(context)) return 0.9;
    return 1.0;
  }

  // =========================
  // BUTTON
  // =========================
  static double buttonHeight(BuildContext context) {
    if (isMobile(context)) return 52;
    if (isTablet(context)) return 56;
    return 60;
  }

  // =========================
  // CHART / TABLE HEIGHT
  // =========================
  static double chartHeight(BuildContext context) {
    final h = height(context);
    if (isMobile(context)) return h * 0.25;
    if (isTablet(context)) return h * 0.3;
    return h * 0.35;
  }

  static double tableHeight(BuildContext context) {
    final h = height(context);
    if (isMobile(context)) return h * 0.4;
    if (isTablet(context)) return h * 0.5;
    return h * 0.6;
  }

  // =========================
  // SAFE AREA HELPERS
  // =========================
  static double safeWidth(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    return width(context) - padding.left - padding.right;
  }

  static double safeHeight(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    return height(context) - padding.top - padding.bottom;
  }
}