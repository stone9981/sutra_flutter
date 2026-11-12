# -*- coding: utf-8 -*-
"""把 data/meta.js、data/texts.js 内联进 index.html，生成自包含单文件应用。

可重复运行：修改 data/*.js 或 index.html 后执行 `python bundle.py` 即可重新打包。
同时写入一份「静态首屏」：即使预览环境完全禁用脚本，目录与大纲也依然可见。
"""
import os
import re
import json
import html
import subprocess

ROOT = os.path.dirname(os.path.abspath(__file__))
INDEX = os.path.join(ROOT, 'index.html')
META_JS = os.path.join(ROOT, 'data', 'meta.js')
TEXTS_JS = os.path.join(ROOT, 'data', 'texts.js')

D_BEGIN = '<!-- BEGIN INLINE DATA · 由 bundle.py 生成，请勿手改 -->'
D_END = '<!-- END INLINE DATA -->'
C_BEGIN = '<!-- BEGIN STATIC CATALOG -->'
C_END = '<!-- END STATIC CATALOG -->'
V_BEGIN = '<!-- BEGIN STATIC VIEW -->'
V_END = '<!-- END STATIC VIEW -->'
H_BEGIN = '<!-- BEGIN STATIC HERO -->'
H_END = '<!-- END STATIC HERO -->'


def e(s):
    return html.escape(str(s), quote=True)


def load_meta():
    """用 node 加载 meta.js，拿到可直接序列化的 JSON。node 不可用时降级为正则补引号。"""
    js = ("var window = {};" + open(META_JS, encoding='utf-8').read() +
          ";process.stdout.write(JSON.stringify({c:window.SUTRA_CATEGORIES,m:window.SUTRA_META}));")
    try:
        out = subprocess.check_output(['node', '-e', js], cwd=ROOT)
        return json.loads(out.decode('utf-8'))
    except Exception:
        s = open(META_JS, encoding='utf-8').read()
        cats = json.loads(re.search(r'window\.SUTRA_CATEGORIES\s*=\s*(\[[\s\S]*?\])\s*;', s).group(1))
        body = re.search(r'window\.SUTRA_META\s*=\s*(\[[\s\S]*?\])\s*;', s).group(1)
        body = re.sub(r'(?m)^(\s*)([A-Za-z_][A-Za-z0-9_]*)\s*:', r'\1"\2":', body)
        return {'c': cats, 'm': json.loads(body)}


def static_catalog(cats, metas):
    out = []
    for cat in cats:
        rows = [(i, m) for i, m in enumerate(metas) if m['cat'] == cat]
        if not rows:
            continue
        out.append('<button class="cat-head" data-cat="%s"><span class="caret">▼</span>%s'
                   '<span class="cnt">%d</span></button>' % (e(cat), e(cat), len(rows)))
        for i, m in rows:
            out.append('<div class="sitem%s" data-i="%d"><span class="no">%02d</span>'
                       '<span class="nm">%s<span class="alt">%s</span></span></div>' %
                       (' active' if i == 0 else '', i, i + 1, e(m['name']), e(m['alt'])))
    return '\n'.join(out)


def static_view(metas):
    m = metas[0]
    parts = ['<p class="sec-note">下列大纲按经文次第科判，先看结构，再读原文，脉络自明。本部共 %d 段。</p>'
             % len(m['outline'])]
    for i, o in enumerate(m['outline']):
        parts.append('<div class="outline-item"><div class="num kai">%02d</div>'
                     '<div><h3 class="kai">%s</h3><p>%s</p></div></div>'
                     % (i + 1, e(o['t']), e(o['d'])))
    return '\n'.join(parts)


def fill_id(h, tag, ident, value, raw=False):
    """给静态元素填入初始文本，幂等。raw=True 时 value 为已转义的 HTML 片段。"""
    pat = r'(<%s\b[^>]*\bid="%s"[^>]*>)[\s\S]*?(</%s>)' % (tag, ident, tag)
    return re.sub(pat, lambda mo: mo.group(1) + (value if raw else e(value)) + mo.group(2),
                  h, count=1)


def load_texts():
    s = open(TEXTS_JS, encoding='utf-8').read()
    return json.loads(s[s.index('{'):s.rindex(';')])


