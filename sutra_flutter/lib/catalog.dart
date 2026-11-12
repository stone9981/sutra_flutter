import 'dart:async';

import 'package:flutter/material.dart';

import 'palette.dart';
import 'state.dart';

/// 左侧目录（宽屏常驻 / 窄屏放进 Drawer），也可整页作为检索页。
class CatalogPane extends StatefulWidget {
  final bool showHeader;
  final bool inDrawer;
  final VoidCallback? onPick;

  const CatalogPane({
    super.key,
    this.showHeader = true,
    this.inDrawer = false,
    this.onPick,
  });

  @override
  State<CatalogPane> createState() => _CatalogPaneState();
}

class _CatalogPaneState extends State<CatalogPane> {
  final TextEditingController _controller = TextEditingController();
  Timer? _timer;
  bool _synced = false;
  final Set<String> _collapsed = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // initState 里不能 dependOnInheritedWidgetOfExactType，首次同步放这里
    if (!_synced) {
      _synced = true;
      final q = AppScope.of(context).query;
      if (q.isNotEmpty) _controller.text = q;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(AppState st, String v) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 180), () => st.setQuery(v));
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final p = Palette.of(st.night);
    final total = st.sutras.fold<int>(
        0, (n, s) => n + s.text.bodyChars);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.showHeader)
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 14, 10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('五十经藏',
                          style: kaiStyle.copyWith(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              color: p.ink)),
                      const SizedBox(height: 3),
                      Text(
                          '${st.sutras.length} 部 · ${st.library?.categories.length ?? 0} 类 · 原文 ${(total / 10000).toStringAsFixed(1)} 万字',
                          style: TextStyle(fontSize: 11, color: p.faint)),
                    ],
                  ),
                ),
                if (widget.inDrawer)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: p.faint,
                    onPressed: () => Navigator.pop(context),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: TextField(
            controller: _controller,
            onChanged: (v) => _onChanged(st, v),
            style: TextStyle(fontSize: 13, color: p.ink),
            decoration: InputDecoration(
              hintText: '搜经名、译者、关键词或经文…',
              prefixIcon: Icon(Icons.search, size: 18, color: p.faint),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      color: p.faint,
                      onPressed: () {
                        _controller.clear();
                        st.setQuery('');
                        setState(() {});
                      },
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          child: Row(
            children: <Widget>[
              _FilterChip(
                  label: '全部五十部', value: 'all', st: st, p: p),
              const SizedBox(width: 6),
              _FilterChip(label: '我的收藏', value: 'fav', st: st, p: p),
              const Spacer(),
              IconButton(
                tooltip: '随机阅经',
                icon: const Icon(Icons.shuffle, size: 17),
                color: p.soft,
                onPressed: () {
                  st.open(DateTime.now().millisecondsSinceEpoch % st.sutras.length);
                  widget.onPick?.call();
                },
              ),
            ],
          ),
        ),
        Divider(height: 1, color: p.line),
        Expanded(
            child: buildCatalogList(
          context,
          st,
          p,
          () => widget.onPick?.call(),
          collapsed: _collapsed,
          onToggle: (cat) => setState(() {
            if (_collapsed.contains(cat)) {
              _collapsed.remove(cat);
            } else {
              _collapsed.add(cat);
            }
          }),
        )),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final AppState st;
  final Palette p;

  const _FilterChip(
      {required this.label, required this.value, required this.st, required this.p});

  @override
  Widget build(BuildContext context) {
    final active = st.filter == value;
    return GestureDetector(
      onTap: () => st.setFilter(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? p.red : Colors.transparent,
          border: Border.all(color: active ? p.red : p.line),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, color: active ? Colors.white : p.soft, letterSpacing: 1)),
      ),
    );
  }
}

/// 目录列表本体，供侧栏与检索页复用。
/// [collapsed] 与 [onToggle] 让每个部类分组可折叠/展开（点击分组标题切换）。
Widget buildCatalogList(
  BuildContext context,
  AppState st,
  Palette p,
  VoidCallback? onPick, {
  Set<String>? collapsed,
  void Function(String)? onToggle,
}) {
  final indices = st.filteredIndices();
  if (indices.isEmpty) {
    return Center(
      child: Text('没有找到相应经典\n试试更短的关键词',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: p.faint, height: 1.8)),
    );
  }

  final collapseSet = collapsed ?? const <String>{};
  final children = <Widget>[];
  for (final cat in st.library?.categories ?? const <String>[]) {
    final rows = indices.where((i) => st.sutras[i].cat == cat).toList();
    if (rows.isEmpty) continue;
    final isCollapsed = collapseSet.contains(cat);
    children.add(GestureDetector(
      onTap: onToggle != null ? () => onToggle(cat) : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        color: p.card,
        child: Row(children: <Widget>[
          Icon(
              isCollapsed ? Icons.chevron_right : Icons.expand_more,
              size: 13,
              color: p.gold),
          const SizedBox(width: 6),
          Text(cat,
              style: TextStyle(
                  fontSize: 12,
                  color: p.red,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('${rows.length}', style: TextStyle(fontSize: 11, color: p.faint)),
        ]),
      ),
    ));
    if (isCollapsed) continue;
    for (final i in rows) {
      final s = st.sutras[i];
      final active = i == st.currentIndex;
      final hits = st.bodyHits(s);
      children.add(InkWell(
        onTap: () {
          st.open(i);
          if (onPick != null) onPick();
        },
        child: Container(
          decoration: BoxDecoration(
            color: active ? p.chip : Colors.transparent,
            border: Border(
                left: BorderSide(
                    color: active ? p.red : Colors.transparent, width: 2)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 24,
                child: Text((i + 1).toString().padLeft(2, '0'),
                    style: TextStyle(fontSize: 10, color: p.faint, height: 1.7)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(s.name,
                        style: TextStyle(
                            fontSize: 13,
                            color: active ? p.red : p.ink,
                            height: 1.35)),
                    const SizedBox(height: 2),
                    Text(s.alt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: p.faint)),
                  ],
                ),
              ),
              if (hits > 0)
                Container(
                  margin: const EdgeInsets.only(left: 4, top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                      color: p.red.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(2)),
                  child: Text('原文 $hits',
                      style: TextStyle(fontSize: 9.5, color: p.red)),
                ),
              if (st.isFav(s.key))
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 2),
                  child: Icon(Icons.star, size: 13, color: p.gold),
                ),
            ],
          ),
        ),
      ));
    }
  }
  return ListView(children: children, padding: EdgeInsets.zero);
}

/// 窄屏用的整页检索。
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(AppScope.of(context).night);
    return Scaffold(
      backgroundColor: p.paper,
      appBar: AppBar(title: const Text('检索经藏', style: TextStyle(fontSize: 15))),
      body: CatalogPane(
        showHeader: false,
        onPick: () => Navigator.pop(context),
      ),
    );
  }
}
