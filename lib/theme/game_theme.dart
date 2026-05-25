import 'package:flutter/material.dart';

class GameTheme {
  final Color primary;
  final List<Color> background;
  final Color card;
  final Color accent;

  final String logoAsset;
  final Color textPrimary;

  const GameTheme({
    required this.primary,
    required this.background,
    required this.card,
    required this.accent,
    required this.logoAsset,
    required this.textPrimary,
  });

  /// 🔵 Blue team
  factory GameTheme.blue() {
    return const GameTheme(
      primary: Colors.lightBlueAccent,
      accent: Colors.blue,
      background: [
        Color(0xFF0F2027),
        Color(0xFF203A43),
        Color(0xFF2C5364),
      ],
      card: Color(0xFF203A43),
      logoAsset: 'assets/images/codename_logo_blue.png',
      textPrimary: Colors.white,
    );
  }

  /// 🔴 Red team
  factory GameTheme.red() {
    return const GameTheme(
      primary: Colors.redAccent,
      accent: Colors.red,
      background: [
        Color(0xFF2C0F0F),
        Color(0xFF432020),
        Color(0xFF642C2C),
      ],
      card: Color(0xFF3A1A1A),
      logoAsset: 'assets/images/codename_logo_red.png',
      textPrimary: Colors.redAccent,
    );
  }

/// ⚪ Default / Neutral (no team yet)
factory GameTheme.defaultView() {
  return const GameTheme(
    // Primary actions (buttons, focus)
    primary: Color(0xFF1C1C1E), // iOS-like dark text
    accent: Color(0xFF6B7280),  // neutral gray accent

    // App background (body)
background: [
  Color(0xFFE1C7A3), // light roasted almond
  Color(0xFFC6A47A), // caramel brown
  Color(0xFFAD8A63), // soft coffee
],

    // Cards / sheets
    card: Colors.white,

    // Logo
    logoAsset: 'assets/images/codename_logo_default.png',

    // Main text color
    textPrimary: Color(0xFF111827), // almost-black, readable
  );
}

}