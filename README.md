<div align="center">
  
  <img src="docs/logo.svg" width="160" alt="Trans Prism Logo">

# Trans Prism (TP) 🌈

**专为跨性别群体打造的极简、安全、双擎驱动的实用工具箱**

  <p>
    <a href="https://github.com/daanser/Trans-Prism/stargazers"><img src="https://img.shields.io/github/stars/daanser/Trans-Prism.svg?style=social&label=Star" alt="GitHub stars"></a>
    <a href="https://github.com/daanser/Trans-Prism/network/members"><img src="https://img.shields.io/github/forks/daanser/Trans-Prism.svg?style=social&label=Fork" alt="GitHub forks"></a>
  </p>
  <p>
    <a href="https://flutter.dev/"><img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter"></a>
    <a href="https://www.apache.org/licenses/LICENSE-2.0"><img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" alt="License: Apache 2.0"></a>
    <a href="http://makeapullrequest.com"><img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg" alt="PRs Welcome"></a>
    <a href="https://github.com/Trans-Prism/Trans-Prism/releases"><img src="https://img.shields.io/github/v/release/Trans-Prism/Trans-Prism?include_prereleases&color=%235BCEFA&label=Version" alt="Version"></a>
  </p>

</div>

---

## 📖 关于

**Trans Prism（稳态光盒）** 是一款致力于为跨性别群体提供安全、客观、无审查的日常辅助工具的开源 App。采用**在线/离线双擎架构**与**纯本地物理持久化**策略，核心知识库和极其隐私的生理数据不依赖任何第三方服务器。

> Created via Deepseek, Gemini, Claude, GLM, Mimo Vibe Coding（按使用率排序）

---

## ✨ 核心功能

### 💊 药物存量仪表盘 & 智能调度提醒
追踪 HRT 药物库存与安全续航天数。**Chronos 智能调度引擎**支持小时/天/周/月四种给药周期——从口服（12h）、外用凝胶到针剂（7天）、GnRHa（28天/84天）全覆盖。基于绝对时间戳的 OS 级通知，点击"已服药"自动扣减库存、推算下次给药时间并重设系统闹钟。

