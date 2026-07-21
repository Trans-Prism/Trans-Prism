# Trans Prism · 液态玻璃（Liquid Glass）主题重构计划 v2

> 状态：**规划阶段**（待用户确认后进入实现）
> 前序文档：[`LIQUID_GLASS_PLAN.md`](LIQUID_GLASS_PLAN.md:1)（v1，原生 `BackdropFilter` 方案，已落地但效果与可用性不达标）
> 关联技能：Apple Liquid Glass（WWDC *Designing Fluid Interfaces* §12 Materials & depth / §14 无障碍）
> 架构约束：✅ 纯 `StatefulWidget` + `setState` / `ListenableBuilder`　✅ 无 Riverpod　✅ 无 SQLite
> 本次变更：⚠️ **引入 UI 渲染类第三方包**（用户明确要求，需更新 ADR-010）

---

## 0. 现状诊断：为什么当前方案"效果不好且无法正常使用"

当前液态玻璃实现（v1）完全基于 Flutter 原生 `BackdropFilter` + `ImageFilter.blur` + 手写 `CustomPaint` 色散边缘，分布在 6 个组件中：

| 组件 | 文件 | 渲染结构问题 |
|---|---|---|
| [`GlassCard`](Trans-Prism/lib/widgets/glass_card.dart:102) | `glass_card.dart` | `Stack` 内 **6 层 `Positioned.fill`** 叠加：BackdropFilter → ColoredBox → 光泽渐变 → 色散 CustomPaint → 高光边 Border → 内容。每层 `Positioned.fill` 在 `StackFit.loose` 下与内容层高度解耦，**导致 Stack 高度塌陷/溢出**（"无法正常使用"的根因之一） |
| [`GlassNav`](Trans-Prism/lib/widgets/glass_nav.dart:68) | `glass_nav.dart` | 同样 7 层 Stack，`StackFit.passthrough` + 多个 `SizedBox.expand` 与导航内容高度计算冲突 |
| [`GlassAppBar`](Trans-Prism/lib/widgets/glass_app_bar.dart:69) | `glass_app_bar.dart` | `ClipRect`+`BackdropFilter` 包裹 `SafeArea`，模糊区域与状态栏安全区叠加错位 |
| [`GlassSheet`](Trans-Prism/lib/widgets/glass_sheet.dart:59) | `glass_sheet.dart` | 单层 BackdropFilter，但 `foregroundDecoration` 的顶部高光边与 `ClipRRect` 圆角不匹配 |
| [`GlassDialog`](Trans-Prism/lib/widgets/glass_dialog.dart:71) | `glass_dialog.dart` | 同 Sheet 问题 |
| [`GlassPill`](Trans-Prism/lib/widgets/glass_pill.dart:73) | `glass_pill.dart` | 相对最简单，问题最小 |

**根因总结：**

1. **渲染性能**：每个玻璃面 = 1 次 `BackdropFilter`（触发一次全屏 saveLayer）+ 1 次 `CustomPaint`（再触发一次 saveLayer）+ 多个 `DecoratedBox`。在 Skia 后端下，`BackdropFilter` 是已知最昂贵的操作之一，多个玻璃面同屏叠加直接掉帧。
2. **布局正确性**：`Stack` + `StackFit.loose` + `Positioned.fill` 装饰层 + 非 `Positioned` 内容层的组合，在内容高度由子节点决定时，装饰层 `Positioned.fill` 会铺满 Stack 实际尺寸，但 Stack 实际尺寸又依赖非 Positioned 内容层——**形成循环依赖**，导致高度计算异常（塌陷为 0 或溢出）。这是"根本无法正常使用"的核心。
3. **视觉 fidelity**：手写的色散边缘（`ChromaticEdgePainter` 用线性渐变 stroke 模拟）与真实 Apple Liquid Glass 的折射/法线贴图效果差距大；光泽渐变是静态的，无动态光照响应。
4. **Impeller 未显式启用**：[`AndroidManifest.xml`](Trans-Prism/android/app/src/main/AndroidManifest.xml:1) 无 `io.flutter.embedding.android.EnableImpeller` meta-data。虽然 Flutter 3.16+ 在 Android 默认开启 Impeller，但显式声明可避免被 OEM/旧引擎回退覆盖，且 Impeller 对 `BackdropFilter` 有原生优化。

---

## 1. 重构目标

