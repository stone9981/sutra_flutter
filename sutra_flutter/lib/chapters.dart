import 'models.dart';

/// 传统分章条目：标题 + 可供正文命中的锚点片段。
/// 用于补足 CBETA 底本没有品目标题、但传统上确有分章的经典
/// （如《金刚经》昭明太子三十二分、《圆觉经》十二章）。
class Chapter {
  final String t;
  final String a;
  const Chapter(this.t, this.a);
}

/// 人工校订的传统分章表。锚点取该章起始处的独有的字句，
/// 运行时在正文里查找定位，避免依赖段落下标（数据重抓后仍可用）。
const Map<String, List<Chapter>> kChapters = <String, List<Chapter>>{
  // 《金刚般若波罗蜜经》昭明太子三十二分
  'T0235_1': <Chapter>[
    Chapter('法会因由分第一', '如是我闻'),
    Chapter('善现启请分第二', '长老须菩提在大众中即从座起'),
    Chapter('大乘正宗分第三', '诸菩萨摩诃萨应如是降伏其心'),
    Chapter('妙行无住分第四', '菩萨于法应无所住行于布施'),
    Chapter('如理实见分第五', '可以身相见如来不'),
    Chapter('正信希有分第六', '颇有众生，得闻如是言说章句'),
    Chapter('无得无说分第七', '如来得阿耨多罗三藐三菩提耶'),
    Chapter('依法出生分第八', '若人满三千大千世界七宝以用布施'),
    Chapter('一相无相分第九', '须陀洹能作是念'),
    Chapter('庄严净土分第十', '如来昔在然灯佛所'),
    Chapter('无为福胜分第十一', '如恒河中所有沙数'),
    Chapter('尊重正教分第十二', '随说是经，乃至四句偈等'),
    Chapter('如法受持分第十三', '当何名此经'),
    Chapter('离相寂灭分第十四', '须菩提闻说是经，深解义趣'),
    Chapter('持经功德分第十五', '初日分以恒河沙等身布施'),
    Chapter('能净业障分第十六', '受持、读诵此经，若为人轻贱'),
    Chapter('究竟无我分第十七', '善男子、善女人发阿耨多罗三藐三菩提心，云'),
    Chapter('一体同观分第十八', '如来有肉眼不'),
    Chapter('法界通化分第十九', '若有人满三千大千世界七宝以用布施'),
    Chapter('离色离相分第二十', '佛可以具足色身见不'),
    Chapter('非说所说分第二十一', '汝勿谓如来作是念，『我当有所说法』'),
    Chapter('无法可得分第二十二', '佛得阿耨多罗三藐三菩提，为无所得耶'),
    Chapter('净心行善分第二十三', '是法平等，无有高下'),
    Chapter('福智无比分第二十四', '所有诸须弥山王'),
    Chapter('化无所化分第二十五', '汝等勿谓如来作是念：『我当度众生。』'),
    Chapter('法身非相分第二十六', '可以三十二相观如来不'),
    Chapter('无断无灭分第二十七', '如来不以具足相故'),
    Chapter('不受不贪分第二十八', '菩萨以满恒河沙等世界七宝布施'),
    Chapter('威仪寂静分第二十九', '如来若来若去、若坐若卧'),
    Chapter('一合理相分第三十', '三千大千世界碎为微尘'),
    Chapter('知见不生分第三十一', '佛说我见、人见、众生见、寿者见'),
    Chapter('应化非真分第三十二', '若有人以满无量阿僧祇世界七宝持用布施'),
  ],
  // 《大方广圆觉修多罗了义经》十二章（十二菩萨各问一章）
  'T0842_1': <Chapter>[
    Chapter('文殊师利菩萨章', '于是文殊师利菩萨在大众中'),
    Chapter('普贤菩萨章', '于是普贤菩萨在大众中'),
    Chapter('普眼菩萨章', '于是普眼菩萨在大众中'),
    Chapter('金刚藏菩萨章', '于是金刚藏菩萨在大众中'),
    Chapter('弥勒菩萨章', '于是弥勒菩萨在大众中'),
    Chapter('清净慧菩萨章', '于是清净慧菩萨在大众中'),
    Chapter('威德自在菩萨章', '于是威德自在菩萨在大众中'),
    Chapter('辩音菩萨章', '于是辩音菩萨在大众中'),
    Chapter('净诸业障菩萨章', '于是净诸业障菩萨在大众中'),
    Chapter('普觉菩萨章', '于是普觉菩萨在大众中'),
    Chapter('圆觉菩萨章', '于是圆觉菩萨在大众中'),
    Chapter('贤善首菩萨章', '于是贤善首菩萨在大众中'),
  ],
  // 《佛说观无量寿佛经》十六观
  'T0365_1': <Chapter>[
    Chapter('第一观 · 日想观', '皆见日没'),
    Chapter('第二观 · 水想观', '次作水想'),
    Chapter('第三观 · 地想观', '水想成已'),
    Chapter('第四观 · 宝树观', '次观宝树'),
    Chapter('第五观 · 宝池观', '树想成已，次当想水'),
    Chapter('第六观 · 宝楼观', '一一界上有五百亿宝楼'),
    Chapter('第七观 · 华座观', '于七宝地上作莲花想'),
    Chapter('第八观 · 像观', '次当想佛'),
    Chapter('第九观 · 真身观', '次当更观无量寿佛身相光明'),
    Chapter('第十观 · 观音观', '次亦应观观世音菩萨'),
    Chapter('第十一观 · 势至观', '次观大势至菩萨'),
    Chapter('第十二观 · 普往生观', '自见生于西方极乐世界'),
    Chapter('第十三观 · 杂想观', '先当观于一丈六像在池水上'),
    Chapter('第十四观 · 上辈生观', '凡生西方有九品人'),
    Chapter('第十五观 · 中辈生观', '中品上生者'),
    Chapter('第十六观 · 下辈生观', '下品上生者'),
  ],
  // 《大乘起信论》五分
  'T1666_1': <Chapter>[
    Chapter('因缘分', '初说因缘分'),
    Chapter('立义分', '次说立义分'),
    Chapter('解释分', '次说解释分'),
    Chapter('修行信心分', '次说修行信心分'),
    Chapter('劝修利益分', '次说劝修利益分'),
  ],
  // 《佛说八大人觉经》八觉
  'T0779_1': <Chapter>[
    Chapter('第一觉悟 · 世间无常', '第一觉悟：世间无常'),
    Chapter('第二觉知 · 多欲为苦', '第二觉知：多欲为苦'),
    Chapter('第三觉知 · 心无厌足', '第三觉知：心无厌足'),
    Chapter('第四觉知 · 懈怠坠落', '第四觉知：懈怠坠落'),
    Chapter('第五觉悟 · 愚痴生死', '第五觉悟：愚痴生死'),
    Chapter('第六觉知 · 贫苦多怨', '第六觉知：贫苦多怨'),
    Chapter('第七觉悟 · 五欲过患', '第七觉悟：五欲过患'),
    Chapter('第八觉知 · 生死炽然', '第八觉知：生死炽然'),
  ],
};