### 📈 药代动力学 (PK) 模拟器
基于开源项目 [Oyama-s-HRT-Recorder](https://github.com/SmirnovaOyama/Oyama-s-HRT-Tracker) 的一室/多室指数衰减算法与多剂量叠加模型。支持模拟常见 HRT 药物的稳态血药浓度曲线。App 内嵌 WebView 运行，算法在 WebView 内的 JS 中（非 Dart 侧）。

### 📚 双擎动态知识库
无缝集成 **MtF.wiki / FtM.wiki / RLE.wiki / MioMtFWiki** 四大开源指南。默认轻量在线模式（零缓存），支持一键下载离线包（OTA 静默热更新），退出离线模式时可选清理缓存（"阅后即焚"）。

### 🎙️ 声音训练辅助
基于开源项目 [VFS Tracker](https://github.com/Ethanlita/vfs-tracker) 适配集成。包含 F0 实时检测、音阶练习、88 键钢琴、嗓音测试向导、RBH/TVQ-G/OVHS9 主观量表、训练记录时间线与 AI 鼓励消息。

### 🔄 激素换算器
6 项核心激素（E2/T/PRL/P4/FSH/LH）质量浓度 ↔ 摩尔浓度双向换算，数据衍生自 MtF.wiki。

### 🏥 友善医疗名录
收录国内跨性别友善的内分泌科、精神科医生与就诊指南，支持筛选、收藏、自动同步更新。

### 📏 罩杯计算器 & 发育记录追踪
基于 MtF.wiki 大陆标准算法（胸围差 10cm=A，每 2.5cm 递进），5 项测量输入，自动计算 CN/US/EU 三地尺码。每次计算结果自动保存为发育记录，支持历史趋势回溯。所有数据纯本地持久化，绝不离开设备。
      |
### 🎨 SVG 图解资源库
跨性别主题 SVG 图标库（Noto/OpenMoji/Twemoji 三种风格），支持导出 PNG/JPEG/WEBP、分享、存相册。

---

## 🚀 快速使用

### Android
直接前往 [Releases 页面](https://github.com/Trans-Prism/Trans-Prism/releases) 下载最新 APK 安装。

### Windows / Linux / Web
```bash
git clone https://github.com/Trans-Prism/Trans-Prism.git
cd Trans-Prism
flutter pub get
flutter build windows   # Windows
flutter build linux     # Linux
flutter build web       # Web
```

### iOS / macOS
```bash
git clone https://github.com/Trans-Prism/Trans-Prism.git
cd Trans-Prism
flutter pub get
flutter build ios       # iOS（需自行签名）
flutter build macos     # macOS（需自行签名）
```
> ⚠️ 因成本问题暂不提供开发者签名，iOS/macOS 需自行自签名。

> **⚠️ 注意事项：** Windows / Linux / Web / iOS / macOS 平台因环境所限均未经过完整测试，可能存在 Bug。

### 鸿蒙 OS
暂无开发计划。可尝试使用「卓易通」等兼容层运行 Android APK。

---

## 🏗️ 架构速览

```
Trans_Prism (Flutter App) ←── Cloudflare R2 ──→ Trans-Prism-Builder (内容工厂)
     │                                               │
     │ 10 大功能模块                                   │ Python 工具链清洗 5 个上游
     │ 纯本地存储 (SharedPreferences)                  │ 编译 MkDocs Material 静态站点
     │ 三路 OTA: APK/Wiki/Tracker                      │ 封包 ZIP → GitHub Release → R2
```

详细架构决策参见 [`ARCHITECTURE_DECISIONS.md`](ARCHITECTURE_DECISIONS.md)，生态全貌参见 [`SYSTEM_MAP.md`](SYSTEM_MAP.md)。

---

## 🛠️ 技术栈

| 维度 | 方案 |
|------|------|
| 框架 | Flutter 3.x / Dart ≥3.4 |
| 状态管理 | 原生 `StatefulWidget` + `setState`（仅主题一处 ChangeNotifier） |
| 本地存储 | `SharedPreferences`（JSON Key-Value）+ 文件系统（离线包） |
| 网络 | `dio` + `http` + 自研 DoH 抗污染 |
| 路由 | 命令式 `Navigator.push`（无 go_router） |
| WebView | `webview_flutter` |
| 音频 | `record` + `pitch_detector_dart`（YIN 算法） |
| 通知 | `flutter_local_notifications` + `timezone` |
| 更新分发 | Cloudflare R2 边缘节点 `updates.55114514.xyz` |
| 本地服务器 | `shelf`（PK 模拟器内嵌 HttpServer） |

---

## 📄 License & 版权声明

本项目采用**代码、算法与内容分离**的复合授权模式：

1. **原创客户端代码** — [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0)
2. **PK 计算引擎**（衍生自 Oyama）— [MIT License](https://opensource.org/licenses/MIT)
3. **嗓音训练模块**（衍生自 VFS Tracker）— [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh)
4. **内置知识库文本** — [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/deed.zh) / [CC BY-ND 4.0](https://creativecommons.org/licenses/by-nd/4.0/)
5. **激素换算器及罩杯计算器** (衍生自MtF-wiki及网络公开资料) — [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/deed.zh) 

---

## 👨‍💻 开发者参考

| 想做什么 | 先去哪个文件 |
|----------|-------------|
| 改用药/提醒 | [`medication_service.dart`](lib/services/medication_service.dart:25) / [`notification_service.dart`](lib/services/notification_service.dart:14) |
| 改 PK 模拟 | [`tracker_screen.dart`](lib/screens/tracker_screen.dart:189)（⚠️ 算法在 WebView JS 中，非 Dart）|
| 改嗓音训练 | [`pitch_detection_service.dart`](lib/services/pitch_detection_service.dart:16) / `screens/voice_training/` |
| 改 Wiki 知识库 | [`wiki_sync_service.dart`](lib/services/wiki_sync_service.dart:37) / [`wiki_update_manager.dart`](lib/services/wiki_update_manager.dart:31) |
| 改医疗名录 | [`medical_directory_service.dart`](lib/services/medical_directory_service.dart:22) |
| 改激素换算 | [`hormone_converter_logic.dart`](lib/utils/hormone_converter_logic.dart:1)（纯函数）|
| 改罩杯计算 | [`bra_calculator.dart`](lib/services/bra_calculator.dart:1)（纯函数）/ [`bra_calculator_page.dart`](lib/screens/bra_calculator_page.dart:1)（UI）|
| 改主题 | [`theme_service.dart`](lib/services/theme_service.dart:7) |
| 改更新逻辑 | [`update_service.dart`](lib/services/update_service.dart:52) |
| 了解全貌 | [`REPO_MAP.md`](REPO_MAP.md)（AI Agent 导航）|

---

## 🤝 致谢

感谢 [Project Trans](https://project-trans.org/)（MtF/FtM/RLE Wiki）、[MioMtFWiki](https://github.com/KitsuMio/MioMtFWiki)、[Oyama-s-HRT-Recorder](https://github.com/SmirnovaOyama/Oyama-s-HRT-Tracker) 及 [HRT-Recorder-online](https://github.com/LaoZhong-Mihari/HRT-Recorder-online)、[VFS Tracker](https://github.com/Ethanlita/vfs-tracker) 等开源项目与社区。

---

> **⚠️ 医疗免责声明：** 本 App 所有功能仅供学术交流与数据可视化参考，**不能替代专业医生的诊断与处方**。调整激素剂量请务必在正规医生指导下进行。

---

## Star History

<a href="https://www.star-history.com/?type=date&repos=Trans-Prism%2FTrans-Prism">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=Trans-Prism/Trans-Prism&type=date&theme=dark&legend=top-left&sealed_token=Rac_fHrj8ACOWMqtsdR8LJdWDQTj36Zy7oql6OuWtVO84yJViDVTVTNwYdLxnF46HhM0oNseO49w8NHVh1krGhZAv_Y1Ay4sW-oU8vFX_7zdc5cUvQ0IDAvkBhGNCGKlOpmm09HpVB2O92_CCDJNezVI-ZwJ8acrUOxQ9nnPXSxBHGy2qoV1rhAEGl5U" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=Trans-Prism/Trans-Prism&type=date&legend=top-left&sealed_token=Rac_fHrj8ACOWMqtsdR8LJdWDQTj36Zy7oql6OuWtVO84yJViDVTVTNwYdLxnF46HhM0oNseO49w8NHVh1krGhZAv_Y1Ay4sW-oU8vFX_7zdc5cUvQ0IDAvkBhGNCGKlOpmm09HpVB2O92_CCDJNezVI-ZwJ8acrUOxQ9nnPXSxBHGy2qoV1rhAEGl5U" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=Trans-Prism/Trans-Prism&type=date&legend=top-left&sealed_token=Rac_fHrj8ACOWMqtsdR8LJdWDQTj36Zy7oql6OuWtVO84yJViDVTVTNwYdLxnF46HhM0oNseO49w8NHVh1krGhZAv_Y1Ay4sW-oU8vFX_7zdc5cUvQ0IDAvkBhGNCGKlOpmm09HpVB2O92_CCDJNezVI-ZwJ8acrUOxQ9nnPXSxBHGy2qoV1rhAEGl5U" />
 </picture>
</a>

*"May you find your steady state."*
