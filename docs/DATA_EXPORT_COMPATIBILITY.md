# 数据导出兼容性文档 — Trans Prism 统一备份修复指南

> 本文档面向希望修复 Trans Prism「统一数据备份无法导出血药浓度模拟（PK）数据」问题的开发者或 AI Agent。
> 配套阅读：[`SYSTEM_MAP.md`](../SYSTEM_MAP.md) §跨 Dart/JS 边界 / [`ARCHITECTURE_DECISIONS.md`](../ARCHITECTURE_DECISIONS.md) ADR-006。

---

## 1. 问题概述

Trans Prism 的数据备份功能（「我的 → 数据导出与恢复」）当前**无法可靠地导出血药浓度模拟（PK）数据**。用户需要分两步操作：先导出主应用数据，再进入 PK 模拟页面通过 SPA 自带功能单独导出。导入同理。

### 1.1 为什么数据是分裂的

| 数据类别 | 存储位置 | 访问方式 | 导出入口 |
|---------|---------|---------|---------|
| 主应用数据 | `SharedPreferences`（Dart 侧 JSON Key-Value） | Dart 直接读写 | 我的 → 数据导出与恢复 |
| PK 模拟数据 | WebView `localStorage`（绑定 `http://localhost:53140` origin） | 仅可通过 JS 注入访问 | PK 模拟页面内 SPA 设置菜单 |

这两类数据处于**不同的语言运行时**（Dart vs JS）和**不同的存储沙盒**（SP vs WebView origin），由 [ADR-006](../ARCHITECTURE_DECISIONS.md) 的 WebView + shelf 架构决定。

---

## 2. 现有架构与代码地图

### 2.1 统一备份的现有实现

| 文件 | 关键方法 | 职责 |
|------|---------|------|
| [`lib/utils/data_migration_service.dart`](../lib/utils/data_migration_service.dart:25) | `exportData()` | 导出 SP 数据 + 尝试提取 Oyama 数据，用分隔符合并 |
| 同上 | `_extractOyamaExportData()` | 通过 JS 注入 WebView 提取 Oyama `localStorage` + React fiber 状态 |
| 同上 | `importData()` | 按分隔符拆分，分别恢复 SP 与 Oyama 数据 |
| 同上 | `_importOyamaData()` | 通过 JS 注入恢复 Oyama `localStorage` 与 React dispatch |
| [`lib/screens/tracker_screen.dart`](../lib/screens/tracker_screen.dart:195) | `ensureBackgroundInitialized()` | 后台静默初始化 Oyama SPA WebView（供导出/导入调用） |
| [`lib/main.dart`](../lib/main.dart:3195) | `_handleExportData()` | 导出入口，弹出提示对话框后调用 `exportData()` |

### 2.2 备份文件格式

```
{SharedPreferences JSON}
<<<__TP_OYAMA_SEPARATOR__>>
{Oyama SPA JSON}
```

分隔符 `_separator = '\n<<<__TP_OYAMA_SEPARATOR__>>>\n'`（[`data_migration_service.dart:32`](../lib/utils/data_migration_service.dart:32)）。

Oyama JSON 结构：
```json
{
  "events": [...],
  "labResults": [...],
  "weight": 65.0,
  "localStorage": { "key": "value", ... }
}
```

---

## 3. 三个根因（已诊断）

### 根因 #1：误导性对话框 + 不存在的"单独导出"入口

[`_handleExportData`](../lib/main.dart:3195) 弹出对话框告知用户"当前备份操作不包含血药浓度模拟数据"，并指引去"血药浓度板块内的设置进行单独导出"——但 `TrackerScreen` 的 AppBar 没有任何设置/导出按钮，指向一个**从未实现的功能**。

### 根因 #2：后台 WebView 初始化竞态条件

[`ensureBackgroundInitialized()`](../lib/screens/tracker_screen.dart:195) 等待 `onPageFinished` 信号后即注册控制器。但 `onPageFinished` 在 HTML 加载完成时触发，React SPA 的异步水合（读取 localStorage → 恢复 React 状态）发生在**之后**。提取时 SPA 可能尚未就绪。且初始化失败被静默吞掉（只 `debugPrint`），调用方无法感知。

### 根因 #3：React Fiber 树遍历极度脆弱

[`_extractOyamaExportData()`](../lib/utils/data_migration_service.dart:198) 通过遍历 React 内部 `__reactFiber$` 树查找 `memoizedState` hooks，匹配 `"timeH"` / `"date"+"estradiol"` / `weight` 字段名来识别状态。此方法：
- 依赖 React 内部 API（随版本变化）
- 依赖组件层级结构
- 依赖 SPA 已完成水合
- 控制器不可用时直接返回 `null` → 备份中 PK 部分变成 `'{}'`

---

## 4. 修复方案

### 方案 A：增强现有统一备份（推荐，改动最小）

#### 步骤 1：增强 `_extractOyamaExportData()` 健壮性

**文件**：[`data_migration_service.dart`](../lib/utils/data_migration_service.dart:198)

在提取前增加 SPA 就绪轮询：

```dart
/// 等待 SPA 的 JavaScript 上下文就绪
static Future<bool> _waitForSpaReady({
  Duration timeout = const Duration(seconds: 3),
}) async {
  final controller = _oyamaWebViewController;
  if (controller == null) return false;

  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    try {
      final result = await controller.runJavaScriptReturningResult(r'''
(function() {
  if (document.readyState !== 'complete') return 'loading';
  var root = document.getElementById('root');
  if (!root) return 'no_root';
  if (root.children.length === 0) return 'empty_root';
  return 'ready';
})();
''');
      if (result.toString() == 'ready') return true;
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 300));
  }
  return false;
}
```

