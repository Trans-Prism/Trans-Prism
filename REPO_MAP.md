# REPO_MAP — Trans Prism (稳态光盒)

> 本文件是 AI Agent 的项目导航地图。目标不是列文件，而是帮助 AI 在第一次进入仓库时快速理解架构、定位业务逻辑、定位功能入口、定位状态管理、定位数据流。
>
> 配套阅读：[`SYSTEM_MAP.md`](../SYSTEM_MAP.md:1)（生态全貌）/ [`ARCHITECTURE_DECISIONS.md`](../ARCHITECTURE_DECISIONS.md:1)（架构决策记录，含 ADR-011）。
> workspace 根目录另有 **开发辅助子系统** [`rag-system/`](../rag-system/mcp_bridge_bge.py:1)（RAG 知识库 MCP Bridge，检索本生态全部文档），属 workspace 级组件、不属于本 App 仓库；其配置双写点（Zoo/Roo 两处 mcp.json）见 ADR-011 与 SYSTEM_MAP 对应章节。

---

## 项目概述

**Trans Prism（稳态光盒）** 是一款专为跨性别群体打造的 Flutter 跨平台客户端（iOS/Android/macOS/Windows/Web），提供 HRT 用药追踪与提醒、血药浓度 PK 模拟、离线知识库（MtF/FtM/RLE Wiki）、友善医疗名录、激素换算、罩杯计算器等一站式本地优先工具箱。核心策略是**在线/离线双擎 + 纯本地物理持久化**，隐私数据不依赖任何第三方服务器。

---

## 技术栈

| 维度 | 方案 | 关键文件 |
|------|------|----------|
| **App 版本** | **v1.7.0** | [`pubspec.yaml`](pubspec.yaml:5) |
| **Flutter 版本** | Flutter 3.x / Dart >=3.6.2 <4.0.0 | [`pubspec.yaml`](pubspec.yaml:8) |
| **状态管理** | 原生 `StatefulWidget` + `setState`；仅 [`ThemeService`](lib/services/theme_service.dart:7) `extends ChangeNotifier` | 无第三方状态库 |
| **本地存储** | `SharedPreferences`（JSON Key-Value） | [`pubspec.yaml`](pubspec.yaml:20) |
| **路由** | 命令式 `Navigator.push`（无 go_router） | [`main.dart`](lib/main.dart:1899) |
| **网络** | `dio` + 自研 DoH 抗污染（R2 三路热更新 + GitHub API 全部走 `DnsSafeNetworkService`，标准 DNS 优先 + DoH 兜底） | [`dns_safe_network_service.dart`](lib/services/dns_safe_network_service.dart:11)（含 [`downloadBytes()`](lib/services/dns_safe_network_service.dart:71) + `instance` 单例） |
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
| [`notification_service.dart`](lib/services/notification_service.dart:14) | 用药提醒通知调度 + 启动自愈补挂（`restoreMissingSchedules`） |
| [`medication_profile_repository.dart`](lib/storage/medication_profile_repository.dart:14) | 给药日志 JSON 持久化 |

### 1b. 用药成本 / 价格计算器（v1.7.0 新增）

| 文件 | 职责 |
|------|------|
| [`medication_purchase.dart`](lib/models/medication_purchase.dart:13) | 补货价格 + 规格记录模型（`totalPrice` / `specQuantity` / `specUnit` / `doses`）；JSON 全容错 |
| [`medication_price_repository.dart`](lib/storage/medication_price_repository.dart:17) | 价格记录 SP 持久化，key = `medication_purchase_records` |
| [`medication_cost_service.dart`](lib/services/medication_cost_service.dart:130) | **纯函数**成本统计：`avgCostPerDose` = `ΣtotalPrice / Σdoses`、`resolveDoses`（换算表折算）、`summarize` → `DrugCost` / `MedicationCostSummary` |
| [`currency.dart`](lib/utils/currency.dart:37) | 币种定义 + 金额格式化 + SP 持久化（key = `cost_currency_code`）；**只换符号不换算汇率** |
| [`restock_sheet.dart`](lib/widgets/restock_sheet.dart:31) | 补货面板：数量 + 总价/单价 + 规格 + 换算学习（未知单位就地学 `1 针 = 5 mg`） |
| [`medication_cost_screen.dart`](lib/screens/medication_cost_screen.dart:29) | 成本详情页：分药明细 + 补货历史 + 累计支出趋势 |
| [`medication_report_view.dart`](lib/widgets/medication_report_view.dart:44) | 报告长图 Widget（**预览与导出同源**，固定 750px，打码唯一出口 `_buildMaskMap`） |
| [`medication_report_renderer.dart`](lib/services/medication_report_renderer.dart:44) | Widget → PNG 栅格化 + **长图自动分片**（`MedicationReportBoundary` 子类合法暴露 `layer`，再按局部矩形 `toImage`） |
| [`medication_report_export_screen.dart`](lib/screens/medication_report_export_screen.dart:28) | 导出配置页：3 模式 × 打码 × 时间/药物范围 + 实时预览 + 相册/文件/分享 |

