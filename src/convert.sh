#!/usr/bin/env bash
# ==============================================================
#  convert.sh —— 「LaTeX 转换」的转换引擎
#
#  用法:
#     convert.sh word  <文件或文件夹> ...
#     convert.sh pdf   <文件或文件夹> ...
#     convert.sh both  <文件或文件夹> ...
#
#  说明:
#     · word —— 用 pandoc 生成 .docx
#     · pdf  —— 用本地 LaTeX 引擎（latexmk/xelatex/pdflatex/lualatex）编译 .pdf
#     · 传入文件夹时会递归查找其中所有 .tex 文件
#     · 输出与源 .tex 位于同一目录；报错日志写入同目录下的 .texconvert.log
#
#  既可以由 App 的 AppleScript 通过 do shell script 调用，
#  也可以在终端里直接使用。
# ==============================================================
set -uo pipefail

# 保证从 Finder 拖拽启动时也能找到 pandoc / LaTeX
export PATH="/opt/homebrew/bin:/usr/local/bin:/Library/TeX/texbin:/usr/texbin:$PATH"

usage() {
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
}

fmt="${1:-}"
case "$fmt" in
  word|pdf|both) ;;
  -h|--help|"")  usage; exit 0 ;;
  *) echo "未知格式: $fmt （应为 word / pdf / both）" >&2; exit 2 ;;
esac
shift

if [ "$#" -eq 0 ]; then
  usage; exit 2
fi

# ---------------- 收集 .tex 文件 ----------------
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
  echo "没有找到可转换的 .tex 文件。"
  exit 1
fi

# ---------------- 依赖检查 ----------------
need_word=0; { [ "$fmt" = word ] || [ "$fmt" = both ]; } && need_word=1
need_pdf=0;  { [ "$fmt" = pdf  ] || [ "$fmt" = both ]; } && need_pdf=1

PANDOC=""
if [ "$need_word" -eq 1 ]; then
  PANDOC="$(command -v pandoc 2>/dev/null || true)"
  if [ -z "$PANDOC" ]; then
    echo "未找到 pandoc，无法转 Word。请先安装： brew install pandoc"
    exit 1
  fi
fi

ENGINE=""
if [ "$need_pdf" -eq 1 ]; then
  for e in latexmk xelatex pdflatex lualatex; do
    if command -v "$e" >/dev/null 2>&1; then ENGINE="$e"; break; fi
  done
  if [ -z "$ENGINE" ]; then
    echo "未检测到 LaTeX 引擎，无法编译 PDF。请先安装其中之一："
    echo "  brew install --cask basictex   （体积小，常用宏包需另装）"
    echo "  brew install --cask mactex     （体积大，宏包齐全）"
    exit 1
  fi
fi

# ---------------- 逐个转换 ----------------
ok=0; fail=0; fails=""

for f in "${texfiles[@]}"; do
  dir="$(cd "$(dirname "$f")" && pwd)"      # 绝对路径，供子 shell cd 后仍可定位日志
  base="$(basename "$f" .tex)"
  log="$dir/.texconvert.log"

  # --- Word ---
  if [ "$need_word" -eq 1 ]; then
    if "$PANDOC" "$f" -o "$dir/$base.docx" 2>"$log"; then
      ok=$((ok+1)); echo "  · Word  ✓  $base.docx"
    else
      fail=$((fail+1)); fails="${fails}"$'\n'"  · ${base}.tex → Word"
      echo "  · Word  ✗  $base"
    fi
  fi

  # --- PDF ---
  if [ "$need_pdf" -eq 1 ]; then
    if [ "$ENGINE" = "latexmk" ]; then
      # latexmk 会自动处理交叉引用/参考文献所需的多次编译
      ( cd "$dir" && latexmk -pdf -interaction=nonstopmode "$base.tex" >"$log" 2>&1 )
    else
      # 其他引擎手动编译两遍，保证目录/交叉引用正确
      ( cd "$dir" && "$ENGINE" -interaction=nonstopmode "$base.tex" >"$log" 2>&1 )
      ( cd "$dir" && "$ENGINE" -interaction=nonstopmode "$base.tex" >"$log" 2>&1 )
    fi
    if [ -f "$dir/$base.pdf" ]; then
      ok=$((ok+1)); echo "  · PDF   ✓  $base.pdf"
    else
      fail=$((fail+1)); fails="${fails}"$'\n'"  · ${base}.tex → PDF"
      echo "  · PDF   ✗  $base"
    fi
  fi
done

# ---------------- 汇总 ----------------
echo
if [ "$fail" -eq 0 ]; then
  echo "✅ 转换完成，共 $ok 项。文件已生成在源 .tex 所在目录。"
else
  echo "转换结束：成功 $ok 项，失败 $fail 项。${fails}"
  echo "⚠️  详细报错见同目录下的隐藏文件 .texconvert.log"
fi
exit 0
