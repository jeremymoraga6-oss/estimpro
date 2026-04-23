import 'package:flutter/material.dart';

const kGreen = Color(0xFF7CB342);
const kCharcoal = Color(0xFF2D3436);
const kBackground = Color(0xFFF1F5F9);
const kCardBg = Colors.white;
const kGrey = Color(0xFF636E72);
const kLightGrey = Color(0xFFB2BEC3);
const kBorderColor = Color(0xFFDFE6E9);
const kAmber = Color(0xFFFB8C00);
const kRed = Color(0xFFE53935);

const kDpeColors = {
  'A': Color(0xFF1A7A3C),
  'B': Color(0xFF4CAF50),
  'C': Color(0xFF8BC34A),
  'D': Color(0xFFFFC107),
  'E': Color(0xFFFF9800),
  'F': Color(0xFFF44336),
  'G': Color(0xFFB71C1C),
};

ThemeData buildTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: kGreen, brightness: Brightness.light),
      scaffoldBackgroundColor: kBackground,
      fontFamily: 'DMSans',
      appBarTheme: const AppBarTheme(
        backgroundColor: kCharcoal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: kCardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBorderColor, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBorderColor, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kGreen, width: 1.5),
        ),
      ),
      useMaterial3: true,
    );

BoxDecoration kCardDecoration({double radius = 16, Color? borderColor}) =>
    BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 2))],
      border: borderColor != null ? Border.all(color: borderColor, width: 1.5) : null,
    );

TextStyle kLabel = const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: kGrey, letterSpacing: 0.3);
TextStyle kCardTitle = const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kCharcoal);
TextStyle kSectionLabel = const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kGreen, letterSpacing: 0.6);