> **核心口径**：本 app 的 `dosage` / `currentStock` **没有单位**，因此成本统计锚定在**「够用次数」**而不是任何度量单位：
> `单次使用费用（平均）= Σ本次花费 / Σ够用次数`。按次数加权让**总额天然自洽**（先 `¥30/14次` 再 `¥40/14次` → 均价 `¥2.50/次`，28 次 × 2.50 = **¥70 = 真实总支出**），
> 所以**打卡流程零改动**、[`MedicationLog`](lib/models/medication_log.dart:8) 结构不变（不需要逐次价格快照）。
>
> **两个易踩的坑（改这块代码前必读）**：
> 1. 判断「未设价格」**必须用 `DrugCost.costPerDose == null`**，**不能用 `spent == 0`** —— 赠药（`totalPrice == 0`）是合法价格，`spent` 同样是 `0.0` 但它**已定价**。
> 2. `_DrugFormPage._submit()` 是**新建 `Drug(...)`**（不是 `copyWith`），编辑药物时**必须显式带上 `doseUnit` / `specConversions`**，否则用户编辑一次药物就**静默丢失**刚配好的剂量单位与换算表。
>
> **数据流**：价格有**两个录入口** —— ① **首次添加药物**时表单里的「首次购入价格（选填）」折叠区（默认收起留空，编辑药物时不出现）；② 已存在药物的**补货面板**。
> 两者语义一致（按总价/单价、规格、够用次数），都产出 `MedicationPurchase` → SP `medication_purchase_records` → `MedicationCostService` → 卡片「单次花费」/ 仪表盘汇总卡 / 首页摘要 / 成本详情页 / 导出 PNG。
> 价格与补货**完全解耦**：留空只加库存、不写价格记录；未定价药物**不计入任何合计**（不是按 0 元算）。

### 2. 血药浓度 PK 模拟

| 文件 | 职责 |
|------|------|
| [`tracker_screen.dart`](lib/screens/tracker_screen.dart:42) | 内嵌 shelf HttpServer 托管 HRT Tracker SPA；端口由 `TrackerPortConfig` 管理（智能顺延/自定义） |
| [`tracker_port_config.dart`](lib/services/tracker_port_config.dart:19) | Tracker 端口配置：智能/自定义模式读写 + 智能顺延探测（53140~53159） |
| [`tracker_update_service.dart`](lib/services/tracker_update_service.dart:31) | Tracker PWA 热更新下载器 |
| [`tracker_path_resolver.dart`](lib/utils/tracker_path_resolver.dart:1) | Tracker 文件路径解析 |

> **内置基线版本**：`assets/hrt_tracker/` 打包的 HRT Tracker SPA 构建产物对应 Trans-Prism-Builder release `tracker-2026-07-22`（上游 Oyama `v1.3.0-stable` 衍生构建）。运行时 [`_LocalTrackerServer`](lib/screens/tracker_screen.dart:42) 优先从沙盒热更新目录读取，其次回退到此内置基线。基线升级时仅需整体替换该目录并核对 [`index.html`](assets/hrt_tracker/index.html:12) 内的资源哈希引用，无需改动 Dart 代码或 [`pubspec.yaml`](pubspec.yaml:72)（assets 以目录通配声明）。

### 3. 离线知识库（Wiki）

| 文件 | 职责 |
|------|------|
| [`wiki_sync_service.dart`](lib/services/wiki_sync_service.dart:37) | 在线策略仲裁（GitHub SHA -> 是否走离线） |
| [`wiki_update_manager.dart`](lib/services/wiki_update_manager.dart:31) | R2 版本协商 + ZIP 下载 |
| [`wiki_offline_service.dart`](lib/services/wiki_offline_service.dart:23) | 解压 + 阅后即焚 |
| [`wiki_config.dart`](lib/models/wiki_config.dart:47) | WikiCatalog：id/名/色/在线源 注册中心 |
| [`wiki_tab.dart`](lib/screens/wiki_tab.dart:1) | 百科 Tab 主页面 |
| [`wiki_web_screen.dart`](lib/screens/wiki_web_screen.dart:1) | WebView 加载器（在线/离线双擎） |

### 4. 友善医疗名录

| 文件 | 职责 |
|------|------|
| [`medical_directory_service.dart`](lib/services/medical_directory_service.dart:22) | 名录数据加载+缓存+搜索 |
| [`medical_directory_repository.dart`](lib/storage/medical_directory_repository.dart:14) | 收藏/缓存 SP 持久化 |
| [`medical_directory_list_screen.dart`](lib/screens/medical_directory/medical_directory_list_screen.dart:1) | 名录列表页 |
| [`institution_detail_screen.dart`](lib/screens/medical_directory/institution_detail_screen.dart:1) | 机构详情页 |

