// Release builds use only the main manifest; Flutter adds INTERNET to the
// debug and profile ones. Without it the release APK can't sign in to
// Yandex.Disk (even the 127.0.0.1 receiver fails) or load the weather.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the release manifest asks for the internet', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest,
        contains('<uses-permission android:name="android.permission.INTERNET"/>'));
  });
}
