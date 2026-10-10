/// Клиент Yandex.Disk: OAuth PKCE, chunked upload (с resume), listing.
///
/// Чистый Dart (dart:io). На S0 — контракт + тесты с фейковым HTTP. Токен
/// хранит app-слой (SecureStorage); клиент принимает готовый bearer.
library;

import 'dart:convert';
import 'dart:io' as io;

/// Ошибка клиента с кодом.
class YandexDiskError implements Exception {
  final int? status;
  final String message;
  final YandexDiskErrorCode code;
  const YandexDiskError(this.code, this.message, {this.status});
  @override
  String toString() => 'YandexDiskError(${code.name}): $message';
}

enum YandexDiskErrorCode {
  unauthorized, // 401 — токен недействителен
  notFound, // 404 — файла нет
  conflict, // 409 — уже существует
  rateLimited, // 429
  server, // 5xx
  network, // нет соединения
  unexpected,
}


/// Disk usage, bytes (`GET /v1/disk`): «2,3 из 10 ГБ» in Files.
class DiskUsage {
  final int total;
  final int used;
  const DiskUsage({required this.total, required this.used});

  double get fraction => total <= 0 ? 0 : (used / total).clamp(0.0, 1.0);

  static DiskUsage? fromJson(Map<String, dynamic> j) {
    final total = j['total_space'], used = j['used_space'];
    if (total is! num || used is! num) return null;
    return DiskUsage(total: total.toInt(), used: used.toInt());
  }
}

/// Клиент Yandex.Disk.
class YandexDiskClient {
  final String token; // bearer
  final io.HttpClient _http;
  YandexDiskClient(this.token, {io.HttpClient? httpClient})
      : _http = httpClient ?? io.HttpClient();

  static const _api = 'https://cloud-api.yandex.net/v1/disk';

  /// Проверить токен.
  Future<bool> ping() async {
    try {
      final r = await _get('/resources?limit=1');
      return r.status == 200;
    } catch (_) {
      return false;
    }
  }