### 5. 罩杯计算器 & 发育记录追踪（v1.6.0 新增）

| 文件 | 职责 |
|------|------|
| [`bra_calculator.dart`](lib/services/bra_calculator.dart:1) | 无状态计算工具类，提取自 MtF-wiki 大陆标准算法 |
| [`bra_calculator_page.dart`](lib/screens/bra_calculator_page.dart:1) | 计算器交互页面（AnimatedSize 结果卡片 + 发育记录 BottomSheet） |
| [`growth_record_service.dart`](lib/services/growth_record_service.dart:1) | 发育记录 SharedPreferences 持久化（JSON 数组） |

**算法标准**：胸围差 10cm = A 杯，每 ±2.5cm 递进/递减一个罩杯；底围取均值并向上取整至 5 的倍数。5 项输入：直立下胸围(吸气/呼气)、直立/45°/90° 上胸围。

**数据流**：用户输入 → `BraCalculator.calculate()` → `BraResult` → 自动 `GrowthRecordService.saveRecord()` → SharedPreferences JSON → 发育记录 BottomSheet 读取展示。

### 6. 工具模块

| 文件 | 职责 |
|------|------|
| [`hormone_converter_screen.dart`](lib/screens/hormone_converter_screen.dart:1) | 激素换算器 |
| [`hormone_converter_logic.dart`](lib/utils/hormone_converter_logic.dart:1) | 换算算法 |
| [`image_converter_screen.dart`](lib/screens/image_converter_screen.dart:1) | SVG/位图格式互转 |
| [`svg_resource_gallery_screen.dart`](lib/screens/svg_resource_gallery_screen.dart:1) | SVG 图库浏览 |
| [`resource_service.dart`](lib/services/resource_service.dart:14) | SVG 资源元数据服务 |

### 7. 桌面用药小组件（Android / Glance）

| 文件 | 职责 |
|------|------|
| [`MedsWidgetData.kt`](android/app/src/main/kotlin/com/daanser/transprism/widget/MedsWidgetData.kt:1) | 展示模型 + **只读** Flutter SP（`drug_inventory_list` / `medication_logs`）+ 预览假数据 |
| [`MedsWidgetTokens.kt`](android/app/src/main/kotlin/com/daanser/transprism/widget/MedsWidgetTokens.kt:1) | 语义 token（色 / 尺寸 / 字号）+ `MedsWidgetThemeProvider`（CompositionLocal 注入当前 token 集） |
| [`MedsWidgetThemePrefs.kt`](android/app/src/main/kotlin/com/daanser/transprism/widget/MedsWidgetThemePrefs.kt:1) | **主题偏好解析**：`colorsFor()` 读 `flutter.theme_mode` 判定 light/dark/system（跟 App、不跟系统） |
| [`MedsRingRenderer.kt`](android/app/src/main/kotlin/com/daanser/transprism/widget/MedsRingRenderer.kt:1) | 2×2 环形进度**预渲染位图**（Glance 无 Canvas）+ LruCache |
| [`MedsWidgetCommon.kt`](android/app/src/main/kotlin/com/daanser/transprism/widget/MedsWidgetCommon.kt:1) | 共享原子组件（针筒图标、状态点、下一剂竖条、按钮、进度条） |
| [`MediumMedsWidget.kt`](android/app/src/main/kotlin/com/daanser/transprism/widget/MediumMedsWidget.kt:1) | **3×4 中卡**：下一剂左竖条 + 整行可点（打开该药 Sheet）+ 右上 muted 说明「点对应药物服药」 |
| [`SmallMedsWidget.kt`](android/app/src/main/kotlin/com/daanser/transprism/widget/SmallMedsWidget.kt:1) | **2×2 小卡**：下一剂环形 + 单按钮（两者都只打开该药 Sheet） |
| [`MedsWidgetReceivers.kt`](android/app/src/main/kotlin/com/daanser/transprism/widget/MedsWidgetReceivers.kt:1) | 两个 Receiver + `MedsWidgetUpdater.refreshAll()`（Glance 1.2.0 无 `updateAll`，需枚举实例） |
| [`MedsWidgetActions.kt`](android/app/src/main/kotlin/com/daanser/transprism/widget/MedsWidgetActions.kt:1) | 动作契约：`open_record_sheet`（带 `drugId`）+ `open_meds`；旧 `record_dose` 仅作兼容。`widgetClickAction()` 产出**广播** action（HyperOS 兼容，见下） |
| [`MedsWidgetClickReceiver.kt`](android/app/src/main/kotlin/com/daanser/transprism/widget/MedsWidgetClickReceiver.kt:1) | **点击广播中转**（HyperOS 兼容核心）：`onReceive` → `startActivity(makeMainActivity(MainActivity))` |
| [`meds_widget_service.dart`](lib/services/meds_widget_service.dart:1) | Dart 侧桥接：`refresh()` / `canPin()` / `pin(size)` |

