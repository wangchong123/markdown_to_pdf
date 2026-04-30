# Markdown to PDF (Android)

一个用 Flutter 写的 Android 工具：把 Markdown 文档转换为 PDF，支持中文。

## 功能

- 导入本地 `.md` / `.markdown` / `.txt` 文件
- 编辑器 + 实时 Markdown 预览（标题、列表、代码块、表格、引用、链接、图片占位）
- 一键转 PDF：A4 / 中文字体 / 行内样式（加粗、斜体、行内代码、删除线、链接）
- PDF 预览页：缩放、翻页、打印
- 保存到应用文档目录 / 系统分享导出

## 项目结构

```
lib/
├── main.dart                              # 入口 + 主题
├── screens/
│   ├── home_screen.dart                   # 首页（编辑/预览/导入/转换）
│   └── pdf_preview_screen.dart            # PDF 预览/保存/分享
└── services/
    └── markdown_to_pdf_service.dart       # Markdown -> PDF 核心转换
assets/fonts/                              # NotoSansSC 中文字体
android/                                   # Android 平台脚手架
scripts/download_fonts.sh                  # 一键下载中文字体
```

## 运行

### 前置环境

- Flutter ≥ 3.19（已验证 3.24.5）
- Android SDK 34/35 + build-tools 34.0.0
- 中文字体（首次需下载）：
  ```bash
  bash scripts/download_fonts.sh
  ```

### 调试运行

```bash
flutter pub get
flutter run                # 连接真机或启动模拟器后
```

### 打包 Release APK

```bash
# 单个通用包（更大）
flutter build apk --release

# 按 ABI 拆分（推荐，每个包更小）
flutter build apk --release --split-per-abi
```

构建产物位置：`build/app/outputs/flutter-apk/`

| ABI | 适用机型 | 体积 |
|---|---|---|
| `app-arm64-v8a-release.apk` | 大多数现代安卓真机 | ~33 MB |
| `app-armeabi-v7a-release.apk` | 老旧 32 位安卓机 | ~31 MB |
| `app-x86_64-release.apk` | x86 模拟器 | ~34 MB |

## 主要依赖

| 用途 | 包 |
|---|---|
| Markdown 解析 | `markdown` |
| Markdown 预览 | `flutter_markdown` |
| PDF 生成 | `pdf` |
| PDF 预览/打印 | `printing` |
| 文件选取 | `file_picker` |
| 本地路径 | `path_provider` |
| 系统分享 | `share_plus` |

## Android 配置要点

- `minSdk = 23`（Android 6+，覆盖绝大多数设备）
- `compileSdk = 35`、`ndkVersion = 25.1.8937393`（满足主要插件要求）
- `INTERNET` 权限（`printing` 包链接系统打印服务时使用）
- Java 11 source/target

## 后续可扩展

- 应用图标（`flutter_launcher_icons`）
- 启动页（`flutter_native_splash`）
- 嵌入 Markdown 中的本地图片
- 自定义 PDF 主题（页眉页脚、字体选择）
- 历史记录 / 多文档管理