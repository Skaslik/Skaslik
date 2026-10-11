/// File ↔ box format, as plain top-level functions so they can run in
/// `Isolate.run` without dragging app state along.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:ms_core/ms_core.dart' hide Clip;

/// Encrypts [src] into [dst] via `[dst].part` + rename, so a crash never
/// leaves a half file under the real name. Returns the plaintext size.
Future<int> encryptFileTo({
  required String src,
  required String dst,
  required Uint8List key,
  required String fileId,
}) async {
  final part = File('$dst.part');
  var size = 0;
  final plain = File(src).openRead().map((b) {
    size += b.length;
    return b;
  });
  final sink = part.openWrite();
  try {
    await sink.addStream(sealBoxStream(plain, key: key, fileId: fileId));
    await sink.flush();
    await sink.close();
  } catch (_) {
    await sink.close();
    if (await part.exists()) await part.delete();
    rethrow;
  }
  await part.rename(dst);
  return size;
}

/// Decrypts [src] into a plain file [dst]; removes [dst] on failure.
Future<void> decryptFileTo({
  required String src,
  required String dst,
  required Uint8List key,
  required String fileId,
}) async {
  final out = File(dst);
  final sink = out.openWrite();
  try {
    await sink.addStream(
        openBoxStream(File(src).openRead(), key: key, fileId: fileId));
    await sink.flush();
    await sink.close();
  } catch (_) {
    await sink.close();
    if (await out.exists()) await out.delete();
    rethrow;
  }
}

/// Decrypts [src] into memory (image preview).
Future<Uint8List> decryptFileToBytes({
  required String src,
  required Uint8List key,
  required String fileId,
}) async {
  final b = BytesBuilder(copy: false);
  await for (final piece
      in openBoxStream(File(src).openRead(), key: key, fileId: fileId)) {
    b.add(piece);
  }
  return b.takeBytes();
}