1. **可用性**：彻底消除 Stack 高度塌陷/溢出问题，所有玻璃组件在任何内容尺寸下正确布局
2. **视觉效果**：达到接近 Apple WWDC25 Liquid Glass 的折射/光泽/边缘高光质感
3. **性能**：搭配 Impeller，玻璃面在主流机型 60fps 稳定；低端机自动降级
4. **架构不变**：保留"双模自适应"设计（minimal 退化 / liquid 玻璃），保留 [`GlassTokens`](Trans-Prism/lib/theme/glass_tokens.dart:1)/[`GlassTheme`](Trans-Prism/lib/theme/glass_theme.dart:1) Token 体系，业务页调用点零改动
5. **严守红线**：无 Riverpod、无 SQLite（UI 渲染包不触碰这两条）

---

## 2. 包选型评估与推荐

用户提名的 5 个包按"渲染层级"从低到高排列：

| 包 | 渲染层级 | 特点 | Impeller 友好度 | 适配本项目 |
|---|---|---|---|---|
| `liquid_glass_renderer` | **底层**（CustomPainter/Shader） | 直接控制绘制管线，单次绘制合成玻璃材质，无多层 BackdropFilter 堆叠 | ⭐⭐⭐⭐⭐ 最高（可走 Impeller shader 路径） | ✅ **首选**：解决性能+布局双痛点 |
| `liquid_glass_widgets` | 中层（封装 renderer 为 Widget） | 开箱即用玻璃 Widget，API 接近 Material | ⭐⭐⭐⭐ 高 | ✅ **配套**：直接替换自研 GlassXxx |
| `liquid_glass_easy` | 高层（极简 API） | 一行代码玻璃化，封装最厚 | ⭐⭐⭐ 中 | ⚠️ 备选：定制空间小 |
| `flutter_liquid_glass_plus` | 中高层（功能丰富） | 含动态光照、法线贴图、更多预设 | ⭐⭐⭐⭐ 高 | ✅ **增强**：需要更丰富效果时引入 |
| `flutter_glass_morphism` | 高层（morphism 风格） | 偏 Web glassmorphism，渐变+模糊为主 | ⭐⭐⭐ 中 | ⚠️ 备选：风格偏 Web 非 Apple |

### 推荐策略：分层引入

```
liquid_glass_renderer   ← 地基：底层渲染器，替代手写 BackdropFilter+CustomPaint
        │
        ▼
liquid_glass_widgets    ← 组件：用 renderer 封装的标准玻璃 Widget，替代自研 GlassXxx 内部实现
        │
        ▼（按需）
flutter_liquid_glass_plus ← 增强：动态光照/法线贴图等高级效果（可选，二期）
```

**核心原则**：`GlassTokens`/`GlassTheme`/`GlassXxx` 对外 API **保持不变**，仅替换其内部 `build()` 的渲染实现——从"手写 Stack+BackdropFilter"切换为"调用 `liquid_glass_renderer`/`liquid_glass_widgets` 的原语"。这样业务页调用点（`GlassCard`/`GlassNav` 等）零改动，"双模自适应"逻辑（`isEnabled` 分支）保留。

> ⚠️ 实现前需在 pub.dev 核实各包的最新版本号、Flutter SDK 兼容性（要求 `>=3.4.0`）、是否纯 Dart（无原生插件，避免拖大包体违背 ADR-001 精简原则）。若某包含原生插件或已停维，回退到下一备选。

---

## 3. Impeller 渲染引擎适配

### 3.1 显式启用 Impeller（Android）

在 [`AndroidManifest.xml`](Trans-Prism/android/app/src/main/AndroidManifest.xml:22) 的 `<application>` 内追加：

```xml
<meta-data
    android:name="io.flutter.embedding.android.EnableImpeller"
    android:value="true" />
```

- iOS 端 Flutter 3.10+ 已默认 Impeller，无需配置
- 显式声明确保不被 OEM 旧设备回退到 Skia
- Impeller 对 `BackdropFilter` 有预编译着色器优化，是本次性能提升的关键

### 3.2 渲染层适配要点

- `liquid_glass_renderer` 若基于 `CustomPainter` + `ImageFilter`，在 Impeller 下走 GPU 着色器路径，避免 Skia 的 saveLayer 开销
- 大表面玻璃（AppBar/Nav/Sheet）外层包 `RepaintBoundary`，隔离重绘区域
- 避免在玻璃面内再嵌套玻璃面（§12 不叠轻材质于轻材质）——此规则已在 v1 内建，保留

---

## 4. 总体架构（重构后）

```
ThemeService.themeStyle: 'minimal' | 'liquid'
        │
        ▼
MaterialApp( theme/darkTheme 按 style 分支 )   ← 不变
        │
        ▼
GlassTheme( InheritedWidget, 暴露 GlassTokens )  ← 不变
        │
        ▼
GlassCard / GlassAppBar / GlassNav / GlassSheet / GlassDialog / GlassPill
   │  对外 API 不变（双模自适应：minimal 退化 / liquid 玻璃）
   │
   └─ 内部 build() 实现：
        minimal → 实心 Container（不变）
        liquid  → liquid_glass_widgets 的玻璃原语   ← 【本次替换点】
                  （由 liquid_glass_renderer 底层驱动）
```

