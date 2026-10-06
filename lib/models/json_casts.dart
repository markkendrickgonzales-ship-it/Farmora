/// Tolerant JSON cast helpers shared by the API data models.
///
/// PHP/MySQL rows can arrive with numbers as `int`, `double` or numeric
/// `String` depending on the column type, so every value read from a response
/// goes through one of these instead of a force-cast.
library;

num? asNum(dynamic v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v);
  return null;
}

int asInt(dynamic v, {int fallback = 0}) => asNum(v)?.toInt() ?? fallback;

double asDouble(dynamic v, {double fallback = 0}) =>
    asNum(v)?.toDouble() ?? fallback;

String asStr(dynamic v, {String fallback = ''}) => v?.toString() ?? fallback;

String? asStrOrNull(dynamic v) {
  final s = v?.toString();
  return (s == null || s.isEmpty) ? null : s;
}

/// Parses ISO-8601 timestamps coming back from the PHP endpoints; falls back
/// to [DateTime.now] so a bad row never crashes the UI.
DateTime asDate(dynamic v) =>
    DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();

DateTime? asDateOrNull(dynamic v) => DateTime.tryParse(v?.toString() ?? '');