> **数据流（v1.7.0 起：小组件永不写入）**：小组件**只读** Flutter 的同一份
> `SharedPreferences`（键前缀 `flutter.`），不新增任何存储、不复制打卡逻辑。
> **点击链路（HyperOS 兼容，见 §11.6）**：小组件点击产出的是
> `PendingIntent.getBroadcast`（Glance `actionSendBroadcast`）→
> [`MedsWidgetClickReceiver`](android/app/src/main/kotlin/com/daanser/transprism/widget/MedsWidgetClickReceiver.kt:1)
> 在自己的进程里 `startActivity(Intent.makeMainActivity(...))`。
> **不要改回 `actionStartActivity`** —— HyperOS 会拦截「小组件 PendingIntent 直接启动
> Activity」，症状是卡片显示正常但点击无反应。
> 随后带 extra 唤起 `MainActivity` → MethodChannel
> `com.daanser.transprism/widget_action` → Dart `_dispatchWidgetAction` →
> `_openRecordSheetFromWidget()` → 复用既有
> [`RecordDoseDialog.show()`](lib/widgets/record_dose_dialog.dart:27)。
> **只有用户在 Sheet 里点「确认服药」**才走 `MedicationService.executeMedicationDose()`；
> 取消 / 系统返回不改动任何数据。
>
> **主题**：卡片深浅色绑定 App「我的 → 主题模式」的偏好（`flutter.theme_mode`），
> **不跟壁纸、不跟系统**（除非 App 设为「跟随系统」）。偏好变化 → `ThemeService`
> → `MedsWidgetService.refresh()` 重渲染；`resumed` / `paused` 各补刷一次。
>
> ⚠️ **数据与主题必须在 `provideContent { }` 内读取** —— Glance 会话长驻，
> `provideGlance` 只在会话创建时跑一次，提到外面的 `val` 会被闭包捕获而永不刷新。
>
> ⚠️ **每个点击目标的 data URI 必须唯一**：`PendingIntent` 去重依据是
> `Intent.filterEquals`，它**忽略 extras**。若只用 extras 区分不同药的行，
> 几行会被判成同一个 PendingIntent、`FLAG_UPDATE_CURRENT` 让最后一个覆盖全部
> → 点哪行都开同一味药。故写入 `transprism://widget/{action}/{drugId}`。
>
> **「我的 → 外观与显示 → 添加到主屏幕」** 走 `AppWidgetManager.requestPinAppWidget`
> （Android 8+），不支持的设备退化为长按桌面的文字说明。
>
> 完整实装说明与验收清单见 [`docs/WIDGET_IMPLEMENTATION.md`](docs/WIDGET_IMPLEMENTATION.md:1)。

---

## 入口与路由

| 文件 | 职责 |
|------|------|
| [`main.dart`](lib/main.dart:1) | 应用入口：DevicePreview 包裹 → 主题构建 → RootController → MainDashboard（4 Tab 底部导航） |
| [`main.dart:66`](lib/main.dart:66) | `main()`：`WidgetsFlutterBinding.ensureInitialized()` → `tz.initializeTimeZones()` → `runApp(DevicePreview(enabled: !kReleaseMode, builder: ...))` |
| [`main.dart:679`](lib/main.dart:679) | `_TransToolboxAppState.build()`：`ListenableBuilder` + `ThemeService` + `MaterialApp`（含 `DevicePreview.locale()` / `DevicePreview.appBuilder`） |
| [`main.dart:719`](lib/main.dart:719) | `AppRootController`：性别认同/免责路由编排 + 后台同步调度 |
| [`main.dart:1285`](lib/main.dart:1285) | `MainDashboard`：`IndexedStack` 承载 4 个 Tab |
| [`main.dart:1798`](lib/main.dart:1798) | `HomeTab`：首页模块容器（问候语 + HRT + 工具箱），模块可见性由 SP 控制 |
| [`main.dart:2120`](lib/main.dart:2120) | `ProfileTab`（我的）：身份与资料 / 外观与显示（主题模式、主题风格、主题色、**添加到主屏幕**） / **高级**（通知权限与保活、数据导出与恢复、**血药浓度模拟端口**）/ **系统**（关于与支持、**相关链接**、**检查更新**、**再次进入向导**）。所有设置项经 [`_buildSettingsTile`](lib/main.dart:2607) 渲染且**统一无副标题**（`subtitle` 一律为 `null`）；端口设置弹层 [`_showTrackerPortSheet`](lib/main.dart:3368)（智能/自定义 + 修改确认，变更端口会改变 SPA origin，须先内置导出备份；配置**重启应用后生效**）；「再次进入向导」经 `Navigator.push` 重跑 `OnboardingWizard`，完成后 pop 回主界面；「添加到主屏幕」弹层 [`_showAddToHomeSheet`](lib/main.dart:3784)（选尺寸 → 原生 `requestPinAppWidget`）|
| [`main.dart:2197`](lib/main.dart:2197) | `_handleCheckUpdate`：手动检查更新入口（SnackBar「正在检查更新…」→ `UpdateService.checkForUpdate()` → 新版本弹 `UpdateDialog`（含 `release_notes` 更新内容，源字段为 `latest.json` 的**可选** `release_notes`）/ 网络错误 / 已是最新 三态） |
| [`onboarding_wizard.dart`](lib/screens/onboarding/onboarding_wizard.dart:1) | `OnboardingWizard` 初始化引导：欢迎 → 权限 → 性别/主题/称呼 → **使用须知（免责声明，须勾选同意）** → 完成。**「跳过」仅跳转到使用须知步骤（接受默认选择，不自动同意免责）**——必须勾选同意后才能完成进入主界面。启动场景由 `AppRootController` 在 `onboarding_completed` 缺失时展示；「我的 → 系统 → 再次进入向导」可手动重跑（`onCompleted` 后 pop） |
| [`links_screen.dart`](lib/screens/links_screen.dart:1) | `LinksScreen`（相关链接二级页）：「我的 → 系统 → 相关链接」进入，集中展示外部链接（官网 `transprism.chengxi.moe` / GitHub `github.com/Trans-Prism/Trans-Prism`），经 `url_launcher` `LaunchMode.externalApplication` 跳系统浏览器。纯静态 UI，App 内零网络请求、不经 R2 / `DnsSafeNetworkService`，无持久化 / 状态管理 / 新依赖；双模自适应（GlassSurface） |

