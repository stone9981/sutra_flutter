import 'package:flutter/material.dart';

import 'catalog.dart';
import 'notes.dart';
import 'palette.dart';
import 'reader.dart';
import 'state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SutraApp());
}

class SutraApp extends StatefulWidget {
  const SutraApp({super.key});

  @override
  State<SutraApp> createState() => _SutraAppState();
}

class _SutraAppState extends State<SutraApp> {
  final AppState _state = AppState();

  @override
  void initState() {
    super.initState();
    _state.init();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(state: _state, child: const _AppView());
  }
}

/// 单独一层，让主题随 AppState 变化刷新，而不必重建整个状态对象。
class _AppView extends StatelessWidget {
  const _AppView();

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    return MaterialApp(
      title: '五十经藏',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Palette.of(st.night)),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _about(BuildContext context, Palette p, AppState st) {
    showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: p.paper,
        title: Text('五十经藏', style: kaiStyle.copyWith(fontSize: 19, color: p.ink)),
        content: SingleChildScrollView(
          child: Text(
            'FIFTY SŪTRAS · 一部随身的小藏经阁\n\n'
            '收录 ${st.sutras.length} 部经典，分 ${st.library?.categories.length ?? 0} 个部类；'
            '每部含科判大纲、CBETA 藏经原文与导读。\n\n'
            '标注用法：在「原文」里长按并拖动选中经文文字，'
            '可在系统菜单点「✎ 标注这段文字」，也可用工具条上的「标注选中」按钮；'
            '写笔记、选颜色后保存，被选中的文字会高亮。'
            '点击高亮文字可查看、编辑或删除标注，'
            '「注释本」里可集中浏览、检索、导出并跳回原文。\n\n'
            '标注保存在本机，断网可用。原文取自 CBETA 中华电子佛典协会开放数据，'
            '繁体转简体、去除行号与校勘标记，仅供阅读研习。',
            style: TextStyle(fontSize: 13, color: p.soft, height: 1.8),
          ),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(d), child: const Text('知道了')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final p = Palette.of(st.night);

    if (!st.ready) {
      return Scaffold(
        backgroundColor: p.bg,
        body: Center(
          child: st.loadError != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('经藏加载失败：\n${st.loadError}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.red, fontSize: 13, height: 1.7)),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }

    final wide = MediaQuery.of(context).size.width >= 880;

    // 沉浸式全屏：撤掉应用顶栏、目录侧栏与安全区内边距，阅读区铺满整屏。
    if (st.fullScreen) {
      return Scaffold(
        backgroundColor: p.paper,
        body: const ReaderPage(),
      );
    }

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        titleSpacing: 14,
        title: Row(children: <Widget>[
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                border: Border.all(color: p.red, width: 1.4),
                borderRadius: BorderRadius.circular(2)),
            child: Text('五十',
                style: kaiStyle.copyWith(fontSize: 11, color: p.red, height: 1.05)),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text('五十经藏',
                style: kaiStyle.copyWith(
                    fontSize: 17, color: p.ink, fontWeight: FontWeight.w600)),
            Text('FIFTY SŪTRAS · 大纲与原文',
                style: TextStyle(fontSize: 8.5, color: p.faint, letterSpacing: 1)),
          ]),
        ]),
        actions: <Widget>[
          IconButton(
            tooltip: '全屏阅读',
            icon: const Icon(Icons.fullscreen, size: 20),
            onPressed: () => st.enterFullScreen(),
          ),
          IconButton(
            tooltip: '检索',
            icon: const Icon(Icons.search, size: 20),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute<void>(builder: (_) => const SearchPage())),
          ),
          IconButton(
            tooltip: '注释本',
            icon: const Icon(Icons.edit_note_outlined, size: 21),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute<void>(builder: (_) => const NotesPage())),
          ),
          IconButton(
            tooltip: st.night ? '宣纸主题' : '夜读主题',
            icon: Icon(st.night ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 20),
            onPressed: () => st.setNight(!st.night),
          ),
          IconButton(
            tooltip: '关于',
            icon: const Icon(Icons.info_outline, size: 19),
            onPressed: () => _about(context, p, st),
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: wide
          ? null
          : SizedBox(
              width: 300,
              child: Drawer(
                backgroundColor: p.paper,
                child: CatalogPane(
                  inDrawer: true,
                  onPick: () => Navigator.pop(context),
                ),
              ),
            ),
      body: SafeArea(
        child: Row(children: <Widget>[
          if (wide)
            Container(
              width: 292,
              decoration: BoxDecoration(
                  color: p.paper,
                  border: Border(right: BorderSide(color: p.line))),
              child: const CatalogPane(),
            ),
          const Expanded(child: ReaderPage()),
        ]),
      ),
    );
  }
}
