# 中文字体放置说明

本目录需放置以下两个 TTF 文件（用于 PDF 中文渲染）：

- `NotoSansSC-Regular.ttf`
- `NotoSansSC-Bold.ttf`

## 一键下载（推荐）

在项目根目录执行：

```bash
bash scripts/download_fonts.sh
```

## 手动下载

从 Google Fonts 获取 Noto Sans SC：

- https://fonts.google.com/noto/specimen/Noto+Sans+SC

下载后将解压得到的两个文件按上面命名放入 `assets/fonts/` 目录。

## 说明

- 若字体缺失，PDF 仍可生成，但中文会显示为空格/乱码（代码已自动回退到 Helvetica）。
- 字体文件较大，建议不要提交到代码仓库（已在 .gitignore 中忽略）。