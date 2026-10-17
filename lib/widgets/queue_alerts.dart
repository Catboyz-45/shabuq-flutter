import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/queue_entry.dart';
import '../services/queue_service.dart';
import '../utils/queue_position.dart';

/// Watches the signed-in customer's queue on every tab and shows a banner at
/// the top when only a few queues are left and again when the shop calls them.
/// Tapping the banner opens the "My queue" tab.
///
/// This only works while the app is open; background push notifications need
/// Firebase Cloud Messaging plus Cloud Functions (Blaze plan).
class QueueAlerts extends StatefulWidget {
  const QueueAlerts({super.key, required this.child});

  /// Alert once when this many queues or fewer are left.
  static const nearThreshold = 2;

  final Widget child;

  @override
  State<QueueAlerts> createState() => _QueueAlertsState();
}

class _QueueAlertsState extends State<QueueAlerts> {
  final _queueService = QueueService();
  StreamSubscription<QueueEntry?>? _queueSub;
  StreamSubscription<List<QueueTicket>>? _ticketSub;
  String? _watchedTicketId;
  QueueEntry? _queue;
  final _alerted = <String>{};
  ({String message, bool urgent})? _banner;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _queueSub = _queueService.watchMyQueue(uid).listen(_onQueue);
    }
  }

  void _onQueue(QueueEntry? queue) {
    _queue = queue;
    final ticketId = queue?.ticketId;
    if (ticketId != _watchedTicketId) {
      _ticketSub?.cancel();
      _ticketSub = null;
      _watchedTicketId = ticketId;
      if (queue != null && ticketId != null) {
        _ticketSub = _queueService
            .watchWaitingTickets(
              shopId: queue.shopId,
              zone: queue.zone,
              queueDate: queue.queueDate ?? '',
            )
            .listen(_onTickets);
      }
    }
    if (queue != null && queue.status == 'called') {
      _alertOnce(
        '$ticketId:called',
        'ถึงคิว ${queue.queueLabel} แล้ว! เชิญที่หน้าร้าน',
        urgent: true,
      );
    }
  }

  void _onTickets(List<QueueTicket> tickets) {
    final queue = _queue;
    final ticketId = _watchedTicketId;
    if (queue == null ||
        ticketId == null ||
        queue.status != 'waiting' ||
        queue.isStale(queueDateKey(DateTime.now()))) {
      return;
    }
    final ahead = queuesAhead(
      waitingTickets: tickets,
      ownTicketId: ticketId,
      ownCreatedAt: queue.createdAt ?? DateTime.now(),
    );
    if (ahead <= QueueAlerts.nearThreshold) {
      _alertOnce(
        '$ticketId:near',
        ahead == 0
            ? 'คุณเป็นคิวถัดไป กรุณาเตรียมตัวใกล้ร้าน'
            : 'อีก $ahead คิวจะถึงคิวของคุณ',
      );
    }
  }

  void _alertOnce(String key, String message, {bool urgent = false}) {
    if (!mounted || !_alerted.add(key)) return;
    if (urgent) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    } else {
      HapticFeedback.mediumImpact();
    }
    _hideTimer?.cancel();
    setState(() => _banner = (message: message, urgent: urgent));
    _hideTimer = Timer(Duration(seconds: urgent ? 15 : 8), _hide);
  }

  void _hide() {
    if (mounted) setState(() => _banner = null);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _ticketSub?.cancel();
    _queueSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder:
                  (child, animation) => SlideTransition(
                    position: Tween(
                      begin: const Offset(0, -1),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
              child:
                  banner == null
                      ? const SizedBox.shrink()
                      : _AlertBanner(
                        key: ValueKey(banner),
                        message: banner.message,
                        urgent: banner.urgent,
                        onClose: _hide,
                      ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({
    super.key,
    required this.message,
    required this.urgent,
    required this.onClose,
  });

  final String message;
  final bool urgent;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // ใช้สีเข้มกับตัวอักษรขาวทั้งสองโหมดเพื่อให้อ่านง่าย
    final color = urgent ? const Color(0xFF15803D) : scheme.primary;
    final onColor = urgent ? Colors.white : scheme.onPrimary;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Material(
        color: color,
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            onClose();
            DefaultTabController.maybeOf(context)?.animateTo(1);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
            child: Row(
              children: [
                Icon(
                  urgent ? Icons.campaign : Icons.notifications_active,
                  color: onColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: onColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'ปิด',
                  onPressed: onClose,
                  icon: Icon(Icons.close, color: onColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
