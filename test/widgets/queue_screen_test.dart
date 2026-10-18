import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shabuq_flutter/screens/queue_screen.dart';
import 'package:shabuq_flutter/services/admin_service.dart';
import 'package:shabuq_flutter/services/queue_service.dart';
import 'package:shabuq_flutter/services/shop_service.dart';
import 'package:shabuq_flutter/theme/app_theme.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late QueueService queues;
  late AdminService staff;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    queues = QueueService(firestore: firestore);
    staff = AdminService(
      firestore: firestore,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'staff')),
    );
    await firestore.collection('shops').doc('teenoi').set({
      'name': 'Teenoi',
      'zones': ['ในร้าน'],
      'pricePerPerson': 299,
      'active': true,
      'minutesPerQueue': 5,
    });
    for (final uid in ['first', 'me']) {
      await queues.bookQueue(
        uid: uid,
        shopId: 'teenoi',
        zone: 'ในร้าน',
        partySize: 2,
      );
    }
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: QueueScreen(
          queueService: queues,
          shopService: ShopService(firestore: firestore),
          uid: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the queue number, position and estimate', (tester) async {
    await pumpScreen(tester);

    expect(find.text('A002'), findsOneWidget);
    expect(find.text('รออีก 1 คิว'), findsOneWidget);
    // One queue ahead plus the customer, at five minutes each.
    expect(find.textContaining('ประมาณ 10 นาที'), findsOneWidget);
  });

  testWidgets('follows the shop calling queues', (tester) async {
    await pumpScreen(tester);

    await staff.callNext(shopId: 'teenoi', zone: 'ในร้าน');
    await tester.pumpAndSettle();
    expect(find.text('คิวถัดไป'), findsOneWidget);

    await staff.setQueueStatus(queueId: 'me', status: 'called');
    await tester.pumpAndSettle();
    expect(find.text('ถึงคิวแล้ว!'), findsOneWidget);
  });

  testWidgets('tells the shop the customer is on the way', (tester) async {
    // A tall screen, so the whole "your turn" panel fits.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await staff.setQueueStatus(queueId: 'me', status: 'called');
    await pumpScreen(tester);

    await tester.tap(find.text('กำลังเดินทางไป'));
    await tester.pumpAndSettle();

    expect(find.text('แจ้งร้านแล้วว่ากำลังเดินทางไป'), findsOneWidget);
    expect((await queues.queueOf('me').get()).data()!['onTheWayAt'], isNotNull);
  });

  testWidgets('shows closed queues in the history', (tester) async {
    await staff.closeQueue(queueId: 'me', outcome: 'no_show');
    await pumpScreen(tester);

    expect(find.text('ประวัติการใช้บริการ'), findsOneWidget);
    expect(find.text('ไม่มาตามคิว'), findsOneWidget);
    expect(find.text('คิวปัจจุบัน'), findsNothing);
  });

  testWidgets('books the same shop again from the history', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await staff.closeQueue(queueId: 'me', outcome: 'completed');
    await pumpScreen(tester);

    await tester.tap(find.text('จองอีกครั้ง'));
    // The fake Firestore answers on a timer, so let time pass.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'รับคิว'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    // No phone saved yet, so the app asks once; skip it.
    await tester.tap(find.text('ข้าม รับคิวโดยไม่ให้เบอร์'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    final queue = (await queues.queueOf('me').get()).data()!;
    expect(queue['shopId'], 'teenoi');
    expect(queue['partySize'], 2);
    expect(queue.containsKey('customerPhone'), isFalse);
    expect(find.text('จองอีกครั้ง'), findsNothing);
  });

  testWidgets('cancels after confirming', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('ยกเลิกคิว'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ใช่'));
    await tester.pumpAndSettle();

    expect((await queues.queueOf('me').get()).exists, isFalse);
    expect(find.text('ยังไม่มีการจอง'), findsOneWidget);
  });
}