所有页面跳转均使用 `Navigator.push(MaterialPageRoute(...))`，无路由表。

---

## 主题系统（双风格可切换）

用户可在「我的 → 主题风格」中自由切换 **简约风（minimal）** 与 **液态玻璃（liquid）**，选择持久化于 SharedPreferences（`theme_style`）。

| 文件 | 职责 |
|------|------|
| [`theme_service.dart`](lib/services/theme_service.dart:7) | `ThemeService`（ChangeNotifier）：`themeMode`/`themeColor`/`themeStyle` 三态持久化 |
| [`glass_tokens.dart`](lib/theme/glass_tokens.dart:1) | `GlassTokens`：液态玻璃 Token（模糊/表面色/边框/阴影/高光边）+ 简约退化 Token + 无障碍降级变体 |
| [`glass_theme.dart`](lib/theme/glass_theme.dart:1) | `GlassTheme`（InheritedWidget）：向下游暴露当前 Token，`GlassTheme.of(context)` |
| [`glass_card.dart`](lib/widgets/glass_card.dart:1) | `GlassCard`：双模自适应卡片（液态=模糊+半透明+高光边；简约=实色+弥散阴影）。阴影承载于最外层 `DecoratedBox`（不被 Material 裁剪，2026-08-15 修复卡片无阴影/扁平问题） |
| [`glass_app_bar.dart`](lib/widgets/glass_app_bar.dart:1) | `GlassAppBar`：浮动玻璃 AppBar（液态=模糊+滚动边缘；简约=实色） |
| [`glass_nav.dart`](lib/widgets/glass_nav.dart:1) | `GlassNav`：玻璃底部导航（液态=浮动胶囊+高光边；简约=实色） |
| [`glass_sheet.dart`](lib/widgets/glass_sheet.dart:1) | `GlassSheet`：玻璃 BottomSheet 容器 |
| [`glass_dialog.dart`](lib/widgets/glass_dialog.dart:1) | `GlassDialog`：玻璃对话框容器 |
| [`glass_pill.dart`](lib/widgets/glass_pill.dart:1) | `GlassPill`：玻璃胶囊/Chip（轻材质） |
| [`main.dart`](lib/main.dart:679) | `_TransToolboxAppState.build()`：按 `themeStyle` 分支选择 `_buildLiquidXxxTheme`/`_buildXxxTheme`，注入 `GlassTheme`，并按 `accessibleNavigation` 触发无障碍降级 |

**设计原则**：组件库"双模自适应"——`GlassXxx` 在 minimal 模式下退化为与既有简约外观一致，业务页调用点改动极小即可在两风格间无缝切换。液态玻璃遵循 Apple WWDC *Designing Fluid Interfaces* §12 Materials & depth（半透明浮动层 + 顶部高光边 + 滚动边缘效果）与 §14 无障碍降级。

