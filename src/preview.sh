#!/usr/bin/env bash
# ==============================================================
#  preview.sh —— 「LaTeX 阅览」阅读器
#
#  用法:
#     preview.sh <文件或文件夹> ...
#
#  效果:
#     为每个 .tex 生成一个自我包含的 HTML 阅读页，并在浏览器中打开：
#       · 「排版预览」标签页 —— 用 pandoc 把源码渲染成 HTML（公式转 MathML，
#                                图片以 base64 内嵌，离线也能看）
#       · 「源码」标签页     —— 显示 .tex 原文，带行号与语法高亮
#
#  说明:
#     · 没有 pandoc 时自动降级为「只看源码」
#     · 生成的 HTML 放在系统临时目录下，不会污染你的工程目录
# ==============================================================
set -uo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/Library/TeX/texbin:/usr/texbin:$PATH"

usage() {
  sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
}

if [ "$#" -eq 0 ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage; exit 0
fi

# ---------------- 收集 .tex ----------------
texfiles=()
for arg in "$@"; do
  if [ -d "$arg" ]; then
    while IFS= read -r -d '' t; do texfiles+=("$t"); done \
      < <(find "$arg" -type f -name '*.tex' -print0)
  elif [ -f "$arg" ] && [[ "$arg" == *.tex ]]; then
    texfiles+=("$arg")
  fi
done

if [ "${#texfiles[@]}" -eq 0 ]; then
  echo "没有找到可阅览的 .tex 文件。"
  exit 1
fi

PANDOC="$(command -v pandoc 2>/dev/null || true)"
OUTROOT="${TMPDIR:-/tmp}/latex-preview"
rm -rf "$OUTROOT"
mkdir -p "$OUTROOT"

esc_html() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

opened=()
for f in "${texfiles[@]}"; do
  dir="$(cd "$(dirname "$f")" && pwd)"
  base="$(basename "$f" .tex)"
  sub="$OUTROOT/$(printf '%s' "$base" | tr -c 'A-Za-z0-9._-' '_')"
  mkdir -p "$sub"

  # ---------- 1) 用 pandoc 渲染 ----------
  have_render=0
  if [ -n "$PANDOC" ]; then
    if ( cd "$dir" && "$PANDOC" "$(basename "$f")" -s --mathml --embed-resources \
           --metadata "title=$base" -o "$sub/render.html" ) >"$sub/render.log" 2>&1; then
      have_render=1
    fi
  fi

  # ---------- 2) 组装阅读页 ----------
  lines=$(wc -l < "$f" | tr -d ' ')
  chars=$(wc -m < "$f" | tr -d ' ')

  {
    cat <<'HTML_HEAD'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>LaTeX 阅览</title>
<style>
:root{--bg:#fff;--fg:#1f2328;--muted:#656d76;--line:#e6e8eb;--panel:#f6f8fa;--accent:#4b3fe3;
  --c-com:#8b949e;--c-cmd:#8250df;--c-env:#0a7ea4;--c-math:#b35900;--c-brace:#6e7781}
@media (prefers-color-scheme:dark){:root{--bg:#0d1117;--fg:#e6edf3;--muted:#8b949e;--line:#21262d;
  --panel:#161b22;--accent:#8b83ff;--c-com:#6e7681;--c-cmd:#d2a8ff;--c-env:#79c0ff;--c-math:#ffa657;--c-brace:#8b949e}}
*{box-sizing:border-box}
body{margin:0;height:100vh;display:flex;flex-direction:column;background:var(--bg);color:var(--fg);
  font:14px/1.6 -apple-system,"PingFang SC",system-ui,sans-serif}
header{flex:0 0 auto;display:flex;align-items:center;gap:12px;flex-wrap:wrap;padding:10px 16px;
  border-bottom:1px solid var(--line);background:var(--bg)}
.brand{font-weight:600}
.tabs{display:flex;gap:6px;margin-left:auto}
.tabs button{border:1px solid var(--line);background:var(--panel);color:var(--fg);
  padding:5px 12px;border-radius:999px;cursor:pointer;font-size:13px}
.tabs button.on{background:var(--accent);border-color:var(--accent);color:#fff}
.meta{color:var(--muted);font-size:12px;width:100%;word-break:break-all}
main{flex:1 1 auto;min-height:0;display:flex}
.pane{flex:1 1 auto;min-width:0;height:100%}
iframe{width:100%;height:100%;border:0;background:#fff}
pre.src{margin:0;height:100%;overflow:auto;padding:12px 16px;background:var(--panel);
  font:13px/1.65 ui-monospace,"SF Mono",Menlo,Consolas,monospace;tab-size:4}
.ln{color:var(--muted);user-select:none;display:inline-block;width:3.2em;text-align:right;
  padding-right:1.2em;position:sticky;left:0;background:var(--panel)}
.c{color:var(--c-com);font-style:italic}
.k{color:var(--c-cmd)}
.e{color:var(--c-env)}
.m{color:var(--c-math)}
.b{color:var(--c-brace)}
.empty{padding:40px;color:var(--muted);font-size:14px;line-height:1.9}
</style>
</head>
<body>
<header>
  <span class="brand">LaTeX 阅览</span>
  <div class="tabs">
    <button id="bt-render" class="on">排版预览</button>
    <button id="bt-src">源码</button>
  </div>
  <div class="meta">
HTML_HEAD

    printf '%s' "$(esc_html "$f")"
    printf '　·　%s 行，%s 字符' "$lines" "$chars"

    cat <<'HTML_MID'
  </div>
</header>
<main>
  <section id="pane-render" class="pane">
HTML_MID

    if [ "$have_render" -eq 1 ]; then
      printf '    <iframe src="render.html" title="排版预览"></iframe>\n'
    else
      printf '    <div class="empty">未能渲染排版预览（需要 pandoc）。<br>可直接切到「源码」标签页查看原文。<br><br>%s</div>\n' \
        "$(esc_html "$(tail -n 3 "$sub/render.log" 2>/dev/null | tr '\n' ' ')")"
    fi

    cat <<'HTML_PRE'
  </section>
  <section id="pane-src" class="pane" hidden>
<pre class="src" id="src">
HTML_PRE

    sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' "$f"

    cat <<'HTML_TAIL'
</pre>
  </section>
</main>
<script>
(function () {
  function esc(s) { return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }
  var RE = /(%[^\n]*)|(\\begin\{[^}]*\}|\\end\{[^}]*\})|(\\[a-zA-Z@]+\*?|\\.)|(\$\$[\s\S]*?\$\$|\$[^$\n]*\$)|([{}])/g;
  function hl(line) {
    var s = esc(line), out = '', last = 0, m;
    RE.lastIndex = 0;
    while ((m = RE.exec(s)) !== null) {
      out += s.slice(last, m.index);
      var cls = m[1] ? 'c' : m[2] ? 'e' : m[3] ? 'k' : m[4] ? 'm' : 'b';
      out += '<span class="' + cls + '">' + m[0] + '</span>';
      last = RE.lastIndex;
      if (m[0] === '') RE.lastIndex++;
    }
    return out + s.slice(last);
  }
  var pre = document.getElementById('src');
  var raw = pre.textContent.replace(/\n$/, '');
  var lines = raw.split('\n');
  var buf = '';
  for (var i = 0; i < lines.length; i++) {
    buf += '<span class="ln">' + (i + 1) + '</span>' + hl(lines[i]) + '\n';
  }
  pre.innerHTML = buf;

  var bs = document.getElementById('bt-src');
  var br = document.getElementById('bt-render');
  var ps = document.getElementById('pane-src');
  var pr = document.getElementById('pane-render');
  function show(src) {
    ps.hidden = !src; pr.hidden = src;
    bs.classList.toggle('on', src); br.classList.toggle('on', !src);
  }
  bs.addEventListener('click', function () { show(true); });
  br.addEventListener('click', function () { show(false); });
  document.addEventListener('keydown', function (e) {
    if (e.key === '1') show(false);
    if (e.key === '2') show(true);
  });
})();
</script>
</body>
</html>
HTML_TAIL
  } > "$sub/index.html"

  open "$sub/index.html" 2>/dev/null && opened+=("$base")
  echo "  · 阅览  ✓  $base"
done

echo
if [ "${#opened[@]}" -gt 0 ]; then
  echo "✅ 已在浏览器中打开 ${#opened[@]} 个文件的阅读页（「排版预览 / 源码」可切换，按 1 / 2 快速切换）。"
else
  echo "⚠️  阅读页已生成，但调用浏览器失败，可手动打开： $OUTROOT"
fi
exit 0
