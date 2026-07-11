# REPO_MAP — Trans Prism (稳态光盒)

> 本文件是 AI Agent 的项目导航地图。目标不是列文件，而是帮助 AI 在第一次进入仓库时快速理解架构、定位业务逻辑、定位功能入口、定位状态管理、定位数据流。
>
> 配套阅读：[`SYSTEM_MAP.md`](../SYSTEM_MAP.md:1)（生态全貌）/ [`ARCHITECTURE_DECISIONS.md`](../ARCHITECTURE_DECISIONS.md:1)（架构决策记录）。

---

## 项目概述

**Trans Prism（稳态光盒）** 是一款专为跨性别群体打造的 Flutter 跨平台客户端（iOS/Android/macOS/Windows/Web），提供 HRT 用药追踪与提醒、血药浓度 PK 模拟、嗓音训练辅助、离线知识库（MtF/FtM/RLE Wiki）、友善医疗名录、激素换算、罩杯计算器等一站式本地优先工具箱。核心策略是**在线/离线双擎 + 纯本地物理持久化**，隐私数据不依赖任何第三方服务器。

---

## 技术栈

| 维度 | 方案 | 关键文件 |
|------|------|----------|
| **Flutter 版本** | Flutter 3.x / Dart >=3.4.0 | [`pubspec.yaml`](pubspec.yaml:8) |
| **状态管理** | 原生 `StatefulWidget` + `setState`；仅 [`ThemeService`](lib/services/theme_service.dart:7) `extends ChangeNotifier` | 无第三方状态库 |
| **本地存储** | `SharedPreferences`（JSON Key-Value） | [`pubspec.yaml`](pubspec.yaml:20) |
| **路由** | 命令式 `Navigator.push`（无 go_router） | [`main.dart`](lib/main.dart:1257) |
| **网络** | `dio` + `http` + 自研 DoH 抗污染 | [`dns_safe_network_service.dart`](lib/services/dns_safe_network_service.dart:11) |
| **Android 构建配置** | `compileSdk = 36`, `targetSdk = 36`, `ndkVersion = "28.2.13676358"` | [`android/app/build.gradle:28`](android/app/build.gradle:28) |


---

## 功能模块 & 文件地图

### 1. HRT 用药追踪 / 提醒 / 库存

| 文件 | 职责 |
|------|------|
| [`medication_service.dart`](lib/services/medication_service.dart:25) | 药物增删改查 + 库存管理，直读写 SharedPreferences |
| [`medication_card.dart`](lib/widgets/medication_card.dart:15) | 单条药物卡片 UI（库存、剂量、给药方式） |
| [`medication_stock_summary.dart`](lib/widgets/medication_stock_summary.dart:15) | 首页续航摘要卡片（直读 SP，**绕过 Service**） |
| [`record_dose_dialog.dart`](lib/widgets/record_dose_dialog.dart:15) | 记录单次给药剂量的对话框 |
| [`inventory_dashboard_screen.dart`](lib/screens/inventory_dashboard_screen.dart:1) | 库存仪表板全屏页面 |
| [`notification_service.dart`](lib/services/notification_service.dart:14) | 用药提醒通知调度 |
| [`medication_profile_repository.dart`](lib/storage/medication_profile_repository.dart:14) | 给药日志 JSON 持久化 |

### 2. 血药浓度 PK 模拟

| 文件 | 职责 |
|------|------|
| [`tracker_screen.dart`](lib/screens/tracker_screen.dart:42) | 内嵌 shelf HttpServer 托管 HRT Tracker SPA |
| [`tracker_update_service.dart`](lib/services/tracker_update_service.dart:31) | Tracker PWA 热更新下载器 |
| [`tracker_path_resolver.dart`](lib/utils/tracker_path_resolver.dart:1) | Tracker 文件路径解析 |

### 3. 嗓音训练

