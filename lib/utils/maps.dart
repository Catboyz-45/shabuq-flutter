import 'package:url_launcher/url_launcher.dart';

import '../models/shop.dart';

/// Opens Google Maps searching for the shop; false if nothing could open it.
Future<bool> openShopInMaps(Shop shop) {
  final query = '${shop.name} ${shop.location}'.trim();
  final uri = Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': query,
  });
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
