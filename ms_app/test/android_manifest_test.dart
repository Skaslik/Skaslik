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

  // open_filex adds these; МС only opens its own cache files, so the
  // permissions (and the «доступ к фото» prompt) aren't needed.
  test('storage and media permissions from open_filex are removed', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('xmlns:tools="http://schemas.android.com/tools"'));
    for (final perm in [
      'READ_EXTERNAL_STORAGE',
      'READ_MEDIA_IMAGES',
      'READ_MEDIA_VIDEO',
      'READ_MEDIA_AUDIO',
    ]) {
      expect(
          manifest,
          contains('<uses-permission android:name="android.permission.$perm" '
              'tools:node="remove"/>'),
          reason: perm);
    }
  });
}
