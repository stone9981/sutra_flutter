import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sutra_flutter/models.dart';
import 'package:sutra_flutter/palette.dart';
import 'package:sutra_flutter/reader.dart';
import 'package:sutra_flutter/state.dart';

/// 记录 open() 调用，验证大纲点击是否真的带 para 跳到原文。
class _SpyState extends AppState {
  int? lastIndex;
  int? lastTab;
  int? lastPara;

  @override
  void open(int index, {int? tabIndex, int? para, String? annotationId}) {
    lastIndex = index;
    lastTab = tabIndex;
    lastPara = para;
    super.open(index, tabIndex: tabIndex, para: para, annotationId: annotationId);
  }
}

Sutra _buildSutra() => Sutra(
      key: 'T0251_1',
      cat: '测试类',
      name: '测试经',
      alt: '别名',
      tag: '主题',
      line: '一句话提要',
      notes: '导读',
      outline: <OutlineItem>[
        OutlineItem('科判一', '菩提相关的说明，用来测试锚点定位。'),
        OutlineItem('科判二', '第二段科判的说明文字。'),
      ],
      text: SutraText(
        work: 'T0251',
        juan: 1,
        juanTotal: 1,
        title: '测试经',
        titleOrig: '測試經',
        byline: '译者',
        category: '测试类',
        scope: '全卷',
        link: 'http://example.com',
        colophon: '',
        bodyChars: 100,
        paras: <Para>[
          Para('p', '第一段落。'),
          Para('p', '第二段落。'),
          Para('p', '菩提相关的说明，用来测试锚点定位。'), // index 2，含科判一关键词
          Para('p', '第三段落。'),
          Para('h', '目录测试品第一'), // index 4，自动生成的结构条目
          Para('p', '品内正文。'),
        ],
      ),
    );

void main() {
  _SpyState _state() {
    final s = _buildSutra();
    final spy = _SpyState();
    spy.library = Library(<String>['测试类'], <Sutra>[s]);
    spy.currentIndex = 0;
    spy.tab = 0;
    spy.ready = true;
    return spy;
  }

  Widget _wrap(AppState state) => AppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Row(children: <Widget>[Expanded(child: ReaderPage())]),
            ),
          ),
        ),
      );

  testWidgets('大纲：科判条目默认折叠，点击标题可展开说明', (tester) async {
    final spy = _state();
    await tester.pumpWidget(_wrap(spy));
    // 默认折叠：说明文字不应出现
    expect(find.text('菩提相关的说明，用来测试锚点定位。'), findsNothing);
    // 点击科判标题展开
    await tester.tap(find.text('科判一'));
    await tester.pumpAndSettle();
    expect(find.text('菩提相关的说明，用来测试锚点定位。'), findsOneWidget);
  });

  testWidgets('大纲：科判「原文」按钮跳到对应段落（锚点命中关键词）', (tester) async {
    final spy = _state();
    await tester.pumpWidget(_wrap(spy));
    await tester.tap(find.text('原文').first);
    await tester.pumpAndSettle();
    expect(spy.lastIndex, 0);
    expect(spy.lastTab, 1);
    expect(spy.lastPara, 2, reason: '「菩提到」命中第 3 段（index 2）');
  });

  testWidgets('大纲：自动「本文结构」条目可点击跳转到品目标题段', (tester) async {
    final spy = _state();
    await tester.pumpWidget(_wrap(spy));
    expect(find.text('本文结构（品目 · 共 1）'), findsOneWidget);
    await tester.ensureVisible(find.text('目录测试品第一'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('目录测试品第一'));
    await tester.pumpAndSettle();
    expect(spy.lastIndex, 0);
    expect(spy.lastTab, 1);
    expect(spy.lastPara, 4, reason: '结构条目对应第 5 段（index 4）');
  });
}
