import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'annotation_ui.dart';
import 'annotations.dart';
import 'chapters.dart';
import 'models.dart';
import 'palette.dart';
import 'state.dart';

/// 一部经的阅读页：经题卡 + 大纲 / 原文 / 导读三栏 + 翻经。
class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey> _paraKeys = <int, GlobalKey>{};
  final ValueNotifier<int> _selectedLen = ValueNotifier<int>(0);

  String? _loadedKey;
  String? _jumpToken;
  int? _activePara;
  TextSelection? _activeSelection;

  @override
  void dispose() {
    _scroll.dispose();
    _selectedLen.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(int i) =>
      _paraKeys.putIfAbsent(i, () => GlobalKey(debugLabel: 'para_$i'));

  void _onSelection(int para, TextSelection sel) {
    if (!sel.isValid || sel.isCollapsed || sel.end <= sel.start) return;
    _activePara = para;
    _activeSelection = sel;
    // 只刷新工具条，避免打断正在进行的文字选择手势
    _selectedLen.value = sel.end - sel.start;
  }

  void _clearSelection() {
    _activePara = null;
    _activeSelection = null;
    _selectedLen.value = 0;
  }

  Future<void> _annotate(
    Sutra s,
    Palette p, {
    int? paraIndex,
    TextSelection? selection,
  }) async {
    final para = paraIndex ?? _activePara;
    final sel = selection ?? _activeSelection;
    if (para == null || sel == null || sel.isCollapsed) return;
    final text = s.text.paras[para].v;
    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(0, text.length);
    if (end <= start) return;
    final quote = text.substring(start, end);

    final Annotation? a = await showAnnotationEditor(
      context,
      palette: p,
      sutraKey: s.key,
      para: para,
      start: start,
      end: end,
      quote: quote,
    );
    if (a == null || !mounted) return;
    AppScope.of(context).addAnnotation(a);
    _clearSelection();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('标注已保存，选中文字已高亮'),
      duration: Duration(seconds: 2),
    ));
  }

  Future<void> _editMark(Annotation a, Palette p) async {
    final Annotation? b =
        await showAnnotationEditor(context, palette: p, existing: a);
    if (b != null && mounted) AppScope.of(context).updateAnnotation(b);
  }

  Future<void> _tapMarks(List<Annotation> marks, Palette p) async {
    if (marks.isEmpty) return;
    await showMarksSheet(
      context,
      palette: p,
      marks: marks,
      onEdit: (a) => _editMark(a, p),
      onDelete: (id) {
        if (mounted) {
          AppScope.of(context).deleteAnnotation(id);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('标注已删除'), duration: Duration(seconds: 2)));
        }
      },
    );
  }

  /// 从「注释本」跳转：ListView 是懒加载的，逐屏推进直到目标段落被构建，再精确滚到可见。
  Future<void> _focusPara(int para) async {
    final st = AppScope.of(context);
    final key = _keyFor(para);
    for (int i = 0; i < 90; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
      final ctx = key.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(ctx,
            alignment: 0.22, duration: const Duration(milliseconds: 320));
        break;
      }
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      if (_scroll.offset >= max - 1) return;
      _scroll.jumpTo((_scroll.offset + 900).clamp(0.0, max));
    }
    if (mounted) st.clearJump();
  }

  void _copyVolume(Sutra s) {
    final body = s.text.paras
        .where((x) => !x.isPreface)
        .map((x) => x.v)
        .join('\n\n');
    Clipboard.setData(ClipboardData(text: '《${s.name}》\n\n$body'));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本卷经文已复制到剪贴板'), duration: Duration(seconds: 2)));
  }

  int? _lastTab;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final p = Palette.of(st.night);
    final s = st.current;
    if (s == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadedKey != s.key) {
      _loadedKey = s.key;
      _lastTab = st.tab;
      _paraKeys.clear();
      _clearSelection();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(0);
      });
    } else if (_lastTab != st.tab) {
      _lastTab = st.tab;
      // 切标签时回到顶部；若有待定位的段落则交给 _focusPara 处理
      if (st.jumpPara == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) _scroll.jumpTo(0);
        });
      }
    }
    final token = '${s.key}/${st.jumpPara}/${st.jumpSeq}/${st.jumpAnnotationId}';
    if (st.jumpPara != null && token != _jumpToken) {
      _jumpToken = token;
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusPara(st.jumpPara!));
    }

    // 单一 CustomScrollView：经题、标签、正文同处一条滚动轴，
    // 避免「固定高度内嵌列表」造成的嵌套滚动与回溯卡顿。
    final body = st.fullScreen && st.tab == 1
        ? _fullScreenView(s, st, p)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: p.paper,
                    border: Border(bottom: BorderSide(color: p.line)),
                  ),
                  child: CustomScrollView(
                    key: PageStorageKey<String>('reader_${s.key}_${st.tab}'),
                    controller: _scroll,
                    // 段落带 KeepAlive，回滚时直接复用已建好的段落；
                    // 缓存区保持适中，避免同时布局过多重型 SelectableText。
                    cacheExtent: 800,
                    slivers: _slivers(s, st, p),
                  ),
                ),
              ),
              _Pager(st: st, p: p),
            ],
          );

    // 全屏时系统返回键先退出全屏，而不是直接离开经藏。
    return PopScope(
      canPop: !st.fullScreen,
      onPopInvoked: (didPop) {
        if (!didPop && st.fullScreen) st.setFullScreen(false);
      },
      child: body,
    );
  }

  /// 沉浸式全屏：只有经文铺满屏幕，顶部保留经名与一个退出按钮。
  Widget _fullScreenView(Sutra s, AppState st, Palette p) {
    final marks = _marksByPara(st, s.key);
    final width = MediaQuery.of(context).size.width;
    final side = width > 860 ? (width - 760) / 2 : 22.0;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Container(
          color: p.paper,
          child: CustomScrollView(
            key: PageStorageKey<String>('reader_fs_${s.key}'),
            controller: _scroll,
            cacheExtent: 800,
            slivers: <Widget>[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(side, 62, side, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _paraRow(s, st, i, marks),
                    childCount: s.text.paras.length,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            bottom: false,
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 0, 0),
                child: Text(s.name,
                    style: kaiStyle.copyWith(fontSize: 13, color: p.faint)),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: IconButton(
              tooltip: '退出全屏',
              icon: Icon(Icons.fullscreen_exit, size: 22, color: p.soft),
              color: p.paper.withOpacity(0.85),
              highlightColor: p.chip,
              onPressed: () => st.setFullScreen(false),
            ),
          ),
        ),
      ],
    );
  }

  /// 一次遍历建立「段落 → 标注」索引，避免每段都全量过滤标注列表。
  Map<int, List<Annotation>> _marksByPara(AppState st, String key) {
    final map = <int, List<Annotation>>{};
    for (final a in st.annotations) {
      if (a.sutraKey == key) {
        map.putIfAbsent(a.para, () => <Annotation>[]).add(a);
      }
    }
    return map;
  }

  Widget _paraRow(Sutra s, AppState st, int i,
      Map<int, List<Annotation>> marks) {
    final para = s.text.paras[i];
    if (para.isPreface && !st.showPreface) return const SizedBox.shrink();
    return Container(
      key: _keyFor(i),
      margin: EdgeInsets.only(bottom: para.k == 'p' ? 13 : 9),
      child: AnnotatedParagraph(
        text: para.v,
        kind: para.k,
        fontSize: st.fontSize,
        palette: Palette.of(st.night),
        marks: marks[i] ?? const <Annotation>[],
        onSelection: (sel) => _onSelection(i, sel),
        onAnnotate: (sel) => _annotate(s, Palette.of(st.night),
            paraIndex: i, selection: sel),
        onTapMarks: (marks) => _tapMarks(marks, Palette.of(st.night)),
      ),
    );
  }

  List<Widget> _slivers(Sutra s, AppState st, Palette p) {
    final head = <Widget>[
      _Hero(s: s, st: st, p: p),
      const SizedBox(height: 16),
      _Tabs(s: s, st: st, p: p),
      const SizedBox(height: 14),
    ];
    if (st.tab == 0) {
      head.add(_OutlineView(s: s, p: p));
    } else if (st.tab == 2) {
      head.add(_NotesView(s: s, p: p));
    } else {
      head.add(_TextTools(
        st: st,
        p: p,
        s: s,
        preface: s.text.paras.where((x) => x.isPreface).length,
        selectedLen: _selectedLen,
        onAnnotate: () => _annotate(s, p),
        onCopy: () => _copyVolume(s),
        onFullScreen: () => st.enterFullScreen(),
      ));
      head.add(const SizedBox(height: 8));
    }

    final paras = s.text.paras;
    final marks = _marksByPara(st, s.key);
    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        sliver: SliverList(delegate: SliverChildListDelegate(head)),
      ),
      if (st.tab == 1)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 96),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _paraRow(s, st, i, marks),
              childCount: paras.length,
            ),
          ),
        )
      else
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
  }
}

