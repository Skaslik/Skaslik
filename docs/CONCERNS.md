# Concerns log — UI rebuild

Running list of things that need your eye. Newest at the bottom; each entry says the phase, what I saw, what I did for now, and what I suggest. Nothing here blocks the current phase.

## Status (2026-10-11)

| # | Status |
|---|---|
| 1 | **Fixed:** hybrid logical clock in `Replica` (approved «do your concerns»); tests in `core/test/replica_clock_test.dart`. |
| 2 | **Fixed:** `SyncService.dispose` is a no-op, like `Family`. |
| 3 | **Resolved:** the synced profile (Phase 7) decides who is «me». |
| 4, 5, 10, 15, 18, 21 | **Information only:** nothing to do. |
| 6 | **Open, roadmap S3:** upload and scan into the shared folder. The private box (part of 6) is done. |
| 7 | **Fixed:** «несколько дней» in the event sheet sets the last day. |
| 8 | **Fixed:** «Изменить событие»; emptied fields are cleared on both phones (`CalendarRepo.edit`). |
| 9 | **Open, your call:** confirm the screenshot sizes. |
| 11 | **Fixed:** without a PIN the triple tap does nothing; «Безопасность» says why. |
| 12 | **Fixed:** with no PIN the recovery sheet asks for the fingerprint. |
| 13 | **Open, on demand:** tell me any name that reads wrong. |
| 14 | **Open, your call:** a local-only «забыть этот телефон» if you want one. |
| 16 | **Fixed:** PIN set/verify/fake-exit are tested (cheap Argon2 cost in tests only). |
| 17 | **Open, your call:** bring back the full «думаю о тебе» list? |
| 19 | **Open, needs a phone:** QA-3, QA-5, cold start. Fingerprint unlock was broken on Android (plain FlutterActivity) — **fixed** with FlutterFragmentActivity. |
| 20, 22 | **By design:** the safe is local only; pure-Dart crypto speed. |
| 23 | **Fixed:** iPhone blurs the app-switcher snapshot while the safe is open (`AppDelegate.swift`). Screenshots can't be blocked on iOS. |
| 24 | **Fixed:** no Google backup and no device transfer (see below). |

---

## Open

### 1. Same-millisecond writes can lose in the sync engine (Phase 6) — needs your OK to fix
- **What:** `core/lib/src/sync/replica.dart` orders writes by `(time, seq, deviceId)`. On merge it raises its clock only to the partner's time, so two writes in the same millisecond on different phones are compared by each phone's **own** counter `seq`. A newer write can lose to an older one.
- **Seen in:** the checklist test. Mikhail adds «Хлеб» (not done), Sofia ticks it in the same millisecond, and the tick is lost. In real use writes are human-paced, so this is rare, but I8 says no record may be lost.
- **For now:** tests use a shared clock that always moves forward. No sync code changed.
- **Suggest:** after a merge, make the next local write at least `max seen time + 1` (a hybrid logical clock). It's a small, additive change to `Replica._newOp`, but it touches sync, so I'm asking first.

### 2. `SyncService` dies if a provider container is disposed (Phase 4)
- **What:** `syncServiceProvider` wraps the global `syncService`. Disposing a `ProviderScope` (tests, or any future nested scope) calls `dispose()` on that global, and every later use crashes.
- **For now:** I fixed the same issue in `Family` (its `dispose` is a no-op). Tests give each run its own `SyncService`.
- **Suggest:** the same one-line no-op `dispose()` in `SyncService`. It's sync code, so I'm asking first.

### 3. Who is «me» until the profile domain (Phases 3–6)
- **What:** until Phase 7 the app decides «me = София» only if the colour chosen at onboarding is Sofia's; otherwise «me = Михаил». Names and genders come from constants (decision #13).
- **Effect:** if both phones picked the same colour, both think they're the same person. Greetings and «добавил/добавила» would be wrong on one of them.
- **Plan:** Phase 7 adds the synced profile domain and replaces this.

