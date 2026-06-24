<div align="center">
  
  <img src="docs/logo.svg" width="160" alt="Trans Prism Logo">

# Trans Prism (TP) 🌈

**专为跨性别群体（Transgender）打造的极简、安全、双擎驱动的实用工具箱**

  <p>
    <a href="https://github.com/daanser/Trans-Prism/stargazers"><img src="https://img.shields.io/github/stars/daanser/Trans-Prism.svg?style=social&label=Star" alt="GitHub stars"></a>
    <a href="https://github.com/daanser/Trans-Prism/network/members"><img src="https://img.shields.io/github/forks/daanser/Trans-Prism.svg?style=social&label=Fork" alt="GitHub forks"></a>
  </p>
  <p>
    <a href="https://flutter.dev/"><img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter"></a>
    <a href="https://www.apache.org/licenses/LICENSE-2.0"><img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" alt="License: Apache 2.0"></a>
    <a href="http://makeapullrequest.com"><img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg" alt="PRs Welcome"></a>
    <a href="TODO.md"><img src="https://img.shields.io/badge/📋-TODO%20List-ff69b4" alt="TODO List"></a>
  </p>

</div>

---

## 📖 关于项目 (About)

**Trans Prism (稳态光盒)** 是一款致力于为跨性别群体提供安全、客观、无审查的日常辅助工具的开源 App。

在信息获取日益困难、医疗资源分配不均的当下，TP 旨在成为一个"装在口袋里的庇护所"。它采用了独特的**在线/离线双擎架构**与**纯本地物理持久化**策略，确保你的核心知识库和极其隐私的生理数据不依赖于任何第三方服务器，永远牢牢掌握在自己手中。

> ** Created via Deepseek, Gemini, Claude Vibe Coding ** (Sorted by usage rate)

---

## ✨ 核心功能 (Features)

### 📚 双擎动态知识库 (Dual-Engine Wiki)
* **无缝集成四大开源指南**：MtF.wiki, FtM.wiki, RLE.wiki, MioMtFWiki。
* **默认轻量在线模式**：App 安装包极致精简（~25MB），默认采用零缓存直连加载，不占手机空间。
* **硬核 OTA 离线引擎**：支持按需一键下载离线包。通过监听 GitHub Releases API 触发静默热更新，将云端编译的 `.zip` 静态站点拉取至本地沙盒，实现断网环境下的完美秒开。
* **动态阅后即焚**：退出离线模式时提供可选的缓存清理机制，彻底告别数百 MB 的缓存爆炸，把空间选择权交还给用户。

### 💊 药物存量仪表盘 & 智能调度提醒
* **全景追踪**：追踪 HRT 药物库存存量与安全续航天数，提供直观的量化面板。
* **Chronos 智能调度引擎**：支持小时、天、周、月四种给药周期——从口服（12h）、外用凝胶到针剂（7天）、GnRHa（28天/84天）全覆盖。
* **绝对锚点系统**：基于绝对时间戳精准注册本地 OS 级别通知，即便长效药物也永不错过。
* **闭环推算**：点击"已服药"自动扣减库存、推算下一次给药时间并重设系统闹钟。数据采用纯本地 JSON持久化，极致隐私。