/* ------------------------------ 经题 / 标签 / 翻经 ------------------------------ */

class _Hero extends StatelessWidget {
  final Sutra s;
  final AppState st;
  final Palette p;

  const _Hero({required this.s, required this.st, required this.p});

  @override
  Widget build(BuildContext context) {
    final t = s.text;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: BoxDecoration(
        color: p.card,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: <Widget>[
            _Chip(text: s.cat, p: p, filled: true),
            const SizedBox(width: 6),
            _Chip(text: s.tag, p: p),
            const Spacer(),
            GestureDetector(
              onTap: () => st.toggleFav(s.key),
              child: Row(children: <Widget>[
                Icon(st.isFav(s.key) ? Icons.star : Icons.star_border,
                    size: 17, color: st.isFav(s.key) ? p.gold : p.faint),
                const SizedBox(width: 4),
                Text(st.isFav(s.key) ? '已收藏' : '收藏',
                    style: TextStyle(fontSize: 12, color: p.soft)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: p.red.withOpacity(0.7))),
              child: Text(
                  (st.currentIndex + 1).toString().padLeft(2, '0'),
                  style: kaiStyle.copyWith(fontSize: 17, color: p.red)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(s.name,
                      style: kaiStyle.copyWith(
                          fontSize: 27, color: p.ink, letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text('又名 · ${s.alt}',
                      style: TextStyle(fontSize: 11.5, color: p.faint)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Text(s.line, style: TextStyle(fontSize: 14.5, color: p.ink, height: 1.7)),
          const SizedBox(height: 14),
          Wrap(spacing: 16, runSpacing: 6, children: <Widget>[
            _Meta('译／撰', t.byline, p),
            _Meta('部类', t.category.isEmpty ? s.cat : t.category, p),
            _Meta('收录',
                t.juanTotal > 1 ? '全经 ${t.juanTotal} 卷 · 第 ${t.juan} 卷' : '一卷本 · 全经', p),
            _Meta('经文', '${t.bodyChars} 字', p),
            _Meta('编号', t.work, p),
          ]),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Palette p;
  final bool filled;
  const _Chip({required this.text, required this.p, this.filled = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: filled ? p.red.withOpacity(0.10) : p.chip,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: filled ? p.red.withOpacity(0.35) : p.line),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10.5, color: filled ? p.red : p.soft, letterSpacing: 1)),
      );
}

class _Meta extends StatelessWidget {
  final String k;
  final String v;
  final Palette p;
  const _Meta(this.k, this.v, this.p);

  @override
  Widget build(BuildContext context) => Text('$k：$v',
      style: TextStyle(fontSize: 11.5, color: p.soft));
}

class _Tabs extends StatelessWidget {
  final Sutra s;
  final AppState st;
  final Palette p;
  const _Tabs({required this.s, required this.st, required this.p});

  @override
  Widget build(BuildContext context) {
    final structCount = structureHeadings(s).length;
    final labels = <String>[
      '大纲 ${s.outline.length + structCount}',
      '原文 ${s.text.paras.length}',
      '导读与版本',
    ];
    return Row(children: <Widget>[
      ...List<Widget>.generate(3, (i) {
        final active = st.tab == i;
        return GestureDetector(
          onTap: () => st.setTab(i),
          child: Container(
            margin: const EdgeInsets.only(right: 22),
            padding: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: active ? p.red : Colors.transparent, width: 2)),
            ),
            child: Text(labels[i],
                style: TextStyle(
                    fontSize: 14,
                    color: active ? p.red : p.soft,
                    letterSpacing: 1,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
          ),
        );
      }),
      const Spacer(),
      Text('${st.marksForSutra(s.key).length} 条标注',
          style: TextStyle(fontSize: 11, color: p.faint)),
    ]);
  }
}

class _Pager extends StatelessWidget {
  final AppState st;
  final Palette p;
  const _Pager({required this.st, required this.p});

  @override
  Widget build(BuildContext context) {
    final i = st.currentIndex;
    Widget side(bool prev) {
      final target = prev ? i - 1 : i + 1;
      final ok = target >= 0 && target < st.sutras.length;
      return Expanded(
        child: InkWell(
          onTap: ok ? () => st.open(target) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            alignment: prev ? Alignment.centerLeft : Alignment.centerRight,
            child: Column(
              crossAxisAlignment:
                  prev ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: <Widget>[
                Text(prev ? '← 上一部' : '下一部 →',
                    style: TextStyle(fontSize: 10.5, color: p.faint)),
                const SizedBox(height: 2),
                Text(ok ? st.sutras[target].name : (prev ? '已是第一部' : '已是最后一部'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: ok ? p.ink : p.faint)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
          color: p.paper, border: Border(top: BorderSide(color: p.line))),
      child: Row(children: <Widget>[
        side(true),
        Text('${i + 1} / ${st.sutras.length}',
            style: TextStyle(fontSize: 11, color: p.faint)),
        side(false),
      ]),
    );
  }
}

/* ------------------------------ 大纲 / 导读 ------------------------------ */

class _OutlineView extends StatefulWidget {
  final Sutra s;
  final Palette p;
  const _OutlineView({required this.s, required this.p});

  @override
  State<_OutlineView> createState() => _OutlineViewState();
}

class _OutlineViewState extends State<_OutlineView> {
  final Set<int> _expanded = {};
  bool _allExpanded = false;

  /// 为科判条目找一个可定位的段落：优先用标题/描述里的关键词在正文命中，
  /// 找不到则按序号把整卷均分，保证点击一定能跳到大致位置。
  int _anchor(OutlineItem o, int index, int count) {
    final paras = widget.s.text.paras;
    final cands = <String>[o.t];
    cands.addAll(o.d
        .split(RegExp(r'[，。、；：！？（）—\s]+'))
        .where((w) => w.length >= 3));
    for (final c in cands) {
      if (c.isEmpty) continue;
      for (int i = 0; i < paras.length; i++) {
        if (!paras[i].isPreface && paras[i].v.contains(c)) return i;
      }
    }
    final n = paras.length;
    return ((index + 0.5) * n / count).floor().clamp(0, n - 1);
  }

  void _jump(int para) {
    if (para < 0) return;
    final st = AppScope.of(context);
    st.open(st.currentIndex, tabIndex: 1, para: para);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final p = widget.p;
    final structure = structureHeadings(s);
    final curated = hasCuratedChapters(s.key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
            '科判大纲按经文次第梳理义理脉络，点标题可展开/折叠说明，点「原文」直接定位到对应段落；下方分品目录取自经文品目或传统分章，同样可点击跳转。',
            style: TextStyle(fontSize: 12, color: p.faint, height: 1.7)),
        const SizedBox(height: 12),
        Row(children: <Widget>[
          Text('科判大纲', style: kaiStyle.copyWith(fontSize: 15, color: p.ink)),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() {
              _allExpanded = !_allExpanded;
              _expanded.clear();
              if (_allExpanded) {
                _expanded.addAll(List<int>.generate(s.outline.length, (i) => i));
              }
            }),
            child: Text(_allExpanded ? '折叠全部' : '展开全部',
                style: TextStyle(fontSize: 11.5, color: p.red, letterSpacing: 1)),
          ),
        ]),
        const SizedBox(height: 10),
        ...List<Widget>.generate(s.outline.length, (i) {
          final o = s.outline[i];
          final open = _expanded.contains(i);
          final anchor = _anchor(o, i, s.outline.length);
          return Container(
            margin: const EdgeInsets.only(bottom: 9),
            decoration: BoxDecoration(
              color: p.card,
              border: Border.all(color: p.line),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() {
                  if (open) _expanded.remove(i);
                  else _expanded.add(i);
                }),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: 30,
                          child: Text((i + 1).toString().padLeft(2, '0'),
                              style: kaiStyle.copyWith(fontSize: 18, color: p.gold)),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(o.t,
                                  style: kaiStyle.copyWith(
                                      fontSize: 15.5, color: p.ink, letterSpacing: 1.2)),
                              if (open) ...<Widget>[
                                const SizedBox(height: 6),
                                Text(o.d,
                                    style: TextStyle(
                                        fontSize: 13, color: p.soft, height: 1.8)),
                              ],
                            ],
                          ),
                        ),
                        Icon(open ? Icons.expand_less : Icons.chevron_right,
                            size: 18, color: p.faint),
                        const SizedBox(width: 2),
                        InkWell(
                          onTap: () => _jump(anchor),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            child: Row(children: <Widget>[
                              Icon(Icons.place_outlined, size: 14, color: p.red),
                              const SizedBox(width: 2),
                              Text('原文',
                                  style: TextStyle(fontSize: 11, color: p.red)),
                            ]),
                          ),
                        ),
                      ]),
                ),
              ),
            ),
          );
        }),
        if (structure.isNotEmpty) ...<Widget>[
          const SizedBox(height: 18),
          Text(
              curated
                  ? '分章目录 · 共 ${structure.length} 章'
                  : '本文结构（品目 · 共 ${structure.length}）',
              style: kaiStyle.copyWith(fontSize: 15, color: p.ink)),
          const SizedBox(height: 4),
          Text(
              curated
                  ? '${kChapterSource[s.key] ?? '依传统分科'}，点击直达该段。'
                  : '经文自带的品、卷标题，点击直达该段。',
              style: TextStyle(fontSize: 11, color: p.faint, height: 1.6)),
          const SizedBox(height: 10),
          ...structure.map((h) => _HeadingRow(
                title: h.title,
                index: h.para,
                p: p,
                onJump: h.para >= 0 ? () => _jump(h.para) : null,
              )),
        ] else ...<Widget>[
          const SizedBox(height: 16),
          Text('本经在藏经底本中未分品目，以上科判即其通行的义理结构。',
              style: TextStyle(fontSize: 11.5, color: p.faint, height: 1.7)),
        ],
      ],
    );
  }
}

