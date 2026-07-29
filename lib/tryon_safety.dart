// Defensive parsing for the DailyWear Try On flow.
//
// The Try On crash — "type 'Null' is not a subtype of type 'String' in type
// cast" — came from `_currentOutfit['id'] as String` when the outfit map had
// no id. These helpers convert/validate nullable values instead of casting.

/// Trim to a non-empty String, or null. Never throws.
String? nullableText(dynamic value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}

/// Resolve the Try On outfit id: explicit id first, then the current outfit
/// map. Returns null when neither yields a usable id — replaces the unsafe
/// `map['id'] as String` cast.
String? resolveTryOnOutfitId(
  String? explicitId,
  Map<String, dynamic> currentOutfit,
) {
  return nullableText(explicitId) ?? nullableText(currentOutfit['id']);
}

/// Validate an image URL before it is used/navigated to. Accepts only a
/// non-empty http(s) URL; returns null otherwise. Never fabricates a URL.
String? safeImageUrl(dynamic value) {
  final t = nullableText(value);
  if (t == null) return null;
  final u = Uri.tryParse(t);
  if (u == null || !(u.isScheme('http') || u.isScheme('https'))) return null;
  return t;
}
