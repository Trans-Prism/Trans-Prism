import 'package:shared_preferences/shared_preferences.dart';

/// =============================================================================
/// HomeModuleVisibility — 首页模块可见性管理器
///
/// 使用 SharedPreferences 持久化用户对首页各模块的显示偏好。
/// 每个模块有一个唯一的 String key，对应一个 bool 值（true=显示）。
///
/// 首次启动时，默认开启 5 个最核心模块，其余默认关闭，
/// 确保首页初次展示时内容丰富且排版充实。
/// =============================================================================
class HomeModuleVisibility {
  HomeModuleVisibility._();

  // ── 模块 Key 常量 ──
  static const String keyGreeting = 'home_module_greeting';
  static const String keyMedStock = 'home_module_med_stock';
  static const String keyPkSim = 'home_module_pk_sim';
  static const String keyVoiceTraining = 'home_module_voice_training';
  static const String keyMedicalDirectory = 'home_module_medical_directory';
  static const String keySvgLibrary = 'home_module_svg_library';
  static const String keyImageConverter = 'home_module_image_converter';
  static const String keyHormoneConverter = 'home_module_hormone_converter';

  /// SP 初始化标记 Key（无此标记即为首次启动）
  static const String _initFlagKey = 'home_modules_initialized';

  /// 所有模块的 key 列表，用于遍历
  static const List<String> allKeys = [
    keyGreeting,
    keyMedStock,
    keyPkSim,
    keyVoiceTraining,
    keyMedicalDirectory,
    keySvgLibrary,
    keyImageConverter,
    keyHormoneConverter,
  ];

  /// 5 个核心模块（首次启动默认开启）
  static const Set<String> coreKeys = {
    keyGreeting,
    keyMedStock,
    keyPkSim,
    keyVoiceTraining,
    keyMedicalDirectory,
  };

  /// 模块显示名称映射
  static const Map<String, String> moduleLabels = {
    keyGreeting: '问候语',
    keyMedStock: '药物存量',
    keyPkSim: '血药浓度模拟',
    keyVoiceTraining: '声音训练',
    keyMedicalDirectory: '友善医疗名录',
    keySvgLibrary: '图解资源 (SVG库)',
    keyImageConverter: '图片格式转换',
    keyHormoneConverter: '激素换算器',
  };

  /// 模块图标映射
  static const Map<String, String> moduleIcons = {
    keyGreeting: '👋',
    keyMedStock: '💊',
    keyPkSim: '📈',
    keyVoiceTraining: '🎤',
    keyMedicalDirectory: '🏥',
    keySvgLibrary: '🖼️',
    keyImageConverter: '🔄',
    keyHormoneConverter: '⚖️',
  };

  /// 从 SharedPreferences 读取所有模块可见性。
  ///
  /// 首次启动（无初始化标记）时：
  ///   - 5 个核心模块 → true
  ///   - 其余模块 → false
  /// 并写入标记，后续读取全部依赖 SP 中已存储的值。
  static Future<Map<String, bool>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final isInitialized = prefs.getBool(_initFlagKey) == true;
    final map = <String, bool>{};

    if (isInitialized) {
      // 已有配置：读取 SP 值，缺失的 key 按非核心处理 → false
      for (final key in allKeys) {
        map[key] = prefs.getBool(key) ?? false;
      }
    } else {
      // 首次启动：核心开启，其余关闭，并写入标记
      for (final key in allKeys) {
        final defaultValue = coreKeys.contains(key);
        map[key] = defaultValue;
        await prefs.setBool(key, defaultValue);
      }
      await prefs.setBool(_initFlagKey, true);
    }

    return map;
  }

  /// 保存单个模块的可见性
  static Future<void> save(String key, bool visible) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, visible);
  }

  /// 批量保存所有模块的可见性
  static Future<void> saveAll(Map<String, bool> visibility) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in visibility.entries) {
      await prefs.setBool(entry.key, entry.value);
    }
  }

  /// 重置所有模块为核心默认值
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in allKeys) {
      await prefs.setBool(key, coreKeys.contains(key));
    }
  }
}
