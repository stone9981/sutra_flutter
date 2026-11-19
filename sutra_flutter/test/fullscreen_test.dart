import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sutra_flutter/models.dart';
import 'package:sutra_flutter/reader.dart';
import 'package:sutra_flutter/state.dart';

Sutra _buildSutra() => Sutra(
      key: 'T0251_1',
      cat: '测试类',
      name: '测试经',
      alt: '别名',
      tag: '主题',
      line: '一句话提要',
      notes: '导读',
      outline: <OutlineItem>[OutlineItem('科判一', '说明文字。')],
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
          Para('p', '第三段落。'),
        ],
      ),
    );

Widget _wrap(AppState state) => AppScope(
      state: state,
      child: MaterialApp(
        home: Scaffold(body: SafeArea(child: Row(children: <Widget>[
          Expanded(child: ReaderPage())
        ]))),
      ),
    );

AppState _state({int tab = 1}) {
  final st = AppState();
  st.library = Library(<String>['测试类'], <Sutra>[_buildSutra()]);
  st.currentIndex = 0;
  st.tab = tab;
  st.ready = true;
  return st;
}

void main() {
  testWidgets('全屏：点工具条按钮进入，隐藏经题/标签/工具条，退出按钮出现', (tester) async {
    final st = _state();
    await tester.pumpWidget(_wrap(st));

    expect(find.text('阅读设置'), findsOneWidget, reason: '原文页有工具条');
    await tester.tap(find.text('⛶ 全屏阅读'));
    await tester.pumpAndSettle();

    expect(st.fullScreen, isTrue);
    expect(find.text('阅读设置'), findsNothing, reason: '全屏后工具条隐藏');
    expect(find.byTooltip('退出全屏'), findsOneWidget);
    expect(find.text('第一段落。'), findsOneWidget, reason: '经文仍可见');
  });

  testWidgets('全屏：点退出按钮恢复普通阅读', (tester) async {
    final st = _state();
    await tester.pumpWidget(_wrap(st));
    await tester.tap(find.text('⛶ 全屏阅读'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('退出全屏'));
    await tester.pumpAndSettle();

    expect(st.fullScreen, isFalse);
    expect(find.text('阅读设置'), findsOneWidget, reason: '工具条恢复');
  });

  testWidgets('全屏：从大纲页进入会强制切换到原文 tab', (tester) async {
    final st = _state(tab: 0);
    await tester.pumpWidget(_wrap(st));
    expect(st.tab, 0);

    st.enterFullScreen();
    await tester.pumpAndSettle();

    expect(st.fullScreen, isTrue);
    expect(st.tab, 1, reason: '沉浸阅读强制显示原文');
    expect(find.text('第一段落。'), findsOneWidget);
  });
}
