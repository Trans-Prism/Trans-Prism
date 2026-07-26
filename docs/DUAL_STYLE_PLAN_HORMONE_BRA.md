# 激素换算器 & 罩杯计算器 · 双风格（简约风 / 毛玻璃）适配计划

> 状态：**计划阶段（未动代码）**
> 范围：[`hormone_converter_screen.dart`](../lib/screens/hormone_converter_screen.dart) 与 [`bra_calculator_page.dart`](../lib/screens/bra_calculator_page.dart)
> 目标：每个组件提供**两套独立 UI**（简约风 / 毛玻璃），运行时按当前主题风格条件渲染。

---

## 0. 现状与问题

两个页面目前都通过 [`GlassSurface`](../lib/widgets/glass_surface.dart) 做"双模自适应"——即同一个 `GlassSurface` 在 `tokens.isEnabled == true`（毛玻璃）时走 `LiquidGlassLens`，在 `minimal` 时退化为实色 `Container`。

问题：
1. **简约风分支是"退化"而非"设计"**——`GlassSurface` 的 minimal 路径只是用 `solidColor` 填一个实色 `Container`，没有为简约风专门设计的间距/阴影/边框/排版。
2. **毛玻璃分支缺少针对性调优**——直接套用全局 `GlassTokens`，没有针对这两个页面"输入控件密集 + 参考卡片网格"场景做透明度/模糊/边框的局部调优。
3. **无法独立演进**——两套风格耦合在同一个 `build` 里，改一边容易影响另一边。

用户要求：**分别写两套 UI，按当前风格切换显示**。

---

## 1. 风格判定机制

### 1.1 判定来源
- 主题风格持久化在 [`ThemeService.themeStyle`](../lib/services/theme_service.dart:14)（`'minimal'` / `'liquid'`）。
- 运行时通过 [`GlassTheme.of(context)`](../lib/theme/glass_theme.dart) 取到 `GlassTokens`，其 `isEnabled` 字段等价于 `themeStyle == 'liquid'`。
- **推荐**：在页面 `build` 顶部取一次 `final isLiquid = GlassTheme.of(context).isEnabled;`，避免每个子 builder 重复 `of(context)`。

### 1.2 分发模式
每个组件采用"三方法"结构：
```dart
Widget _buildHormoneChips() {
  final isLiquid = GlassTheme.of(context).isEnabled;
  return isLiquid ? _buildHormoneChipsLiquid() : _buildHormoneChipsMinimal();
}
Widget _buildHormoneChipsMinimal() { /* 简约风专属 */ }
Widget _buildHormoneChipsLiquid()  { /* 毛玻璃专属 */ }
```
- 公共 `_buildX()` 只做分发，不含样式逻辑。
- 数据/状态（`_selectedHormone`、`_fromUnit`、`_result` 等）两套共用，仅 UI 不同。
- 亮/暗色在每套内部各自处理（`isDark`）。

---

## 2. 激素换算器 · 双风格设计

文件：[`hormone_converter_screen.dart`](../lib/screens/hormone_converter_screen.dart)

需拆分的组件（共 7 个）：

| # | 组件 | 当前方法 | 简约风设计 | 毛玻璃设计 |
|---|------|----------|------------|-----------|
| 1 | 激素选择药丸 | `_buildHormoneChips` | 实色胶囊：选中=品牌色填充+白字，未选=透明+灰字，无阴影 | `GlassSurface` 药丸：选中=品牌色半透 + 折射边，未选=近透明 + 光学边框 |
| 2 | 换算输入区容器 | `_buildConversionSection` | 白/深灰实色圆角卡 + 1px 边框 + 柔阴影 | `GlassSurface` 玻璃卡：半透 + 模糊 + 折射边 |
| 3 | 输入块 | `_buildInputBlock` | 实色填充 `Container` + 底部 1px 分隔线，焦点=品牌色边框 | `GlassSurface` 子表面：透明填充，焦点=品牌色折射边 + 轻发光 |
| 4 | 单位下拉触发器 | `_buildUnitDropdown` | 实色 `Container` + chevron，简约边框 | `GlassSurface` 药丸：近透明 + 光学边框 |
| 5 | 交换按钮 | （在 `_buildConversionSection` 内） | 圆形实色 `Container` + `Icon` | 圆形 `GlassSurface`：玻璃材质 + 折射边 |
| 6 | 参考范围卡片网格 | `_buildReferenceRanges` + `_buildRangeCard` | 实色卡：命中=品牌色填充+白字，未命中=灰底 | `GlassSurface` 卡：命中=品牌色半透+折射边发光，未命中=近透明 |
| 7 | 出处说明 | `_buildAttribution` | 灰色 `Text`，无容器 | `GlassSurface` 轻材质药丸包裹 |

### 2.1 简约风视觉规范（Minimal）
- **底色**：亮 `Color(0xFFF2F2F7)` / 暗 `Color(0xFF1C1C1A)`（Scaffold）；卡片亮 `Colors.white` / 暗 `Color(0xFF24242C)`。
- **圆角**：卡片 16，药丸 18，输入块 12。
- **边框**：`0.5px`，亮 `Color(0xFFC6C6C8)` / 暗 `Color(0xFF333338)`。
- **阴影**：`BoxShadow(color: 0x14000000, blurRadius: 12, offset: (0,4))`。
- **选中态**：品牌色 `themeColor` 填充 + 白字（亮）/深字（暗）。
- **无 `BackdropFilter`、无 `LiquidGlassLens`**——纯实色。

