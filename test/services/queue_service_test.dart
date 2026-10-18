import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shabuq_flutter/services/admin_service.dart';
import 'package:shabuq_flutter/services/queue_service.dart';
import 'package:shabuq_flutter/utils/queue_position.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late QueueService queues;
  late AdminService admin;
  final today = queueDateKey(DateTime.now());

  Future<void> addShop({bool acceptingQueues = true}) {
    return firestore.collection('shops').doc('teenoi').set({
      'name': 'Teenoi',
      'zones': ['ในร้าน', 'ระเบียง'],
      'pricePerPerson': 299,
      'active': true,
      'acceptingQueues': acceptingQueues,
    });
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    queues = QueueService(firestore: firestore);
    admin = AdminService(
      firestore: firestore,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'staff')),
    );
    await addShop();
  });

  group('bookQueue', () {
    test('numbers queues per zone and day', () async {
      final first = await queues.bookQueue(
        uid: 'u1',
        shopId: 'teenoi',
        zone: 'ในร้าน',
        partySize: 2,
      );
      final second = await queues.bookQueue(
        uid: 'u2',
        shopId: 'teenoi',
        zone: 'ในร้าน',
        partySize: 3,
      );
      final otherZone = await queues.bookQueue(
        uid: 'u3',
        shopId: 'teenoi',
        zone: 'ระเบียง',
        partySize: 4,
      );

      expect([first, second, otherZone], ['A001', 'A002', 'B001']);
      final queue = (await queues.queueOf('u2').get()).data()!;
      expect(queue['queueDate'], today);
      final ticket = await queues.ticketOf(queue['ticketId'] as String).get();
      expect(ticket.data()!['queueLabel'], 'A002');
      expect(ticket.data()!.containsKey('userId'), isFalse);
    });

    test('restarts numbering when the counter is from another day', () async {
      await firestore
          .collection('shops')
          .doc('teenoi')
          .collection('queueCounters')
          .doc('A')
          .set({'date': '2000-01-01', 'last': 57});

      final label = await queues.bookQueue(
        uid: 'u1',
        shopId: 'teenoi',
        zone: 'ในร้าน',
        partySize: 2,
      );

      expect(label, 'A001');
    });

    test('refuses a second active queue for the same customer', () async {
      await queues.bookQueue(
        uid: 'u1',
        shopId: 'teenoi',
        zone: 'ในร้าน',
        partySize: 2,
      );

      expect(
        () => queues.bookQueue(
          uid: 'u1',
          shopId: 'teenoi',
          zone: 'ในร้าน',
          partySize: 2,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('refuses bookings while the shop is paused', () async {
      await addShop(acceptingQueues: false);

      expect(
        () => queues.bookQueue(
          uid: 'u1',
          shopId: 'teenoi',
          zone: 'ในร้าน',
          partySize: 2,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  test('cancelMyQueue removes the queue and its ticket', () async {
    await queues.bookQueue(
      uid: 'u1',
      shopId: 'teenoi',
      zone: 'ในร้าน',
      partySize: 2,
    );
    final ticketId =
        (await queues.queueOf('u1').get()).data()!['ticketId'] as String;

    await queues.cancelMyQueue('u1');

    expect((await queues.queueOf('u1').get()).exists, isFalse);
    expect((await queues.ticketOf(ticketId).get()).exists, isFalse);
  });

  group('staff actions', () {
    test('callNext calls the oldest of today and skips stale queues', () async {
      await firestore.collection('queues').doc('stale').set({
        'shopId': 'teenoi',
        'zone': 'ในร้าน',
        'status': 'waiting',
        'queueDate': '2000-01-01',
        'queueLabel': 'A099',
        'ticketId': 'stale',
        'createdAt': Timestamp.fromDate(DateTime(2000)),
      });
      await queues.bookQueue(
        uid: 'u1',
        shopId: 'teenoi',
        zone: 'ในร้าน',
        partySize: 2,
      );
      await queues.bookQueue(
        uid: 'u2',
        shopId: 'teenoi',
        zone: 'ในร้าน',
        partySize: 2,
      );

      final called = await admin.callNext(shopId: 'teenoi', zone: 'ในร้าน');

      expect(called, 'A001');
      final queue = (await queues.queueOf('u1').get()).data()!;
      expect(queue['status'], 'called');
      expect(queue['calledAt'], isA<Timestamp>());
      final ticket = await queues.ticketOf(queue['ticketId'] as String).get();
      expect(ticket.data()!['status'], 'called');
      final stale = await firestore.collection('queues').doc('stale').get();
      expect(stale.data()!['status'], 'waiting');
    });

    test('closeQueue moves the queue to history', () async {
      await queues.bookQueue(
        uid: 'u1',
        shopId: 'teenoi',
        zone: 'ในร้าน',
        partySize: 2,
      );
      final ticketId =
          (await queues.queueOf('u1').get()).data()!['ticketId'] as String;

      await admin.closeQueue(queueId: 'u1', outcome: 'no_show');

      expect((await queues.queueOf('u1').get()).exists, isFalse);
      expect((await queues.ticketOf(ticketId).get()).exists, isFalse);
      final history =
          (await firestore.collection('queueHistory').doc(ticketId).get())
              .data()!;
      expect(history['status'], 'no_show');
      expect(history['queueId'], 'u1');
      expect(history['completedBy'], 'staff');
    });

    test('closeQueues skips queues that are already gone', () async {
      await queues.bookQueue(
        uid: 'u1',
        shopId: 'teenoi',
        zone: 'ในร้าน',
        partySize: 2,
      );

      final closed = await admin.closeQueues(
        queueIds: ['u1', 'missing'],
        outcome: 'cancelled',
      );

      expect(closed, 1);
    });

    test('walk-ins get a number and no user', () async {
      final label = await queues.addWalkIn(
        shopId: 'teenoi',
        zone: 'ระเบียง',
        partySize: 4,
        customerName: ' คุณต้น ',
      );

      expect(label, 'B001');
      final walkIns =
          await firestore
              .collection('queues')
              .where('walkIn', isEqualTo: true)
              .get();
      expect(walkIns.docs.single.id, startsWith('walkin-'));
      expect(walkIns.docs.single.data()['userId'], '');
      expect(walkIns.docs.single.data()['customerName'], 'คุณต้น');
    });
  });

  test('markOnTheWay records the time and survives closing', () async {
    await addShop();
    await queues.bookQueue(
      uid: 'me',
      shopId: 'teenoi',
      zone: 'ในร้าน',
      partySize: 2,
    );
    await admin.setQueueStatus(queueId: 'me', status: 'called');

    await queues.markOnTheWay('me');
    final queue = (await queues.queueOf('me').get()).data()!;
    expect(queue['onTheWayAt'], isA<Timestamp>());

    await admin.closeQueue(queueId: 'me', outcome: 'completed');
    final history = await firestore.collection('queueHistory').get();
    expect(history.docs.single.data()['onTheWayAt'], isA<Timestamp>());
  });

  test('a booking carries the name and phone the shop can call', () async {
    await addShop();
    await firestore.collection('users').doc('me').set({
      'displayName': 'สมชาย',
      'phone': '081-234-5678',
    });

    final contact = await queues.customerContact('me');
    await queues.bookQueue(
      uid: 'me',
      shopId: 'teenoi',
      zone: 'ในร้าน',
      partySize: 2,
      customerName: contact.name,
      customerPhone: contact.phone,
    );

    final queue = (await queues.queueOf('me').get()).data()!;
    expect(queue['customerName'], 'สมชาย');
    expect(queue['customerPhone'], '081-234-5678');
  });
}
