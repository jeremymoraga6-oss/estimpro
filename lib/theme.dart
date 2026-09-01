import 'package:flutter/material.dart';

// Charte de marque — identique au rapport PDF (pdf_service.dart), pour que le
// client et l'agent voient exactement les mêmes couleurs.
const kGreen = Color(0xFF4DA050);
const kCharcoal = Color(0xFF1C2830);
const kBackground = Color(0xFFF7F8F8);
const kCardBg = Colors.white;
const kGrey = Color(0xFF5F6B72);
const kLightGrey = Color(0xFF9AA6AD);
const kBorderColor = Color(0xFFE4E8E5);
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
  'NC': Color(0xFF9E9E9E),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
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

/// Carte de contenu.
///
/// Filet fin plutôt qu'ombre portée : plus lisible en extérieur (une ombre
/// « bave » en plein soleil) et visuellement plus actuel.
BoxDecoration kCardDecoration({double radius = 14, Color? borderColor}) =>
    BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? kBorderColor, width: 1),
    );

TextStyle kLabel = const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: kGrey, letterSpacing: 0.1);
TextStyle kCardTitle = const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: kCharcoal);
TextStyle kSectionLabel = const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: kGreen, letterSpacing: 0.2);