### 4. Old entries stamped «local» count as mine (Phase 3)
- **What:** the pre-redesign Копилки and Записки screens wrote `'local'` instead of a device id, so after a sync both phones see those entries as their own.
- **For now:** new entries carry the real device id. Old `'local'` ones show as «ты» on both phones.
- **Suggest:** nothing, unless real data already exists. If it does, they can be re-attributed by hand.

### 5. «Ok» read as approval of the disk-info call (Phase 6 start)
- **What:** I asked whether to add a read-only `diskInfo()` to the Yandex client, and you replied «Ok».
- **For now:** I read that as yes. It's committed separately (`aa0e3bd`), so it's easy to revert.

### 6. Upload, scan and the private box are not built (Phase 5, by agreement)
- **What:** these are roadmap S3. The buttons show an honest toast, and «Открыть сейф» is disabled. Documents can still be recorded without a file.
- **Risk:** a reader of the screenshots might expect them to work. Worth a line in the next release note.

### 7. Multi-day events can't be created yet (Phase 4)
- **What:** the agreed add-event sheet has no end date, so the two-colour bars only show for events that already have an end, for example from an older version or a future import.
- **Suggest:** an optional «до …» date chip in the sheet, using the same Russian date wheel as Files.

### 8. Events can't be edited, only deleted (Phase 4)
- **What:** the old screen couldn't edit either. `editedBy/editedAt` are stored, and «изменил Михаил 2 мин назад» works for edits made elsewhere.
- **Suggest:** an «Изменить» action in the event sheet in Phase 8.

### 9. Screenshots vs. spec numbers differ in a few places
- **What:** where the screenshots (reference CSS, content-box) and the spec text (prototype, border-box) disagree, I followed the screenshots: list rows 80 px (spec says 56), calendar cells 46 px with a 28 px circle (spec says 42 / 30), file rows 72 px of content.
- **Suggest:** confirm these are the intended look. Each is one constant in `ms_sizes.dart`.

### 10. Windows desktop needs a rebuild for the new plugins (Phase 6)
- **What:** `wakelock_plus` and `screen_brightness` add native plugins, so the next `flutter run -d windows` runs a full native build (several minutes on this PC).
- **Note:** on Windows, «keep the screen on» works but «brightness 100 %» usually doesn't on desktop monitors. The card screen handles failures silently.

### 11. Leaving the fake calculator needs a PIN (Phase 7)
- **What:** the way back is «PIN, then =». If no PIN was set in onboarding, there is no way back except closing the app. Fake mode is not saved, so a cold start opens «МС» again.
- **Risk:** the cold-start escape also works for someone else holding the phone. The lock screen still asks for the fingerprint or PIN after it, so the data stays closed.
- **Suggest:** keep it, or make the PIN required in onboarding.

### 12. Recovery sheet without a PIN (Phase 7)
- **What:** «Лист восстановления» asks for the PIN first. With no PIN set, it opens straight away, behind the app's own fingerprint lock only.
- **Suggest:** ask for the fingerprint there too. `local_auth` is already in the app.

### 13. Name endings are a heuristic (Phase 7)
- **What:** «письмо от Софии», «у Сони на стене» come from a small rule for Russian first names. It is right for Михаил, Миша, София, Соня and common names. Unusual or foreign names are left as typed.
- **Suggest:** if a phrase reads wrong on the phone, tell me the name and I'll add it.

### 14. «Удалить все записи» also deletes them on the partner's phone (Phase 7)
- **What:** this is the old «Сбросить все данные», moved to «Мы → Устройства». It deletes calendar, piggy banks, files, cards, lists and notes through the CRDT, so they disappear on both phones after a sync. Capsules, the pulse, the candle and the profile stay, as before.
- **Suggest:** a separate «забыть этот телефон» that wipes only local files, if that's what you expect from the button.

### 15. Lock-screen copy uses «ты» (Phase 7)
- **What:** the lock screenshot says «приложите палец или введите PIN». The brand book and IMPLEMENTATION.md say «ты», so the app says «приложи палец или введи PIN».

