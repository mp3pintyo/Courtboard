import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A pubspec.yaml `msix_config` szakaszának egy kulcsa (egyszerű, egysoros
/// YAML-értékekhez elég).
String? _msixValue(String pubspec, String key) {
  final section = pubspec.split(RegExp(r'^msix_config:\s*$', multiLine: true));
  if (section.length < 2) return null;
  return RegExp(
    '^  $key:\\s*(.+?)\\s*\$',
    multiLine: true,
  ).firstMatch(section[1])?.group(1);
}

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final version = RegExp(
    r'^version:\s*(\d+\.\d+\.\d+)\+\d+\s*$',
    multiLine: true,
  ).firstMatch(pubspec)?.group(1);

  test('a pubspec verziója x.y.z+build alakú', () {
    expect(version, isNotNull);
  });

  test('az MSIX-verzió a pubspec verziójából jön (x.y.z.0)', () {
    expect(_msixValue(pubspec, 'msix_version'), '$version.0');
  });

  test('az MSIX-azonosítók és a biztonságos alapbeállítások', () {
    expect(_msixValue(pubspec, 'display_name'), 'Courtboard');
    expect(_msixValue(pubspec, 'publisher_display_name'), 'Mp3Pintyo');
    expect(_msixValue(pubspec, 'identity_name'), 'Mp3Pintyo.Courtboard');
    expect(_msixValue(pubspec, 'capabilities'), 'internetClient');
    expect(_msixValue(pubspec, 'languages'), 'hu-hu, en-us');
    expect(_msixValue(pubspec, 'store'), 'false');
    // A build soha nem telepít tanúsítványt a gépre.
    expect(_msixValue(pubspec, 'install_certificate'), 'false');
    final logo = _msixValue(pubspec, 'logo_path');
    expect(logo, isNotNull);
    expect(File(logo!).existsSync(), isTrue);
  });
}
