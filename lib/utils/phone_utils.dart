/// Normalizes a phone number for Sudan and international messaging.
///
/// Rules:
/// - Strips whitespace, dashes, parentheses, dots, slashes.
/// - If phone is null or empty after stripping, returns null.
/// - Replaces '+249' or '00249' prefix with '249'.
/// - If phone starts with local '0' followed by 9 digits (10 digits total),
///   replaces leading '0' with '249' -> 12 digits.
/// - If phone has 9 digits and starts with '9' or '1' (local mobile code),
///   prepends '249' -> 12 digits.
/// - If phone is already in standard 12-digit format '249' + 9 digits, keeps it.
/// - If phone is an international number (8 to 15 digits), normalizes to digits only.
/// - Returns null if the normalized string is not a valid phone number.
String? normalizeSudanPhone(String? phone) {
  if (phone == null) return null;
  var cleaned = phone.trim().replaceAll(RegExp(r'[\s\-\(\)\./\\]'), '');
  if (cleaned.isEmpty) return null;

  if (cleaned.startsWith('00249')) {
    cleaned = '249${cleaned.substring(5)}';
  } else if (cleaned.startsWith('+249')) {
    cleaned = '249${cleaned.substring(4)}';
  } else if (cleaned.startsWith('00')) {
    cleaned = cleaned.substring(2);
  } else if (cleaned.startsWith('+')) {
    cleaned = cleaned.substring(1);
  }

  // Strictly check digits
  if (!RegExp(r'^\d+$').hasMatch(cleaned)) return null;

  // Sudan local: 0 + 9 digits (e.g. 0912345678, 0123456789) -> 249 + 9 digits
  if (cleaned.length == 10 && cleaned.startsWith('0')) {
    return '249${cleaned.substring(1)}';
  }

  // Sudan 9 digits starting with 9 or 1 (e.g. 912345678) -> 249 + 9 digits
  if (cleaned.length == 9 &&
      (cleaned.startsWith('9') || cleaned.startsWith('1'))) {
    return '249$cleaned';
  }

  // Sudan full: 249 + 9 digits = 12 digits
  if (cleaned.length == 12 && cleaned.startsWith('249')) {
    return cleaned;
  }

  // Generic valid international number between 8 and 15 digits (ITU E.164 max 15 digits)
  if (cleaned.length >= 8 && cleaned.length <= 15) {
    return cleaned;
  }

  return null;
}