### 16. Onboarding and PIN aren't covered by widget tests (Phase 7)
- **What:** the PIN is hashed with Argon2id at 128 MB. That is too heavy to run in tests on this PC, so the tests cover the lock screen, the keypad, fake-mode entry and the calculator, but not a full onboarding or a correct-PIN unlock.
- **Check on the phone:** create a family, set a PIN, lock, unlock with the PIN, enter fake mode, leave it with «PIN =».

### 17. The «думаю о тебе» history list is gone (Phase 7)
- **What:** the old «Пульс» screen listed every «думаю о тебе». Now the pulse sheet shows the partner's latest one, and each one also appears in «Записки» as a bubble when sent from there. Nothing is deleted from the data.
- **Suggest:** say if you want the full list back as a section of the pulse sheet.

### 18. Larger touch areas without moving pixels (Phase 8)
- **What:** segments (32 px), small pills (36 px) and text links (18 px) were below 48 dp. A new wrapper, `MsTapTarget`, extends their touch and accessibility area to 48 dp around the centre, while the layout stays exactly as in the screenshots.
- **Trade-off:** where two controls sit closer than 48 dp, the margins overlap and the later one wins. No such pair exists on the current screens.
- **Check on the phone:** the «+ 1 000 ₽» pill and the «Месяц / Неделя / Список» switch should be easy to hit.

### 19. QA items that need a real phone (Phase 8)
- **QA-3, force-kill during sync:** not checkable here. The sync code wasn't touched in the redesign, and each domain still saves to its own file after every change. Check: start «Синхронизировать сейчас», kill the app from recents, reopen, sync again.
- **QA-5, offline reminder:** not checkable here. Event reminders still go through the same local scheduler as before. Check: flight mode, an event 2 minutes ahead with «за 1 мин», wait.
- **QA-12, fake mode:** covered by tests as far as possible. The calculator is its own tiny app with no МС colours, fonts or text, and it never builds the real screens. Not covered: the Android recents thumbnail may still show the last real screen, because the app doesn't set FLAG_SECURE. Suggest adding it if that matters.
- **Cold start under 1.5 s:** not measurable without a device. Nothing new waits on the network at start-up: the weather loads from its cache and refreshes in the background, and the room is local SVGs.

### 20. The private box lives on one phone only
- **What:** «Личный сейф» is not synced, not on Yandex.Disk and not in the recovery sheet. By design its password is not derived from the family secret (PLAN.md §2 п.5). A lost phone or a forgotten password loses the files. The create sheet says so.
- **Suggest:** an optional encrypted export to the Disk later, still behind the box password.

### 21. Opening a document briefly makes a plain copy
- **What:** PDFs and other non-images open in another app, which needs a readable file. МС writes it to its cache and deletes it when you come back to the app, when the safe locks, and on the next start. Photos open inside МС from memory only.
- **Also:** `file_picker` copies picked files to the cache; МС clears that right after encrypting. The original stays where it was, and the toast says so.

### 22. Pure-Dart crypto speed
- **What:** files are encrypted in pure Dart in a background isolate. Fine for documents and photos; a 200 MB cap keeps it bearable. `cryptography_flutter` would make it native-fast if needed.

### 23. Screenshot protection for the safe is Android-only
- **What:** while «Личный сейф» is open, Android blocks screenshots and blanks the recent-apps thumbnail (FLAG_SECURE). On iPhone the same call does nothing, so the app switcher snapshot can show the safe's list or an open photo.
- **Why not yet:** iOS needs native code (a blur over the window when the app resigns active) that can't be built or tested on this PC; iOS is «later» in CLAUDE.md.
- **Suggest:** add the blur in `ios/Runner/SceneDelegate.swift` behind the same `ms/secure_screen` channel when iPhone becomes a real target.

### 24. Android backed up the app's data to Google
- **What:** `allowBackup` was unset, so Android's Auto Backup uploaded the app folder to the user's Google account — including the local replicas, which are plain JSON (calendar, notes, lists). That breaks I2: only ciphertext may leave the phone.
- **Done:** `allowBackup="false"`, `fullBackupContent="false"`, and `data_extraction_rules.xml` exclude everything from cloud backup and from device-to-device transfer. A new phone recovers through the recovery sheet and sync. A test pins the manifest.