**改动收敛**：仅替换 6 个 `GlassXxx` 组件的 `liquid` 分支内部实现 + `pubspec.yaml` 加依赖 + `AndroidManifest` 启用 Impeller。`GlassTokens` 字段可能微调（去掉手写色散/光泽字段，改由包的参数接管），但 `GlassTheme.of()` 访问方式不变。

---

## 5. 实施分层与任务清单

### 阶段 A · 依赖引入与 Impeller 启用（地基）

- [ ] **A1** 核实包：在 pub.dev 确认 `liquid_glass_renderer` / `liquid_glass_widgets` 的最新版本、SDK 兼容、是否纯 Dart
- [ ] **A2** [`pubspec.yaml`](Trans-Prism/pubspec.yaml:10) `dependencies` 段追加两个包（若 `flutter_liquid_glass_plus` 二期再引）
- [ ] **A3** `flutter pub get` 验证解析无冲突
- [ ] **A4** [`AndroidManifest.xml`](Trans-Prism/android/app/src/main/AndroidManifest.xml:22) 追加 `EnableImpeller` meta-data
- [ ] **A5** 确认 `android/build.gradle` 的 `minSdkVersion` 满足 Impeller 要求（Impeller Android 需 minSdk 21+，当前项目应已满足，需核实）

### 阶段 B · GlassTokens 精简与适配

- [ ] **B1** 审查 [`GlassTokens`](Trans-Prism/lib/theme/glass_tokens.dart:1)：标记哪些字段改由包接管（`chromaticEdgeColors`/`sheenGradient`/`saturationBoost` 可能被包的内置效果替代），保留 `blurSigma`/`surfaceColor`/`borderRadius`/`shadowColor` 等通用字段作为传给包的参数
- [ ] **B2** 保留 `minimalLight`/`minimalDark`/`liquidLight`/`liquidDark` 四预设与 `toReducedTransparency()` 降级（§14 无障碍不变）
- [ ] **B3** `GlassTheme` InheritedWidget 不动

### 阶段 C · 玻璃组件内部实现替换（核心）

逐个替换 6 个 `GlassXxx` 的 `liquid` 分支，**对外构造参数与 minimal 分支不变**：

- [ ] **C1** [`GlassCard`](Trans-Prism/lib/widgets/glass_card.dart:102)：删除 6 层 Stack+BackdropFilter+ChromaticEdgePainter，改为调用 `liquid_glass_widgets` 的玻璃容器原语，传入 tokens 的 blur/surface/radius/shadow
- [ ] **C2** [`GlassNav`](Trans-Prism/lib/widgets/glass_nav.dart:68)：同样替换为包原语，保留浮动胶囊布局与选中项放大动画
- [ ] **C3** [`GlassAppBar`](Trans-Prism/lib/widgets/glass_app_bar.dart:69)：替换为包的玻璃 AppBar 原语，修复 SafeArea 与模糊区域叠加
- [ ] **C4** [`GlassSheet`](Trans-Prism/lib/widgets/glass_sheet.dart:59)：替换为包原语，修复圆角高光边
- [ ] **C5** [`GlassDialog`](Trans-Prism/lib/widgets/glass_dialog.dart:71)：同 Sheet
- [ ] **C6** [`GlassPill`](Trans-Prism/lib/widgets/glass_pill.dart:73)：替换为包的轻量玻璃原语
- [ ] **C7** 删除 [`ChromaticEdgePainter`](Trans-Prism/lib/widgets/glass_card.dart:187)（若包自带边缘效果）或保留为 fallback

### 阶段 D · 性能与重绘优化

- [ ] **D1** 大表面玻璃（AppBar/Nav/Sheet）外层加 `RepaintBoundary`
- [ ] **D2** 验证包的渲染在 Impeller 下走 GPU 着色器路径（无 saveLayer 堆叠）
- [ ] **D3** 低端机检测：`MediaQuery.accessibleNavigation` 或自定义性能探测触发降级（复用 `toReducedTransparency`）

### 阶段 E · 动效与手感（Apple 灵魂，保留 v1 设计）

- [ ] **E1** 玻璃面进入/退出：模糊半径 + scale 联动动画（§12 Materialize）——若包支持动画参数则用包，否则外层包 `AnimatedBuilder`
- [ ] **E2** 底部导航切换弹簧（damping 1.0 / response 0.3）+ 选中项放大
- [ ] **E3** 卡片按压 `onTapDown` 即时 scale 0.97（§1 Response）

