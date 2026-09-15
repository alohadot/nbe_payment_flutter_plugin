import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nbe_payment_flutter_plugin/nbe_payment_flutter_plugin.dart';

// Guards against releasing with version constants that no longer describe what is bundled.
// Tests run from the package root, so paths are relative to it.
void main() {
  test('plugin version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);

    expect(NbePaymentVersions.plugin, version);
  });

  test('Android Gateway SDK version matches the Gradle dependency', () {
    final gradle = File('android/build.gradle.kts').readAsStringSync();
    final version = RegExp(
      r'val gatewaySdkVersion = "([^"]+)"',
    ).firstMatch(gradle)!.group(1);

    expect(NbePaymentVersions.androidGatewaySdk, version);
  });

  test(
    'iOS Gateway SDK version matches the latest released entry in CHANGES.md',
    () {
      final changes = File('ios/Frameworks/CHANGES.md').readAsStringSync();
      final version = RegExp(
        r'^## \[(\d+\.\d+\.\d+)\] - \d',
        multiLine: true,
      ).firstMatch(changes)!.group(1);

      expect(NbePaymentVersions.iosGatewaySdk, version);
    },
  );
}
