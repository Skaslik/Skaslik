import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_app/design_system/ms_theme.dart';
import 'package:ms_app/design_system/widgets/widgets.dart';

void main() {
  Future<Future<bool>> open(WidgetTester tester) async {
    late Future<bool> answer;
    await tester.pumpWidget(MaterialApp(
      theme: MsTheme.evening(),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => answer = confirmDanger(context,
              title: 'Удалить «a.pdf»?',
              body: 'Из сейфа он пропадёт насовсем.',
              action: 'Удалить'),
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    return answer;
  }

  testWidgets('both buttons start with a verb; the action answers yes',
      (tester) async {
    final answer = await open(tester);
    expect(find.text('Удалить «a.pdf»?'), findsOneWidget);
    expect(find.text('Из сейфа он пропадёт насовсем.'), findsOneWidget);
    expect(find.text('Отмена'), findsNothing);
    expect(find.text('Оставить'), findsOneWidget);
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(await answer, isTrue);
  });

  testWidgets('«Оставить» and tapping outside answer no', (tester) async {
    var answer = await open(tester);
    await tester.tap(find.text('Оставить'));
    await tester.pumpAndSettle();
    expect(await answer, isFalse);

    answer = await open(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(await answer, isFalse);
  });
}
