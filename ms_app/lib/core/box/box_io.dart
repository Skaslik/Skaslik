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
    await _closeQuietly(sink);
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
    await _closeQuietly(sink);
    if (await out.exists()) await out.delete();
    rethrow;
  }
}

/// After a failed write the sink may already be closed; closing it again
/// throws «File closed», which would hide the real error.
Future<void> _closeQuietly(IOSink sink) async {
  try {
    await sink.close();
  } catch (_) {
    // Already closed.
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