class _HeadingRow extends StatelessWidget {
  final String title;
  final int index;
  final Palette p;
  final VoidCallback? onJump;
  const _HeadingRow(
      {required this.title, required this.index, required this.p, this.onJump});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 7),
        decoration: BoxDecoration(
          color: p.card,
          border: Border(left: BorderSide(color: p.gold, width: 2)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onJump,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
              child: Row(children: <Widget>[
                Expanded(
                    child: Text(title,
                        style:
                            TextStyle(fontSize: 13.5, color: p.ink, height: 1.5))),
                if (index >= 0) ...<Widget>[
                  const SizedBox(width: 6),
                  Text('段落 ${index + 1}',
                      style: TextStyle(fontSize: 10, color: p.faint)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 16, color: p.faint),
                ],
              ]),
            ),
          ),
        ),
      );
}

class _NotesView extends StatelessWidget {
  final Sutra s;
  final Palette p;
  const _NotesView({required this.s, required this.p});

  @override
  Widget build(BuildContext context) {
    final t = s.text;
    final rows = <List<String>>[
      ['CBETA 经号', t.work],
      ['原题（繁体）', t.titleOrig],
      ['译／撰者', t.byline],
      ['藏经部类', t.category],
      ['全经卷数', '${t.juanTotal} 卷'],
      ['此处收录', '第 ${t.juan} 卷 · ${t.scope}'],
      ['本卷经文字数', '${t.bodyChars} 字'],
      ['主题', s.tag],
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: p.card, border: Border.all(color: p.line), borderRadius: BorderRadius.circular(3)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text('导读', style: kaiStyle.copyWith(fontSize: 17, color: p.ink)),
          const SizedBox(height: 10),
          Text(s.notes, style: TextStyle(fontSize: 14, color: p.ink, height: 1.9)),
        ]),
      ),
      const SizedBox(height: 14),
      Wrap(spacing: 10, runSpacing: 10, children: <Widget>[
        ...rows.map((r) => Container(
              width: 170,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: p.card, border: Border.all(color: p.line)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(r[0], style: TextStyle(fontSize: 10, color: p.faint)),
                const SizedBox(height: 4),
                Text(r[1], style: TextStyle(fontSize: 12.5, color: p.ink)),
              ]),
            )),
      ]),
      const SizedBox(height: 14),
      Text('原文取自 CBETA 电子佛典集成该卷全文，繁体转简体、去除行号与校勘标记，未改写经文。',
          style: TextStyle(fontSize: 12, color: p.faint, height: 1.8)),
      if (t.colophon.isNotEmpty) ...<Widget>[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: p.card, border: Border.all(color: p.line, style: BorderStyle.solid)),
          child: Text('CBETA 卷末版本记录\n${t.colophon}',
              style: TextStyle(fontSize: 11, color: p.faint, height: 1.7)),
        ),
      ],
      const SizedBox(height: 12),
      OutlinedButton.icon(
        icon: const Icon(Icons.link, size: 15),
        label: const Text('复制 CBETA 全经链接'),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: t.link));
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('链接已复制'), duration: Duration(seconds: 2)));
        },
      ),
    ]);
  }
}