  /// Read-only: total and used space. `null` when offline or refused.
  Future<DiskUsage?> diskInfo() async {
    try {
      final r = await _get('');
      if (r.status != 200) return null;
      return DiskUsage.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<({int status, String body, Map<String, String> headers})>
      _readResponse(io.HttpClientResponse res) async {
    final body = await res.transform(utf8.decoder).join();
    final headers = <String, String>{};
    res.headers.forEach((name, values) => headers[name] = values.join(','));
    return (status: res.statusCode, body: body, headers: headers);
  }

  Future<({int status, String body, Map<String, String> headers})> _get(
      String path) async {
    final req = await _http.getUrl(Uri.parse('$_api$path'));
    req.headers.set('Authorization', 'OAuth $token');
    req.headers.set('Accept', 'application/json');
    final res = await req.close();
    return _readResponse(res);
  }


  /// Загрузить файл chunk-ами (с resume). Возвращает true при успехе.
  Future<bool> upload({
    required String path,
    required List<int> bytes,
    int chunkSize = 5 * 1024 * 1024,
    void Function(int uploaded, int total)? onProgress,
  }) async {
    final total = bytes.length;
    var uploaded = 0;
    while (uploaded < total) {
      final end = (uploaded + chunkSize - 1).clamp(0, total - 1);
      final chunk = bytes.sublist(uploaded, end + 1);
      final req = await _http.postUrl(Uri.parse('$_api/resources?path=${Uri.encodeComponent(path)}&overwrite=true'));
      req.headers.set('Authorization', 'OAuth $token');
      req.headers.set('Content-Type', 'application/octet-stream');
      req.headers.set('Range', 'bytes $uploaded-$end/$total');
      req.add(chunk);
      final res = await req.close();
      if (res.statusCode == 201) {
        uploaded = end + 1;
        onProgress?.call(uploaded, total);
      } else if (res.statusCode == 416) {
        // Range not satisfiable — файл уже загружен полностью.
        uploaded = total;
      } else {
        throw YandexDiskError(_codeFor(res.statusCode), 'upload $path',
            status: res.statusCode);
      }
    }
    onProgress?.call(total, total);
    return true;
  }

  /// Скачать файл.
  Future<List<int>> download(String path) async {
    final req = await _http.getUrl(
        Uri.parse('$_api/resources?path=${Uri.encodeComponent(path)}'));
    req.headers.set('Authorization', 'OAuth $token');
    final res = await req.close();
    if (res.statusCode != 200) {
      throw YandexDiskError(_codeFor(res.statusCode), 'download $path',
          status: res.statusCode);
    }
    final stream = await res.toList();
    return stream.expand((c) => c).toList();
  }

  /// Список файлов в каталоге.
  Future<List<String>> list(String path) async {
    final r = await _get('/resources?path=${Uri.encodeComponent(path)}&limit=100');
    if (r.status != 200) {
      throw YandexDiskError(_codeFor(r.status), 'list $path', status: r.status);
    }
    final map = jsonDecode(r.body) as Map<String, dynamic>;
    final items = (map['items'] as List? ?? const []).cast<Map<String, dynamic>>();
    return [for (final i in items) (i['name'] as String? ?? '')];
  }

  /// Создать каталог (идемпотентно: 409 = уже существует).
  Future<void> mkdir(String path) async {
    final req = await _http.postUrl(
        Uri.parse('$_api/resources?path=${Uri.encodeComponent(path)}&mkdir=true'));
    req.headers.set('Authorization', 'OAuth $token');
    final res = await req.close();
    await res.drain<void>();
    final status = res.statusCode;
    // 201 — создан; 400 «уже существует» / 409 — каталог на месте.
    if (status == 201 || status == 400 || status == 409) return;
    throw YandexDiskError(_codeFor(status), 'mkdir $path', status: status);
  }

  YandexDiskErrorCode _codeFor(int status) {
    switch (status) {
      case 401:
        return YandexDiskErrorCode.unauthorized;
      case 404:
        return YandexDiskErrorCode.notFound;
      case 409:
        return YandexDiskErrorCode.conflict;
      case 429:
        return YandexDiskErrorCode.rateLimited;
      default:
        if (status >= 500) return YandexDiskErrorCode.server;
        return YandexDiskErrorCode.unexpected;
    }
  }
}

// ---------------------------------------------------------------------------
// OAuth PKCE: параметры запроса авторизации (чистая генерация, без сети)
// ---------------------------------------------------------------------------

/// PKCE-пара (code_verifier, code_challenge) для Yandex OAuth.
///
/// [random] — источник случайности (byte 0..255); [sha256] — асинхронный
/// SHA-256 (см. ms_core). Детерминированно тестируемо с фиксированными источниками.
Future<({String verifier, String challenge})> pkce({
  required int Function() random,
  required Future<List<int>> Function(List<int>) sha256,
}) async {
  final verifierBytes = List<int>.generate(43, (_) => random() & 0xFF);
  final verifier = base64Url.encode(verifierBytes).replaceAll(RegExp(r'[=+/]'), '');
  final digest = await sha256(utf8.encode(verifier));
  final challenge = base64Url.encode(digest).replaceAll(RegExp(r'[=+/]'), '');
  return (verifier: verifier, challenge: challenge);
}

/// Собрать URL авторизации Yandex OAuth.
String yandexAuthorizeUrl({
  required String clientId,
  required String redirectUri,
  required String codeChallenge,
  List<String> scopes = const [
    'disk:files_read',
    'disk:files_upload',
    'disk:files_info',
  ],
  String? state,
}) {
  final q = <String, String>{
    'response_type': 'code',
    'client_id': clientId,
    'redirect_uri': redirectUri,
    'scope': scopes.join(' '),
    'code_challenge': codeChallenge,
    'code_challenge_method': 'S256',
    if (state != null) 'state': state,
  };
  final uri = Uri.https('oauth.yandex.ru', '/authorize',
      {for (final e in q.entries) Uri.encodeComponent(e.key): Uri.encodeComponent(e.value)});
  return uri.toString();
}

/// Обмен code на токены (параметры запроса; сетевой вызов — в app-слое).
Map<String, String> yandexTokenParams({
  required String clientId,
  required String code,
  required String codeVerifier,
  required String redirectUri,
}) => {
        'grant_type': 'authorization_code',
        'client_id': clientId,
        'code': code,
        'code_verifier': codeVerifier,
        'redirect_uri': redirectUri,
      };