在 `_extractOyamaExportData()` 开头调用：
```dart
await _waitForSpaReady();
```

**关键原则**：`localStorage` 是 SPA 的真正持久化层（ADR-006），在页面加载后即可读取（浏览器同步 API），是提取的**可靠主路径**。React fiber 遍历降级为"尽力而为"的补充。

#### 步骤 2：增强 `ensureBackgroundInitialized()` 可靠性

**文件**：[`tracker_screen.dart`](../lib/screens/tracker_screen.dart:195)

- 返回 `Future<bool>` 而非 `Future<void>`，让调用方感知成功/失败
- `onPageFinished` 后增加 1.5 秒缓冲，让 React 水合完成
- 失败时输出详细日志（端口、文件路径）

```dart
static Future<bool> ensureBackgroundInitialized() async {
  if (DataMigrationService.hasOyamaController) return true;
  try {
    // ... 现有初始化逻辑 ...
    await pageLoaded.future.timeout(const Duration(seconds: 15));
    await Future.delayed(const Duration(milliseconds: 1500)); // 新增缓冲
    DataMigrationService.registerOyamaController(ctrl);
    return true;
  } catch (e) {
    debugPrint('[TrackerScreen] 后台 SPA 初始化失败: $e');
    return false;
  }
}
```

#### 步骤 3：在 `exportData()` 增加重试机制

**文件**：[`data_migration_service.dart`](../lib/utils/data_migration_service.dart:48)

首次提取返回 `null` 时，等待 2 秒后重试一次（应对 SPA 异步初始化延迟）。返回值改为包含 PK 包含状态：

```dart
static Future<({bool success, bool includedPkData})> exportData() async {
  // ...
  Map<String, dynamic>? oyamaData = await _extractOyamaExportData();
  if (oyamaData == null) {
    await Future.delayed(const Duration(seconds: 2));
    oyamaData = await _extractOyamaExportData();
  }
  final includedPkData = oyamaData != null && oyamaData.isNotEmpty;
  // ...
  return (success: result != null, includedPkData: includedPkData);
}
```

#### 步骤 4：修正误导性对话框 + 增加 TrackerScreen 独立导出入口

**文件**：[`main.dart`](../lib/main.dart:3195) + [`tracker_screen.dart`](../lib/screens/tracker_screen.dart:404)

- 对话框文案改为"本次备份将导出所有本地数据，包括血药浓度模拟数据"
- 在 `TrackerScreen` AppBar 增加 `PopupMenuButton`，含"导出/导入血药浓度数据"两个入口
- 在 `DataMigrationService` 增加 `exportOyamaDataOnly()` / `importOyamaDataOnly()` 方法

### 方案 B：完全依赖 Oyama SPA 自带导出（零 Dart 改动）

如果不想修改 Dart 代码，可以：
1. 在 README/TODO 中明确告知用户需分两步操作（当前已采用此方案作为临时措施）
2. 确保 Oyama SPA 自带的导出功能在 WebView 内可用
3. 统一备份仅导出 SharedPreferences 数据，不再尝试提取 Oyama 数据

**缺点**：用户体验割裂，需手动管理两个备份文件。

---

## 5. 注意事项

### 5.1 分隔符向后兼容

备份文件用 `__TP_OYAMA_SEPARATOR__` 分隔两部分数据。**修改格式必须保持向后兼容**，否则旧备份文件无法导入。`importData()` 已处理无分隔符的旧格式（整个文件视为 SP 数据）。

### 5.2 localStorage origin 绑定

Oyama SPA 的 `localStorage` 绑定到 `http://localhost:53140` origin（ADR-006 固定端口）。如果端口被占用回退到随机端口，`localStorage` 会因 origin 变化而**数据丢失**。提取数据时必须确保使用已注册的控制器（同一 origin）。

### 5.3 React Fiber 遍历的局限性

React fiber 树遍历（`__reactFiber$`）是 React 内部 API，**非公开接口**，随 React 版本升级可能变化。如果 Oyama 上游升级 React 版本，此遍历逻辑可能失效。`localStorage` 提取不依赖 React 内部 API，是更可靠的路径。

### 5.4 架构约束（不可违反）

- **ADR-001**：禁止引入 SQLite / drift / isar / hive
- **ADR-002**：禁止引入 Riverpod / Provider / Bloc / GetX，状态管理用 `StatefulWidget` + `setState`
- **ADR-006**：WebView + shelf 架构不变，`localStorage` 仍为 SPA 持久化层

---

## 6. 验证清单

修复后应验证：

- [ ] 用户从未打开过 PK 模拟 → 统一备份导出 SP 数据，PK 部分为空，SnackBar 提示"未检测到血药浓度模拟数据"
- [ ] 用户曾在 PK 模拟中录入数据 → 统一备份导出 SP 数据 + PK 数据，SnackBar 提示"含血药浓度模拟数据"
- [ ] 导入含 PK 数据的备份 → SP 数据恢复 + PK 数据恢复到 SPA
- [ ] 导入不含 PK 数据的旧备份（无分隔符）→ 仅恢复 SP 数据，不报错
- [ ] TrackerScreen 独立导出 → 生成 `trans_prism_pk_backup.json`，仅含 PK 数据
- [ ] TrackerScreen 独立导入 → PK 数据恢复，WebView 自动刷新