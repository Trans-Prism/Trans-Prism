
========================================================================
                    Trans Prism (稳态光盒) — 复合开源许可证
                    COMPOSITE OPEN SOURCE LICENSE
========================================================================

Trans Prism 项目采用「代码、算法与内容分离」的复合授权模式(Composite Licensing
Model)。不同组件适用不同的开源许可证，具体映射见下文「组件-许可证映射表」。

本文件构成整个项目的完整许可声明。使用、分发、修改本项目或其任何部分时，
您必须同时遵守本文件列出的所有适用许可证条款。

========================================================================
第 I 部分：组件-许可证映射表 (Component-License Mapping)
========================================================================

┌─────────────────────────────────────────────────────────────────────────────┐
│ 编号 │ 组件 / Component               │ 许可证 / License        │ 类别    │
├──────┼────────────────────────────────┼────────────────────────┼─────────┤
│  1   │ 原创客户端代码                  │ Apache License 2.0     │ 代码    │
│      │ (Flutter/Dart 源码, lib/)       │                        │         │
├──────┼────────────────────────────────┼────────────────────────┼─────────┤
│  2   │ PK 计算引擎                     │ MIT License            │ 算法    │
│      │ (PK Simulator, 衍生自 Oyama)   │                        │         │
├──────┼────────────────────────────────┼────────────────────────┼─────────┤
│  3   │ 嗓音训练模块                     │ CC BY-NC-SA 4.0       │ 代码    │
│      │ (Voice Training, 衍生自 VFS     │                        │ 算法    │
│      │  Tracker)                       │                        │         │
├──────┼────────────────────────────────┼────────────────────────┼─────────┤
│  4a  │ MtF.Wiki 知识库内容             │ CC BY-SA 4.0          │ 内容    │
│      │ (Project Trans 系)              │                        │         │
├──────┼────────────────────────────────┼────────────────────────┼─────────┤
│  4b  │ FtM.Wiki 知识库内容             │ CC BY-SA 4.0          │ 内容    │
│      │ (Project Trans 系)              │                        │         │
├──────┼────────────────────────────────┼────────────────────────┼─────────┤
│  4c  │ RLE.Wiki 知识库内容             │ CC BY-SA 4.0          │ 内容    │
│      │ (Project Trans 系)              │                        │         │
├──────┼────────────────────────────────┼────────────────────────┼─────────┤
│  4d  │ MioMtFWiki 知识库内容           │ CC BY-ND 4.0          │ 内容    │
│      │ (社区驱动项目)                   │                        │         │
├──────┼────────────────────────────────┼────────────────────────┼─────────┤
│  5   │ 激素换算器 & 罩杯计算器          │ CC BY-SA 4.0          │ 算法    │
│      │ (衍生自 MtF.wiki 及网络公开资料) │                        │ 内容    │
├──────┼────────────────────────────────┼────────────────────────┼─────────┤
│  6   │ SVG 图解资源库                   │ 各自保留               │ 资源    │
│      │ (Twemoji / OpenMoji /           │ (CC-BY / Apache 2.0   │         │
│      │  Noto Emoji 风格)              │  / SIL OFL 等)        │         │
├──────┼────────────────────────────────┼────────────────────────┼─────────┤
│  7   │ 2345.LGBT 导航页源码            │ LGPL-3.0              │ 代码    │
│      │ (衍生自 Project Trans)          │                        │         │
├──────┼────────────────────────────────┼────────────────────────┼─────────┤
│  8   │ Trans-Prism-Builder 流水线脚本  │ Apache License 2.0     │ 代码    │
│      │ (Python 工具链, CI Workflows)   │                        │         │
├──────┼────────────────────────────────┼────────────────────────┼─────────┤
│  9   │ 第三方 Dart/Flutter 依赖包       │ 各自许可               │ 依赖    │
│      │ (见 pubspec.yaml)               │ (MIT / BSD / Apache   │         │
│      │                                  │  等)                  │         │
└──────┴────────────────────────────────┴────────────────────────┴─────────┘

========================================================================
第 II 部分：各许可证全文与适用说明
========================================================================

