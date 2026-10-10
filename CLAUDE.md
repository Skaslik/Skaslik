# МС — guide for Claude Code

«МС» (Михаил & София) is a private app for one couple: shared calendar, files on Yandex.Disk, piggy banks, loyalty cards, notes, and a «room» home screen with a shared candle. It is built in Flutter, Android first (Samsung S24 Ultra) and iOS later. It is local-first, end-to-end encrypted and has no server. **UI language: Russian.**

## Repo map

- `core/` — pure Dart, no Flutter. Contains:
  - `crypto/`: X25519 pairing, HKDF, XChaCha20-Poly1305, seed phrase;
  - `sync/`: CRDT replica (LWW per field + Lamport clocks + tombstones), sync engine, encrypted blobs, Yandex.Disk transport;
  - `domain/`: calendar, banks, cards, messages/notes/clips, delight (capsule, ritual, pulse, places);
  - `integrations/yandex_disk.dart`.
  - 84 tests.
- `ms_app/` — the Flutter app. `lib/core/` holds family, lock and fake calculator, notifications, secure vault, storage, sync service, and `providers.dart` (Riverpod). The UI is in `lib/design_system/` and `lib/features/<screen>/`; `lib/app.dart` (go_router) and `lib/main.dart` (onboarding → lock gate → app) are the entry points.
- `docs/design/` — **the agreed new UI.** Start with `docs/design/README.md`, then `docs/design/IMPLEMENTATION.md`.
- `PLAN.md` — master plan: invariants, architecture, module specs, QA matrix (RU). `запрос.txt` — the couple's request and the current status (RU). `dela.txt` — older status. `docs/tech-spike.md` — plugin checks.
- `fetch_all.sh` — offline build helper (Flutter SDK + pub cache + tests [+ Android SDK/APK]).

## Commands

```bash
cd core   && dart pub get && dart analyze && dart test          # must stay green
cd ms_app && flutter pub get && flutter analyze && flutter test
cd ms_app && flutter run                                         # device / emulator
cd ms_app && flutter build apk --debug
python3 docs/design/tools/gen_dart.py                            # tokens.json → docs/design/flutter/ms_tokens.dart
```

Some of the user's networks block pub.dev and dl.google.com (see `запрос.txt`). If `pub get` or Gradle can't download, stop and tell the user. Don't vendor packages and don't change mirrors on your own.

## Invariants — never break (PLAN.md §1.2)

- **I1** No own server. Sync goes over P2P (BLE/WebRTC) plus encrypted blobs on Yandex.Disk; ntfy only for wake-up signals.
- **I2** Zero-knowledge: only ciphertext leaves the devices.
- **I3** Offline-first: everything works without network.
- **I4** Cold start under 1.5 s; data is always local.
- **I5** Biometric/PIN gate and fake mode are part of the MVP.
- **I6** No ML or LLM, deterministic algorithms only. Barcode decoding, geometry and sunrise maths are fine.
- **I7** No monetisation, ads, analytics, accounts or e-mail sign-up.
- **I8** CRDT: no record may ever be lost. Data-model changes are **additive only**, because older app versions must still read new ops.
- **I9** Every «delight» feature must carry meaning («я рядом, я помню»).

## Architecture rules

- Domain logic lives in `core/` with tests. Widgets go through repos (`CalendarRepo`, `BanksRepo`, …) on a `MsStore` replica and never write replica fields directly.
- When the UI needs a new field, add it in `core/` first (parse/serialise plus a test), then in the UI.
- State is Riverpod (`lib/core/providers.dart`); routing is go_router. Keep `MsStore` as one ChangeNotifier per domain.
- Never log or print secrets, PINs, the seed or the family secret S. Leave the Yandex `client_id` placeholder as a placeholder.

## Design system rules (details: `docs/design/brand-book.md`)

- **Tokens:** `docs/design/tokens.json` is the source of truth. The Dart mirror is `ms_app/lib/design_system/ms_tokens.dart`, copied from the generated `docs/design/flutter/ms_tokens.dart`.
  - **Never hard-code** colours, sizes, radii or fonts in widgets. Use `context.ms.<token>`, `MsSpace`, `MsRadius` and `MsText`.
- **Themes:** «Вечер» (dark, default) and «День». The mode is `auto` (by sunset), `evening` or `day`, switched in «Мы → Тема».
- **Fonts** (bundled, offline):
  - `Onest` — interface text.
  - `IBMPlexMono` — dates, numbers, money, meta, upper-case eyebrows; always tabular figures.
  - `PTSerif` — only the greeting, the weather in the window, the wall note and the lock-screen title.
- **Icons:** Material Symbols **Rounded** via `material_symbols_icons`, 24 px, outline; filled only on the active tab. No emoji anywhere in the UI chrome.
- **Partner colours** `michael` / `sofia` are author markers only: an 8 px dot, a 3 px bar, a progress segment, a pin. Shared items show **two halves**, never a third colour.
- **Copy** is Russian and addresses the user as «ты». Buttons start with a verb. Verbs agree with the member's gender («добавил Михаил» / «добавила София»). Money is «84 500 ₽», dates «8 октября», time «21:14».
- **Status bar:** the mock-ups draw a phone frame and a fake status bar — do not implement them. Go edge-to-edge with the real status bar.
- The **room scene** is layered SVGs plus Flutter overlays, built exactly to `docs/design/IMPLEMENTATION.md` § Phase 3.

## Working agreement

- Implement in the phases of `docs/design/IMPLEMENTATION.md`, one at a time. After each phase:
  - `flutter analyze` is clean and core plus app tests are green;
  - post a short summary: what changed, what to check on a device, and which open-decision defaults you relied on.
  - Then wait for the user's OK.
- **Ask before you:**
  - add a package that is not listed in IMPLEMENTATION.md §1;
  - change existing `core/` data formats (additive fields are fine);
  - touch crypto or sync;
  - remove a user-facing feature.
- Open items in `docs/design/decisions.md`: implement the proposed default behind one constant, flag or setting.
- Small commits with English messages. Don't push unless the user asks.
