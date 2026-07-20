# Trans Prism · 液态玻璃（Liquid Glass）主题开发计划

> 状态：**规划阶段**（待用户确认后进入实现）
> 关联技能：Apple Liquid Glass（WWDC *Designing Fluid Interfaces* + *Principles of Great Design* WWDC 2026）
> 架构约束：✅ 纯 `StatefulWidget` + `setState` / `ListenableBuilder`　✅ 无 Riverpod　✅ 无 SQLite　✅ 无新增依赖

---

## 0. 现状盘点（已完成调研）

| 维度 | 现状 | 结论 |
|---|---|---|
| 主题风格切换基础设施 | [`ThemeService.themeStyle`](Trans-Prism/lib/services/theme_service.dart:14) 已存在 `'minimal' \| 'liquid'`，已持久化 | ✅ 可直接复用 |
| "我的"→"主题风格"入口 | [`_showStyleSelectionSheet`](Trans-Prism/lib/main.dart:2516) 已实现，含"简约风/液态玻璃"两项 | ✅ 入口已就位 |
| 液态玻璃选项 | [`isDisabled: true`](Trans-Prism/lib/main.dart:2588) + `// TODO: Implement Liquid Glass` | ⚠️ 需解锁并接入 |
| 主题构建分支 | [`MaterialApp`](Trans-Prism/lib/main.dart:535) 始终调用 `_buildLightTheme`/`_buildDarkTheme`（简约风） | ❌ 需按 `themeStyle` 分支 |
| 模糊能力 | `BackdropFilter` + `ImageFilter.blur` 已在 3 处使用（[`main.dart:1222`](Trans-Prism/lib/main.dart:1222) 等） | ✅ 原生可用，零新增依赖 |
| 简约风完整性 | [`_buildLightTheme`](Trans-Prism/lib/main.dart:53) / [`_buildDarkTheme`](Trans-Prism/lib/main.dart:192) 为当前唯一主题 | ✅ 必须保持不动 |

**核心结论：本任务不是"从零搭建切换框架"，而是"实现被预留的 liquid 分支 + 玻璃组件库 + 接入既有切换入口"。**

---

## 1. 设计原则（源自 Apple 技能）

落地时严格遵循 Apple 技能中与"液态玻璃"直接相关的条款：

- **§12 Materials & depth** — 半透明材质作为浮动功能层，传达层级而非抢夺焦点
  - 导航栏/工具栏/Sheet 用 `backdrop-filter: blur()` + 半透明背景，内容在其下滚动
  - 材质重量编码层级：重材质分隔结构区，轻材质突出交互元素
  - **绝不把轻半透明面叠在另一个半透明面上**（可读性崩塌）
  - 大表面读起来应"更厚"：更强模糊 + 更深阴影
  - 滚动边缘效果替代硬分隔线（内容接触浮动 chrome 处用渐变蒙版淡出）
  - "材质化"而非单纯淡入：进入/退出时模糊半径与缩放一起动画
- **§14 无障碍** — 三路独立信号必须内建
  - `prefers-reduced-motion: reduce` → 弹簧/滑动改为短淡入
  - `prefers-reduced-transparency: reduce` → 玻璃面变实心（提高背景不透明度、去模糊）
  - `prefers-contrast: more` → 近实心背景 + 明确对比边框
- **§16 Simplicity — not minimalism** — 简约风（minimal）与液态玻璃（liquid）**并存且可切换**，不互相覆盖

---

## 2. 总体架构

```
ThemeService.themeStyle: 'minimal' | 'liquid'
        │
        ▼
MaterialApp(
  theme:        style=='minimal' ? _buildLightTheme(color) : _buildLiquidLightTheme(color),
  darkTheme:    style=='minimal' ? _buildDarkTheme(color)  : _buildLiquidDarkTheme(color),
)
        │
        ▼
GlassTheme.of(context)  ← InheritedWidget，暴露玻璃 Token（模糊半径/表面色/边框/阴影）
        │
        ▼
GlassCard / GlassAppBar / GlassNav / GlassSheet / GlassDialog  ← 复用组件库
        │
        ▼
各 Screen 按需用 GlassXxx 替换 Card/AppBar/Container（仅 liquid 风格生效；minimal 下自动降级为简约外观）
```

**关键设计：组件库"双模自适应"** —— `GlassCard` 等组件内部读取 `GlassTheme`，当 `themeStyle=='minimal'` 时退化为简约卡片（白底/无边框/柔弥散阴影），从而**无需改动各业务 Screen 的调用代码即可在两风格间切换**。这是把改动面收敛到最小的关键。

---

## 3. 实施分层与任务清单

### 阶段 A · 主题 Token 与构建分支（地基）

