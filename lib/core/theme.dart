import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GymTheme {
  static const Color black = Color(0xFF121212);
  static const Color darkGray = Color(0xFF1E1E1E);
  static const Color neonGreen = Color(0xFF2ECC71);
  static const Color textWhite = Colors.white;

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: neonGreen,
    scaffoldBackgroundColor: black,
    cardColor: darkGray,
    textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme),
    appBarTheme: const AppBarTheme(backgroundColor: black, elevation: 0),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: neonGreen,
        foregroundColor: black,
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
  );
}