| 文件 | 职责 |
|------|------|
| [`voice_training_home.dart`](lib/screens/voice_training/voice_training_home.dart:1) | 嗓音训练首页 |
| [`voice_training_service.dart`](lib/services/voice_training_service.dart:12) | 训练事件持久化 + F0 分析 |
| [`pitch_detection_service.dart`](lib/services/pitch_detection_service.dart:16) | YIN 算法基频检测 |
| [`audio_recorder_widget.dart`](lib/widgets/audio_recorder_widget.dart:1) | 录音控件 |
| [`f0_meter.dart`](lib/widgets/f0_meter.dart:1) | 实时 F0 显示仪表盘 |

### 4. 离线知识库（Wiki）

| 文件 | 职责 |
|------|------|
| [`wiki_sync_service.dart`](lib/services/wiki_sync_service.dart:37) | 在线策略仲裁（GitHub SHA -> 是否走离线） |
| [`wiki_update_manager.dart`](lib/services/wiki_update_manager.dart:31) | R2 版本协商 + ZIP 下载 |
| [`wiki_offline_service.dart`](lib/services/wiki_offline_service.dart:23) | 解压 + 阅后即焚 |
| [`wiki_config.dart`](lib/models/wiki_config.dart:47) | WikiCatalog：id/名/色/在线源 注册中心 |
| [`wiki_tab.dart`](lib/screens/wiki_tab.dart:1) | 百科 Tab 主页面 |
| [`wiki_web_screen.dart`](lib/screens/wiki_web_screen.dart:1) | WebView 加载器（在线/离线双擎） |

### 5. 友善医疗名录

| 文件 | 职责 |
|------|------|
| [`medical_directory_service.dart`](lib/services/medical_directory_service.dart:22) | 名录数据加载+缓存+搜索 |
| [`medical_directory_repository.dart`](lib/storage/medical_directory_repository.dart:14) | 收藏/缓存 SP 持久化 |
| [`medical_directory_list_screen.dart`](lib/screens/medical_directory/medical_directory_list_screen.dart:1) | 名录列表页 |
| [`institution_detail_screen.dart`](lib/screens/medical_directory/institution_detail_screen.dart:1) | 机构详情页 |

### 6. 罩杯计算器 & 发育记录追踪（v1.6.0 新增）

| 文件 | 职责 |
|------|------|
| [`bra_calculator.dart`](lib/services/bra_calculator.dart:1) | 无状态计算工具类，提取自 MtF-wiki 大陆标准算法 |
| [`bra_calculator_page.dart`](lib/screens/bra_calculator_page.dart:1) | 计算器交互页面（AnimatedSize 结果卡片 + 发育记录 BottomSheet） |
| [`growth_record_service.dart`](lib/services/growth_record_service.dart:1) | 发育记录 SharedPreferences 持久化（JSON 数组） |

**算法标准**：胸围差 10cm = A 杯，每 ±2.5cm 递进/递减一个罩杯；底围取均值并向上取整至 5 的倍数。5 项输入：直立下胸围(吸气/呼气)、直立/45°/90° 上胸围。

**数据流**：用户输入 → `BraCalculator.calculate()` → `BraResult` → 自动 `GrowthRecordService.saveRecord()` → SharedPreferences JSON → 发育记录 BottomSheet 读取展示。

### 7. 工具模块

| 文件 | 职责 |
|------|------|
| [`hormone_converter_screen.dart`](lib/screens/hormone_converter_screen.dart:1) | 激素换算器 |
| [`hormone_converter_logic.dart`](lib/utils/hormone_converter_logic.dart:1) | 换算算法 |
| [`image_converter_screen.dart`](lib/screens/image_converter_screen.dart:1) | SVG/位图格式互转 |
| [`svg_resource_gallery_screen.dart`](lib/screens/svg_resource_gallery_screen.dart:1) | SVG 图库浏览 |
| [`resource_service.dart`](lib/services/resource_service.dart:14) | SVG 资源元数据服务 |

---

## 入口与路由

