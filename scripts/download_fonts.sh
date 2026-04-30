#!/usr/bin/env bash
# 下载完整版 Noto Sans SC（variable font，覆盖完整 CJK 字符集）
# Google Fonts 仓库 google/fonts 中只有一份 variable font，可同时充当 Regular 与 Bold。
# 必须使用完整字符集字体，否则 pdf 包遇到不在字形表里的字会抛
# Invalid argument (string): Contains invalid characters。
set -euo pipefail

DEST="$(cd "$(dirname "$0")/.." && pwd)/assets/fonts"
mkdir -p "$DEST"

URL='https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf'

echo "下载 NotoSansSC variable font (~17MB) ..."
curl -L --fail -o "$DEST/NotoSansSC-Regular.ttf" "$URL"

# Bold 复用同一份 variable font（pdf 包会读取字体内的 weight 元数据；
# 不需要单独的静态 Bold 文件）
cp "$DEST/NotoSansSC-Regular.ttf" "$DEST/NotoSansSC-Bold.ttf"

echo "完成，文件已保存到：$DEST"
ls -lh "$DEST"

# 校验：完整版 TTF 通常 > 15MB（子集版仅 ~8MB）
SIZE=$(stat -f%z "$DEST/NotoSansSC-Regular.ttf" 2>/dev/null || stat -c%s "$DEST/NotoSansSC-Regular.ttf")
if [ "$SIZE" -lt 15000000 ]; then
  echo "⚠️  字体偏小 ($SIZE bytes)，可能下载失败，PDF 中文可能报错。"
  exit 1
fi
echo "✓ 字体校验通过（$SIZE bytes）"