--- II-A: Apache License 2.0（组件 1: 原创客户端代码）---

                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

   END OF TERMS AND CONDITIONS

   APPENDIX: How to apply the Apache License to your work.

      To apply the Apache License to your work, attach the following
      boilerplate notice, with the fields enclosed by brackets "[]"
      replaced with your own identifying information. (Don't include
      the brackets!)  The text should be enclosed in the appropriate
      comment syntax for the file format. We also recommend that a
      file or class name and description of purpose be included on the
      same "printed page" as the copyright notice for easier
      identification within third-party archives.

   Copyright [2025] [Trans Prism Contributors]

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.


--- II-B: MIT License（组件 2: PK 计算引擎）---

PK 计算引擎（PK Simulation Engine）衍生自 Oyama's HRT Recorder
(https://github.com/SmirnovaOyama/Oyama-s-HRT-Tracker) 及
HRT-Recorder-online (https://github.com/LaoZhong-Mihari/HRT-Recorder-online)，
遵循 MIT License：

MIT License

Copyright (c) [Oyama's HRT Recorder Contributors]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


--- II-C: Creative Commons Attribution-NonCommercial-ShareAlike 4.0
         International（组件 3: 嗓音训练模块）---

嗓音训练模块（Voice Training Module）衍生自 VFS Tracker
(https://github.com/Ethanlita/vfs-tracker)，遵循 CC BY-NC-SA 4.0。

本模块仅允许**非商业性使用**。您可以自由地共享、复制、重新发布本模块的
代码与算法，但必须满足以下条件：
  - 署名（Attribution）：必须标注原始作者与 VFS Tracker 项目链接。
  - 非商业性（NonCommercial）：不得将本模块或其衍生作品用于商业目的，
    包括但不限于将其置于付费墙之后、作为付费 App 的独占功能、或通过
    售卖本模块直接获利。
  - 相同方式共享（ShareAlike）：如果您对本模块进行修改、转换或构建，
    则必须使用相同的 CC BY-NC-SA 4.0 许可分发您的衍生作品。

完整许可证文本：https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode.zh-hans


--- II-D: Creative Commons Attribution-ShareAlike 4.0 International
         （组件 4a/4b/4c/5: Project Trans 系知识库内容与衍生算法）---

内置知识库中属于 Project Trans 系的内容（MtF.Wiki、FtM.Wiki、RLE.Wiki），
以及衍生自 MtF.wiki 及网络公开资料的激素换算器与罩杯计算器，遵循 CC BY-SA 4.0。

您可以自由地共享、复制、重新发布相关内容，但必须满足以下条件：
  - 署名（Attribution）：必须标注原始来源为 Project Trans 及对应的 Wiki 项目，
    并提供指向原项目的链接。
  - 相同方式共享（ShareAlike）：如果您对内容进行修改、转换或构建，
    则必须使用相同的 CC BY-SA 4.0 许可分发您的衍生作品。

完整许可证文本：https://creativecommons.org/licenses/by-sa/4.0/legalcode.zh-hans


--- II-E: Creative Commons Attribution-NoDerivatives 4.0 International
         （组件 4d: MioMtFWiki 知识库内容）---

内置知识库中属于 MioMtFWiki (社区驱动的跨性别知识项目) 的内容遵循
CC BY-ND 4.0（署名—禁止演绎 4.0 协议国际版）。

允许的操作：
  ✓ 转载、镜像、离线打包和重新分发
  ✓ 转换格式、建立索引、全文搜索、响应式排版等技术性处理
  ✓ 在应用程序中集成和展示
  ✓ 商业传播

禁止的操作：
  ✗ 修改、删减、重写或翻译后再次发布项目内容

署名要求：
  使用时须保留来源信息、标明 MioMtFWiki 项目链接并保留协议声明。

完整许可证文本：https://creativecommons.org/licenses/by-nd/4.0/legalcode.zh-hans


--- II-F: SVG 资源库许可说明（组件 6）---

SVG 图解资源库中的图标素材来源于以下三个开源项目，各自保留其原始许可：

  1. Noto Emoji       → Apache License 2.0
  2. OpenMoji         → CC BY-SA 4.0
  3. Twemoji          → CC-BY 4.0

具体图标归属详见 assets/resource_metadata.json。


--- II-G: 第三方依赖许可说明（组件 9）---

Trans Prism 使用的大量第三方 Dart/Flutter 依赖包（详见 pubspec.yaml）
各自遵循其原始许可协议（MIT、BSD、Apache 2.0 等）。本项目的原创代码
不改变这些第三方组件的许可条款。


========================================================================
第 III 部分：特别声明与注意事项
========================================================================

--- III-A: 商业使用提醒 ---

本项目整体采用复合许可模式。如果您计划将本项目或其部分用于商业用途
（包括但不限于：将本软件或其功能置于付费墙之后、在商业产品中集成使用、
或基于本项目提供商业服务），请务必注意：

  • 原创客户端代码（Apache 2.0）允许商业使用，无需额外授权。
  • 嗓音训练模块（CC BY-NC-SA 4.0）**禁止**商业使用。
  • Project Trans 系知识库内容（CC BY-SA 4.0）允许商业使用，
    但须以相同方式共享。
  • MioMtFWiki 内容（CC BY-ND 4.0）允许商业传播，但**禁止**修改后发布。
  • SVGs 图标资源须遵循各自原始许可的商业使用条款。

**您有责任自行评估并遵守所有适用的上游许可条款。**

--- III-B: 医疗免责声明 ---

本 App 所有功能仅供学术交流与数据可视化参考，**不能替代专业医生的诊断
与处方**。调整激素剂量请务必在正规医生指导下进行。项目的贡献者和版权
持有者不对因使用本软件导致的任何健康损害承担责任。

--- III-C: 贡献者须知 ---

任何向 Trans Prism 项目提交的贡献（包括但不限于代码提交、Pull Request、
问题反馈中的代码片段），若涉及原创客户端代码部分，将被视为同意以
Apache License 2.0 条款提交。若贡献涉及其他许可组件，须确保您有权
按该组件的许可条款提交。

--- III-D: 商标声明 ---

"Trans Prism" 名称与项目标识（Logo）不属于开源许可的授权范围。
在合理描述项目出处之外使用这些商标，需获得项目维护者的明确许可。

--- III-E: 上游项目致谢 ---

本项目建立在以下开源项目的基础上，特此致谢：

  • Project Trans — MtF.Wiki, FtM.Wiki, RLE.Wiki (CC BY-SA 4.0 / LGPL-3.0)
  • KitsuMio — MioMtFWiki (CC BY-ND 4.0)
  • SmirnovaOyama — Oyama's HRT Recorder (MIT)
  • LaoZhong-Mihari — HRT-Recorder-online (MIT)
  • Ethanlita — VFS Tracker (CC BY-NC-SA 4.0)
  • Twitter/Twemoji, OpenMoji, Google/Noto Emoji (SVG 图标来源)


========================================================================
第 IV 部分：许可选择流程图（快速参考）
========================================================================

您想对 Trans Prism 进行什么操作？
                
    ├── 使用/运行 App
    │     └── ✅ 无需额外授权，直接使用
    │
    ├── 修改原创 Flutter/Dart 代码
    │     └── ✅ Apache 2.0 — 可修改，须标注变更
    │
    ├── 修改嗓音训练模块
    │     └── ⚠️ CC BY-NC-SA — 非商业 + 署名 + 相同方式共享
    │
    ├── 打包/分发完整 App
    │     └── ✅ 可分发，须附本 LICENSE 全文
    │
    ├── 将 App 置于付费墙销售
    │     ├── ✔️ 原创代码部分：允许
    │     ├── ❌ 嗓音训练模块：禁止
    │     └── ⚠️ 知识库内容：须遵守各自 CC 许可
    │
    ├── 修改知识库内容后再次分发
    │     ├── ⚠️ Project Trans 系：CC BY-SA（须相同方式共享）
    │     ├── ❌ MioMtFWiki：禁止修改后发布（CC BY-ND）
    │     └── ⚠️ 激素换算器/罩杯计算器：CC BY-SA
    │
    └── 提取 SVG 图标用于其他项目
          └── ✅ 遵照各自原始许可（Apache 2.0 / CC BY-SA 4.0 / CC-BY 4.0）


========================================================================
第 V 部分：附录 — 许可全文链接
========================================================================

  • Apache License 2.0        → https://www.apache.org/licenses/LICENSE-2.0
  • MIT License               → https://opensource.org/licenses/MIT
  • CC BY-SA 4.0              → https://creativecommons.org/licenses/by-sa/4.0/legalcode.zh-hans
  • CC BY-ND 4.0              → https://creativecommons.org/licenses/by-nd/4.0/legalcode.zh-hans
  • CC BY-NC-SA 4.0           → https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode.zh-hans
  • LGPL-3.0                  → https://www.gnu.org/licenses/lgpl-3.0.html

---

*May you find your steady state.*