| 文件 | 职责 |
|------|------|
| [`main.dart`](lib/main.dart:1) | 应用入口：DevicePreview 包裹 → 主题构建 → RootController → MainDashboard（4 Tab 底部导航） |
| [`main.dart:37`](lib/main.dart:37) | `main()`：`WidgetsFlutterBinding.ensureInitialized()` → `tz.initializeTimeZones()` → `runApp(DevicePreview(enabled: !kReleaseMode, builder: ...))` |
| [`main.dart:386`](lib/main.dart:386) | `_TransToolboxAppState.build()`：`ListenableBuilder` + `ThemeService` + `MaterialApp`（含 `DevicePreview.locale()` / `DevicePreview.appBuilder`） |
| [`main.dart:413`](lib/main.dart:413) | `AppRootController`：性别认同/免责路由编排 + 后台同步调度 |
| [`main.dart:782`](lib/main.dart:782) | `MainDashboard`：`IndexedStack` 承载 4 个 Tab |
| [`main.dart:1176`](lib/main.dart:1176) | `HomeTab`：首页模块容器（问候语 + HRT + 工具箱 + 声音训练），模块可见性由 SP 控制 |

所有页面跳转均使用 `Navigator.push(MaterialPageRoute(...))`，无路由表。

---

## 数据持久化总览

| 存储类型 | 用途 | Key 示例 |
|----------|------|----------|
| `SharedPreferences` JSON | 药物库存 | `drug_inventory_list` |
| `SharedPreferences` JSON | 给药日志 | `medication_logs` |
| `SharedPreferences` JSON | 嗓音训练事件 | `voice_training_events` |
| `SharedPreferences` JSON | 罩杯发育记录 | `bra_growth_records` |
| `SharedPreferences` JSON | 医疗名录收藏 | `medical_directory_favorites` |
| `SharedPreferences` JSON | Wiki 同步状态 | `wiki_sync_snapshots` |
| `SharedPreferences` 直接 bool | 模块可见性 | `home_module_*` |
| `SharedPreferences` 直接 string | 主题/称呼/前缀 | `user_greeting_name` |
| 文件系统 | 离线 Wiki/Tracker ZIP | `getApplicationDocumentsDirectory()` |

---

## 依赖风险提醒

1. **首页与详情页用药数据各自直读 SharedPreferences**：`MedicationStockSummary` 绕过 Service 直读 SP key `drug_inventory_list`，存在双写口子。
2. **R2 命名空间分裂**：`/app/` 与 `/builder/` 路径规则不同，新增分发类目时容易混淆。
3. **罩杯发育记录 JSON 整体读写**（非增量）：记录增多后序列化/反序列化成本线性增长，当前数据量可忽略。

---

## 许可模型

> 完整的许可证文本与法律条款见 [`LICENSE`](LICENSE)。本仓库采用**复合授权（Composite Licensing）**模式。

| 组件 | 许可证 | 说明 |
|------|--------|------|
| 原创 Dart/Flutter 源码（`lib/`、`android/`、`ios/` 等） | **Apache License 2.0** | 允许商业使用、修改、分发，须保留版权声明 |
| PK 计算引擎（`assets/hrt_tracker/`，WebView JS） | **MIT License** | 衍生自 Oyama's HRT Recorder |
| 嗓音训练模块（`lib/screens/voice_training/`） | **CC BY-NC-SA 4.0** | 衍生自 VFS Tracker，**禁止商业使用** |
| 内置知识库内容（MtF/FtM/RLE Wiki） | **CC BY-SA 4.0** | Project Trans 系，修改后须相同方式共享 |
| MioMtFWiki 内容 | **CC BY-ND 4.0** | **禁止修改后再次发布** |
| 激素换算器 & 罩杯计算器算法 | **CC BY-SA 4.0** | 衍生自 MtF.wiki 及网络公开资料 |
| SVG 图标资源（`assets/svg_resources/`） | 各自原始许可 | Twemoji(CC-BY) / OpenMoji(CC BY-SA) / Noto(Apache 2.0) |
| 第三方依赖（pubspec.yaml） | 各自许可 | MIT / BSD / Apache 2.0 等 |

**贡献者须知**：向本仓库提交的原创代码贡献，将被视为按 Apache License 2.0 条款授权。
