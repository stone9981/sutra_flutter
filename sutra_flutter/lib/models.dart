import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 科判大纲的一条。
class OutlineItem {
  final String t;
  final String d;

  const OutlineItem(this.t, this.d);

  factory OutlineItem.fromJson(Map<String, dynamic> j) =>
      OutlineItem(j['t'] as String? ?? '', j['d'] as String? ?? '');
}

/// 经文段落：k = p 正文 / h 标题 / b 译者题记 / x 卷首序跋。
class Para {
  final String k;
  final String v;

  const Para(this.k, this.v);

  factory Para.fromJson(Map<String, dynamic> j) =>
      Para(j['k'] as String? ?? 'p', j['v'] as String? ?? '');

  bool get isPreface => k == 'x';
}

class SutraText {
  final String work;
  final int juan;
  final int juanTotal;
  final String title;
  final String titleOrig;
  final String byline;
  final String category;
  final String scope;
  final String link;
  final String colophon;
  final int bodyChars;
  final List<Para> paras;

  const SutraText({
    required this.work,
    required this.juan,
    required this.juanTotal,
    required this.title,
    required this.titleOrig,
    required this.byline,
    required this.category,
    required this.scope,
    required this.link,
    required this.colophon,
    required this.bodyChars,
    required this.paras,
  });

  factory SutraText.fromJson(Map<String, dynamic> j) => SutraText(
        work: j['work'] as String? ?? '',
        juan: (j['juan'] as num?)?.toInt() ?? 1,
        juanTotal: (j['juanTotal'] as num?)?.toInt() ?? 1,
        title: j['title'] as String? ?? '',
        titleOrig: j['titleOrig'] as String? ?? '',
        byline: j['byline'] as String? ?? '',
        category: j['category'] as String? ?? '',
        scope: j['scope'] as String? ?? '',
        link: j['link'] as String? ?? '',
        colophon: j['colophon'] as String? ?? '',
        bodyChars: (j['bodyChars'] as num?)?.toInt() ?? 0,
        paras: (j['paras'] as List<dynamic>? ?? [])
            .map((e) => Para.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Sutra {
  final String key;
  final String cat;
  final String name;
  final String alt;
  final String tag;
  final String line;
  final String notes;
  final List<OutlineItem> outline;
  final SutraText text;

  /// 预先拼好的纯经文，供全文检索使用。
  late final String plainText;

  Sutra({
    required this.key,
    required this.cat,
    required this.name,
    required this.alt,
    required this.tag,
    required this.line,
    required this.notes,
    required this.outline,
    required this.text,
  }) {
    plainText = text.paras.map((p) => p.v).join('\n');
  }

  factory Sutra.fromJson(Map<String, dynamic> j) => Sutra(
        key: j['key'] as String? ?? '',
        cat: j['cat'] as String? ?? '',
        name: j['name'] as String? ?? '',
        alt: j['alt'] as String? ?? '',
        tag: j['tag'] as String? ?? '',
        line: j['line'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        outline: (j['outline'] as List<dynamic>? ?? [])
            .map((e) => OutlineItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        text: SutraText.fromJson(j['text'] as Map<String, dynamic>),
      );

  /// 经名、别名、译者、主题、大纲文字，供轻量检索。
  String get headText =>
      '$name $alt $cat $tag $line $notes ${text.byline} ${text.titleOrig} ' +
      outline.map((o) => '${o.t} ${o.d}').join(' ');
}

class Library {
  final List<String> categories;
  final List<Sutra> sutras;

  const Library(this.categories, this.sutras);

  /// 顶层函数，可传给 compute 在后台 isolate 解析。
  static Library parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return Library(
      (j['categories'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      (j['sutras'] as List<dynamic>? ?? [])
          .map((e) => Sutra.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static Future<Library> load() async {
    final raw = await rootBundle.loadString('assets/sutras.json');
    return compute(Library.parse, raw);
  }

  Sutra byKey(String key) => sutras.firstWhere((s) => s.key == key);
}
