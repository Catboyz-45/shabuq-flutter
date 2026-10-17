import 'package:flutter_test/flutter_test.dart';
import 'package:shabuq_flutter/utils/queue_position.dart';

void main() {
  final base = DateTime(2026, 1, 1, 12);

  group('queuesAhead', () {
    test('counts only tickets created earlier', () {
      final tickets = [
        QueueTicket(id: 'a', createdAt: base),
        QueueTicket(id: 'b', createdAt: base.add(const Duration(minutes: 1))),
        QueueTicket(id: 'me', createdAt: base.add(const Duration(minutes: 2))),
        QueueTicket(id: 'c', createdAt: base.add(const Duration(minutes: 3))),
      ];

      expect(
        queuesAhead(
          waitingTickets: tickets,
          ownTicketId: 'me',
          ownCreatedAt: base.add(const Duration(minutes: 2)),
        ),
        2,
      );
    });

    test('is zero when first in line or the list is empty', () {
      expect(
        queuesAhead(waitingTickets: [], ownTicketId: 'me', ownCreatedAt: base),
        0,
      );
      expect(
        queuesAhead(
          waitingTickets: [QueueTicket(id: 'me', createdAt: base)],
          ownTicketId: 'me',
          ownCreatedAt: base,
        ),
        0,
      );
    });

    test('breaks timestamp ties by ticket id', () {
      final tickets = [
        QueueTicket(id: 'a', createdAt: base),
        QueueTicket(id: 'z', createdAt: base),
      ];

      expect(
        queuesAhead(
          waitingTickets: tickets,
          ownTicketId: 'm',
          ownCreatedAt: base,
        ),
        1,
      );
    });
  });

  group('queueProgress', () {
    test('uses the shop status before the position', () {
      expect(queueProgress(status: 'called', ahead: 3), QueueProgress.called);
      expect(queueProgress(status: 'serving', ahead: 0), QueueProgress.serving);
    });

    test('is next only when waiting with nobody ahead', () {
      expect(queueProgress(status: 'waiting', ahead: 0), QueueProgress.next);
      expect(queueProgress(status: 'waiting', ahead: 2), QueueProgress.waiting);
    });
  });

  group('queue numbers', () {
    test('letters zones by their order and falls back to A', () {
      const zones = ['ในร้าน', 'ริมหน้าต่าง', 'ระเบียง'];
      expect(zoneCodeFor(zones, 'ในร้าน'), 'A');
      expect(zoneCodeFor(zones, 'ระเบียง'), 'C');
      expect(zoneCodeFor(zones, 'ไม่มีโซนนี้'), 'A');
    });

    test('formats labels with three digits', () {
      expect(formatQueueLabel('A', 7), 'A007');
      expect(formatQueueLabel('B', 123), 'B123');
    });

    test('restarts at 1 on a new day', () {
      final today = queueDateKey(DateTime(2026, 3, 5, 23, 59));
      expect(today, '2026-03-05');
      expect(
        nextQueueNumber(counterDate: today, counterLast: 41, today: today),
        42,
      );
      expect(
        nextQueueNumber(
          counterDate: '2026-03-04',
          counterLast: 41,
          today: today,
        ),
        1,
      );
      expect(
        nextQueueNumber(counterDate: null, counterLast: null, today: today),
        1,
      );
    });
  });

  group('wait estimate', () {
    test('counts the customer and uses the default pace without data', () {
      expect(estimateWaitMinutes(ahead: 0), 10);
      expect(estimateWaitMinutes(ahead: 2, minutesPerQueue: 4.4), 13);
    });

    test('averages call intervals and ignores outliers', () {
      expect(nextMinutesPerQueue(previous: null, intervalMinutes: 8), 8);
      expect(
        nextMinutesPerQueue(previous: 10, intervalMinutes: 20),
        closeTo(13, 0.001),
      );
      expect(nextMinutesPerQueue(previous: 10, intervalMinutes: 0.1), 10);
      expect(nextMinutesPerQueue(previous: 10, intervalMinutes: 180), 10);
    });
  });
}