- [ ] **A1** 新建 [`lib/theme/glass_tokens.dart`](Trans-Prism/lib/theme/glass_tokens.dart:1)
  - `GlassTokens` 不可变类：`blurSigma`、`surfaceAlpha`、`borderAlpha`、`borderRadius`、`shadowColor`、`shadowBlur`、`highlightEdgeAlpha`（顶部高光边）
  - 亮/暗两套预设值（暗色玻璃更厚：更高 alpha、更深阴影）
  - 内建 `reducedTransparency` / `reducedContrast` 降级变体（实心化）
- [ ] **A2** 新建 [`lib/theme/glass_theme.dart`](Trans-Prism/lib/theme/glass_theme.dart:1)
  - `GlassTheme` InheritedWidget，挂载 `GlassTokens` + 当前是否启用玻璃（`isEnabled = themeStyle=='liquid'`）
  - `GlassTheme.of(context)` 静态访问；minimal 模式下返回"退化 Token"（blur=0、surface 实心）
- [ ] **A3** 在 [`main.dart`](Trans-Prism/lib/main.dart:528) 的 `MaterialApp` 上方注入 `GlassTheme`，按 `_themeService.themeStyle` 决定 Token
- [ ] **A4** 新增 `_buildLiquidLightTheme(color)` / `_buildLiquidDarkTheme(color)`
  - 复用简约风的 `textTheme`/`colorScheme`（保持品牌色与字体不变）
  - 差异点：`scaffoldBackgroundColor` 改为带轻微渐变/纹理的底（供玻璃透视）；`appBarTheme`/`navigationBarTheme`/`cardTheme`/`bottomSheetTheme`/`dialogTheme` 背景设为透明（由 GlassXxx 组件接管材质）
- [ ] **A5** `MaterialApp.theme`/`darkTheme` 按 `themeStyle` 三元分支

### 阶段 B · 玻璃组件库（核心交付物）

- [ ] **B1** `GlassCard`（[`lib/widgets/glass_card.dart`](Trans-Prism/lib/widgets/glass_card.dart:1)）
  - `ClipRRect` → `BackdropFilter(blur)` → 半透明 `Container` + 顶部 1px 高光边 + 柔弥散阴影
  - minimal 模式：退化为白底/`#24242C` 底、无边框、原弥散阴影（与现 [`cardTheme`](Trans-Prism/lib/main.dart:145) 一致）
  - 进入动画：模糊半径 0→target + scale 0.98→1（"材质化"而非淡入，§12）
- [ ] **B2** `GlassAppBar`（浮动半透明 AppBar）
  - 透明背景 + `BackdropFilter`；滚动时内容从其下透出
  - 底部边缘渐变蒙版（滚动边缘效果，§12）替代 1px 分隔线
- [ ] **B3** `GlassNav`（底部导航栏玻璃化）
  - 浮动胶囊形玻璃条，与屏幕底边留间距；选中项用品牌色 + 轻微放大（弹簧 damping 1.0 / response 0.3，§4）
- [ ] **B4** `GlassSheet`（BottomSheet 玻璃化）
  - 替代 [`_showStyleSelectionSheet`](Trans-Prism/lib/main.dart:2516) 等弹层的实心 `Container`
  - 拖拽条 + 顶部高光边 + 背景模糊
- [ ] **B5** `GlassDialog`（对话框玻璃化）
  - 用于 [`update_dialog.dart`](Trans-Prism/lib/widgets/update_dialog.dart:1) 等弹窗
- [ ] **B6** `GlassPill` / `GlassChip`（小尺寸玻璃胶囊，用于标签/按钮）
  - 轻材质（§12：小元素用更轻的玻璃）

### 阶段 C · 接入既有 UI（最小侵入）

- [ ] **C1** 解锁液态玻璃选项：移除 [`main.dart:2588`](Trans-Prism/lib/main.dart:2588) 的 `isDisabled: true`，启用 [`onChanged`](Trans-Prism/lib/main.dart:2582) 回调
- [ ] **C2** 更新选项副标题文案：去掉"(开发中)"
- [ ] **C3** 主框架 [`AppRootController`](Trans-Prism/lib/main.dart:545) 的 `AppBar` + 底部 `NavigationBar` 替换为 `GlassAppBar`/`GlassNav`
- [ ] **C4** 首页/工作台卡片群（[`workspace_tab.dart`](Trans-Prism/lib/screens/workspace_tab.dart:1) 等）的 `Card` → `GlassCard`（因组件双模自适应，调用点改动极小）
- [ ] **C5** 设置页"外观与显示"区段卡片玻璃化
- [ ] **C6** 全局弹层（`showModalBottomSheet`/`showDialog`）在 liquid 模式下用 `GlassSheet`/`GlassDialog`

