import 'package:shared_preferences/shared_preferences.dart';

/// The zone and party size last booked at each shop, kept on the device so
/// the shop page opens with them already chosen.
abstract final class LastBooking {
  static String _key(String shopId) => 'lastBooking.$shopId';

  static Future<({String zone, int partySize})?> load(String shopId) async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(
        _key(shopId),
      );
      final separator = saved?.indexOf('|') ?? -1;
      if (saved == null || separator < 1) return null;
      final partySize = int.tryParse(saved.substring(0, separator));
      if (partySize == null) return null;
      return (zone: saved.substring(separator + 1), partySize: partySize);
    } on Exception {
      // Storage can be unavailable (private browser window, tests).
      return null;
    }
  }

  static Future<void> save(String shopId, String zone, int partySize) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _key(shopId),
        '$partySize|$zone',
      );
    } on Exception {
      // Remembering is a convenience; booking already succeeded.
    }
  }
}
