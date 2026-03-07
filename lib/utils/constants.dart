import 'package:flutter/cupertino.dart';

/// Shared spacing, padding, and radius constants used across the app.
/// Use these instead of magic numbers to keep the UI consistent.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  /// Standard horizontal page padding
  static const EdgeInsets pagePadding =
      EdgeInsets.symmetric(horizontal: md, vertical: lg);

  /// Card inner padding
  static const EdgeInsets cardPadding =
      EdgeInsets.symmetric(horizontal: md, vertical: md);
}

class AppRadius {
  AppRadius._();

  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double card = 16.0;
  static const double button = 12.0;
  static const double pill = 50.0;
}

/// Semantic colour aliases — always use CupertinoColors so dark mode works.
class AppColors {
  AppColors._();

  static const CupertinoDynamicColor primary = CupertinoColors.systemOrange;
  static const CupertinoDynamicColor destructive = CupertinoColors.systemRed;
  static const CupertinoDynamicColor success = CupertinoColors.systemGreen;
  static const CupertinoDynamicColor info = CupertinoColors.systemBlue;
  static const CupertinoDynamicColor secondaryText =
      CupertinoColors.secondaryLabel;
  static const CupertinoDynamicColor cardBg =
      CupertinoColors.secondarySystemBackground;
  static const CupertinoDynamicColor separator = CupertinoColors.separator;
}

