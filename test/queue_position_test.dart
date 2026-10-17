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
      expect(queueProgress(status: 'serving', ahead: 3), QueueProgress.serving);
      expect(
        queueProgress(status: 'cancelled', ahead: 0),
        QueueProgress.cancelled,
      );
    });

    test('is next only when waiting with nobody ahead', () {
      expect(queueProgress(status: 'waiting', ahead: 0), QueueProgress.next);
      expect(queueProgress(status: 'waiting', ahead: 2), QueueProgress.waiting);
    });
  });
}