def main():
    h = open(INDEX, encoding='utf-8').read()
    meta = load_meta()
    cats, metas = meta['c'], meta['m']
    texts = load_texts()
    m0 = metas[0]
    t0 = texts.get(m0['key'], {})
    total_chars = sum(v.get('bodyChars') or v.get('takenChars') or 0 for v in texts.values())

    # 1) 内联数据（替换旧的外链脚本或上一轮的内联块）
    data_block = (D_BEGIN + '\n<script>\n' + open(META_JS, encoding='utf-8').read().strip() +
                  '\n</script>\n<script>\n' + open(TEXTS_JS, encoding='utf-8').read().strip() +
                  '\n</script>\n' + D_END)
    if D_BEGIN in h:
        h = re.sub(re.escape(D_BEGIN) + r'[\s\S]*?' + re.escape(D_END), lambda mo: data_block, h, count=1)
    else:
        old = '<script src="data/meta.js"></script>\n<script src="data/texts.js"></script>'
        if old not in h:
            raise SystemExit('未找到外链脚本标记，无法内联，请检查 index.html')
        h = h.replace(old, data_block, 1)

    # 2) 静态经题区
    for tag, ident, val in [
        ('span', 'heroCat', m0['cat']), ('span', 'heroTag', m0['tag']),
        ('div', 'heroIdx', '01'), ('h2', 'heroName', m0['name']),
        ('p', 'heroAlias', '又名 · ' + m0['alt']), ('p', 'heroLede', m0['line']),
        ('span', 'tabOutlineN', '%02d' % len(m0['outline'])),
        ('span', 'tabTextN', str(len(t0.get('paras', [])))),
        ('div', 'statLine', '%d 部 · %d 类 · 原文 %.1f 万字' %
         (len(metas), len(cats), total_chars / 10000.0)),
        ('div', 'progress', '1 / %d' % len(metas)),
        ('span', 'prevName', '已是第一部'),
        ('span', 'nextName', metas[1]['name'] if len(metas) > 1 else ''),
        ('button', 'starBtn', '☆ 收藏'),
    ]:
        h = fill_id(h, tag, ident, val)
    hero_meta = (
        '<span>译／撰：<b>%s</b></span><span>部类：<b>%s</b></span>'
        '<span>%s</span><span>经文 <b>%s</b> 字</span><span>编号 <b>%s</b></span>' % (
            e(t0.get('byline', '—')), e(t0.get('category', m0['cat'])),
            '全经 %d 卷 · 此录第 %d 卷' % (t0.get('juanTotal', 1), t0.get('juan', 1))
            if t0.get('juanTotal', 1) > 1 else '一卷本 · 全经',
            format(t0.get('bodyChars') or t0.get('takenChars') or 0, ','),
            e(t0.get('work', ''))))
    h = fill_id(h, 'div', 'heroMeta', hero_meta, raw=True)
    hero_note = (H_BEGIN + '\n<noscript><div class="empty" style="margin:0 0 14px;padding:10px 14px;'
                 'line-height:1.8">当前预览环境未启用脚本：目录与大纲已作为静态内容显示。'
                 '完整交互（原文、搜索、竖排等）请用浏览器打开本地 HTML 文件。</div></noscript>\n' + H_END)
    if H_BEGIN in h:
        h = re.sub(re.escape(H_BEGIN) + r'[\s\S]*?' + re.escape(H_END), lambda mo: hero_note, h, count=1)
    else:
        h = h.replace('<div id="catalog">', hero_note + '\n    <div id="catalog">', 1)

    # 3) 静态目录
    cat_block = C_BEGIN + '\n' + static_catalog(cats, metas) + '\n' + C_END
    if C_BEGIN in h:
        h = re.sub(re.escape(C_BEGIN) + r'[\s\S]*?' + re.escape(C_END), lambda mo: cat_block, h, count=1)
    else:
        h = h.replace('<div id="catalog"></div>', '<div id="catalog">\n' + cat_block + '\n</div>', 1)

    # 4) 静态大纲视图
    view_block = V_BEGIN + '\n' + static_view(metas) + '\n' + V_END
    if V_BEGIN in h:
        h = re.sub(re.escape(V_BEGIN) + r'[\s\S]*?' + re.escape(V_END), lambda mo: view_block, h, count=1)
    else:
        h = h.replace('<div id="content"></div>', '<div id="content">\n' + view_block + '\n</div>', 1)

    # 5) 数据缺失时不要清空静态兜底
    guard = ("  if (!META.length) {\n"
             "    var box = document.getElementById('content');\n"
             "    if (box) box.insertAdjacentHTML('beforeend',\n"
             "      '<p class=\"sec-note\">经文数据未能载入，以上为静态目录与大纲。请确认 index.html 完整，或重新运行 python bundle.py。</p>');\n"
             "    return;\n"
             "  }\n")
    if 'if (!META.length) {' not in h:
        h = h.replace('  var LS = \'sutra50.v1\';\n', '  var LS = \'sutra50.v1\';\n' + guard, 1)

    with open(INDEX, 'w', encoding='utf-8', newline='') as f:
        f.write(h)
    # 另存一份中文名的独立单文件，方便单独复制 / 发送给别人（内容完全一致）
    alt = os.path.join(ROOT, '五十经藏.html')
    with open(alt, 'w', encoding='utf-8', newline='') as f:
        f.write(h)
    print('打包完成：index.html 与 五十经藏.html（内容相同，均为自包含单文件）')
    print('  %d 部 / %d 类 / 单文件 %.2f MB' %
          (len(metas), len(cats), len(h.encode('utf-8')) / 1048576.0))


if __name__ == '__main__':
    main()
