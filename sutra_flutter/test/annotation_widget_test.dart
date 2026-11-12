import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sutra_flutter/annotation_ui.dart';
import 'package:sutra_flutter/annotations.dart';
import 'package:sutra_flutter/palette.dart';
import 'package:sutra_flutter/reader.dart';

void main() {
  testWidgets('已标注文字渲染为高亮片段，并可点击', (tester) async {
    List<Annotation>? tapped;
    final a = Annotation.create(
      sutraKey: 'T0251_1',
      para: 0,
      start: 1,
      end: 3,
      quote: '自在',
      note: '能观之人',
      color: 1,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AnnotatedParagraph(
            text: '观自在菩萨',
            kind: 'p',
            fontSize: 18,
            palette: Palette.day,
            marks: [a],
            onSelection: (_) {},
            onAnnotate: (_) {},
            onTapMarks: (marks) => tapped = marks,
          ),
        ),
      ),
    ));

    final selectable = tester.widget<SelectableText>(find.byType(SelectableText));
    final spans = selectable.textSpan!.children!;
    expect(spans.length, 3, reason: '前 / 高亮 / 后 三段');
    final mid = spans[1] as TextSpan;
    expect(mid.text, '自在');
    expect(mid.style?.backgroundColor, isNotNull);
    expect(mid.style?.decoration, TextDecoration.underline);
    expect(mid.recognizer, isA<TapGestureRecognizer>());

    // 点击高亮区域会把该处标注交给上层
    (mid.recognizer as TapGestureRecognizer).onTap!();
    expect(tapped, isNotNull);
    expect(tapped!.length, 1);
    expect(tapped!.first.id, a.id);
  });

  testWidgets('标注编辑器写入笔记后返回 Annotation', (tester) async {
    Annotation? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showAnnotationEditor(
                  context,
                  palette: Palette.day,
                  sutraKey: 'T0251_1',
                  para: 0,
                  start: 0,
                  end: 2,
                  quote: '心经',
                );
              },
              child: const Text('打开编辑器'),
            ),
          );
        }),
      ),
    ));

    await tester.tap(find.text('打开编辑器'));
    await tester.pumpAndSettle();
    expect(find.text('标注这段文字'), findsOneWidget);
    expect(find.text('心经'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '色即是空');
    await tester.tap(find.text('保存标注'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.quote, '心经');
    expect(result!.note, '色即是空');
    expect(result!.start, 0);
    expect(result!.end, 2);
  });

  testWidgets('编辑已有标注时保留定位并更新笔记', (tester) async {
    final a = Annotation.create(
      sutraKey: 'T0251_1',
      para: 3,
      start: 5,
      end: 9,
      quote: '应无所住',
      note: '旧笔记',
      color: 0,
    );
    Annotation? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showAnnotationEditor(
                  context,
                  palette: Palette.day,
                  existing: a,
                );
              },
              child: const Text('编辑'),
            ),
          );
        }),
      ),
    ));

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect(find.text('编辑标注'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '新理解');
    await tester.tap(find.text('保存标注'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.id, a.id);
    expect(result!.para, 3);
    expect(result!.start, 5);
    expect(result!.end, 9);
    expect(result!.note, '新理解');
  });
}
