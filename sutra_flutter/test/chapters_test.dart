import 'package:flutter_test/flutter_test.dart';
import 'package:sutra_flutter/chapters.dart';
import 'package:sutra_flutter/models.dart';

Sutra _sutra(String key, String name, List<Para> paras) => Sutra(
      key: key,
      cat: '测试类',
      name: name,
      alt: '',
      tag: '',
      line: '',
      notes: '',
      outline: const <OutlineItem>[],
      text: SutraText(
        work: 'T0000',
        juan: 1,
        juanTotal: 1,
        title: name,
        titleOrig: '',
        byline: '',
        category: '',
        scope: '',
        link: '',
        colophon: '',
        bodyChars: 0,
        paras: paras,
      ),
    );

void main() {
  test('金刚经：四字分章数据为昭明太子三十二分，首尾正确', () {
    final list = kChapters['T0235_1']!;
    expect(list.length, 32);
    expect(list.first.t, '法会因由分第一');
    expect(list.last.t, '应化非真分第三十二');
  });

  test('金刚经：三十二分锚点能在正文中逐一定位且顺序递增', () {
    final chapters = kChapters['T0235_1']!;
    final paras = <Para>[
      for (final c in chapters) Para('p', '引文${c.a}结束'),
    ];
    final s = _sutra('T0235_1', '金刚般若波罗蜜经', paras);
    final structure = structureHeadings(s);
    expect(structure.length, 32);
    for (int i = 0; i < 32; i++) {
      expect(structure[i].title, chapters[i].t);
      expect(structure[i].para, i, reason: '第 ${i + 1} 分应定位到第 $i 段');
    }
    expect(hasCuratedChapters('T0235_1'), isTrue);
  });

  test('观无量寿经：十六观数据完整且锚点可定位', () {
    final chapters = kChapters['T0365_1']!;
    expect(chapters.length, 16);
    final paras = <Para>[
      for (final c in chapters) Para('p', '……${c.a}……'),
    ];
    final structure = structureHeadings(_sutra('T0365_1', '佛说观无量寿佛经', paras));
    expect(structure.length, 16);
    expect(structure.first.title, '第一观 · 日想观');
    expect(structure.last.title, '第十六观 · 下辈生观');
    expect(structure.every((h) => h.para >= 0), isTrue);
  });

  test('无人工分章时：从品目标题取结构，并过滤卷题/真言/目录等噪声', () {
    final s = _sutra('ZZZ_1', '测试经', <Para>[
      Para('h', '测试经'),
      Para('h', '测试经卷第一'),
      Para('h', '◎测试经'),
      Para('h', '真言'),
      Para('h', '测试经亦名别经'),
      Para('h', '目录测试品第一'),
      Para('h', '测试经终'),
      Para('h', '第二品'),
      Para('p', '正文'),
    ]);
    final structure = structureHeadings(s);
    expect(structure.map((h) => h.title).toList(), <String>['目录测试品第一', '第二品']);
    expect(hasCuratedChapters('ZZZ_1'), isFalse);
  });

  test('底本未分品目：结构为空（由界面给出说明）', () {
    final s = _sutra('T0251_1', '般若波罗蜜多心经', <Para>[
      Para('h', '般若波罗蜜多心经'),
      Para('p', '观自在菩萨行深般若波罗蜜多时。'),
    ]);
    expect(structureHeadings(s), isEmpty);
  });
}