### 📈 药代动力学 (PK) 模拟器
* **算法与模型引用**：内置严谨的一室/多室指数衰减算法与多剂量叠加模型，**核心算法与药代动力学数据模型源码衍生自开源项目 [Oyama-s-HRT-Recorder](https://github.com/SmirnovaOyama/Oyama-s-HRT-Tracker) 及 [HRT-Recorder-online](https://github.com/LaoZhong-Mihari/HRT-Recorder-online) (MIT License)**。
* **浓度曲线可视化**：支持模拟常见 HRT 药物（如雌二醇、CPA、螺内酯代谢物等）的稳态血药浓度曲线。
* **药理科普**：帮助用户直观理解给药间隔、半衰期与体内浓度波动的数学关系。

### 🔄 激素换算器
* 数据直接衍生自 [MtF-wiki](https://github.com/project-trans/Next-MtF-wiki) (CC BY-SA 4.0)。
* **6 项核心激素双向换算**：雌二醇（E2）、睾酮（T）、泌乳素（PRL）、孕酮（P4）、FSH、LH。
* 支持质量浓度与摩尔浓度的智能单位切换，自动过滤无逻辑的等价单位。

### 🎙️ 声音训练辅助
* **声音组件集成**：基于开源项目 [VFS Tracker](https://github.com/Ethanlita/vfs-tracker) 进行适配、跨端渲染优化与体验集成。
* **全套练习流**：包含嗓音测试、音阶练习、88键钢琴、F0检测、主观量表与鼓励机制。
* **本地分析**：生成本地音频分析报告与训练记录时间线。

### 🏥 友善医疗名录（待开发）
* 收录国内跨性别友善的内分泌科、精神科医生与就诊指南。

### 📋 开发路线图 (Roadmap)
查看项目详细的开发计划与待办事项，请参阅 [`TODO.md`](TODO.md)。

---

## 🚀 快速使用 (Quick Start)

### Android
直接前往 [Releases 页面](https://github.com/Trans-Prism/Trans-Prism/releases) 下载最新 APK 安装包即可使用。

### Windows / Linux / Web
```bash
# 克隆仓库
git clone https://github.com/Trans-Prism/Trans-Prism.git
cd Trans-Prism

# 获取依赖
flutter pub get

# Windows / Linux 桌面端
flutter build windows   # Windows
flutter build linux     # Linux

# Web 端
flutter build web
```

### iOS / macOS
```bash
# 克隆仓库
git clone https://github.com/Trans-Prism/Trans-Prism.git
cd Trans-Prism
flutter pub get

# 构建后需自行签名
flutter build ios       # iOS
flutter build macos     # macOS
```
> ⚠️ 因成本问题，暂不提供开发者签名，iOS/macOS 用户需自行进行自签名后方可安装使用。

> **⚠️ 注意事项：** Windows、Linux、Web、iOS、macOS 平台因环境所限均未经过完整测试，可能存在意想不到的 Bug，请酌情使用。

### 鸿蒙 OS (HarmonyOS)
暂无开发计划。鸿蒙用户可尝试使用「卓易通」等兼容层运行 Android 版本 APK。

---

## 🏗️ 核心架构 (Architecture)

本项目除了 Flutter 客户端，还包含一套高度自动化的云端流水线[Trans-Prism-Builder](https://github.com/daanser/Trans-Prism-Builder)：
* **Mono-repo CI/CD**：通过 GitHub Actions 每日定时监听上游 Wiki 仓库。
* **Python 语法清洗器**：自动拉取上游 Markdown 源码，拦截并洗稿 Hugo / VitePress 专属语法，重构为标准 MkDocs 格式。
* **无头构建与分发**：云端全自动编译 HTML 静态站点，压缩打包并发布至 Release，为客户端提供源源不断的热更新数据流。

---

## 🛠️ 本地构建与运行 (Build & Run)

本项目使用 [Flutter](https://flutter.dev) 框架构建，支持 Android / iOS / MacOS / Windows / Web 等多端运行。
构建见上方**🚀 快速使用 (Quick Start)**Part。



---

## ⚖️ 医疗免责声明 (Medical Disclaimer)

**⚠️ 极度重要：使用本软件前请务必仔细阅读此声明。**

1. **非医疗建议：** 本应用提供的所有功能、文本、图表及**尤其是"PK 血药浓度模拟器"得出的任何计算结果，均仅供学术交流与数据可视化参考。** 它**绝对不能**替代专业内分泌科医生的诊断、处方或临床医学检验。
2. **个体差异：** 药代动力学算法中的常量取自开源社区经验值与公开医学文献的平均水平。**每个人的肝肾代谢酶活性、体重、吸收率存在极其巨大的个体差异。** 模拟器画出的完美曲线，绝不代表您体内的真实浓度。
3. **责任豁免：** 本项目的开发者、贡献者不对用户依据本应用提供的数据进行的任何"自我药疗（DIY HRT）"行为及其产生的任何生理、心理后果承担任何形式的法律和医疗责任。
4. **遵医嘱：** 调整激素剂量是一项严肃的医疗行为，请务必在正规医生的指导下并结合实际的血液化验化验单进行。

---

## 🤝 开源与致谢 (Acknowledgments)

本项目秉承"属于社群，回馈社群"的开源精神。特别致谢以下组织与项目：

* 感谢 **[Project Trans](https://project-trans.org/)** 及其维护的 **MtF.wiki / FtM.wiki / RLE.wiki** 团队，为中文性别多元社群提供了极其宝贵的开源知识库。
* 感谢 **[MioMtFWiki](https://github.com/KitsuMio/MioMtFWiki)** 项目及社区贡献者，为社群提供了贴近当下、实时滚动的跨性别参考站。
* 感谢 **[Oyama-s-HRT-Recorder](https://github.com/SmirnovaOyama/Oyama-s-HRT-Tracker) 及 [HRT-Recorder-online](https://github.com/LaoZhong-Mihari/HRT-Recorder-online)** 开源项目作者，为 PK 模拟器的核心底层算法与多剂量叠加模型提供了坚实、优秀的数学及代码实现基础。
* 感谢 **[TransFeminine Science](https://transfemscience.org/)** 等开源社区前辈在药代动力学算法领域的卓越贡献，为 PK 核心引擎提供了坚实的数学理论支持。
* 感谢 **[VFS Tracker](https://github.com/Ethanlita/vfs-tracker)** 开源项目及作者，声音训练模块的音频分析与功能流程参考并继承自该项目。
* 感谢所有为跨性别生存与医疗权益发声的勇敢者。

---

## 📄 许可证 (License) & 版权声明

本项目属于开源聚合体（Collection）。为了充分尊重上游开源社区的劳动成果，并确保本软件原创核心逻辑的安全，本项目针对不同模块采用**代码、算法与内容分离**的复合授权模式：

1. **📦 软件原创客户端代码 (App Original Source Code)：**
本项目由原创开发完成的客户端框架、UI 交互界面、本地持久化逻辑及云端自动化流水线（脚本），采用 **[Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0)** 协议授权。
2. **📈 药代动力学计算引擎 (PK Core Engine)：**
衍生及参考自 [Oyama-s-HRT-Recorder](https://github.com/SmirnovaOyama/Oyama-s-HRT-Tracker) 及 [HRT-Recorder-online](https://github.com/LaoZhong-Mihari/HRT-Recorder-online) 的药代计算核心算法源码，其版权归原作者所有，严格遵循 **[MIT License](https://opensource.org/licenses/MIT)** 授权。
3. **🎙️ 声音训练模块核心逻辑 (Voice Training Module)：**
集成、适配及优化自 [VFS Tracker](https://github.com/Ethanlita/vfs-tracker) 的嗓音训练相关逻辑，严格遵循 **[CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh)**（署名-非商业性使用-相同方式共享 4.0 国际公共许可证）协议授权。
4. **📚 内置知识库文本数据 (Wiki Content Data)：**
本项目内嵌及在线拉取的各指南文本数据，其原始版权分别归属于 [Project Trans](https://project-trans.org/) 及其团队（采用 **[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/deed.zh)** 协议）和 [MioMtFWiki](https://github.com/KitsuMio/MioMtFWiki) 及其社区贡献者（采用 **[CC BY-ND 4.0](https://creativecommons.org/licenses/by-nd/4.0/)** 协议）。本项目严格遵循上述协议，不对该部分数据增加任何额外限制。

---

*"May you find your steady state."*
