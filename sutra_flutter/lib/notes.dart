import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'annotation_ui.dart';
import 'annotations.dart';
import 'palette.dart';
import 'state.dart';

/// 注释本：全部标注，按经分组（经藏次第）或按时间倒序，可跳转回原文段落。
class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final TextEditingController _search = TextEditingController();
  bool _bySutra = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _sutraName(AppState st, String key) {
    for (final s in st.sutras) {
      if (s.key == key) return s.name;
    }
    return key;
  }

  List<Annotation> _filtered(AppState st) {
    final q = _search.text.trim();
    return st.annotations.where((a) {
      if (q.isEmpty) return true;
      return a.quote.contains(q) ||
          a.note.contains(q) ||
          _sutraName(st, a.sutraKey).contains(q);
    }).toList();
  }

  Future<void> _edit(AppState st, Palette p, Annotation a) async {
    final b = await showAnnotationEditor(context, palette: p, existing: a);
    if (b != null) st.updateAnnotation(b);
  }

  Future<void> _delete(AppState st, Palette p, Annotation a) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            backgroundColor: p.paper,
            title: const Text('删除这条标注？'),
            content: const Text('删除后原文中的高亮也会消失，此操作不可撤销。'),
            actions: <Widget>[
              TextButton(
                  onPressed: () => Navigator.pop(d, false), child: const Text('取消')),
              TextButton(
                  onPressed: () => Navigator.pop(d, true), child: const Text('删除')),
            ],
          ),
        ) ??
        false;
    if (ok) st.deleteAnnotation(a.id);
  }

  void _jump(AppState st, Annotation a) {
    st.openKey(a.sutraKey, para: a.para, annotationId: a.id);
    Navigator.pop(context);
  }

  void _export(AppState st, List<Annotation> items) {
    final buf = StringBuffer('五十经藏 · 我的标注（共 ${items.length} 条）\n');
    String last = '';
    for (final a in items) {
      if (a.sutraKey != last) {
        last = a.sutraKey;
        buf.writeln('\n《${_sutraName(st, a.sutraKey)}》');
      }
      buf.writeln('  [${a.start}–${a.end}] 「${a.quote}」');
      if (a.note.isNotEmpty) buf.writeln('    笔记：${a.note}');
      buf.writeln('    ${kMarkNames[normalizeColor(a.color)]} · ${formatAnnotationTime(a.updatedAt)}');
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('全部标注已复制为文本'), duration: Duration(seconds: 2)));
  }

  Widget _card(AppState st, Palette p, Annotation a) {
    final c = Color(kMarkArgb[normalizeColor(a.color)]);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
      decoration: BoxDecoration(
        color: p.paper,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        GestureDetector(
          onTap: () => _jump(st, a),
          child: Row(children: <Widget>[
            Container(width: 3, height: 14, color: c),
            const SizedBox(width: 8),
            Expanded(
              child: Text('《${_sutraName(st, a.sutraKey)}》 · 第 ${a.para + 1} 段',
                  style: TextStyle(fontSize: 11.5, color: p.red)),
            ),
            Icon(Icons.arrow_forward, size: 13, color: p.faint),
          ]),
        ),
        const SizedBox(height: 9),
        GestureDetector(
          onTap: () => _jump(st, a),
          child: Text('「${a.quote}」',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, color: p.ink, height: 1.7)),
        ),
        if (a.note.isNotEmpty) ...<Widget>[
          const SizedBox(height: 7),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
                color: p.card, borderRadius: BorderRadius.circular(2)),
            child: Text(a.note,
                style: TextStyle(fontSize: 13, color: p.soft, height: 1.65)),
          ),
        ],
        const SizedBox(height: 6),
        Row(children: <Widget>[
          Text('${kMarkNames[normalizeColor(a.color)]} · ${formatAnnotationTime(a.updatedAt)}',
              style: TextStyle(fontSize: 10, color: p.faint)),
          const Spacer(),
          TextButton(
              onPressed: () => _edit(st, p, a),
              child: const Text('编辑', style: TextStyle(fontSize: 11.5))),
          TextButton(
              onPressed: () => _delete(st, p, a),
              child: const Text('删除', style: TextStyle(fontSize: 11.5))),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final p = Palette.of(st.night);
    final items = _filtered(st);
    final byTime = <Annotation>[...items]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final children = <Widget>[];
    if (_bySutra) {
      for (final s in st.sutras) {
        final group =
            items.where((a) => a.sutraKey == s.key).toList()
              ..sort((a, b) => a.para == b.para
                  ? a.start.compareTo(b.start)
                  : a.para.compareTo(b.para));
        if (group.isEmpty) continue;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
          child: Row(children: <Widget>[
            Icon(Icons.menu_book_outlined, size: 14, color: p.gold),
            const SizedBox(width: 7),
            Text('《${s.name}》',
                style: kaiStyle.copyWith(fontSize: 15, color: p.ink)),
            const SizedBox(width: 8),
            Text('${group.length} 条', style: TextStyle(fontSize: 11, color: p.faint)),
          ]),
        ));
        for (final a in group) {
          children.add(_card(st, p, a));
        }
      }
    } else {
      for (final a in byTime) {
        children.add(_card(st, p, a));
      }
    }

    final sutraCount = items.map((a) => a.sutraKey).toSet().length;

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: Text('注释本', style: kaiStyle.copyWith(fontSize: 17, color: p.ink)),
        actions: <Widget>[
          IconButton(
            tooltip: '导出全部标注',
            icon: const Icon(Icons.copy_all_outlined, size: 20),
            onPressed: items.isEmpty ? null : () => _export(st, byTime),
          ),
        ],
      ),
      body: Column(children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            style: TextStyle(fontSize: 13, color: p.ink),
            decoration: InputDecoration(
              hintText: '搜引文、笔记或经名…',
              prefixIcon: Icon(Icons.search, size: 18, color: p.faint),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      }),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: <Widget>[
            Text('${items.length} 条标注 · 涉及 $sutraCount 部经',
                style: TextStyle(fontSize: 11.5, color: p.faint)),
            const Spacer(),
            _SortChip('按经', _bySutra, p, () => setState(() => _bySutra = true)),
            const SizedBox(width: 6),
            _SortChip('按时间', !_bySutra, p, () => setState(() => _bySutra = false)),
          ]),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: children.isEmpty
              ? Center(
                  child: Text(
                    st.annotations.isEmpty
                        ? '还没有标注\n在「原文」里长按选中一段经文，点「标注」即可写下笔记'
                        : '没有匹配的标注',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: p.faint, height: 1.9),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                  children: children),
        ),
      ]),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool active;
  final Palette p;
  final VoidCallback onTap;
  const _SortChip(this.label, this.active, this.p, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? p.red : Colors.transparent,
            border: Border.all(color: active ? p.red : p.line),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11, color: active ? Colors.white : p.soft)),
        ),
      );
}