**简约风背景承载约定（2026-08-15 修复）**：`GlassSurface` / `GlassSheet` / `GlassCard` 在简约风下**必须把背景色渲染在 `Material` 上**（而非内层 `Container`/`DecoratedBox`）。原因：子级 `ListTile` 的 ink splash 绘制在最近 `Material` 上，若背景放在内层带颜色容器（`ColoredBox`/`DecoratedBox`），Flutter 框架断言 `ListTile._debugCheckBackgroundIsHidden` 会判定该容器遮挡 ink splash，抛出 "ListTile background color or ink splashes may be invisible"（曾误报于百科 Tab 列表项、主题/性别/风格选择 BottomSheet、引导页 CheckboxListTile）。背景承载于 Material 后：① 断言检查向上遇 Material 即停、不再误报；② InkWell 波纹真实绘制在背景之上可见。任何新增玻璃容器组件均须遵守此模式（`Material(color) → InkWell → 无背景 Container`）。

**`solidColor` 双模语义（2026-08-15 修复）**：[`GlassSurface`](lib/widgets/glass_surface.dart:27) 液态分支此前完全忽略 `solidColor`，导致简约风"实色强调"语义在液态下丢失（如工作台分类胶囊选中态深灰底不生效，白字落在白玻璃上对比度不足）。现已与 `GlassCard` 液态分支对齐：**不透明** `solidColor`（alpha==1）以 `GlassTokens.surfaceColor.a` 的 alpha 掺入玻璃表面色；调用方已传半透明色（alpha<1，如 10% 白 / 15% 品红）则保留其原 alpha。配合 [`workspace_tab.dart:293`](lib/screens/workspace_tab.dart:293) 分类胶囊选中态文字在液态下反相（亮色深字 `0xFF333333` / 暗色白字 `Colors.white`，简约风保持深底白字/白底黑字不变），保证选中态对比度。

---

## 数据持久化总览

| 存储类型 | 用途 | Key 示例 |
|----------|------|----------|
| `SharedPreferences` JSON | 药物库存 | `drug_inventory_list` |
| `SharedPreferences` JSON | 给药日志 | `medication_logs` |
| `SharedPreferences` JSON | 补货价格 / 规格记录 | `medication_purchase_records` |
| `SharedPreferences` 直接 string | 成本展示币种（仅符号） | `cost_currency_code` |
| `SharedPreferences` JSON | 罩杯发育记录 | `bra_growth_records` |
| `SharedPreferences` JSON | 医疗名录收藏 | `medical_directory_favorites` |
| `SharedPreferences` JSON | Wiki 同步状态 | `wiki_sync_snapshots` |
| `SharedPreferences` 直接 bool | 模块可见性 | `home_module_*` |
| `SharedPreferences` 直接 string | 主题/称呼/前缀 | `user_greeting_name` |
| `SharedPreferences` 直接 string | **主题模式（App 与桌面小组件共享的深浅色唯一来源）** | `theme_mode`（`light`/`dark`/`system`） |
| `SharedPreferences` 直接 string/int | Tracker 端口模式/自定义端口 | `tracker_port_mode` / `tracker_custom_port` |
| 文件系统 | 离线 Wiki/Tracker ZIP | `getApplicationDocumentsDirectory()` |

---

## 依赖风险提醒

1. **首页与详情页用药数据各自直读 SharedPreferences**：`MedicationStockSummary` 绕过 Service 直读 SP key `drug_inventory_list`，存在双写口子。
2. **R2 命名空间分裂**：`/app/` 与 `/builder/` 路径规则不同，新增分发类目时容易混淆。
3. **罩杯发育记录 JSON 整体读写**（非增量）：记录增多后序列化/反序列化成本线性增长，当前数据量可忽略。
4. **数据备份分裂（待修复）**：[`DataMigrationService`](lib/utils/data_migration_service.dart:25) 统一备份跨 Dart/JS 边界提取 Oyama SPA `localStorage` 依赖 React fiber 树遍历（脆弱）且后台 WebView 初始化存在竞态，**无法可靠导出 PK 模拟数据**。当前需分两步操作（主应用 SP + Oyama 各导出/导入），已列为待修复项，修复方案见 [`docs/DATA_EXPORT_COMPATIBILITY.md`](docs/DATA_EXPORT_COMPATIBILITY.md:1)。
5. **模拟器 + 宿主机 TUN fake-ip 双重不可路由**：标准 DNS 返回 fake-ip（不经 TUN）+ DoH 解析真实 IP 后直连遭 TUN 干扰，此组合应用层无法修复。真机 TUN 代理因流量经 TUN 拦截故标准 DNS 路径有效，模拟器需调整代理 DNS 模式或将域名设为直连。

---

## 构建排障（Android）

### `Failed file name validation for file .../drawable/launch_image 2.png`

**症状**：`flutter run` / `flutter build apk` 在 `:app:parseDebugLocalResources` 任务失败，报错指向 `build/app/intermediates/packaged_res/debug/packageDebugResources/drawable/launch_image 2.png` 这类含空格的文件名。

