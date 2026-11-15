/// First visible character of [name], safe for empty strings, surrogate pairs
/// and Arabic. Never throws.
String initialOf(String? name, {String fallback = '?'}) {
  final t = (name ?? '').trim();
  if (t.isEmpty) return fallback;
  return String.fromCharCode(t.runes.first).toUpperCase();
}
