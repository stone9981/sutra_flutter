import 'package:flutter_test/flutter_test.dart';
import 'package:sutra_flutter/annotations.dart';

Annotation mark(int start, int end, String id, {int color = 0, int createdAt = 1}) {
  return Annotation(
    id: id,
    sutraKey: 'T0251_1',
    para: 0,
    start: start,
    end: end,
    quote: 'x' * (end - start),
    note: '笔记 $id',
    color: color,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

void main() {
  group('高亮区间切分', () {
    test('无标注时整段是一个片段', () {
      final segs = splitSegments('观自在菩萨', <Annotation>[]);
      expect(segs.length, 1);
      expect(segs.first.start, 0);
      expect(segs.first.end, 5);
      expect(segs.first.highlighted, false);
    });

    test('单条标注切成前 / 中 / 后三段', () {
      final segs = splitSegments('观自在菩萨行深', [mark(1, 3, 'a')]);
      expect(segs.length, 3);
      expect(segs[0].highlighted, false);
      expect(segs[1].start, 1);
      expect(segs[1].end, 3);
      expect(segs[1].marks.length, 1);
      expect(segs[1].marks.first.id, 'a');
      expect(segs[2].highlighted, false);
    });

    test('重叠区间同时携带两条标注，颜色取最后创建的一条', () {
      final segs = splitSegments('色即是空空即是色', [
        mark(0, 6, 'a', color: 0, createdAt: 1),
        mark(2, 8, 'b', color: 2, createdAt: 2),
      ]);
      final overlap = segs.where((s) => s.start == 2 && s.end == 6).toList();
      expect(overlap.length, 1);
      expect(overlap.first.marks.length, 2);
      expect(overlap.first.color, 2);
      // 所有片段首尾相接，无空洞、无重叠
      int cursor = 0;
      for (final s in segs) {
        expect(s.start, cursor);
        cursor = s.end;
      }
      expect(cursor, 8);
    });

    test('越界或空区间的旧数据被忽略，不会抛异常', () {
      final segs = splitSegments('心经', [
        mark(-1, 1, 'bad1'),
        mark(1, 1, 'bad2'),
        mark(0, 99, 'bad3'),
        mark(0, 1, 'ok'),
      ]);
      expect(segs.length, 2);
      expect(segs.first.marks.length, 1);
      expect(segs.first.marks.first.id, 'ok');
    });

    test('连续相同标注集合会被合并', () {
      final segs = splitSegments('四字经文', [mark(0, 2, 'a'), mark(2, 4, 'a')]);
      expect(segs.length, 1);
      expect(segs.first.start, 0);
      expect(segs.first.end, 4);
    });
  });

  group('标注持久化', () {
    test('encode / decode 往返不丢字段', () {
      final a = mark(1, 5, 'id1', color: 3, createdAt: 1700000000000);
      final decoded = Annotation.decode(Annotation.encode([a]));
      expect(decoded.length, 1);
      expect(decoded.first.id, 'id1');
      expect(decoded.first.start, 1);
      expect(decoded.first.end, 5);
      expect(decoded.first.color, 3);
      expect(decoded.first.note, '笔记 id1');
    });

    test('损坏的 JSON 返回空列表', () {
      expect(Annotation.decode('not-json'), isEmpty);
      expect(Annotation.decode(null), isEmpty);
    });

    test('copyWith 更新时间而不改定位', () {
      final a = mark(1, 4, 'id1');
      final b = a.copyWith(note: '新笔记', color: 2);
      expect(b.start, 1);
      expect(b.end, 4);
      expect(b.note, '新笔记');
      expect(b.color, 2);
      expect(b.updatedAt, greaterThanOrEqualTo(a.updatedAt));
    });
  });
}
