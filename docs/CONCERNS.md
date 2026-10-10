# Concerns log — UI rebuild

Running list of things that need your eye. Newest at the bottom; each entry says the phase, what I saw, what I did for now, and what I suggest. Nothing here blocks the current phase.

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
