# -*- coding: utf-8 -*-
"""从 CBETA 开放数据接口抓取 50 部经典某一卷的真实经文，生成 texts.js。

用法：
    python build.py verify   # 核对经号、题名、译者、卷数
    python build.py build    # 抓取并生成 texts.js
数据来源：CBETA 中华电子佛典协会 https://cbdata.dila.edu.tw/stable/
"""
import sys
import os
import json
import re
import html
import ssl
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed

try:
    from opencc import OpenCC
    CC = OpenCC('t2s')
except Exception:
    CC = None

# 本机证书链缺少 Subject Key Identifier，公开只读接口改用不校验上下文
SSL_CTX = ssl._create_unverified_context()

API = 'https://cbdata.dila.edu.tw/stable/juans?work={work}&juan={juan}&work_info=1'
READER = 'https://cbetaonline.dila.edu.tw/{file}_{juan:03d}'
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'texts.js')
LIMIT = 10 ** 9  # 所选卷整卷收录，不截断

# (CBETA 经号, 卷次, 简体经名提示) —— 提示仅用于核对，实际题名以 work_info 为准
LIST = [
    ('T0251', 1, '般若波罗蜜多心经'),
    ('T0235', 1, '金刚般若波罗蜜经'),
    ('T0220', 1, '大般若波罗蜜多经'),
    ('T0233', 1, '文殊师利所说般若波罗蜜经'),
    ('T0245', 1, '佛说仁王般若波罗蜜经'),
    ('T0262', 1, '妙法莲华经'),
    ('T0276', 1, '无量义经'),
    ('T0277', 1, '佛说观普贤菩萨行法经'),
    ('T0374', 1, '大般涅槃经'),
    ('T0279', 14, '大方广佛华严经·净行品'),
    ('T0278', 1, '大方广佛华严经（六十卷本）'),
    ('T0293', 40, '普贤行愿品（四十华严）'),
    ('T0366', 1, '佛说阿弥陀经'),
    ('T0360', 1, '佛说无量寿经'),
    ('T0365', 1, '佛说观无量寿佛经'),
    ('T0452', 1, '佛说观弥勒菩萨上生兜率天经'),
    ('T0454', 1, '佛说弥勒下生成佛经'),
    ('T0475', 1, '维摩诘所说经'),
    ('T0670', 1, '楞伽阿跋多罗宝经'),
    ('T0842', 1, '大方广圆觉修多罗了义经'),
    ('T0945', 1, '大佛顶首楞严经'),
    ('T0676', 1, '解深密经'),
    ('T0665', 1, '金光明最胜王经'),
    ('T0450', 1, '药师琉璃光如来本愿功德经'),
    ('T0412', 1, '地藏菩萨本愿经'),
    ('T0353', 1, '胜鬘师子吼一乘大方便方广经'),
    ('T0839', 1, '占察善恶业报经'),
    ('T0310', 1, '大宝积经'),
    ('T0001', 1, '长阿含经'),
    ('T0099', 1, '杂阿含经'),
    ('T0026', 1, '中阿含经'),
    ('T0125', 1, '增一阿含经'),
    ('T0210', 1, '法句经'),
    ('T0784', 1, '四十二章经'),
    ('T0779', 1, '佛说八大人觉经'),
    ('T0389', 1, '佛垂般涅槃略说教诫经'),
    ('T0685', 1, '佛说盂兰盆经'),
    ('T0801', 1, '佛说无常经'),
    ('T0600', 1, '佛说十善业道经'),
    ('T1484', 2, '梵网经·菩萨心地戒品'),
    ('T1488', 1, '优婆塞戒经'),
    ('T0848', 1, '大毗卢遮那成佛神变加持经'),
    ('T0865', 1, '金刚顶一切如来真实摄大乘现证大教王经'),
    ('T1666', 1, '大乘起信论'),
    ('T1564', 1, '中论'),
    ('T1586', 1, '唯识三十论颂'),
    ('T1509', 1, '大智度论'),
    ('T1579', 1, '瑜伽师地论'),
    ('T1558', 1, '阿毗达磨俱舍论'),
    ('T2008', 1, '六祖大师法宝坛经'),
]


def fetch(work, juan):
    url = API.format(work=work, juan=juan)
    last = None
    for _ in range(3):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=40, context=SSL_CTX) as r:
                return json.loads(r.read().decode('utf-8'))
        except Exception as e:
            last = e
    raise RuntimeError('%s j%d: %s' % (work, juan, last))


def s2s(s):
    return CC.convert(s) if CC else s