### 阶段 D · 动效与手感（Apple 灵魂）

- [ ] **D1** 玻璃面进入/退出：模糊半径 + scale 联动动画（§12 Materialize）
- [ ] **D2** 底部导航切换：弹簧（damping 1.0 / response 0.3）+ 选中项轻微放大
- [ ] **D3** 卡片按压：`onTapDown` 即时 scale 0.97（§1 Response），弹簧回弹
- [ ] **D4** 滚动边缘：AppBar 底部渐变蒙版随滚动偏移淡入淡出

### 阶段 E · 无障碍与降级（§14 强制）

- [ ] **E1** 读取 `MediaQuery.accessibleNavigation` / 平台 `prefers-reduced-transparency` 等价信号
- [ ] **E2** `GlassTokens` 在降级路径下：blur→0、surfaceAlpha→1.0（实心）、保留边框
- [ ] **E3** 动效降级：弹簧→短淡入（200ms opacity）

### 阶段 F · 验证与文档

- [ ] **F1** 亮/暗 × 简约/液态 四象限手动走查（首页、设置、弹层、对话框、导航）
- [ ] **F2** 性能：`BackdropFilter` 在低端机上的帧率抽测（必要时给大表面加 `RepaintBoundary`）
- [ ] **F3** 更新 [`REPO_MAP.md`](Trans-Prism/REPO_MAP.md:1) 与 [`ARCHITECTURE_DECISIONS.md`](Trans-Prism/ARCHITECTURE_DECISIONS.md:1)（记录"双主题 + 玻璃组件库"决策）
- [ ] **F4** 运行 `/upmap` 同步四件套

---

## 4. 文件改动清单（预估）

| 类型 | 路径 | 动作 |
|---|---|---|
| 新建 | `lib/theme/glass_tokens.dart` | 玻璃 Token + 降级变体 |
| 新建 | `lib/theme/glass_theme.dart` | InheritedWidget |
| 新建 | `lib/widgets/glass_card.dart` | 双模自适应卡片 |
| 新建 | `lib/widgets/glass_app_bar.dart` | 浮动玻璃 AppBar |
| 新建 | `lib/widgets/glass_nav.dart` | 玻璃底部导航 |
| 新建 | `lib/widgets/glass_sheet.dart` | 玻璃 BottomSheet |
| 新建 | `lib/widgets/glass_dialog.dart` | 玻璃对话框 |
| 新建 | `lib/widgets/glass_pill.dart` | 玻璃胶囊/Chip |
| 修改 | `lib/main.dart` | 注入 GlassTheme + 主题分支 + 解锁选项 + 主框架玻璃化 |
| 修改 | `lib/screens/workspace_tab.dart` 等业务页 | `Card`→`GlassCard`（调用点最小改动） |
| 修改 | `lib/widgets/update_dialog.dart` 等 | 弹层玻璃化 |
| 更新 | `REPO_MAP.md` / `ARCHITECTURE_DECISIONS.md` | 文档同步 |

**不改动**：`ThemeService`（已完备）、简约风主题函数、业务逻辑、存储层。

---

## 5. 风险与对策

| 风险 | 对策 |
|---|---|
| `BackdropFilter` 在部分 Android 机型掉帧 | 大表面套 `RepaintBoundary`；低端机检测后自动降级为实心（E2） |
| 玻璃面叠玻璃面导致可读性崩塌（§12） | 规则内建进组件：`GlassCard` 内部不再嵌套 `GlassCard`，改用实心子容器 |
| 简约风被意外污染 | 组件库"双模自适应"设计：minimal Token 下所有 GlassXxx 退化为简约外观，单一真源 |
| 切换主题时整体闪烁 | `MaterialApp` 外层 `ListenableBuilder` 已就位；切换由 `ThemeService.notifyListeners()` 驱动，Flutter 自动重建 |

---

## 6. 验收标准

1. "我的"→"主题风格"中可自由切换"简约风"与"液态玻璃"，选择持久化，重启保留
2. 液态玻璃模式下：AppBar / 底部导航 / 卡片 / 弹层 / 对话框均呈现半透明 + 模糊材质
3. 简约风模式下：所有界面与改动前**像素级一致**（组件退化保证）
4. 亮色 / 暗色 × 简约 / 液态 四象限均可读、可交互
5. 开启系统"减少透明度"时玻璃面自动实心化（§14）
6. 无 Riverpod、无 SQLite、无新增第三方依赖

---

## 7. 下一步

待用户确认本计划后，按 阶段 A → B → C → D → E → F 顺序实现。建议先做 A+B（地基+组件库），可在独立分支用 demo 页可视化验收后再接入 C。