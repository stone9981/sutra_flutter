/* 把 sutra-app/data 下的两份 JS 数据导出为 Flutter 资源 assets/sutras.json。
   用法：node tool/export_assets.js
   源文件变动后重跑一次即可（或 python ../sutra-app/data/build.py build 重抓经文后再跑）。 */
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const SRC = path.resolve(ROOT, '..', 'sutra-app', 'data');
const OUT = path.join(ROOT, 'assets', 'sutras.json');

global.window = global;
require(path.join(SRC, 'meta.js'));
require(path.join(SRC, 'texts.js'));

const cats = window.SUTRA_CATEGORIES;
const metas = window.SUTRA_META;
const texts = window.SUTRA_TEXTS;

if (!Array.isArray(cats) || !Array.isArray(metas) || !texts) {
  throw new Error('数据加载失败：请检查 sutra-app/data/meta.js 与 texts.js');
}

const sutras = metas.map((m) => {
  const t = texts[m.key];
  if (!t) throw new Error('缺少经文：' + m.key);
  return {
    key: m.key,
    cat: m.cat,
    name: m.name,
    alt: m.alt,
    tag: m.tag,
    line: m.line,
    notes: m.notes,
    outline: m.outline.map((o) => ({ t: o.t, d: o.d })),
    text: {
      work: t.work,
      juan: t.juan,
      juanTotal: t.juanTotal || 1,
      title: t.title,
      titleOrig: t.titleOrig,
      byline: t.byline,
      category: t.category,
      scope: t.scope,
      link: t.link,
      bodyChars: t.bodyChars || t.takenChars || 0,
      colophon: t.colophon || '',
      paras: t.paras.map((p) => ({ k: p.k, v: p.v })),
    },
  };
});

const payload = { categories: cats, sutras };
const json = JSON.stringify(payload);
fs.writeFileSync(OUT, json, 'utf8');

const paras = sutras.reduce((n, s) => n + s.text.paras.length, 0);
const chars = sutras.reduce((n, s) => n + s.text.bodyChars, 0);
console.log('导出 ' + OUT);
console.log('  ' + cats.length + ' 类 / ' + sutras.length + ' 部 / ' + paras + ' 段 / ' +
  chars + ' 字 / ' + (Buffer.byteLength(json, 'utf8') / 1048576).toFixed(2) + ' MB');