def clean(h):
    """把 CBETA HTML 转成段落列表 [{k: h|b|p, v: 文本}]"""
    # 行号、图版链接、校勘锚点、脚注整块
    h = re.sub(r'<span class="lb"[^>]*>.*?</span>', '', h, flags=re.S)
    h = re.sub(r'<a class="facsimile"[^>]*>.*?</a>', '', h, flags=re.S)
    h = re.sub(r"<span class='lineInfo'[^>]*>.*?</span>", '', h, flags=re.S)
    h = re.sub(r'<a class=[\'\"](?:noteAnchor|noteAnchor add|noteAnchor star)[\'\"][^>]*>.*?</a>', '', h, flags=re.S)
    h = re.sub(r'<div class=[\'\"]footnote[^\'\"]*[\'\"][^>]*>.*?</div>', '', h, flags=re.S)
    h = re.sub(r'<span class=[\'\"]footnote[^\'\"]*[\'\"][^>]*>.*?</span>', '', h, flags=re.S)
    h = re.sub(r'<span class="note"[^>]*>.*?</span>', '', h, flags=re.S)
    # 卷首序跋（div-xu）单独标记，前端可默认折叠
    xu_ranges, stack = [], []
    for tag in re.finditer(r'<(/?)div\b([^>]*)>', h):
        if tag.group(1) == '/':
            if stack:
                start, is_xu = stack.pop()
                if is_xu:
                    xu_ranges.append((start, tag.end()))
        else:
            stack.append((tag.start(), 'div-xu' in tag.group(2)))

    # 只剩 p 标签内的正文
    out = []
    for m in re.finditer(r'<p([^>]*)>(.*?)</p>', h, flags=re.S):
        attrs, inner = m.group(1), m.group(2)
        kind = 'p'
        if re.search(r'class=[\'\"](?:head|juan)\b', attrs):
            kind = 'h'
        elif re.search(r'class=[\'\"]byline', attrs):
            kind = 'b'
        if any(a <= m.start() < b for a, b in xu_ranges):
            kind = 'x'
        txt = re.sub(r'<[^>]+>', '', inner)
        txt = html.unescape(txt)
        txt = re.sub(r'\s+', '', txt).strip()
        txt = txt.replace('[＊]', '').replace('[*]', '')
        if not txt:
            continue
        txt = s2s(txt)
        out.append({'k': kind, 'v': txt})
    return out


def build_one(item):
    work, juan, hint = item
    d = fetch(work, juan)
    if d.get('num_found', 0) < 1:
        raise RuntimeError('%s j%d 无数据' % (work, juan))
    raw = ''.join(d['results'])
    paras = clean(raw)
    # CBETA 卷末的版本记录不是经文正文，单独存为 colophon
    colophon, body_paras = '', []
    for p in paras:
        if p['v'].startswith('【经文资讯】'):
            colophon = p['v']
        else:
            body_paras.append(p)
    paras = body_paras
    wi = d.get('work_info') or {}
    total = sum(len(p['v']) for p in paras)
    kept = list(paras)
    if total > LIMIT:
        acc, n = [], 0
        for p in paras:
            if n and n + len(p['v']) > LIMIT:
                break
            acc.append(p)
            n += len(p['v'])
        kept = acc
    taken = sum(len(p['v']) for p in kept)
    f = wi.get('file') or work
    rec = {
        'work': work,
        'juan': juan,
        'title': s2s(wi.get('title') or hint),
        'titleOrig': wi.get('title') or '',
        'byline': s2s(wi.get('byline') or ''),
        'category': s2s(wi.get('category') or ''),
        'juanTotal': wi.get('juan') or 1,
        'cjkChars': wi.get('cjk_chars') or 0,
        'paras': kept,
        'totalChars': total,
        'takenChars': taken,
        'bodyChars': sum(len(p['v']) for p in kept if p['k'] != 'x'),
        'scope': '本卷全文' if total <= LIMIT else '卷首节录',
        'colophon': colophon,
        'link': READER.format(file=f, juan=juan),
    }
    return '%s_%d' % (work, juan), rec


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else 'verify'
    if mode == 'verify':
        with ThreadPoolExecutor(max_workers=6) as ex:
            futs = {ex.submit(fetch, w, 1): (w, j, h) for w, j, h in LIST}
            for fu in as_completed(futs):
                w, j, h = futs[fu]
                try:
                    wi = fu.result().get('work_info') or {}
                    print('%-6s j%-2d | %-28s | %-18s | %2s卷 | %s' % (
                        w, j, wi.get('title', '?')[:28], (wi.get('byline') or '')[:18],
                        wi.get('juan', '?'), h))
                except Exception as e:
                    print('%-6s j%-2d | ERROR %s' % (w, j, e))
        return

    data, errors = {}, []
    with ThreadPoolExecutor(max_workers=6) as ex:
        futs = {ex.submit(build_one, it): it for it in LIST}
        for fu in as_completed(futs):
            it = futs[fu]
            try:
                k, rec = fu.result()
                data[k] = rec
                print('OK  %-10s %-22s %5d/%6d 字  %s' % (
                    k, rec['title'][:22], rec['takenChars'], rec['totalChars'], rec['scope']))
            except Exception as e:
                errors.append((it, str(e)))
                print('ERR', it[0], e)
    # 按 LIST 顺序输出，保证稳定
    ordered = {('%s_%d' % (w, j)): data[('%s_%d' % (w, j))] for w, j, _ in LIST
               if ('%s_%d' % (w, j)) in data}
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write('/* 经文原文：CBETA 中华电子佛典协会开放数据，繁体经标点转简体；build.py 自动生成 */\n')
        f.write('window.SUTRA_TEXTS = ')
        json.dump(ordered, f, ensure_ascii=False, separators=(',', ':'))
        f.write(';\n')
    print('\n生成 %s：%d 部，共 %d 字；失败 %d 部' % (
        OUT, len(ordered), sum(v['takenChars'] for v in ordered.values()), len(errors)))
    if errors:
        print('失败清单：', errors)


if __name__ == '__main__':
    main()
    # 重新抓取经文后，同步把数据内联进单文件 index.html，避免两处数据不一致
    if len(sys.argv) > 1 and sys.argv[1] == 'build':
        sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        import bundle
        bundle.main()