**根因**：**不是源码问题**。源码 `android/app/src/main/res/` 命名完全合规；但 macOS Finder 复制（拖拽 / Command+D）会把副本命名为 `xxx 2.png`。若复制恰好发生在 Gradle 构建中间产物目录（`build/app/intermediates/packaged_res/...`），残留的 `xxx 2.png`（连同 `ic_launcher 2.png`、`values 2.xml`、`launch_background 2.xml` 等几十个副本）会在 AAPT2 增量构建时触发文件名合法性校验失败（Android 资源文件名只允许小写字母/数字/下划线/点）。

> **污染范围可深入 `.git/` 内部**（2026-08-15 实测 Builder 仓库 `.git/` 下清理出 80+ 个副本：`objects/xx/xxx 2`、`HEAD 2`、`config 2`、`refs/remotes/origin/HEAD 2`、pack 文件副本等），会导致 git 命令报 `fatal: bad object refs/remotes/origin/HEAD 2` / push 被拒。清理：`find .git -type f -name "* *" -delete`。此类副本与源码副本一样，均属 Finder 复制产生的冗余残留，删除安全。

> **污染源头（2026-08-15 全盘排查确认）**：workspace 位于 `~/Desktop/` 下，而本机开启了 **iCloud「桌面与文稿」同步**——`~/Desktop` 被 iCloud 完全接管（`bird`/`replicatord` 守护进程常驻）。iCloud 在多设备/多会话间合并桌面内容时，冲突副本以 `xxx 2` 命名（铁证：iCloud Desktop 同步目录同时存在 `桌面 - ProBook Mac` 与 `桌面 - ProBook Mac - 2` 两个内容不同的桌面版本文件夹）。workspace 内的 `.git/`、`build/`、源码目录、venv 全部处于同步范围，冲突合并时**每个文件都可能产生 ` 2` 副本**——这就是周期性（约 1–2 周一次、凌晨设备闲置充电时段）污染的根源。**根治：把 workspace 移出 `~/Desktop`（如 `~/Developer/Trans_Prism`）以脱离 iCloud 同步范围，或关闭 iCloud「桌面与文稿」同步；同时清理 iCloud 中的 `桌面 - ProBook Mac - 2` 冗余版本。**

**修复**：删除整个 `Trans-Prism/build/` 目录后重新构建即可——源码干净时全量重建（`flutter build apk --debug`）不会复现。排查时先确认源码目录无违规文件名：`find android -type f | grep -E "[ (（]"`。

**根治（已植入）**：[`android/app/build.gradle`](android/app/build.gradle:91) 内置自愈钩子任务 `cleanInvalidResourceNames`——每次构建开始（挂载于所有 `preBuild` 之前）自动递归删除 `build/` 与 `src/main/res` 下所有文件名含空格的副本文件，保证 AAPT2 永远看不到非法资源名。Finder 污染无论何时复发，下次构建都会自动自愈，无需手动删缓存。已实测验证：人为在 `packageDebugResources/drawable/` 放置 `launch_image 2.png` 后 `flutter build apk --debug` 依然成功，污染文件被钩子自动清除（日志输出 `TransPrism 自愈: 删除非法文件名副本 ...`）。

**预防**：勿在 `build/` 目录内使用 Finder 复制/移动文件（Finder 会把副本命名为 `xxx 2.xxx`）；即使误操作，自愈钩子会在下次构建时自动清理。

### 用药锚定提醒到点不触发（release APK 缺少 flutter_local_notifications Receiver 声明）

**症状**：设置「用药锚定提醒」后，到点**无通知、无声音、无振动**，logcat 无任何投递记录；但排程存在（`shared_prefs/scheduled_notifications.xml` 记录完整），`dumpsys alarm` 也能看到 `RTC_WAKEUP` 精确闹钟已入队、target 为 `com.daanser.transprism/com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver`，权限（POST_NOTIFICATIONS / SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM）全部 granted。

**根因**：**不是 manifest 合并或构建流程问题**。`flutter_local_notifications` 17.x 起，插件自身的 `AndroidManifest.xml` 只声明 `VIBRATE` / `POST_NOTIFICATIONS` 两个权限，**不再自带任何 Receiver**；官方 README「Scheduled notifications」要求宿主 App 在 `<application>` 内自行声明三个 Receiver。缺失时 `zonedSchedule()` 注册闹钟依然成功（AlarmManager 不校验目标组件是否存在），但到点系统广播找不到接收组件 → 通知静默失效。三个 Receiver 类始终在 `classes.dex` 中（插件 AAR 已编译），所以「类存在但 manifest 无声明」正是本缺陷特征。

**注意**：模拟器里「手动触发通知」走 `show()` 即时路径，不依赖静态 Receiver 声明，**测不出本缺陷**；必须测「等待闹钟到点自动触发」。