### 2.2 毛玻璃视觉规范（Liquid）
- **容器**：统一走 `GlassSurface`（已含 `ClipRRect` + `LiquidGlassLens` + 阴影）。
- **表面色**：复用 `GlassTokens.surfaceColor`，但本页局部降低 alpha（输入块更透，参考卡略厚）。
- **圆角**：卡片 20，药丸 18，输入块 14（比简约风略大，配合折射边）。
- **选中态**：品牌色半透叠加（`themeColor.withValues(alpha: 0.18)`）+ 品牌色折射边框。
- **焦点态**：输入块焦点时 `borderColor: themeColor` + 轻发光阴影。
- **参考卡命中**：品牌色 `chromaticAberration` 拉高，呈现彩色棱镜边。

---

## 3. 罩杯计算器 · 双风格设计

文件：[`bra_calculator_page.dart`](../lib/screens/bra_calculator_page.dart)

需拆分的组件（共 5 个）：

| # | 组件 | 当前方法 | 简约风设计 | 毛玻璃设计 |
|---|------|----------|------------|-----------|
| 1 | 5 个输入项 | `_inputGroup` | 实色填充 `Container` + 步骤序号圆点 + 1px 边框 | `GlassSurface` 子表面：透明 + 折射边，序号圆点=品牌色玻璃 |
| 2 | 计算按钮 | （build 内） | 实色品牌色 `ElevatedButton` 风格圆角矩形 | `GlassSurface` 玻璃按钮：品牌色半透 + 折射边 + 按压发光 |
| 3 | 结果卡片 | `_resultCard` | 实色白/深灰卡 + 品牌色标题条 + 阴影 | `GlassSurface` 玻璃卡：品牌色折射边 + 半透 + 模糊 |
| 4 | 历史记录弹窗 | `_showGrowthHistory` | `showModalBottomSheet` + 实色列表 | `GlassSheet` + 玻璃列表项 |
| 5 | 顶部返回/历史 Row | （build 内） | 普通 `IconButton` | `IconButton` 包裹 `GlassSurface` 圆形玻璃 |

### 3.1 简约风视觉规范
- **底色**：亮 `Colors.grey[50]` / 暗 `Colors.black`。
- **输入填充**：亮 `Colors.black.withValues(alpha:0.04)` / 暗 `Colors.white.withValues(alpha:0.08)`。
- **圆角**：输入 12，结果卡 14，按钮 12。
- **阴影**：结果卡 `BoxShadow(0x1A000000, blur:16, (0,6))`。
- **品牌色**：`Color(0xFFF5A9B8)`（跨旗粉）用于按钮 + 结果标题条。
- **无玻璃材质**。

### 3.2 毛玻璃视觉规范
- **容器**：`GlassSurface` 统一接管。
- **输入项**：`GlassSurface(solidColor: inputFill, borderRadius: 14, shadow: false)`，焦点项加品牌色边。
- **结果卡**：`GlassSurface(solidColor: cardBg, borderRadius: 16, padding: all 20)` + 品牌色折射边。
- **按钮**：`GlassSurface` 包裹 `InkWell`，品牌色半透叠加。
- **历史弹窗**：`GlassSheet`（已存在）+ 列表项用 `GlassSurface`。

---

## 4. 实施步骤（待批准后执行）

1. **激素换算器**
   - [ ] `build` 顶部取 `isLiquid`，分发到 7 个 `_buildXMinimal/_buildXLiquid`。
   - [ ] 实现 7 组双方法，简约风用纯 `Container`/`Material`，毛玻璃用 `GlassSurface`。
   - [ ] 局部调优毛玻璃 alpha/折射参数（输入块 vs 参考卡）。
   - [ ] `flutter analyze` 0 错误。

2. **罩杯计算器**
   - [ ] `build` 顶部取 `isLiquid`，分发到 5 个 `_buildXMinimal/_buildXLiquid`。
   - [ ] 实现 5 组双方法。
   - [ ] 历史弹窗改用 `GlassSheet`（毛玻璃分支）。
   - [ ] `flutter analyze` 0 错误。

3. **验证**
   - [ ] 切换主题风格（简约 ↔ 毛玻璃）两页面即时正确切换。
   - [ ] 亮/暗色下两套 UI 均正常。
   - [ ] 无 `BackdropFilter` 在简约风下被误触发（性能/视觉）。

---

## 5. 风险与对策

| 风险 | 对策 |
|------|------|
| 双方法导致代码量翻倍 | 公共数据/逻辑抽到 mixin 或顶层方法，UI 方法只管渲染 |
| 简约风误用玻璃材质 | 简约风方法内**不 import** `GlassSurface`，纯 `Material`/`Container` |
| 风格切换不刷新 | 依赖 `GlassTheme.of(context)`（InheritedWidget），切换主题会触发 rebuild |
| 毛玻璃输入块焦点态不明显 | 焦点时加品牌色边框 + 轻发光阴影，区别于简约风的实色边框 |

---

## 6. 不在本次范围
- 不改 [`GlassSurface`](../lib/widgets/glass_surface.dart) / [`GlassTokens`](../lib/theme/glass_tokens.dart) 公共组件。
- 不改其他页面（首页/工作台/我的）。
- 不改主题判定逻辑（`ThemeService`）。