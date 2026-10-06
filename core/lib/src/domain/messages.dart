/// Домен «Сообщения и заметки»: сообщения (текст/голос/фото/пинг), burn-режим,
/// scheduled delivery, общие заметки, общий буфер обмена.
library;

import '../sync/replica.dart';

/// Тип сообщения.
enum MsgKind { text, voice, photo, ping }

MsgKind parseMsgKind(String? s) {
  switch (s) {
    case 'voice': return MsgKind.voice;
    case 'photo': return MsgKind.photo;
    case 'ping': return MsgKind.ping;
    default: return MsgKind.text;
  }
}

/// Режим сгорания.
enum BurnMode { none, ttl24h, onView }

BurnMode parseBurn(String? s) {
  switch (s) {
    case 'ttl24h': return BurnMode.ttl24h;
    case 'onView': return BurnMode.onView;
    default: return BurnMode.none;
  }
}

/// Сообщение.
class Message {
  final String id;
  final String from;
  final MsgKind kind;
  final String? text;
  final String? mediaRef; // локальный/шифрованный blob ref
  final BurnMode burn;
  final int? scheduledFor; // ms — «не открывать до»
  final int at; // ms создания

  Message({
    required this.id,
    required this.from,
    required this.kind,
    this.text,
    this.mediaRef,
    this.burn = BurnMode.none,
    this.scheduledFor,
    required this.at,
  });

  static Message? fromFields(String id, Map<String, String> f) {
    final at = int.tryParse(f['at'] ?? '');
    if (at == null) return null;
    return Message(
      id: id,
      from: f['from'] ?? '',
      kind: parseMsgKind(f['kind']),
      text: f['text'],
      mediaRef: f['media'],
      burn: parseBurn(f['burn']),
      scheduledFor: int.tryParse(f['sched'] ?? ''),
      at: at,
    );
  }

  Map<String, String> toFields() => {
        'from': from,
        'kind': kind.name,
        if (text != null) 'text': text!,
        if (mediaRef != null) 'media': mediaRef!,
        'burn': burn.name,
        if (scheduledFor != null) 'sched': '$scheduledFor',
        'at': '$at',
      };
}

/// Состояние burn-жизнeнного цикла (вычисляется локально у получателя).
enum BurnState { live, viewable, burned }

/// Сообщение с учётом burn-состояния.
class MessageView {
  final Message m;
  final BurnState burnState;
  final bool revealed; // видно ли payload (для scheduled — после срока)
  const MessageView({required this.m, required this.burnState, required this.revealed});
}

/// Репозиторий сообщений поверх [Replica].
class MessagesRepo {
  final Replica replica;
  final String deviceId;
  MessagesRepo(this.replica, {required this.deviceId});

  static const _p = 'msg:';

  void send(Message m) {
    for (final entry in m.toFields().entries) {
      replica.set(_p + m.id, entry.key, entry.value);
    }
  }

  /// Отметка «просмотрено» (для on_view — запускает сгорание).
  void markViewed(String id) {
    replica.set(_p + id, 'viewed', '1');
  }

  /// Сгорание: tombstone payload (метаданные остаются для «следа»).
  void burn(String id, int at) {
    replica.set(_p + id, 'burnedAt', '$at');
    replica.set(_p + id, 'payload', 'burned');
  }

  Message? get(String id) {
    final f = replica.entity(_p + id);
    return f == null ? null : Message.fromFields(id, f);
  }

