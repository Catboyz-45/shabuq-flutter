/// Status shown to a customer for their active queue.
enum QueueProgress { waiting, next, serving, cancelled }

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
    case 'serving':
      return QueueProgress.serving;
    case 'cancelled':
      return QueueProgress.cancelled;
    default:
      return ahead == 0 ? QueueProgress.next : QueueProgress.waiting;
  }
}
