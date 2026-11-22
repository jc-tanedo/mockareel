import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final entry in const {
      'MiDaS': 'MiDaS-LICENSE.txt',
      'Streetview 3D maps': 'SOURCES.md',
    }.entries) {
      yield LicenseEntryWithLineBreaks([
        entry.key,
      ], await rootBundle.loadString('assets/streetview3d/${entry.value}'));
    }
  });
  runApp(const MockareelApp());
}
