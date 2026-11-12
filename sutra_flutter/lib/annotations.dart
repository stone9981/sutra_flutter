import 'dart:convert';

/// 四种标注色（ARGB），UI 层用 Color(kMarkArgb[i]) 取色。
const List<int> kMarkArgb = <int>[
  0xFFB4503C, // 朱砂
  0xFFD2A03C, // 藤黄
  0xFF3E8E7A, // 青碧
  0xFF4A6FA5, // 靛蓝
];

const List<String> kMarkNames = <String>['朱砂', '藤黄', '青碧', '靛蓝'];

int normalizeColor(int c) => (c < 0 || c >= kMarkArgb.length) ? 0 : c;

/// 一条标注：定位到某部经某一卷的某一段，字符区间 [start, end)。
/// start/end 采用 Dart 字符串的 UTF-16 code unit 索引，与 TextSelection 完全一致。
class Annotation {
  final String id;
  final String sutraKey;
  final int para;
  final int start;
  final int end;
  final String quote;
  final String note;
  final int color;
  final int createdAt;
  final int updatedAt;

  const Annotation({
    required this.id,
    required this.sutraKey,
    required this.para,
    required this.start,
    required this.end,
    required this.quote,
    required this.note,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Annotation.create({
    required String sutraKey,
    required int para,
    required int start,
    required int end,
    required String quote,
    required String note,
    int color = 0,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return Annotation(
      id: 'a${now}_${quote.hashCode.abs()}_$start',
      sutraKey: sutraKey,
      para: para,
      start: start,
      end: end,
      quote: quote,
      note: note,
      color: normalizeColor(color),
      createdAt: now,
      updatedAt: now,
    );
  }

  Annotation copyWith({String? note, int? color}) => Annotation(
        id: id,
        sutraKey: sutraKey,
        para: para,
        start: start,
        end: end,
        quote: quote,
        note: note ?? this.note,
        color: color == null ? this.color : normalizeColor(color),
        createdAt: createdAt,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'sutraKey': sutraKey,
        'para': para,
        'start': start,
        'end': end,
        'quote': quote,
        'note': note,
        'color': color,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  static Annotation fromJson(Map<String, dynamic> j) => Annotation(
        id: j['id'] as String? ?? '',
        sutraKey: j['sutraKey'] as String? ?? '',
        para: (j['para'] as num?)?.toInt() ?? 0,
        start: (j['start'] as num?)?.toInt() ?? 0,
        end: (j['end'] as num?)?.toInt() ?? 0,
        quote: j['quote'] as String? ?? '',
        note: j['note'] as String? ?? '',
        color: normalizeColor((j['color'] as num?)?.toInt() ?? 0),
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
        updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
      );

  static List<Annotation> decode(String? raw) {
    if (raw == null || raw.isEmpty) return <Annotation>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Annotation.fromJson(e as Map<String, dynamic>))
          .where((a) => a.id.isNotEmpty && a.sutraKey.isNotEmpty)
          .toList();
    } catch (_) {
      return <Annotation>[];
    }
  }

  static String encode(List<Annotation> list) =>
      jsonEncode(list.map((a) => a.toJson()).toList());
}

/// 段落按标注区间切分后的一个连续片段。
class Segment {
  final int start;
  final int end;
  final List<Annotation> marks;

  const Segment(this.start, this.end, this.marks);

  bool get highlighted => marks.isNotEmpty;

  /// 重叠时用最后创建的一条标注的颜色。
  int get color => marks.isEmpty
      ? 0
      : marks.reduce((a, b) => a.createdAt >= b.createdAt ? a : b).color;
}

bool _sameMarks(List<Annotation> a, List<Annotation> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id) return false;
  }
  return true;
}

/// 把一段文字按所有标注的边界切成不重叠的片段。
/// 允许标注互相重叠：重叠区段的 marks 会包含覆盖它的全部标注。
/// 越界或空区间的标注会被忽略，避免旧数据导致越界崩溃。
List<Segment> splitSegments(String text, List<Annotation> marks) {
  final len = text.length;
  final valid = marks
      .where((a) => a.start >= 0 && a.start < a.end && a.end <= len)
      .toList()
    ..sort((a, b) => a.start == b.start
        ? a.createdAt.compareTo(b.createdAt)
        : a.start.compareTo(b.start));

  if (valid.isEmpty) return <Segment>[Segment(0, len, const <Annotation>[])];

  final points = <int>{0, len};
  for (final a in valid) {
    points.add(a.start);
    points.add(a.end);
  }
  final sorted = points.toList()..sort();

  final out = <Segment>[];
  for (int i = 0; i < sorted.length - 1; i++) {
    final s = sorted[i];
    final e = sorted[i + 1];
    if (e <= s) continue;
    final covering =
        valid.where((a) => a.start <= s && a.end >= e).toList();
    if (out.isNotEmpty && out.last.end == s && _sameMarks(out.last.marks, covering)) {
      out[out.length - 1] = Segment(out.last.start, e, out.last.marks);
    } else {
      out.add(Segment(s, e, covering));
    }
  }
  return out;
}
