import 'package:flutter/material.dart';

final ThemeData workoutTheme = ThemeData(
  brightness: Brightness.dark,
  fontFamily: 'Comfortaa',
  scaffoldBackgroundColor: const Color(0xFF121212),
  primaryColor: const Color(0xFFFF9700),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFFFF9700),
    secondary: Color(0xFFFFB74D),
    tertiary: Color(0xFFE65100),
    surface: Color(0xFF1E1E1E),
    // ignore: deprecated_member_use
    background: Color(0xFF121212),
    error: Color(0xFFCF6679),
  ),
  cardTheme: CardThemeData(
    color: const Color(0xFF1E1E1E),
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Color(0xFF434343),
    selectedItemColor: Color(0xFFFF9700),
    unselectedItemColor: Color(0xFFA4A4A4),
  ),
);
