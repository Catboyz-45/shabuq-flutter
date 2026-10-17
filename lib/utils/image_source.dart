/// Longest image link accepted; matches the limit in firestore.rules.
const maxImageSourceLength = 500;

/// Images are either an https link pasted by an admin, or one of the images
/// bundled with the app (`assets/images/...`, used by the demo data). Empty
/// means "no image" and shows a placeholder.
bool isAllowedImageSource(String source) {
  final value = source.trim();
  if (value.isEmpty) return true;
  if (value.length > maxImageSourceLength) return false;
  if (value.startsWith('assets/images/')) return !value.contains('..');
  final uri = Uri.tryParse(value);
  return uri != null && uri.scheme == 'https' && uri.host.contains('.');
}

/// Thai error for an image field, or null when the value is fine.
String? imageSourceError(String source) {
  if (isAllowedImageSource(source)) return null;
  return source.trim().length > maxImageSourceLength
      ? 'ลิงก์ยาวเกิน $maxImageSourceLength ตัวอักษร'
      : 'ต้องเป็นลิงก์ที่ขึ้นต้นด้วย https://';
}
