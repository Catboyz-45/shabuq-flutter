import 'dart:math';

/// Status shown to a customer for their active queue.
enum QueueProgress { waiting, next, called, serving }

/// Statuses an active queue can have. Closed queues move to queueHistory with
/// one of [closedStatuses].
const activeStatuses = ['waiting', 'called', 'serving'];
const closedStatuses = ['completed', 'no_show', 'cancelled'];

/// Minutes a called customer has to show up before the shop may skip them.
const noShowGraceMinutes = 5;

/// Used for the wait estimate until the shop has called a few queues.
const defaultMinutesPerQueue = 10.0;

class QueueTicket {
  const QueueTicket({required this.id, required this.createdAt});

  final String id;
  final DateTime createdAt;
}

/// Counts waiting tickets created before [ownTicketId]. A ticket that has not
/// reached the server yet has no timestamp, so callers pass [ownCreatedAt]
/// (usually "now") and it sorts after everything already queued.
int queuesAhead({
  required List<QueueTicket> waitingTickets,
  required String ownTicketId,
  required DateTime ownCreatedAt,
}) {
  return waitingTickets
      .where(
        (ticket) =>
            ticket.id != ownTicketId &&
            (ticket.createdAt.isBefore(ownCreatedAt) ||
                (ticket.createdAt == ownCreatedAt &&
                    ticket.id.compareTo(ownTicketId) < 0)),
      )
      .length;
}

QueueProgress queueProgress({required String status, required int ahead}) {
  switch (status) {
    case 'called':
      return QueueProgress.called;
    case 'serving':
      return QueueProgress.serving;
    default:
      return ahead == 0 ? QueueProgress.next : QueueProgress.waiting;
  }
}

/// Zones are lettered by their order in the shop: the first zone is A.
String zoneCodeFor(List<String> zones, String zone) {
  final index = max(0, zones.indexOf(zone));
  return String.fromCharCode('A'.codeUnitAt(0) + min(index, 25));
}

String formatQueueLabel(String zoneCode, int number) =>
    '$zoneCode${number.toString().padLeft(3, '0')}';

/// Queue numbers restart at 1 every day (in the device's local time).
String queueDateKey(DateTime time) =>
    '${time.year}-${time.month.toString().padLeft(2, '0')}-'
    '${time.day.toString().padLeft(2, '0')}';

int nextQueueNumber({
  required String? counterDate,
  required int? counterLast,
  required String today,
}) {
  return counterDate == today ? (counterLast ?? 0) + 1 : 1;
}

/// Customers ahead plus the customer themself, times the shop's pace.
int estimateWaitMinutes({required int ahead, double? minutesPerQueue}) {
  final pace = minutesPerQueue ?? defaultMinutesPerQueue;
  return max(1, ((ahead + 1) * pace).round());
}

/// Moving average of the minutes between two "call next" presses. Gaps under
/// half a minute (double taps) or over an hour (a quiet period or a closed
/// shop) are ignored so they do not distort the estimate.
double? nextMinutesPerQueue({
  required double? previous,
  required double intervalMinutes,
}) {
  if (intervalMinutes < 0.5 || intervalMinutes > 60) return previous;
  if (previous == null) return intervalMinutes;
  return previous * 0.7 + intervalMinutes * 0.3;
}