### 阶段 F · 无障碍降级（§14 强制，保留 v1）

- [ ] **F1** `GlassTokens.toReducedTransparency()` 在包原语层生效：blur→0、surface 实心
- [ ] **F2** 动效降级：弹簧→短淡入

### 阶段 G · 验证与文档

- [ ] **G1** 亮/暗 × 简约/液态 四象限手动走查（首页、设置、弹层、对话框、导航）
- [ ] **G2** 性能：Impeller 下帧率抽测，对比 v1
- [ ] **G3** 更新 [`ARCHITECTURE_DECISIONS.md`](ARCHITECTURE_DECISIONS.md:262) ADR-010：记录"从零依赖改为引入 liquid_glass 渲染包 + 启用 Impeller"的决策变更
- [ ] **G4** 运行 `/upmap` 同步四件套

---

## 6. 文件改动清单（预估）

| 类型 | 路径 | 动作 |
|---|---|---|
| 修改 | [`pubspec.yaml`](Trans-Prism/pubspec.yaml:10) | 加 `liquid_glass_renderer` + `liquid_glass_widgets` 依赖 |
| 修改 | [`android/app/src/main/AndroidManifest.xml`](Trans-Prism/android/app/src/main/AndroidManifest.xml:22) | 启用 Impeller |
| 修改 | [`lib/theme/glass_tokens.dart`](Trans-Prism/lib/theme/glass_tokens.dart:1) | 精简/适配字段（包接管部分效果） |
| 修改 | [`lib/widgets/glass_card.dart`](Trans-Prism/lib/widgets/glass_card.dart:1) | 替换 liquid 分支内部实现 |
| 修改 | [`lib/widgets/glass_nav.dart`](Trans-Prism/lib/widgets/glass_nav.dart:1) | 同上 |
| 修改 | [`lib/widgets/glass_app_bar.dart`](Trans-Prism/lib/widgets/glass_app_bar.dart:1) | 同上 |
| 修改 | [`lib/widgets/glass_sheet.dart`](Trans-Prism/lib/widgets/glass_sheet.dart:1) | 同上 |
| 修改 | [`lib/widgets/glass_dialog.dart`](Trans-Prism/lib/widgets/glass_dialog.dart:1) | 同上 |
| 修改 | [`lib/widgets/glass_pill.dart`](Trans-Prism/lib/widgets/glass_pill.dart:1) | 同上 |
| 更新 | [`ARCHITECTURE_DECISIONS.md`](ARCHITECTURE_DECISIONS.md:262) | ADR-010 变更记录 |

**不改动**：`ThemeService`、`GlassTheme` InheritedWidget、`_buildLiquidXxxTheme` 主题函数、业务页调用点、业务逻辑、存储层。

---

## 7. 风险与对策

| 风险 | 对策 |
|---|---|
| 包含原生插件拖大包体（违背 ADR-001 精简） | A1 核实纯 Dart；若含原生，回退到下一备选包 |
| 包已停维/不兼容 Flutter 3.4 | A1 核实；准备 fallback 到 `flutter_glass_morphism` 或保留 v1 优化版 |
| 包的玻璃效果与 Apple 风格偏差大 | 优先 `liquid_glass_renderer`（底层可控）+ tokens 参数调校；二期引 `flutter_liquid_glass_plus` 增强 |
| Impeller 在个别旧机型崩溃 | 包 `RepaintBoundary` + 降级路径；必要时按 API level 条件回退 Skia |
| 简约风被意外污染 | "双模自适应"不变：minimal 分支完全不走包，保持实心 |
| ADR-010"零依赖"决策被推翻 | G3 显式记录决策变更与理由（用户要求 + 性能/可用性刚需） |

---

## 8. 验收标准

1. 液态玻璃模式下：AppBar / 底部导航 / 卡片 / 弹层 / 对话框均呈现包驱动的玻璃材质，**无高度塌陷/溢出**
2. 简约风模式下：所有界面与 v1 **像素级一致**（minimal 分支未动）
3. 亮色 / 暗色 × 简约 / 液态 四象限均可读、可交互
4. Impeller 显式启用，主流机型 60fps 稳定（对比 v1 帧率提升）
5. 开启系统"减少透明度"时玻璃面自动实心化（§14）
6. 无 Riverpod、无 SQLite
7. 安装包体积增幅可控（纯 Dart UI 包，无原生 .so）

---

## 9. 下一步

待用户确认本计划后，按 **A → B → C → D → E → F → G** 顺序实现。建议先做 A+B（依赖+Token），再用一个 demo 页验证包的渲染效果与 Impeller 表现，确认无误后批量替换 C。