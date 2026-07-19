import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData light({required ColorScheme dynamicScheme}) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: dynamicScheme,
      scaffoldBackgroundColor: dynamicScheme.surface,
      textTheme: _textTheme,
    );
  }

  static ThemeData dark({
    required ColorScheme dynamicScheme,
    bool isAmoled = false,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: dynamicScheme,
      scaffoldBackgroundColor: isAmoled ? Colors.black : dynamicScheme.surface,
      textTheme: _textTheme,
    );
  }

  static TextTheme get _textTheme {
    return TextTheme(
      displayLarge: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
      titleLarge: GoogleFonts.oswald(fontSize: 30, fontStyle: FontStyle.normal),
      bodyMedium: GoogleFonts.merriweather(),
      displaySmall: GoogleFonts.pacifico(),
    );
  }
}
