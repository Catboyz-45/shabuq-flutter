import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shabuq_flutter/theme/app_theme.dart';
import 'package:shabuq_flutter/widgets/opening_hours_field.dart';

void main() {
  Future<List<String>> pumpField(WidgetTester tester, String initial) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final changes = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: OpeningHoursField(initial: initial, onChanged: changes.add),
        ),
      ),
    );
    return changes;
  }

  testWidgets('a preset fills both times', (tester) async {
    final changes = await pumpField(tester, '11:00–22:00 ทุกวัน');

    await tester.tap(find.text('22:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('11:00–23:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ใช้เวลานี้'));
    await tester.pumpAndSettle();

    expect(changes.last, '11:00–23:00 ทุกวัน');
    expect(find.text('23:00'), findsOneWidget);
  });

  testWidgets('turning a day off updates the text', (tester) async {
    final changes = await pumpField(tester, '11:00–22:00 ทุกวัน');

    await tester.tap(find.text('อา.'));
    await tester.pump();

    expect(changes.last, '11:00–22:00 จ.–ส.');
  });

  testWidgets('keeps unreadable old text until edited', (tester) async {
    final changes = await pumpField(tester, 'เปิดเที่ยงถึงสี่ทุ่ม');

    expect(find.textContaining('เปิดเที่ยงถึงสี่ทุ่ม'), findsOneWidget);
    expect(changes, isEmpty);
  });
}