/* ------------------------------ 原文工具条 ------------------------------ */

class _MiniButton extends StatelessWidget {
  final String label;
  final bool active;
  final bool enabled;
  final Palette p;
  final VoidCallback? onTap;
  const _MiniButton(
      {required this.label, required this.p, this.active = false, this.enabled = true, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: active ? p.red.withOpacity(0.12) : Colors.transparent,
            border: Border.all(color: active ? p.red : p.line),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11.5,
                  color: !enabled ? p.faint : (active ? p.red : p.soft),
                  letterSpacing: 0.5)),
        ),
      );
}

class _TextTools extends StatelessWidget {
  final AppState st;
  final Palette p;
  final Sutra s;
  final int preface;
  final ValueListenable<int> selectedLen;
  final VoidCallback onAnnotate;
  final VoidCallback onCopy;
  final VoidCallback onFullScreen;

  const _TextTools({
    required this.st,
    required this.p,
    required this.s,
    required this.preface,
    required this.selectedLen,
    required this.onAnnotate,
    required this.onCopy,
    required this.onFullScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text('阅读设置', style: TextStyle(fontSize: 11, color: p.faint, letterSpacing: 1)),
          _MiniButton(
              label: '字号 −', p: p,
              onTap: () => st.setFontSize((st.fontSize - 1).clamp(14.0, 30.0).toDouble())),
          Text(st.fontSize.toStringAsFixed(0),
              style: TextStyle(fontSize: 11.5, color: p.ink)),
          _MiniButton(
              label: '字号 +', p: p,
              onTap: () => st.setFontSize((st.fontSize + 1).clamp(14.0, 30.0).toDouble())),
          _MiniButton(
              label: '卷首序跋${preface > 0 ? ' ($preface)' : ''}',
              p: p, active: st.showPreface, onTap: () => st.setShowPreface(!st.showPreface)),
          _MiniButton(label: '复制本卷', p: p, onTap: onCopy),
          _MiniButton(label: '⛶ 全屏阅读', p: p, onTap: onFullScreen),
          ValueListenableBuilder<int>(
            valueListenable: selectedLen,
            builder: (context, len, _) => _MiniButton(
              label: len > 0 ? '✎ 标注选中（$len 字）' : '✎ 长按经文选中文字后标注',
              p: p,
              active: len > 0,
              enabled: len > 0,
              onTap: len > 0 ? onAnnotate : null,
            ),
          ),
          Text('本卷 ${st.marksForSutra(s.key).length} 条标注',
              style: TextStyle(fontSize: 11, color: p.faint)),
        ]);
  }
}

