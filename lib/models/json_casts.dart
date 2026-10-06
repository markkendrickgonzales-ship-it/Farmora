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

DateTime asDate(dynamic v) =>
    DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();

DateTime? asDateOrNull(dynamic v) => DateTime.tryParse(v?.toString() ?? '');
