```markdown
<div align="center">
  
  <img src="docs/logo.svg" width="160" alt="Trans Prism Logo">

# Trans Prism (TP) 🌈

**专为跨性别群体（Transgender）打造的离线优先、极简开源实用工具箱**

  <p>
    <a href="https://github.com/daanser/Trans-Prism/stargazers"><img src="https://img.shields.io/github/stars/daanser/Trans-Prism.svg?style=social&label=Star" alt="GitHub stars"></a>
    <a href="https://github.com/daanser/Trans-Prism/network/members"><img src="https://img.shields.io/github/forks/daanser/Trans-Prism.svg?style=social&label=Fork" alt="GitHub forks"></a>
  </p>
  <p>
    <a href="https://flutter.dev/"><img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter"></a>
    <a href="https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh"><img src="https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg" alt="License: CC BY-NC-SA 4.0"></a>
    <a href="http://makeapullrequest.com"><img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg" alt="PRs Welcome"></a>
  </p>

</div>

---

## 📖 关于项目 (About)

**Trans Prism (稳态光盒)** 是一款致力于为跨性别群体提供安全、客观、无审查的日常辅助工具的开源 App。

在信息获取日益困难、医疗资源分配不均的当下，TP 旨在成为一个“装在口袋里的庇护所”。它完全支持**离线运行**，确保你的核心知识和生理数据不依赖于任何云端服务器，永远掌握在自己手中。

## ✨ 核心功能 (Features)

* 📈 **药代动力学 (PK) 模拟器**
  * 内置严谨的一室/多室指数衰减算法与多剂量叠加模型（Analytical Solution）。
  * 支持模拟常见 HRT 药物（如雌二醇、CPA、螺内酯代谢物等）的稳态血药浓度曲线。
  * 帮助用户直观理解给药间隔与体内浓度波动的关系。

* 📚 **离线知识库 (Wiki)**
  * 内嵌精编版 MtF/FtM 生存指南与 HRT 基础知识。
  * 纯本地化存储，抗网络审查，断网环境下依然可以随时查阅。

* 🎙️ **声音训练辅助（待开发）**
  * 提供实时的基频 (Pitch) 与共振峰 (Formant) 分析，辅助跨性别嗓音训练。

* 🏥 **友善医疗名录（待开发）**
  * 收录国内跨性别友善的内分泌科、精神科医生与就诊指南。

## 🛠️ 本地构建与运行 (Build & Run)

本项目使用 [Flutter](https://flutter.dev) 框架构建，支持 Android / iOS / Web 多端运行。

```bash
# 1. 克隆本仓库到本地
git clone [https://github.com/daanser/Trans-Prism.git](https://github.com/daanser/Trans-Prism.git)

# 2. 进入项目目录
cd trans-prism

# 3. 获取所有依赖包
flutter pub get

# 4. 在连接的设备或模拟器上运行
flutter run

```

## ⚖️ 医疗免责声明 (Medical Disclaimer)

**⚠️ 极度重要：使用本软件前请务必仔细阅读此声明。**

1. **非医疗建议：** 本应用（Trans Prism）提供的所有功能、文本、图表及**尤其是“血药浓度模拟器”得出的任何计算结果，均仅供学术交流与数据可视化参考。** 它**绝对不能**替代专业内分泌科医生的诊断、处方或临床医学检验（抽血化验）。
2. **个体差异：** 药代动力学（PK）算法中的常量（如半衰期、表观分布容积、达峰时间等）取自开源社区经验值与公开医学文献的平均水平。**每个人的肝肾代谢酶活性、体重、吸收率存在极其巨大的个体差异。** 模拟器画出的完美曲线，绝不代表您体内的真实浓度。
3. **责任豁免：** 本项目的开发者、贡献者不对用户依据本应用提供的数据进行的任何“自我药疗（DIY HRT）”行为及其产生的任何生理、心理后果承担任何形式的法律和医疗责任。
4. **遵医嘱：** 调整激素剂量是一项严肃的医疗行为，请务必在正规医生的指导下并结合实际的血液激素水平化验结果进行。

## 🤝 开源与致谢 (Acknowledgments)

本项目秉承“属于社群，回馈社群”的开源精神。特别致谢以下组织与项目：

* 感谢 **[Project Trans](https://project-trans.org/)** 及 **[MtF.wiki](https://mtf.wiki/)** 团队，为中文跨性别社群提供了极其宝贵的开源知识库和精神指引。本项目的 Wiki 模块理念离不开他们的卓越工作与前人栽树。
* 感谢 **[TransFeminine Science](https://transfemscience.org/)** 及开源社区的前辈们在药代动力学算法领域的卓越贡献和开源代码（如 HRT-Recorder），为本项目的 PK 核心引擎提供了坚实的数学基础。
* 感谢所有为跨性别生存与医疗权益发声的勇敢者。

## 📄 许可证 (License)

本项目采用 [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh)（署名-非商业性使用-相同方式共享 4.0 国际）协议开源。

这意味着你可以自由地共享、修改和分发本项目的代码与内容，但**绝对不允许用于任何商业盈利目的（禁止售卖）**，并且任何基于本项目的衍生作品都必须采用相同的开源协议发布。

---

*“May you find your steady state.”*

```

```