/* ------------------------------ 可选中、可标注的段落 ------------------------------ */

class AnnotatedParagraph extends StatefulWidget {
  final String text;
  final String kind;
  final double fontSize;
  final Palette palette;
  final List<Annotation> marks;
  final ValueChanged<TextSelection> onSelection;
  final ValueChanged<TextSelection> onAnnotate;
  final ValueChanged<List<Annotation>> onTapMarks;

  const AnnotatedParagraph({
    super.key,
    required this.text,
    required this.kind,
    required this.fontSize,
    required this.palette,
    required this.marks,
    required this.onSelection,
    required this.onAnnotate,
    required this.onTapMarks,
  });

  @override
  State<AnnotatedParagraph> createState() => _AnnotatedParagraphState();
}

class _AnnotatedParagraphState extends State<AnnotatedParagraph>
    with AutomaticKeepAliveClientMixin<AnnotatedParagraph> {
  @override
  bool get wantKeepAlive => true;

  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  // 缓存已构建的富文本与手势识别器：滚动导致的重建直接复用，
  // 不再每次重建都重跑 splitSegments、重建 TapGestureRecognizer。
  TextSpan? _cached;
  String? _cachedText;
  String? _cachedKind;
  double? _cachedFont;
  bool? _cachedNight;
  List<Annotation> _cachedMarks = const <Annotation>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  static bool _sameMarks(List<Annotation> a, List<Annotation> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (identical(a[i], b[i])) continue;
      if (a[i].id != b[i].id ||
          a[i].start != b[i].start ||
          a[i].end != b[i].end ||
          a[i].color != b[i].color) {
        return false;
      }
    }
    return true;
  }

  TextSpan _ensureSpan() {
    final fresh = _cached != null &&
        _cachedText == widget.text &&
        _cachedKind == widget.kind &&
        _cachedFont == widget.fontSize &&
        _cachedNight == widget.palette.night &&
        _sameMarks(_cachedMarks, widget.marks);
    if (fresh) return _cached!;
    final span = _buildSpan();
    _cached = span;
    _cachedText = widget.text;
    _cachedKind = widget.kind;
    _cachedFont = widget.fontSize;
    _cachedNight = widget.palette.night;
    _cachedMarks = List<Annotation>.of(widget.marks);
    return span;
  }

  TextStyle _baseStyle(Palette p) {
    switch (widget.kind) {
      case 'h':
        return kaiStyle.copyWith(
            fontSize: widget.fontSize + 2,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            height: 1.6,
            color: p.ink);
      case 'b':
        return TextStyle(fontSize: widget.fontSize - 4, height: 1.7, color: p.soft);
      case 'x':
        return TextStyle(fontSize: widget.fontSize - 3, height: 1.8, color: p.soft);
      default:
        return TextStyle(fontSize: widget.fontSize, height: 1.95, color: p.ink);
    }
  }

  TextSpan _buildSpan() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final segs = splitSegments(widget.text, widget.marks);
    final spans = <InlineSpan>[];
    for (final seg in segs) {
      final piece = widget.text.substring(seg.start, seg.end);
      if (!seg.highlighted) {
        spans.add(TextSpan(text: piece));
        continue;
      }
      final rec = TapGestureRecognizer()
        ..onTap = () => widget.onTapMarks(seg.marks);
      _recognizers.add(rec);
      spans.add(TextSpan(
        text: piece,
        style: TextStyle(
          backgroundColor: widget.palette.markBackground(seg.color),
          decoration: TextDecoration.underline,
          decorationColor: widget.palette.markBorder(seg.color),
          decorationThickness: 1.4,
        ),
        recognizer: rec,
      ));
    }
    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 要求调用
    final p = widget.palette;
    final style = _baseStyle(p);
    final span = _ensureSpan();

    return SelectableText.rich(
      span,
      style: style,
      textAlign: widget.kind == 'h' || widget.kind == 'b'
          ? TextAlign.center
          : TextAlign.left,
      onSelectionChanged: (sel, _) {
        if (!sel.isCollapsed && sel.isValid) widget.onSelection(sel);
      },
      contextMenuBuilder: (context, editableTextState) {
        final buttons = <ContextMenuButtonItem>[
          ...editableTextState.contextMenuButtonItems,
        ];
        final value = editableTextState.textEditingValue;
        final sel = value.selection;
        if (sel.isValid && !sel.isCollapsed && sel.end > sel.start) {
          buttons.add(ContextMenuButtonItem(
            label: '✎ 标注这段文字',
            onPressed: () {
              ContextMenuController.removeAny();
              widget.onAnnotate(sel);
            },
          ));
        }
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: editableTextState.contextMenuAnchors,
          buttonItems: buttons,
        );
      },
    );
  }
}