  /// Все сообщения, отсортированные по времени.
  List<Message> all() {
    final out = <Message>[];
    for (final e in replica.view().entries) {
      if (!e.key.startsWith(_p)) continue;
      final m = Message.fromFields(e.key.substring(_p.length), e.value);
      if (m != null) out.add(m);
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  /// Сообщения с учётом burn/scheduled (для рендера ленты).
  List<MessageView> render(DateTime now) {
    final views = <MessageView>[];
    for (final e in replica.view().entries) {
      if (!e.key.startsWith(_p)) continue;
      final f = e.value;
      final m = Message.fromFields(e.key.substring(_p.length), f);
      if (m == null) continue;
      final burnedAt = int.tryParse(f['burnedAt'] ?? '');
      final viewed = f['viewed'] == '1';
      var state = BurnState.live;
      if (burnedAt != null) {
        state = BurnState.burned;
      } else if (m.burn == BurnMode.onView && viewed) {
        state = BurnState.viewable; // ещё не сгорел, но был просмотрен
      } else if (m.burn == BurnMode.ttl24h &&
          m.at + 24 * 3600 * 1000 < now.millisecondsSinceEpoch) {
        state = BurnState.burned; // просрочено → должно сгореть
      }
      // Scheduled: payload скрыт до срока.
      final revealed = m.scheduledFor == null ||
          m.scheduledFor! <= now.millisecondsSinceEpoch;
      views.add(MessageView(m: m, burnState: state, revealed: revealed));
    }
    views.sort((a, b) => a.m.at.compareTo(b.m.at));
    return views;
  }

  /// Сообщения, которые нужно сжечь сейчас (просроченные TTL / просмотренные on_view).
  List<String> dueToBurn(DateTime now) {
    final due = <String>[];
    for (final e in replica.view().entries) {
      if (!e.key.startsWith(_p)) continue;
      final f = e.value;
      if (f['burnedAt'] != null) continue;
      final m = Message.fromFields(e.key.substring(_p.length), f);
      if (m == null) continue;
      if (m.burn == BurnMode.ttl24h &&
          m.at + 24 * 3600 * 1000 <= now.millisecondsSinceEpoch) {
        due.add(e.key.substring(_p.length));
      } else if (m.burn == BurnMode.onView && f['viewed'] == '1') {
        due.add(e.key.substring(_p.length));
      }
    }
    return due;
  }
}

/// Заметки (общие, CRDT-текст на стороне UI; здесь — структура).
class Note {
  final String id;
  final String title;
  final List<String> tags;
  final bool pinned;
  final int at;
  const Note({
    required this.id,
    required this.title,
    this.tags = const [],
    this.pinned = false,
    required this.at,
  });

  static Note? fromFields(String id, Map<String, String> f) {
    final at = int.tryParse(f['at'] ?? '');
    if (at == null) return null;
    return Note(
      id: id,
      title: f['title'] ?? id,
      tags: f['tags']?.split(',').where((t) => t.isNotEmpty).toList() ?? const [],
      pinned: f['pinned'] == '1',
      at: at,
    );
  }

  Map<String, String> toFields() => {
        'title': title,
        'tags': tags.join(','),
        'pinned': pinned ? '1' : '0',
        'at': '$at',
      };
}

class NotesRepo {
  final Replica replica;
  NotesRepo(this.replica);
  static const _p = 'note:';

  void upsert(Note n) {
    for (final entry in n.toFields().entries) {
      replica.set(_p + n.id, entry.key, entry.value);
    }
  }

  void remove(String id) => replica.delete(_p + id);

  Note? get(String id) {
    final f = replica.entity(_p + id);
    return f == null ? null : Note.fromFields(id, f);
  }

  List<Note> all() {
    final out = <Note>[];
    for (final e in replica.view().entries) {
      if (!e.key.startsWith(_p)) continue;
      final n = Note.fromFields(e.key.substring(_p.length), e.value);
      if (n != null) out.add(n);
    }
    out.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.at.compareTo(a.at);
    });
    return out;
  }
}

/// Общий буфер обмена (клипы).
class Clip {
  final String id;
  final String from;
  final String? text;
  final String? url;
  final int at;
  final int expiresAt;
  const Clip({
    required this.id,
    required this.from,
    this.text,
    this.url,
    required this.at,
    required this.expiresAt,
  });

  static Clip? fromFields(String id, Map<String, String> f) {
    final at = int.tryParse(f['at'] ?? '');
    final exp = int.tryParse(f['exp'] ?? '');
    if (at == null || exp == null) return null;
    return Clip(
      id: id,
      from: f['from'] ?? '',
      text: f['text'],
      url: f['url'],
      at: at,
      expiresAt: exp,
    );
  }

  Map<String, String> toFields() => {
        'from': from,
        if (text != null) 'text': text!,
        if (url != null) 'url': url!,
        'at': '$at',
        'exp': '$expiresAt',
      };
}

class ClipsRepo {
  final Replica replica;
  ClipsRepo(this.replica);
  static const _p = 'clip:';
  static const int ttl = 72 * 3600 * 1000; // 72h

  void put(Clip c) {
    for (final entry in c.toFields().entries) {
      replica.set(_p + c.id, entry.key, entry.value);
    }
  }

  void accept(String id) => replica.set(_p + id, 'accepted', '1');
  void decline(String id) => replica.delete(_p + id);

  Clip? get(String id) {
    final f = replica.entity(_p + id);
    return f == null ? null : Clip.fromFields(id, f);
  }

  List<Clip> all(DateTime now) {
    final out = <Clip>[];
    for (final e in replica.view().entries) {
      if (!e.key.startsWith(_p)) continue;
      if (e.value['accepted'] == '1') continue;
      final c = Clip.fromFields(e.key.substring(_p.length), e.value);
      if (c == null) continue;
      if (c.expiresAt <= now.millisecondsSinceEpoch) continue;
      out.add(c);
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }
}
