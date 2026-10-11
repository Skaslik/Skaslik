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

  // local_auth refuses anything but a FragmentActivity
  // (LocalAuthPlugin: `activity instanceof FragmentActivity`), so with a
  // plain FlutterActivity the fingerprint never works.
  test('MainActivity is a FlutterFragmentActivity (fingerprint unlock)', () {
    final kt = File('android/app/src/main/kotlin/ru/afanasev/ms_app/'
            'MainActivity.kt')
        .readAsStringSync();
    expect(kt, contains('class MainActivity : FlutterFragmentActivity()'));
    expect(kt, contains('import io.flutter.embedding.android.FlutterFragmentActivity'));
  });

  // I2: only ciphertext leaves the phone. The local replicas are plain
  // JSON, so no Google backup and no phone-to-phone transfer of app data;
  // recovery is the recovery sheet plus sync.
  test('no Google backup and no device transfer of app data', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
    expect(manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
    final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml')
        .readAsStringSync();
    for (final part in ['cloud-backup', 'device-transfer']) {
      expect(rules, contains('<$part>'), reason: part);
    }
    for (final domain in ['root', 'file', 'database', 'sharedpref', 'external']) {
      expect(
          RegExp('<exclude domain="$domain" path="\\."\\s*/>')
              .allMatches(rules)
              .length,
          2,
          reason: domain);
    }
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
