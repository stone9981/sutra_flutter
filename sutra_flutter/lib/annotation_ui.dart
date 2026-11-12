import 'package:flutter/material.dart';

import 'annotations.dart';
import 'palette.dart';

String formatAnnotationTime(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

/// 打开标注编辑器。返回新建／更新后的 Annotation；取消返回 null。
/// existing 为 null 时表示新建，此时其余定位参数必填。
Future<Annotation?> showAnnotationEditor(
  BuildContext context, {
  required Palette palette,
  Annotation? existing,
  String sutraKey = '',
  int para = 0,
  int start = 0,
  int end = 0,
  String quote = '',
}) {
  return showDialog<Annotation>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.42),
    builder: (ctx) => AnnotationEditor(
      palette: palette,
      existing: existing,
      sutraKey: sutraKey,
      para: para,
      start: start,
      end: end,
      quote: quote,
    ),
  );
}

class AnnotationEditor extends StatefulWidget {
  final Palette palette;
  final Annotation? existing;
  final String sutraKey;
  final int para;
  final int start;
  final int end;
  final String quote;

  const AnnotationEditor({
    super.key,
    required this.palette,
    this.existing,
    this.sutraKey = '',
    this.para = 0,
    this.start = 0,
    this.end = 0,
    this.quote = '',
  });

  @override
  State<AnnotationEditor> createState() => _AnnotationEditorState();
}

class _AnnotationEditorState extends State<AnnotationEditor> {
  late final TextEditingController _note;
  late int _color;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: widget.existing?.note ?? '');
    _color = widget.existing?.color ?? 0;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final note = _note.text.trim();
    final Annotation result;
    if (widget.existing != null) {
      result = widget.existing!.copyWith(note: note, color: _color);
    } else {
      result = Annotation.create(
        sutraKey: widget.sutraKey,
        para: widget.para,
        start: widget.start,
        end: widget.end,
        quote: widget.quote,
        note: note,
        color: _color,
      );
    }
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final isEdit = widget.existing != null;
    final quote = isEdit ? widget.existing!.quote : widget.quote;
    final color = Color(kMarkArgb[normalizeColor(_color)]);

    return AlertDialog(
      backgroundColor: p.paper,
      surfaceTintColor: Colors.transparent,
      titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
      title: Text(isEdit ? '编辑标注' : '标注这段文字',
          style: kaiStyle.copyWith(fontSize: 18, color: p.ink)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.card,
                border: Border(left: BorderSide(color: color, width: 3)),
                borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(3), bottomRight: Radius.circular(3)),
              ),
              child: Text(
                quote.isEmpty ? '（所选文字）' : quote,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, height: 1.7, color: p.ink),
              ),
            ),
            const SizedBox(height: 16),
            Text('笔记', style: TextStyle(fontSize: 11, color: p.faint, letterSpacing: 2)),
            const SizedBox(height: 6),
            TextField(
              controller: _note,
              autofocus: !isEdit,
              maxLines: 5,
              minLines: 3,
              style: TextStyle(fontSize: 14, height: 1.6, color: p.ink),
              decoration: const InputDecoration(
                hintText: '写下你的理解、疑问、联想…（可留空，仅作高亮）',
              ),
            ),
            const SizedBox(height: 16),
            Text('标注颜色',
                style: TextStyle(fontSize: 11, color: p.faint, letterSpacing: 2)),
            const SizedBox(height: 10),
            Row(
              children: List<Widget>.generate(kMarkArgb.length, (i) {
                final c = Color(kMarkArgb[i]);
                final active = _color == i;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => setState(() => _color = i),
                    child: Column(
                      children: <Widget>[
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: c.withOpacity(0.85),
                            shape: BoxShape.circle,
                            border: active
                                ? Border.all(color: p.ink, width: 2)
                                : Border.all(color: Colors.transparent, width: 2),
                          ),
                          child: active
                              ? const Icon(Icons.check, size: 15, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(kMarkNames[i],
                            style: TextStyle(fontSize: 10, color: active ? p.ink : p.faint)),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Text('字符区间 ${widget.existing?.start ?? widget.start}–${widget.existing?.end ?? widget.end}' +
                (isEdit ? ' · 创建于 ${formatAnnotationTime(widget.existing!.createdAt)}' : ''),
                style: TextStyle(fontSize: 10, color: p.faint)),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('取消', style: TextStyle(color: p.soft)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: p.red),
          onPressed: _save,
          child: const Text('保存标注'),
        ),
      ],
    );
  }
}

/// 点击已高亮的经文时，弹出该处的全部标注（支持重叠标注）。
Future<void> showMarksSheet(
  BuildContext context, {
  required Palette palette,
  required List<Annotation> marks,
  required ValueChanged<Annotation> onEdit,
  required ValueChanged<String> onDelete,
}) {
  final p = palette;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: p.paper,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(children: <Widget>[
              Text('此处标注 · ${marks.length} 条',
                  style: kaiStyle.copyWith(fontSize: 16, color: p.ink)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: p.faint,
                onPressed: () => Navigator.pop(ctx),
              ),
            ]),
            const SizedBox(height: 6),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: marks.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 14, color: p.line),
                itemBuilder: (_, i) {
                  final a = marks[i];
                  final c = Color(kMarkArgb[normalizeColor(a.color)]);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: p.card,
                          border: Border(left: BorderSide(color: c, width: 3)),
                        ),
                        child: Text('「${a.quote}」',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: p.soft, height: 1.6)),
                      ),
                      if (a.note.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 8, 2, 2),
                          child: Text(a.note,
                              style: TextStyle(fontSize: 14, color: p.ink, height: 1.6)),
                        ),
                      const SizedBox(height: 4),
                      Row(children: <Widget>[
                        Text('${kMarkNames[normalizeColor(a.color)]} · ${formatAnnotationTime(a.updatedAt)}',
                            style: TextStyle(fontSize: 10, color: p.faint)),
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          label: const Text('编辑', style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            onEdit(a);
                          },
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.delete_outline, size: 15),
                          label: const Text('删除', style: TextStyle(fontSize: 12)),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (d) => AlertDialog(
                                    backgroundColor: p.paper,
                                    title: const Text('删除这条标注？'),
                                    content: const Text('删除后高亮也会一并消失，此操作不可撤销。'),
                                    actions: <Widget>[
                                      TextButton(
                                          onPressed: () => Navigator.pop(d, false),
                                          child: const Text('取消')),
                                      TextButton(
                                          onPressed: () => Navigator.pop(d, true),
                                          child: const Text('删除')),
                                    ],
                                  ),
                                ) ??
                                false;
                            if (ok) {
                              if (ctx.mounted) Navigator.pop(ctx);
                              onDelete(a.id);
                            }
                          },
                        ),
                      ]),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
