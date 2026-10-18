import 'package:flutter/material.dart';

import '../services/queue_service.dart';
import '../theme/app_theme.dart';
import '../utils/input_formatters.dart';
import '../utils/last_booking.dart';

/// Taking a queue, shared by the shop page and "book again": asks for a
/// phone number once if the profile has none, books with the customer's
/// name and phone so the shop can call, and remembers the zone and party
/// size for next time.
class BookingFlow {
  const BookingFlow(this.queueService);

  final QueueService queueService;

  /// The new queue label, or null if the customer backed out.
  Future<String?> book(
    BuildContext context, {
    required String uid,
    required String shopId,
    required String zone,
    required int partySize,
  }) async {
    final contact = await queueService.customerContact(uid);
    var phone = contact.phone;
    if (phone.isEmpty) {
      if (!context.mounted) return null;
      final entered = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const PhoneSheet(),
      );
      if (entered == null) return null;
      phone = entered;
      if (phone.isNotEmpty) await queueService.saveCustomerPhone(uid, phone);
    }
    final label = await queueService.bookQueue(
      uid: uid,
      shopId: shopId,
      zone: zone,
      partySize: partySize,
      customerName: contact.name,
      customerPhone: phone,
    );
    await LastBooking.save(shopId, zone, partySize);
    return label;
  }
}

/// Asks for a phone number before the first booking. Pops with the number,
/// with '' when the customer skips, or null when they close the sheet.
class PhoneSheet extends StatefulWidget {
  const PhoneSheet({super.key});

  @override
  State<PhoneSheet> createState() => _PhoneSheetState();
}

class _PhoneSheetState extends State<PhoneSheet> {
  final _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  /// Thai numbers have 9 (landline) or 10 (mobile) digits.
  bool get _valid {
    final digits = _phone.text.replaceAll('-', '');
    return digits.length == 9 || digits.length == 10;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ขอเบอร์โทรไว้ให้ร้านติดต่อ',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'ร้านจะโทรหาเมื่อถึงคิวถ้าคุณยังไม่มา ใส่ครั้งเดียว '
                'แอปจำไว้ให้ และแก้ได้ที่หน้าโปรไฟล์',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phone,
                autofocus: true,
                keyboardType: TextInputType.phone,
                maxLength: phoneMaxLength,
                inputFormatters: [phoneCharacters],
                style: AppFonts.numbers(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  labelText: 'เบอร์โทร',
                  hintText: '08x-xxx-xxxx',
                  prefixIcon: Icon(Icons.phone_outlined),
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted:
                    (_) =>
                        _valid
                            ? Navigator.pop(context, _phone.text.trim())
                            : null,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed:
                    _valid
                        ? () => Navigator.pop(context, _phone.text.trim())
                        : null,
                child: const Text('ใช้เบอร์นี้ แล้วรับคิว'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, ''),
                child: const Text('ข้าม รับคิวโดยไม่ให้เบอร์'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
