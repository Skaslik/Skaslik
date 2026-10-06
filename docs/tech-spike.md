# Сетевой/средовой доступ (S0 spike)

Цель S0 — снять верификацию зависимостей и платформенных возможностей, которую
невозможно выполнить в офлайн-окружении. Выполнить НА МАСШИНЕ с Flutter SDK + сетью.

## 1. Зависимости (Dart, pub.dev)
Проверить `flutter pub get` и `dart analyze` для каждой. Записать точную версию и
«работает/проблемы/запасной».

| Пакет | Зачем | Запасной | Статус |
|-------|-------|----------|--------|
| `cryptography` | X25519, XChaCha20-Poly1305, AES-GCM, HKDF, SHA | `pointycastle` (более тяжёлый API) | |
| `argon2` | Argon2id (derivation из секретов) | PBKDF2-SHA256 (через cryptography) | |
| `drift` + `drift_dev` | Локальная SQLite БД | `sqflite` напрямую | |
| `flutter_secure_storage` | Keystore/Keychain (секреты) | `enigma_box` | |
| `flutter_local_notifications` | Локальные напоминания | — | |
| `mobile_scanner` | Сканер штрихкодов/QR (детерминированный, ML Kit) | `zxing_lib` | |
| `qr_code` | Рендер QR | `qr_flutter` | |
| `flutter_reactive_ble` | BLE (L1 синк) | `ble_lib` | |
| `mdns_discoverer` | mDNS discovery | — | |
| `flutter_webrtc` | WebRTC data channel (L2 синк) | только BLE+L3 | |
| `file_picker` + SAF | Файлы Android (SAF) | — | |
| `local_auth` | Biometrics | `flutter_local_authenticator` | |
| `go_router` | Роутинг | — | |
| `riverpod` | State | — | |
| `cbor` | Бинарный формат change (опц.) | ручной bin | |
| `opencv_dart` | Выравнивание сканов (опц., большой размер APK) | ручной crop | |
| `image` | Обработка фото/превью | — | |
| `rxdart` | Streams/async | — | |

CRDT: ядро реализовано **в-росте** (`lib/sync`) как LWW-регистры + Lamport +
tombstones (детерминированное, полностью тестируемое, без нативных зависимостей).
Если spike покажет, что `automerge` (нативный Rust FFI) стабилен на Flutter —
допускается заменить движок, **сохранив формат envelope** (секция sync/envelope.dart).

## 2. Платформенные возможности
- [ ] Android: local notifications работают при force-kill (alarm-based).
- [ ] Android: BLE в фоне (foreground service), WebRTC data channel в фоне.
- [ ] iOS: background modes `bluetooth-central`, Keychain, FaceID, SAF-аналог
      (PhotosPicker / Files).
- [ ] Яндекс.Диск API: актуальные OAuth scopes, лимиты (req/s), chunked upload,
      list-polling по `updated_at`, наличие webhooks.
- [ ] ntfy: доставка сигнала при убитом приложении (FCM/APNs relay).

## 3. Результат
Заполнить таблицу статусами. Любая зависимость со статусом «сломан» → заменить
запасной из таблицы, архитектуру НЕ менять.
