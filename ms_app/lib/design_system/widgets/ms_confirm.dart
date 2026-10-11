import 'package:flutter/material.dart';

import '../ms_sizes.dart';
import '../ms_tokens.dart';

/// «Удалить …?» before anything that can't be undone. True only when the
/// red [action] is tapped; «Оставить» or tapping outside answers false.
/// Both buttons start with a verb (CLAUDE.md copy rules).
Future<bool> confirmDanger(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Оставить')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action,
                style: MsTextX.link.copyWith(color: ctx.ms.danger))),
      ],
    ),
  );
  return ok ?? false;
}
