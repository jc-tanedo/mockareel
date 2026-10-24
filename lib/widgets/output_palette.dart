import 'package:flutter/material.dart';

/// Colors belong to the rendered reel, independently of the editor's theme.
class OutputPalette {
  final bool dark;
  const OutputPalette({required this.dark});
  Color get surface => dark ? const Color(0xff202124) : Colors.white;
  Color get text => dark ? const Color(0xffe8eaed) : const Color(0xff202124);
  Color get muted => dark ? const Color(0xffbdc1c6) : const Color(0xff666d72);
  Color get accent => dark ? const Color(0xff8bd3dd) : const Color(0xff075d6b);
  Color get primaryText => dark ? const Color(0xff10373d) : Colors.white;
  Color get pale => dark ? const Color(0xff29464d) : const Color(0xffddf0f3);
  Color get iconSurface =>
      dark ? const Color(0xff303134) : const Color(0xfff1f3f4);
  Color get reviewSurface =>
      dark ? const Color(0xff303134) : const Color(0xffeef0f2);
  Color get reviewText =>
      dark ? const Color(0xffd3d7db) : const Color(0xff444a50);
  Color get hours => dark ? const Color(0xff81c995) : const Color(0xff39825d);
  Color get progress =>
      dark ? const Color(0xff8ab4f8) : const Color(0xff1a73e8);
  Color get inactiveDot =>
      dark ? const Color(0xff5f6368) : const Color(0xffd4d8de);
}
