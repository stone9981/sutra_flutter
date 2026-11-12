import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'annotations.dart';
import 'models.dart';

/// 全局状态：阅读偏好、收藏、当前经典与全部标注。
/// 标注与各偏好写入 SharedPreferences，离线可用、重启不丢。
class AppState extends ChangeNotifier {
  static const String kAnnotations = 'sutra50.annotations.v1';
  static const String kPrefs = 'sutra50.prefs.v1';

  SharedPreferences? _prefs;

  Library? library;
  bool ready = false;
  String? loadError;

  List<Annotation> annotations = <Annotation>[];
  final Set<String> favorites = <String>{};
  bool night = false;
  double fontSize = 18;
  bool showPreface = false;
  int currentIndex = 0;
  int tab = 0; // 0 大纲 / 1 原文 / 2 导读
  String query = '';
  String filter = 'all'; // all / fav

  /// 「注释本」跳转：切到原文后滚动定位到该段。
  int? jumpPara;
  String? jumpAnnotationId;
  int jumpSeq = 0; // 每次带 para 的跳转都 +1，确保重复点同一项也能重新定位

  List<Sutra> get sutras => library?.sutras ?? const <Sutra>[];
  Sutra? get current =>
      (currentIndex >= 0 && currentIndex < sutras.length) ? sutras[currentIndex] : null;

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      annotations = Annotation.decode(_prefs!.getString(kAnnotations));
      final rawPrefs = _prefs!.getString(kPrefs);
      if (rawPrefs != null && rawPrefs.isNotEmpty) {
        final j = jsonDecode(rawPrefs) as Map<String, dynamic>;
        night = j['night'] as bool? ?? false;
        fontSize = (j['fontSize'] as num?)?.toDouble() ?? 18;
        showPreface = j['showPreface'] as bool? ?? false;
        currentIndex = (j['currentIndex'] as num?)?.toInt() ?? 0;
        favorites.addAll(
            (j['favorites'] as List<dynamic>? ?? []).map((e) => e.toString()));
      }
      library = await Library.load();
      if (currentIndex >= sutras.length || currentIndex < 0) currentIndex = 0;
      ready = true;
    } catch (e) {
      loadError = e.toString();
    }
    notifyListeners();
  }

  void _savePrefs() {
    _prefs?.setString(
        kPrefs,
        jsonEncode(<String, dynamic>{
          'night': night,
          'fontSize': fontSize,
          'showPreface': showPreface,
          'currentIndex': currentIndex,
          'favorites': favorites.toList(),
        }));
  }

  void _saveAnnotations() {
    _prefs?.setString(kAnnotations, Annotation.encode(annotations));
  }

  void setNight(bool v) {
    night = v;
    _savePrefs();
    notifyListeners();
  }

  void setFontSize(double v) {
    fontSize = v.clamp(14.0, 30.0).toDouble();
    _savePrefs();
    notifyListeners();
  }

  void setShowPreface(bool v) {
    showPreface = v;
    _savePrefs();
    notifyListeners();
  }

  void setQuery(String v) {
    query = v.trim();
    notifyListeners();
  }

  void setFilter(String v) {
    filter = v;
    notifyListeners();
  }

  void setTab(int v) {
    tab = v;
    notifyListeners();
  }

  bool isFav(String key) => favorites.contains(key);

  void toggleFav(String key) {
    if (favorites.contains(key)) {
      favorites.remove(key);
    } else {
      favorites.add(key);
    }
    _savePrefs();
    notifyListeners();
  }

  void open(int index, {int? tabIndex, int? para, String? annotationId}) {
    if (index < 0 || index >= sutras.length) return;
    currentIndex = index;
    if (tabIndex != null) tab = tabIndex;
    jumpPara = para;
    jumpAnnotationId = annotationId;
    if (para != null) jumpSeq++;
    _savePrefs();
    notifyListeners();
  }

  void openKey(String key, {int? para, String? annotationId}) {
    final i = sutras.indexWhere((s) => s.key == key);
    if (i >= 0) open(i, tabIndex: 1, para: para, annotationId: annotationId);
  }

  void clearJump() {
    jumpPara = null;
    jumpAnnotationId = null;
    notifyListeners();
  }

  List<Annotation> marksFor(String key, int para) => annotations
      .where((a) => a.sutraKey == key && a.para == para)
      .toList();

  List<Annotation> marksForSutra(String key) =>
      annotations.where((a) => a.sutraKey == key).toList();

  void addAnnotation(Annotation a) {
    annotations = <Annotation>[...annotations, a];
    _saveAnnotations();
    notifyListeners();
  }

  void updateAnnotation(Annotation a) {
    annotations = annotations.map((x) => x.id == a.id ? a : x).toList();
    _saveAnnotations();
    notifyListeners();
  }

  void deleteAnnotation(String id) {
    annotations = annotations.where((x) => x.id != id).toList();
    _saveAnnotations();
    notifyListeners();
  }

  /// 按查询词筛选目录：命中经名、别名、译者、主题、大纲或经文原文。
  List<int> filteredIndices() {
    final out = <int>[];
    for (int i = 0; i < sutras.length; i++) {
      final s = sutras[i];
      if (filter == 'fav' && !favorites.contains(s.key)) continue;
      if (query.isEmpty || s.headText.contains(query) || s.plainText.contains(query)) {
        out.add(i);
      }
    }
    return out;
  }

  /// 命中的经文原文次数，用于目录上显示「原文 N」。
  int bodyHits(Sutra s) {
    if (query.isEmpty) return 0;
    int n = 0, pos = 0;
    while ((pos = s.plainText.indexOf(query, pos)) >= 0) {
      n++;
      pos += query.length;
      if (n > 99) break;
    }
    return n;
  }
}

/// 不用第三方状态管理包：InheritedNotifier 即可让 dependents 随 notifyListeners 重建。
class AppScope extends InheritedNotifier<AppState> {
  AppScope({Key? key, required AppState state, required Widget child})
      : super(key: key, notifier: state, child: child);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!.notifier!;
  }
}