/// 分章来源说明（展示用）。
const Map<String, String> kChapterSource = <String, String>{
  'T0235_1': '依昭明太子三十二分',
  'T0365_1': '依观经十六观',
  'T0842_1': '依圆觉经十二章',
  'T1666_1': '依论文五分',
  'T0779_1': '依八大人觉次第',
};

/// 一个可跳转的结构条目：标题 + 正文段落下标（-1 表示未能定位）。
class HeadingEntry {
  final String title;
  final int para;
  const HeadingEntry(this.title, this.para);
}

/// 过滤卷题、经题重复、真言、目录等噪声标题（它们不是品目）。
bool _isNoise(String v, String name) {
  final t = v.replaceAll('◎', '').replaceAll('　', '').trim();
  if (t.isEmpty) return true;
  if (t == name || t == '$name一卷') return true;
  if (t == '真言' || t == '目录' || t == '附录') return true;
  if (t.endsWith('目录') || t.endsWith('附录') || t.endsWith('终')) return true;
  if (t.contains('亦名')) return true;
  // 卷次标题：卷第N、卷上、卷下、上卷、下卷
  if (RegExp(r'卷第[一二三四五六七八九十百千0-9]').hasMatch(t)) return true;
  if (RegExp(r'卷[上下]$').hasMatch(t)) return true;
  if (RegExp(r'[上下]卷$').hasMatch(t)) return true;
  if (RegExp(r'卷[上下](出|之)').hasMatch(t)) return true;
  // 经名后面只跟一个卷次，如「测试经卷第一」「法句经卷上」——是卷题而非品目
  if (t.startsWith(name)) {
    final suffix = t.substring(name.length).replaceAll(RegExp(r'^[·・]'), '');
    if (RegExp(r'^卷[第上下一二三四五六七八九十百千0-9]*$').hasMatch(suffix)) {
      return true;
    }
  }
  return false;
}

int _findPara(Sutra s, String anchor) {
  final paras = s.text.paras;
  for (int i = 0; i < paras.length; i++) {
    if (paras[i].isPreface) continue;
    if (paras[i].v.contains(anchor)) return i;
  }
  return -1;
}

/// 该经是否有「人工校订的传统分章」。
bool hasCuratedChapters(String key) => kChapters.containsKey(key);

/// 取该经的分章/品目结构：优先用人工分章，其次用经文自带的品目标题。
/// 返回空列表表示底本未分品目（短经多属此类）。
List<HeadingEntry> structureHeadings(Sutra s) {
  final curated = kChapters[s.key];
  if (curated != null && curated.isNotEmpty) {
    return <HeadingEntry>[
      for (final c in curated) HeadingEntry(c.t, _findPara(s, c.a)),
    ];
  }
  final out = <HeadingEntry>[];
  final seen = <String>{};
  final paras = s.text.paras;
  for (int i = 0; i < paras.length; i++) {
    final para = paras[i];
    if (para.k != 'h') continue;
    if (_isNoise(para.v, s.name)) continue;
    final title = para.v.replaceAll('◎', '').trim();
    if (title.isEmpty || !seen.add(title)) continue;
    out.add(HeadingEntry(title, i));
  }
  return out;
}