**修复（2026-09-08）**：在 [`android/app/src/main/AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml:67) 的 `<application>` 内补齐：
- `ScheduledNotificationReceiver`（闹钟到点接收器，`zonedSchedule` 的 PendingIntent 目标）
- `ScheduledNotificationBootReceiver`（`BOOT_COMPLETED` / `MY_PACKAGE_REPLACED` / `QUICKBOOT_POWERON`，开机与应用更新后由插件 `rescheduleNotifications()` 自动恢复排程）
- `ActionBroadcastReceiver`（通知按钮「已服药」/「5分钟后提醒」）

`android:exported` 一律为 `false`（与插件官方示例一致；**不要**按网上常见建议改成 `true`，无必要且扩大攻击面）。同时补齐 `USE_FULL_SCREEN_INTENT` 权限与 MainActivity 的 `android:showWhenLocked` / `android:turnScreenOn`——代码里 `AndroidNotificationDetails.fullScreenIntent=true`，Android 14+ 缺该权限会被静默降级为横幅。

**预防 / 验收**：升级 `flutter_local_notifications` 或改动 manifest 后，必须对 **release APK** 验证，而非模拟器手点通知：
```bash
aapt2 dump xmltree --file AndroidManifest.xml build/app/outputs/flutter-apk/app-release.apk | grep dexterous
```
应列出上述三个 Receiver。

**兜底（已植入）**：部分 OEM（HyperOS / MIUI 等）在进程被清理、强停或省电策略介入时会移除 AlarmManager 中的闹钟且不回调 App。[`NotificationService.restoreMissingSchedules()`](lib/services/notification_service.dart:477) 在每次启动时对账「待处理通知 ID vs 未来到点的启用中药物」，缺失即补挂（`zonedSchedule` 同 ID 覆盖写，幂等），由 [`main.dart`](lib/main.dart:734) `_initNotifications()` 调用。

---

## CI/CD

本仓库只有一个 GitHub Actions 工作流：

### [`sync_app_to_r2.yml`](.github/workflows/sync_app_to_r2.yml)

| 属性 | 值 |
|------|-----|
| **触发条件** | `release: [published]` 或 `workflow_dispatch`（手动） |
| **运行环境** | `ubuntu-latest` |
| **职责** | Release 产物镜像到 Cloudflare R2 并生成版本索引 |

**执行流程**：
1. `🗂️ 检出代码库` — `actions/checkout@v4`
2. `🚀 拉取、生成索引并同步 App`（单一步骤内完成）：
   - 下载指定 Release 的全部 assets 到 `release_assets/`
   - **🔐 计算 APK SHA-256 校验和**：遍历所有 `.apk` 文件，用 `sha256sum` 计算哈希值，生成 `${apk}.sha256` 文件，通过 `gh release upload` 上传回 GitHub Release
   - 归档到 R2 `/app/releases/{tag}/`
   - 清理 R2 `/app/latest/` 下的旧版 APK
   - 生成 `latest.json`（含 `latest_file` / `tag` / `update_time` / **可选** `release_notes`——GitHub Release body 更新内容，客户端 [`UpdateService`](lib/services/update_service.dart:53) 解析后由 [`UpdateDialog`](lib/widgets/update_dialog.dart:8) 展示）
   - 同步到 R2 `/app/latest/`
3. `🧹 清理 R2 历史版本` — 仅保留最近 5 个 Release 在 R2 上

---

## 许可模型

> 完整的许可证文本与法律条款见 [`LICENSE`](LICENSE)。本仓库采用**复合授权（Composite Licensing）**模式。

| 组件 | 许可证 | 说明 |
|------|--------|------|
| 原创 Dart/Flutter 源码（`lib/`、`android/`、`ios/` 等） | **Apache License 2.0** | 允许商业使用、修改、分发，须保留版权声明 |
| PK 计算引擎（`assets/hrt_tracker/`，WebView JS） | **MIT License** | 衍生自 Oyama's HRT Recorder |
| 内置知识库内容（MtF/FtM/RLE Wiki） | **CC BY-SA 4.0** | Project Trans 系，修改后须相同方式共享 |
| MioMtFWiki 内容 | **CC BY-ND 4.0** | **禁止修改后再次发布** |
| 激素换算器 & 罩杯计算器算法 | **CC BY-SA 4.0** | 衍生自 MtF.wiki 及网络公开资料 |
| SVG 图标资源（`assets/svg_resources/`） | 各自原始许可 | Twemoji(CC-BY) / OpenMoji(CC BY-SA) / Noto(Apache 2.0) |
| 第三方依赖（pubspec.yaml） | 各自许可 | MIT / BSD / Apache 2.0 等 |

**贡献者须知**：向本仓库提交的原创代码贡献，将被视为按 Apache License 2.0 条款授权。
