/// Авторизация в Яндекс.Диске: OAuth 2.0 authorization-code + PKCE (S256).
///
/// Mobile-friendly loopback redirect (RFC 8252):
///  1. поднимаем локальный `dart:io`-сервер на `127.0.0.1:<port>`;
///  2. открываем Yandex-авторизацию в системном браузере с
///     `redirect_uri = http://127.0.0.1:<port>/oauth`;
///  3. браузер после логина редиректит обратно с `?code=...`;
///  4. обмениваем code на access/refresh-токены;
///  5. токены — в SecureVault.
///
/// Работает офлайн при сборке; сеть нужна только в момент авторизации
/// (у пользователя на телефоне).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ms_core/ms_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../security/secure_vault.dart';

/// Настройки Yandex OAuth-приложения.
///
/// Зарегистрировать приложение на https://oauth.yandex.ru/ и вписать сюда
/// client_id. Redirect URI — `http://127.0.0.1:8450/oauth` (см. [kRedirectPort]).
const String kYandexClientId = 'ВСТАВЬТЕ_CLIENT_ID';

/// Loopback-порт для OAuth redirect (фиксируется в настройках Yandex-приложения).
const int kRedirectPort = 8450;
const String _redirectPath = '/oauth';
const String _redirectUri = 'http://127.0.0.1:$kRedirectPort$_redirectPath';

const String _tokenEndpoint = 'https://oauth.yandex.ru/token';

const String _kAccess = 'ms/yandex/access';
const String _kRefresh = 'ms/yandex/refresh';


/// Ошибка OAuth-флоу.
class YandexAuthError implements Exception {
  final String message;
  YandexAuthError(this.message);
  @override
  String toString() => 'YandexAuthError: $message';
}

/// Менеджер OAuth-авторизации в Яндекс.Диске.
class YandexAuth {
  YandexAuth._();
  static final instance = YandexAuth._();

  final Random _rng = Random.secure();
  bool _authorizing = false;
  String? _accessToken;

  /// Есть ли сохранённый access-токен.
  bool get hasToken => _accessToken != null;

  /// Access-токен (bearer).
  String? get accessToken => _accessToken;

  /// Загрузить сохранённые токены.
  Future<void> load() async {
    final a = await SecureVault.read(_kAccess);
    if (a != null && a.isNotEmpty) _accessToken = a;
  }

  /// Полный флоу авторизации: браузер → loopback → обмен на токены.
  Future<void> authorize() async {
    if (_authorizing) throw YandexAuthError('уже идёт авторизация');
    _authorizing = true;
    HttpServer? server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, kRedirectPort,
          shared: false);

      // PKCE: verifier (48 случайных байт → base64url) → S256 challenge.
      final verifier = _b64UrlEncode(Uint8List.fromList(
          List<int>.generate(48, (_) => _rng.nextInt(256))));
      final challenge = await _s256(verifier);

      final codeCompleter = Completer<String>();
      server.listen((req) async {
        final q = req.uri.queryParameters;
        final code = q['code'];
        final err = q['error'];
        req.response
          ..statusCode = 200
          ..write('МС · авторизация завершена. Можно закрыть это окно.');
        await req.response.close();
        if (!codeCompleter.isCompleted) {
          if (code != null && code.isNotEmpty) {
            codeCompleter.complete(code);
          } else {
            codeCompleter
                .completeError(YandexAuthError(err ?? 'ошибка Yandex OAuth'));
          }
        }
      });

      final authUrl = yandexAuthorizeUrl(
        clientId: kYandexClientId,
        redirectUri: _redirectUri,
        codeChallenge: challenge,
      );
      final launched = await launchUrl(Uri.parse(authUrl),
          mode: LaunchMode.externalApplication);
      if (!launched) throw YandexAuthError('не удалось открыть браузер');

      final code = await codeCompleter.future.timeout(
          const Duration(seconds: 180),
          onTimeout: () =>
              throw YandexAuthError('таймаут: браузер не завершил вход'));

      await _exchangeCode(code, verifier);
    } finally {
      _authorizing = false;
      await server?.close(force: true);
    }
  }

  /// Обменять authorization code на токены и сохранить.
  Future<void> _exchangeCode(String code, String verifier) async {
    final json = await _tokenRequest({
      'grant_type': 'authorization_code',
      'code': code,
      'client_id': kYandexClientId,
      'code_verifier': verifier,
      'redirect_uri': _redirectUri,
    });
    _store(json);
  }

  /// Обновить access-токен по refresh-токену.
  Future<void> refresh() async {
    final refresh = await SecureVault.read(_kRefresh);
    if (refresh == null) throw YandexAuthError('нет refresh-токена');
    final json = await _tokenRequest({
      'grant_type': 'refresh_token',
      'refresh_token': refresh,
      'client_id': kYandexClientId,
    });
    _store(json);
  }

  void _store(Map<String, dynamic> json) {
    final access = json['access_token'] as String?;
    if (access == null) {
      throw YandexAuthError('нет access_token в ответе');
    }
    _accessToken = access;
    unawaited(SecureVault.write(_kAccess, access));
    final refresh = json['refresh_token'] as String?;
    if (refresh != null) unawaited(SecureVault.write(_kRefresh, refresh));
  }

  /// Отключиться: удалить токены.
  Future<void> disconnect() async {
    await SecureVault.delete(_kAccess);
    await SecureVault.delete(_kRefresh);
    _accessToken = null;
  }

  // --- helpers ---
  Future<Map<String, dynamic>> _tokenRequest(
      Map<String, String> body) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.parse(_tokenEndpoint));
      req.headers.set('Content-Type', 'application/x-www-form-urlencoded');
      req.write(_formEncode(body));
      final res = await req.close();
      final text = await utf8.decoder.bind(res).join();
      if (res.statusCode != 200) {
        throw YandexAuthError('token: ${res.statusCode} $text');
      }
      return jsonDecode(text) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  /// base64url(SHA-256(verifier)), без padding.
  Future<String> _s256(String verifier) async {
    final hex = await sha256Hex(utf8.encode(verifier));
    return _b64UrlEncode(hexToBytes(hex)).replaceAll('=', '');
  }

  String _formEncode(Map<String, String> body) => body.entries
      .map((e) =>
          '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');

  String _b64UrlEncode(List<int> bytes) => base64Url.encode(bytes);
}
