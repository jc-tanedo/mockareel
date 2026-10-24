import 'package:flutter/material.dart';

const ink = Color(0xff171719),
    panel = Color(0xff232326),
    mint = Color(0xffb1a6ff);

ThemeData buildAppTheme() => ThemeData(
  brightness: Brightness.dark,
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xff202023),
    surfaceTintColor: Colors.transparent,
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Color(0xff202023),
    indicatorColor: Color(0xff39334f),
    height: 68,
  ),
  dividerTheme: const DividerThemeData(color: Color(0xff38383d), thickness: 1),
  sliderTheme: const SliderThemeData(
    trackHeight: 2,
    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
  ),
  scaffoldBackgroundColor: ink,
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: mint,
    brightness: Brightness.dark,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: panel,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
  ),
);
