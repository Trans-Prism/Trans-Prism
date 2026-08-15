# TODO List - Trans Prism

## 📋 待做清单

### 🔴 高优先级

- [ ] 统一数据备份导出/导入（主应用 + Oyama HRT Tracker PK 数据合并）
  - **现状**：需分两步分别导出/导入主应用数据（SharedPreferences）与 PK 模拟数据（WebView localStorage），体验割裂
  - **根因**：PK 数据在 WebView `localStorage` 中（绑定 `localhost:{port}` origin，默认 53140、可配置），跨 Dart/JS 边界提取依赖 React fiber 树遍历，存在竞态条件与版本脆弱性
  - **修复方案**：详见 [`docs/DATA_EXPORT_COMPATIBILITY.md`](docs/DATA_EXPORT_COMPATIBILITY.md)

- [ ] [HRT TransMTF](https://hrt.transmtf.com/) 的 Web 接入及离线版构建
  - WebView 集成
  - 离线资源缓存策略
  - 离线版本构建与加载

- [ ] [HRT TransMTF](https://hrt.transmtf.com/) 与 [HRT Mahiro](https://hrt.mahiro.uk/) 自由选择切换功能
  - 多源配置管理
  - 切换 UI/UX
  - 状态持久化

- [ ] [Lycoris Maps](https://lycoris.online/maps) 接入及离线版构建
  - 地图 WebView 集成
  - 离线瓦片缓存
  - 离线版本构建与加载

### 🟡 中优先级

- [ ] [TransCircle](https://transcircle.org/) 接入及离线版构建（等待开源许可确认）
  - 确认项目开源许可证
  - WebView 集成
  - 离线版本构建与加载

### 🟢 远期规划

- [ ] 用药提醒 & HRT Tracker 等功能数据同步
  - 用药提醒功能
  - HRT Tracker 数据同步
  - 跨设备/平台数据一致性

- [ ] 友好医疗信息页面完善
  - 友好医疗机构/医生数据库
  - 地区筛选与搜索
  - 用户评价与反馈机制

---

> 最后更新: 2026-07-28
